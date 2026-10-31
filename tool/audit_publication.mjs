// Dependency-free, value-redacting audit. Never writes to the application's .git.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = path.resolve(import.meta.dirname, '..');
const staged = process.argv.includes('--staged');
const hasGit = fs.existsSync(path.join(root, '.git'));
const findings = [];
let temporary;
const report = (file, rule) => findings.push({ file: file.replaceAll('\\', '/'), rule });
function git(args, options = {}) {
  const result = spawnSync('git', args, { cwd: root, maxBuffer: 32 * 1024 * 1024, ...options });
  if (result.error || result.status !== 0) throw new Error('Git audit command failed; no command output or private values displayed.');
  return result.stdout;
}
try {
  if (staged && !hasGit) throw new Error('There is no application Git repository yet. Run the staged audit only after approved initialization and staging.');
  if (!hasGit) {
    temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'moda-publication-audit-'));
    git(['init', '-q', temporary]);
  }
  const prefix = temporary ? [`--git-dir=${path.join(temporary, '.git')}`, `--work-tree=${root}`] : [];
  const list = args => git([...prefix, ...args]).toString('utf8').split('\0').filter(Boolean);
  const files = staged
    ? list(['diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z'])
    : [...new Set([...list(['ls-files', '--cached', '-z']), ...list(['ls-files', '--others', '--exclude-standard', '-z'])])];

  // Check actual private values for accidental duplication without ever reporting them.
  const privateValues = new Set();
  let privateEnvFiles = 0;
  for (const directory of ['', 'backend']) {
    if (!fs.existsSync(path.join(root, directory))) continue;
    for (const name of fs.readdirSync(path.join(root, directory))) {
      if (!/^\.env(?:\.|$)/.test(name) || name.endsWith('.example')) continue;
      const full = path.join(root, directory, name);
      if (!fs.statSync(full).isFile()) continue;
      privateEnvFiles++;
      for (const line of fs.readFileSync(full, 'utf8').split(/\r?\n/)) {
        const match = /^\s*([A-Z_0-9]+)\s*=\s*(.*?)\s*$/.exec(line);
        if (!match || !/(?:SECRET|PASSWORD|API_KEY|ACCESS_TOKEN|PRIVATE_KEY|DATABASE_URL|CONNECTION_STRING)$/.test(match[1])) continue;
        const value = match[2].replace(/^(['"])(.*)\1(?:\s*#.*)?$/, '$2').replace(/\s+#.*$/, '');
        if (value.length >= 8 && !/^(?:replace|change_me|placeholder|your_|test[-_])/i.test(value)) privateValues.add(value);
      }
    }
  }

  const forbidden = file => /(?:^|\/)(?:\.env(?:\..*)?|local\.properties|key\.properties)$/.test(file) && !file.endsWith('.example')
    || /\.(?:log|pem|key|jks|keystore|p12|pfx|mobileprovision|db|sqlite3?|dump|backup|apk|aab)$/i.test(file)
    || /(?:^|\/)(?:node_modules|pgdata|postgres-data|backups|dumps)\//.test(file)
    || /\.sql$/i.test(file) && !file.startsWith('backend/prisma/migrations/');
  const patterns = [
    ['private-key', /-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/],
    ['provider-token', /\b(?:sk-[A-Za-z0-9_-]{20,}|re_[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{40,})\b/],
    ['embedded-jwt', /\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{16,}\b/],
    ['machine-local-path', /[A-Za-z]:[\\/](?:Users|Program Files|Android|flutter|src)[\\/][^\s"'`]+/i],
  ];
  const binary = /\.(?:png|jpe?g|webp|gif|ico|jar|ttf|otf|woff2?|pdf)$/i;
  const replacementPath = path.join(root, 'assets/images/PUBLICATION_REPLACEMENTS.json');
  const replacements = fs.existsSync(replacementPath) ? JSON.parse(fs.readFileSync(replacementPath, 'utf8')) : {};
  const retiredHashes = new Set([...(replacements.replacements ?? []), ...(replacements.screenshots ?? [])].map(row => row.previousSha256).filter(Boolean));
  let textFiles = 0;
  for (const file of files) {
    if (forbidden(file)) report(file, 'private-or-generated-file-is-publishable');
    if (binary.test(file)) {
      const full = path.join(root, file);
      if (!staged && !fs.existsSync(full)) continue;
      if (!staged && fs.lstatSync(full).isSymbolicLink()) { report(file, 'review-symbolic-link'); continue; }
      const bytes = staged ? git(['show', `:${file}`]) : fs.readFileSync(full);
      if (retiredHashes.has(createHash('sha256').update(bytes).digest('hex'))) report(file, 'retired-unverified-asset');
      continue;
    }
    const full = path.join(root, file);
    if (!staged && !fs.existsSync(full)) continue;
    if (!staged && fs.lstatSync(full).isSymbolicLink()) { report(file, 'review-symbolic-link'); continue; }
    const bytes = staged ? git(['show', `:${file}`]) : fs.readFileSync(full);
    if (bytes.includes(0)) { report(file, 'unexpected-binary-review'); continue; }
    const text = bytes.toString('utf8');
    textFiles++;
    if ([...privateValues].some(value => text.includes(value))) report(file, 'matches-private-environment-value');
    for (const [rule, pattern] of patterns) if (pattern.test(text)) report(file, rule);
    if (/(?:^|\/)\.env(?:\..*)?\.example$/.test(file) || file.endsWith('/.env.example')) {
      for (const line of text.split(/\r?\n/)) {
        const setting = /^\s*([A-Z_0-9]+)\s*=\s*(.*?)\s*$/.exec(line);
        if (!setting || !/(?:SECRET|PASSWORD|API_KEY|ACCESS_TOKEN|PRIVATE_KEY)$/.test(setting[1])) continue;
        const value = setting[2].replace(/^(['"])(.*)\1$/, '$2');
        if (value && !/^(?:replace|change_me|placeholder|your_|<)/i.test(value)) report(file, 'populated-secret-example');
      }
    }
    for (const match of text.matchAll(/\bpostgres(?:ql)?:\/\/([^\s/:]+):([^\s@]+)@([^\s/'"]+)/g)) {
      if (!/^(?:replace_me|placeholder|test|password|postgres|test_password)$/.test(match[2]) || !/^(?:localhost|127\.0\.0\.1|db)(?::\d+)?$/.test(match[3])) report(file, 'credentialed-database-url-review');
    }
    for (const match of text.matchAll(/[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g)) {
      const domain = match[1].toLowerCase();
      if (!/(?:^|\.)(?:example\.(?:com|org|net)|test|invalid|example)$/.test(domain) && domain !== 'resend.dev') report(file, 'non-example-email-review');
    }
  }
  const probes = ['backend/.env', '.env', 'backend/.env.local', 'android/local.properties', 'android/key.properties', 'private.pem', 'signing.jks', 'backend/customer-data.dump', 'backend/backup.sql', 'local.sqlite', 'backend/server.log', 'backend/node_modules/package/index.js', 'build/app.apk', 'tool/generated_photo_sources.json', 'tool/photo_reframe_sources.json'];
  const ignoreResult = spawnSync('git', [...prefix, 'check-ignore', '--no-index', '--stdin'], { cwd: root, input: probes.join('\n') + '\n', encoding: 'utf8' });
  if (ignoreResult.error || ![0, 1].includes(ignoreResult.status)) throw new Error('Git ignore verification failed.');
  const ignored = new Set(ignoreResult.stdout.trim().split(/\r?\n/));
  for (const probe of probes) if (!ignored.has(probe)) report(probe, 'required-ignore-rule-missing');
  const unique = [...new Map(findings.map(f => [`${f.file}:${f.rule}`, f])).values()];
  console.log(JSON.stringify({ mode: staged ? 'staged-index' : hasGit ? 'tracked-and-unignored-worktree' : 'publishable-candidates-with-temporary-git-metadata', applicationGitInitialized: hasGit, publishableFiles: files.length, textFilesScanned: textFiles, privateEnvFilesChecked: privateEnvFiles, ignoreProbesPassed: probes.length - probes.filter(p => !ignored.has(p)).length, findings: unique }, null, 2));
  if (process.argv.includes('--inventory') && !unique.length) {
    const destination = path.join(root, 'build', 'publication-inventory.json');
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, JSON.stringify(files, null, 2) + '\n');
  }
  if (unique.length) process.exitCode = 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (temporary) {
    const resolved = path.resolve(temporary);
    const allowed = path.resolve(os.tmpdir()) + path.sep;
    if (!resolved.startsWith(allowed) || !path.basename(resolved).startsWith('moda-publication-audit-')) throw new Error('Temporary audit cleanup path rejected.');
    fs.rmSync(resolved, { recursive: true, force: true });
  }
}

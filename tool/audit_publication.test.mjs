import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomBytes, createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
function fixture() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'moda-audit-test-'));
  fs.mkdirSync(path.join(directory, 'tool'));
  fs.copyFileSync(path.join(root, 'tool/audit_publication.mjs'), path.join(directory, 'tool/audit_publication.mjs'));
  fs.copyFileSync(path.join(root, '.gitignore'), path.join(directory, '.gitignore'));
  const secret = randomBytes(32).toString('hex');
  fs.writeFileSync(path.join(directory, '.env'), `JWT_SECRET=${secret}\n`);
  return { directory, secret };
}
function cleanup(directory) {
  const resolved = path.resolve(directory);
  assert.ok(resolved.startsWith(path.resolve(os.tmpdir()) + path.sep));
  assert.ok(path.basename(resolved).startsWith('moda-audit-test-'));
  fs.rmSync(resolved, { recursive: true, force: true });
}
function audit(directory, args = []) {
  return spawnSync(process.execPath, ['tool/audit_publication.mjs', ...args], { cwd: directory, encoding: 'utf8' });
}

test('Retired unverified photo bytes cannot re-enter under a different public filename', () => {
  const {directory} = fixture();
  try {
    const oldBytes = randomBytes(64);
    fs.mkdirSync(path.join(directory,'assets/images'),{recursive:true});
    fs.writeFileSync(path.join(directory,'assets/images/PUBLICATION_REPLACEMENTS.json'),JSON.stringify({replacements:[{previousSha256:createHash('sha256').update(oldBytes).digest('hex')}]}));
    fs.writeFileSync(path.join(directory,'renamed-photo.png'),oldBytes);
    const result=audit(directory);
    assert.equal(result.status,1);
    assert.ok(JSON.parse(result.stdout).findings.some(f=>f.file==='renamed-photo.png'&&f.rule==='retired-unverified-asset'));
  } finally {cleanup(directory);}
});

test('Private configuration is excluded without initializing the application repository', () => {
  const { directory, secret } = fixture();
  try {
    const result = audit(directory);
    assert.equal(result.status, 0);
    assert.equal(JSON.parse(result.stdout).ignoreProbesPassed, 15);
    assert.equal(fs.existsSync(path.join(directory, '.git')), false);
    assert.equal(result.stdout.includes(secret), false);
  } finally { cleanup(directory); }
});

test('A private value copied into public source is detected without exposing it', () => {
  const { directory, secret } = fixture();
  try {
    fs.writeFileSync(path.join(directory, 'accidental-copy.txt'), secret);
    const result = audit(directory);
    assert.equal(result.status, 1);
    assert.ok(JSON.parse(result.stdout).findings.some(f => f.rule === 'matches-private-environment-value'));
    assert.equal(result.stdout.includes(secret), false);
  } finally { cleanup(directory); }
});

test('A force-staged ignored credential file is still rejected by the staged audit', () => {
  const { directory, secret } = fixture();
  try {
    assert.equal(spawnSync('git', ['init', '-q'], { cwd: directory }).status, 0);
    assert.equal(spawnSync('git', ['add', '-f', '.env'], { cwd: directory }).status, 0);
    const result = audit(directory, ['--staged']);
    assert.equal(result.status, 1);
    assert.ok(JSON.parse(result.stdout).findings.some(f => f.file === '.env' && f.rule === 'private-or-generated-file-is-publishable'));
    assert.equal(result.stdout.includes(secret), false);
  } finally { cleanup(directory); }
});

test('Examples reject non-placeholder secrets even when they differ from the local configuration', () => {
  const { directory } = fixture();
  const unrelated = randomBytes(32).toString('hex');
  try {
    fs.writeFileSync(path.join(directory, '.env.example'), `JWT_SECRET=${unrelated}\n`);
    const result = audit(directory);
    assert.equal(result.status, 1);
    assert.ok(JSON.parse(result.stdout).findings.some(f => f.rule === 'populated-secret-example'));
    assert.equal(result.stdout.includes(unrelated), false);
  } finally { cleanup(directory); }
});

import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path) : path.endsWith('.js') ? [path] : [];
  });
}
for (const file of ['prisma.config.js', ...['src', 'prisma', 'scripts', 'test'].flatMap(files)]) {
  const result = spawnSync(process.execPath, ['--check', file], { stdio: 'inherit' });
  if (result.error || result.status !== 0) process.exit(1);
}
console.log('JavaScript syntax checks passed.');


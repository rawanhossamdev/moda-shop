import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { verificationEmail, passwordResetEmail } from '../src/emails/templates.js';

// Fixture-only preview. No .env, provider, database, account or real code access.
const directory = new URL('../../build/email-previews/', import.meta.url);
await mkdir(directory, { recursive: true });
for (const [name, email] of [
  ['verification', verificationEmail('000000')],
  ['password-reset', passwordResetEmail('preview'.padEnd(43, 'x'))],
]) {
  await writeFile(new URL(`${name}.html`, directory), email.html, 'utf8');
  await writeFile(new URL(`${name}.txt`, directory), email.text, 'utf8');
}
console.log(`Fixture-only email previews written to ${fileURLToPath(directory)}. No email sent.`);

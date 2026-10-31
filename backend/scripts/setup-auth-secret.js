import { randomBytes } from 'node:crypto';
import { readFileSync, appendFileSync, existsSync } from 'node:fs';
import { parse } from 'dotenv';
import { readAuthConfig } from '../src/config/env.js';

if (!existsSync('.env')) {
  console.error('Copy .env.example to your private .env and configure DATABASE_URL first.');
  process.exitCode = 1;
} else {
  const values = parse(readFileSync('.env'));
  if (values.JWT_SECRET) {
    try {
      readAuthConfig({ ...values, JWT_TTL_SECONDS: values.JWT_TTL_SECONDS ?? '604800' });
      console.log('Existing private JWT_SECRET is valid and was preserved.');
    } catch {
      console.error('Existing JWT configuration is invalid. Update it privately; no secret was replaced.');
      process.exitCode = 1;
    }
  } else if (process.env.JWT_SECRET) {
    console.error('JWT_SECRET is supplied externally. Remove the override or configure .env privately; nothing was overwritten.');
    process.exitCode = 1;
  } else {
    appendFileSync('.env', '\nJWT_SECRET=' + randomBytes(48).toString('base64url') + '\n');
    console.log('Generated JWT_SECRET in private backend/.env. Its value is not displayed.');
  }
}

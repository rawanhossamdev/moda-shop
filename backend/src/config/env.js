import 'dotenv/config';

export function readEnvironment(source = process.env) {
  const port = Number(source.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }
  const nodeEnv = source.NODE_ENV ?? 'development';
  if (!['development', 'test', 'production'].includes(nodeEnv)) {
    throw new Error('NODE_ENV must be development, test, or production.');
  }
  return { port, host: source.HOST ?? '127.0.0.1', nodeEnv };
}

export function requireDatabaseUrl(source = process.env) {
  const value = source.DATABASE_URL;
  if (!value) throw new Error('DATABASE_URL is required. Copy .env.example to .env and configure PostgreSQL.');
  let url;
  try { url = new URL(value); } catch { throw new Error('DATABASE_URL must be a valid PostgreSQL URL.'); }
  if (!['postgres:', 'postgresql:'].includes(url.protocol)) {
    throw new Error('DATABASE_URL must use the postgres:// or postgresql:// protocol.');
  }
  return value;
}

export function readAuthConfig(source = process.env) {
  const secret = source.JWT_SECRET;
  if (typeof secret !== 'string' || Buffer.byteLength(secret, 'utf8') < 32 || /^(replace|change_me|changeme)/i.test(secret)) {
    throw new Error('JWT_SECRET must be a private random secret of at least 32 bytes. Run npm run auth:secret.');
  }
  const ttlSeconds = Number(source.JWT_TTL_SECONDS ?? 604800);
  if (!Number.isInteger(ttlSeconds) || ttlSeconds < 300 || ttlSeconds > 604800) {
    throw new Error('JWT_TTL_SECONDS must be an integer from 300 through 604800.');
  }
  return { secret, ttlSeconds, issuer: 'moda-shop-api', audience: 'moda-shop-app' };
}


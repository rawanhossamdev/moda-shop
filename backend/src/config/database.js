import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { requireDatabaseUrl } from './env.js';

let client;
export function getDatabase() {
  client ??= new PrismaClient({
    adapter: new PrismaPg({ connectionString: requireDatabaseUrl(), connectionTimeoutMillis: 5000 }),
  });
  return client;
}

export async function disconnectDatabase() {
  if (client) {
    await client.$disconnect();
    client = undefined;
  }
}


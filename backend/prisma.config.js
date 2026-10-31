import 'dotenv/config';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations', seed: 'node prisma/seed.js' },
  // Validation and generation work offline. Database commands require a real URL.
  datasource: { url: process.env.DATABASE_URL ?? '' },
});


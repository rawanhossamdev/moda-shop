import { getDatabase, disconnectDatabase } from '../src/config/database.js';

try {
  await getDatabase().$queryRaw`SELECT 1`;
  console.log('PostgreSQL connection succeeded.');
} catch (error) {
  const reason = error.message?.startsWith('DATABASE_URL ')
    ? error.message
    : `Verify DATABASE_URL and PostgreSQL availability (${error.code ?? error.name}).`;
  console.error(`Database check failed: ${reason}`);
  process.exitCode = 1;
} finally {
  await disconnectDatabase();
}


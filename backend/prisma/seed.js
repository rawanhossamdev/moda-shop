import { getDatabase, disconnectDatabase } from '../src/config/database.js';
import { seedCatalog } from './seed-catalog.js';
try {
  const result = await getDatabase().$transaction(seedCatalog, { timeout: 60000 });
  console.log(`Catalog seed completed: ${result.products} demo products, ${result.categories} categories; existing owner data preserved.`);
} catch (error) {
  console.error(`Catalog seed failed (${error.code ?? error.name}). Check local migrations; no private data printed.`);
  process.exitCode = 1;
} finally { await disconnectDatabase(); }

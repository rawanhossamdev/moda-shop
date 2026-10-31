import { createApp } from './app.js';
import { readEnvironment, readAuthConfig } from './config/env.js';
import { disconnectDatabase } from './config/database.js';

const { port, host } = readEnvironment();
readAuthConfig();
const server = createApp().listen(port, host, () => {
  console.log(`MODA API listening at http://${host}:${port}`);
});
server.on('error', (error) => {
  console.error(error.code === 'EADDRINUSE' ? 'PORT is already in use.' : 'Unable to start the HTTP server.');
  process.exitCode = 1;
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => {
    server.close(async () => {
      await disconnectDatabase();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
}


import 'dotenv/config';
import { createApp } from './app.js';
import { initPersistence, closePersistence } from './config/persistence.js';

const app = createApp();
const port = process.env.PORT || 4000;

async function start() {
  const where = await initPersistence();
  console.log(`[persist] data stored in: ${where}`);
  if (!process.env.JWT_SECRET) {
    console.log('[auth] JWT_SECRET not set — using a generated secret saved with the data');
  }
  const server = app.listen(port, () => {
    console.log(`FamilyGuard backend listening on http://localhost:${port}`);
  });

  const shutdown = async (signal) => {
    console.log(`[server] ${signal} — saving and shutting down`);
    server.close();
    try {
      await closePersistence();
    } catch (err) {
      console.error('[persist] final save failed:', err.message);
    }
    process.exit(0);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start().catch((err) => {
  console.error('[server] failed to start:', err.message);
  process.exit(1);
});

import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { registerRoutes } from './routes.js';
import { errorHandler } from './middleware/errorHandler.js';
import { initPersistence, scheduleSave, closePersistence } from './config/persistence.js';

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Any request may change state (writes, device heartbeats): save shortly after.
app.use((req, res, next) => {
  res.on('finish', scheduleSave);
  next();
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'familyguard-backend' });
});

// All feature modules are wired up here.
registerRoutes(app);

// Centralised error handling (must be last).
app.use(errorHandler);

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

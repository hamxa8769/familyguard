import express from 'express';
import cors from 'cors';
import { registerRoutes } from './routes.js';
import { errorHandler } from './middleware/errorHandler.js';
import { scheduleSave } from './config/persistence.js';

// Extracted from index.js so tests can start the app on a random port
// without the module binding a real one on import.
export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '5mb' }));

  // Any request may change state (writes, device heartbeats): save shortly
  // after (persistence layer, v0.8.0).
  app.use((req, res, next) => {
    res.on('finish', scheduleSave);
    next();
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'familyguard-backend' });
  });
  registerRoutes(app);
  app.use(errorHandler);
  return app;
}

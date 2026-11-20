import express from 'express';
import cors from 'cors';
import { registerRoutes } from './routes.js';
import { errorHandler } from './middleware/errorHandler.js';

// Extracted from index.js so tests can start the app on a random port
// without the module binding a real one on import.
export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'familyguard-backend' });
  });
  registerRoutes(app);
  app.use(errorHandler);
  return app;
}

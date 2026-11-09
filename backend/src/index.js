import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { registerRoutes } from './routes.js';
import { errorHandler } from './middleware/errorHandler.js';

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'familyguard-backend' });
});

// All feature modules are wired up here.
registerRoutes(app);

// Centralised error handling (must be last).
app.use(errorHandler);

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`FamilyGuard backend listening on http://localhost:${port}`);
});

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { access, constants } from 'node:fs/promises';
import { registerRoutes } from './routes.js';
import { errorHandler } from './middleware/errorHandler.js';
import { rateLimit } from './middleware/rateLimit.js';
import { scheduleSave } from './config/persistence.js';
import { pool } from './config/db.js';

// Extracted from index.js so tests can start the app on a random port
// without the module binding a real one on import.
export function createApp() {
  const app = express();

  // Behind a proxy (laptop tunnel, reverse proxy) req.ip must be the real
  // client IP, or every user shares one rate-limit bucket.
  app.set('trust proxy', 1);

  // Security headers.
  app.use(helmet());

  // Request logging (morgan 'tiny': method, path, status, time, size).
  app.use(morgan('tiny'));

  // Restricted CORS (Phase 5): requests with no Origin (native mobile
  // apps, curl) are always allowed. Browser origins must be listed in
  // ALLOWED_ORIGINS when it is set; when unset, any origin is allowed
  // but a startup warning is logged once.
  const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  let warnedCors = false;
  app.use(
    cors({
      origin: (origin, cb) => {
        if (!origin) return cb(null, true);
        if (allowedOrigins.length === 0) {
          if (!warnedCors) {
            warnedCors = true;
            console.warn(
              '[cors] ALLOWED_ORIGINS is not set — allowing any browser origin. ' +
                'Set ALLOWED_ORIGINS to a comma-separated list to restrict it.',
            );
          }
          return cb(null, true);
        }
        return allowedOrigins.includes(origin)
          ? cb(null, true)
          : cb(new Error('Not allowed by CORS'));
      },
    }),
  );

  // 12 MB: media uploads are base64-in-JSON and the cap is 8 MB of file
  // bytes (~10.7 MB encoded), so a 5 MB limit rejected legal uploads
  // before the controller's 413 check ever ran.
  app.use(express.json({ limit: '12mb' }));

  // Global rate limit (Phase 5): generous — 1000 requests per 15 minutes
  // per IP. The child's 60 s version check + 15-min sync cadence is far
  // below this; the stricter per-route auth limiter still applies to
  // login/register/pairing.
  app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 1000 }));

  // Any request may change state (writes, device heartbeats): save shortly
  // after (persistence layer, v0.8.0).
  app.use((req, res, next) => {
    res.on('finish', scheduleSave);
    next();
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'familyguard-backend' });
  });

  // Readiness: a real check, not just "the process is up". Postgres mode
  // runs SELECT 1; file mode checks the data file is readable (a missing
  // file on first run is fine — nothing has been saved yet); memory mode
  // (tests) has nothing to check.
  app.get('/health/ready', async (_req, res) => {
    if (process.env.DATABASE_URL && pool) {
      try {
        await pool.query('SELECT 1');
        return res.json({ status: 'ok', db: 'postgres' });
      } catch (err) {
        return res
          .status(503)
          .json({ status: 'degraded', db: 'postgres', error: err.message });
      }
    }
    if (process.env.PERSIST === 'memory') {
      return res.json({ status: 'ok', db: 'memory' });
    }
    const dataFile = process.env.DATA_FILE || './data/familyguard.json';
    try {
      await access(dataFile, constants.R_OK);
      return res.json({ status: 'ok', db: 'file', dataFile });
    } catch (err) {
      if (err.code === 'ENOENT') {
        return res.json({ status: 'ok', db: 'file', dataFile, note: 'no data file yet' });
      }
      return res
        .status(503)
        .json({ status: 'degraded', db: 'file', dataFile, error: err.message });
    }
  });

  registerRoutes(app);

  // JSON 404 catch-all: unknown routes return { error, code }, never
  // Express's default HTML 404 page.
  app.use((req, res) => {
    res.status(404).json({ error: `Not found: ${req.method} ${req.path}`, code: 'not_found' });
  });

  app.use(errorHandler);
  return app;
}

import crypto from 'node:crypto';
import { store } from './store.js';

// JWT signing secret: JWT_SECRET from the environment, otherwise a random one
// generated on first start and saved with the data (so tokens survive restarts
// and no shared default secret exists).
export function jwtSecret() {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  if (!store.meta.jwtSecret) {
    store.meta.jwtSecret = crypto.randomBytes(48).toString('base64url');
  }
  return store.meta.jwtSecret;
}

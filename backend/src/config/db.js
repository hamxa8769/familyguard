// Thin Postgres pool wrapper. In the MVP you can start with an in-memory
// fallback (see store.js) and switch to this once Postgres is set up.
import pg from 'pg';

const { Pool } = pg;

export const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL })
  : null;

export async function query(text, params) {
  if (!pool) {
    throw new Error('DATABASE_URL not set — configure Postgres or use the in-memory store.');
  }
  return pool.query(text, params);
}

#!/usr/bin/env node
// Minimal migration runner: applies backend/src/db/migrations/*.sql in
// filename order, tracking applied versions in schema_migrations.
// Usage:  npm run db:migrate        (requires DATABASE_URL in .env)
import 'dotenv/config';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import pg from 'pg';

const dir = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.join(dir, 'migrations');

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL is not set — see backend/.env.example.');
  process.exit(1);
}

const pool = new pg.Pool({ connectionString: databaseUrl });

try {
  const files = readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  if (files.length === 0) {
    console.log('No migrations found.');
    process.exit(0);
  }
  for (const file of files) {
    const version = file.replace(/\.sql$/, '');
    const { rows } = await pool.query(
      'SELECT 1 FROM schema_migrations WHERE version = $1',
      [version],
    ).catch(async (err) => {
      // schema_migrations itself may not exist on the very first run.
      if (err.code === '42P01') {
        await pool.query(
          `CREATE TABLE IF NOT EXISTS schema_migrations (
             version TEXT PRIMARY KEY,
             applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
           )`,
        );
        return { rows: [] };
      }
      throw err;
    });
    if (rows.length > 0) {
      console.log(`Skipping already-applied migration ${version}`);
      continue;
    }
    const sql = readFileSync(path.join(migrationsDir, file), 'utf8');
    await pool.query(sql);
    await pool.query(
      'INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING',
      [version],
    );
    console.log(`Applied migration ${version}`);
  }
  console.log('Migrations complete.');
} finally {
  await pool.end();
}

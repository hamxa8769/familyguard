// Persistence for the in-process store.
//
// The API modules work on `store` (fast, simple). This layer makes that state
// survive restarts:
//   - DATABASE_URL set  → PostgreSQL: one JSONB row per collection (fg_state).
//   - otherwise         → a JSON file (DATA_FILE, default ./data/familyguard.json).
//   - PERSIST=memory    → nothing is saved (tests / throwaway demos).
//
// Writes are debounced and only changed collections are written. This suits
// one server instance and family-scale data; a normalised schema is the next
// step if it ever needs to scale out.
import fs from 'node:fs/promises';
import path from 'node:path';
import pg from 'pg';
import { store, getCounter, setCounter } from './store.js';

const SAVE_DELAY_MS = 800;
const COUNTER_KEY = '__counter';

let driver = null;
let timer = null;
let saving = Promise.resolve();
const lastWritten = new Map(); // collection -> JSON string last persisted

// ---- Drivers ---------------------------------------------------------------

class FileDriver {
  constructor(file) {
    this.file = path.resolve(file);
    this.label = `file ${this.file}`;
  }

  async load() {
    try {
      return JSON.parse(await fs.readFile(this.file, 'utf8'));
    } catch (err) {
      if (err.code === 'ENOENT') return {};
      throw new Error(`Cannot read ${this.file}: ${err.message}`);
    }
  }

  // The file always holds the full state; write atomically (tmp + rename).
  async save(_changed, all) {
    await fs.mkdir(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    await fs.writeFile(tmp, JSON.stringify(all));
    await fs.rename(tmp, this.file);
  }

  async close() {}
}

export class PostgresDriver {
  constructor(pool, label = 'postgres') {
    this.pool = pool;
    this.label = label;
  }

  static fromUrl(url) {
    const ssl = /sslmode=require/.test(url) ? { rejectUnauthorized: false } : undefined;
    const host = url.replace(/\/\/[^@]*@/, '//***@');
    return new PostgresDriver(new pg.Pool({ connectionString: url, ssl }), `postgres ${host}`);
  }

  async load() {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS fg_state (
        key        TEXT PRIMARY KEY,
        value      JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )`);
    const { rows } = await this.pool.query('SELECT key, value FROM fg_state');
    return Object.fromEntries(rows.map((r) => [r.key, r.value]));
  }

  // Only the collections that changed, in one transaction.
  async save(changed) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      for (const [key, json] of changed) {
        await client.query(
          `INSERT INTO fg_state (key, value, updated_at) VALUES ($1, $2::jsonb, now())
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
          [key, json]
        );
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async close() {
    await this.pool.end();
  }
}

// ---- Retention: keep the store bounded -------------------------------------

const DAY = 24 * 60 * 60 * 1000;

function keepLastPerDevice(list, n) {
  const counts = new Map();
  const out = [];
  for (let i = list.length - 1; i >= 0; i--) {
    const c = counts.get(list[i].deviceId) || 0;
    if (c < n) out.push(list[i]);
    counts.set(list[i].deviceId, c + 1);
  }
  return out.reverse();
}

export function prune(now = Date.now()) {
  store.usageEvents = store.usageEvents.filter((e) => now - new Date(e.startedAt) < 35 * DAY);
  store.locations = keepLastPerDevice(store.locations, 500);
  store.geofenceEvents = keepLastPerDevice(store.geofenceEvents, 300);
  store.sosAlerts = store.sosAlerts.filter((a) => !a.resolved || now - new Date(a.at) < 90 * DAY);
  store.timeRequests = store.timeRequests.filter((r) => now - new Date(r.at) < 30 * DAY);
  store.bonusTime = store.bonusTime.filter((b) => now - new Date(b.day) < 3 * DAY);
}

// ---- Public API ------------------------------------------------------------

function snapshot() {
  const all = {};
  for (const key of Object.keys(store)) all[key] = store[key];
  all[COUNTER_KEY] = getCounter();
  return all;
}

export function pickDriver(env = process.env) {
  if (env.PERSIST === 'memory') return null;
  if (env.DATABASE_URL) return PostgresDriver.fromUrl(env.DATABASE_URL);
  return new FileDriver(env.DATA_FILE || './data/familyguard.json');
}

/** Loads saved state into `store`. Call once before the server listens. */
export async function initPersistence(d = pickDriver()) {
  driver = d;
  if (!driver) return 'memory (not saved)';
  const saved = await driver.load();
  for (const [key, value] of Object.entries(saved)) {
    if (key === COUNTER_KEY) setCounter(value);
    else if (key in store) store[key] = value;
    lastWritten.set(key, JSON.stringify(value));
  }
  return driver.label;
}

/** Debounced save; safe to call after every request. */
export function scheduleSave() {
  if (!driver || timer) return;
  timer = setTimeout(() => {
    timer = null;
    saving = saving.then(flush).catch((err) => console.error('[persist] save failed:', err.message));
  }, SAVE_DELAY_MS);
}

/** Writes changed collections now. */
export async function flush() {
  if (!driver) return 0;
  prune();
  const all = snapshot();
  const changed = [];
  for (const [key, value] of Object.entries(all)) {
    const json = JSON.stringify(value);
    if (lastWritten.get(key) !== json) changed.push([key, json]);
  }
  if (changed.length === 0) return 0;
  await driver.save(changed, all);
  for (const [key, json] of changed) lastWritten.set(key, json);
  return changed.length;
}

/** Flushes pending writes and closes the connection (graceful shutdown). */
export async function closePersistence() {
  if (timer) {
    clearTimeout(timer);
    timer = null;
  }
  await saving;
  await flush();
  await driver?.close();
}

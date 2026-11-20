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
import { existsSync, unlinkSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
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

// Same idea keyed by any id field (childId, ...): keep the newest n rows
// per key. Rows are appended chronologically, so "last n in array order"
// is the newest n.
function keepLastPerKey(list, n, keyOf) {
  const counts = new Map();
  const out = [];
  for (let i = list.length - 1; i >= 0; i--) {
    const key = keyOf(list[i]);
    const c = counts.get(key) || 0;
    if (c < n) out.push(list[i]);
    counts.set(key, c + 1);
  }
  return out.reverse();
}

// Comms are stored as one row per device holding an `items` array
// (replace-all sync). Cap the array so a very chatty device cannot grow
// the single JSON file without bound. SMS / calls keep the newest 1000
// rows by date; contacts (no date) keep the first 2000 as stored.
function capCommsItems(collection, cap, byDate) {
  for (const row of collection) {
    if (!Array.isArray(row.items) || row.items.length <= cap) continue;
    row.items = byDate
      ? [...row.items].sort((a, b) => (b.date || 0) - (a.date || 0)).slice(0, cap)
      : row.items.slice(0, cap);
  }
}

export function prune(now = Date.now()) {
  store.usageEvents = store.usageEvents.filter((e) => now - new Date(e.startedAt) < 35 * DAY);
  store.locations = keepLastPerDevice(store.locations, 500);
  store.geofenceEvents = keepLastPerDevice(store.geofenceEvents, 300);
  // Phase 5: the collections that were never pruned (audit §6).
  // Browsing sessions are append-only — keep the newest 500 per device.
  store.browsingSessions = keepLastPerDevice(store.browsingSessions ?? [], 500);
  // Comms: whole-array replace per sync, no size cap until now.
  capCommsItems(store.contacts ?? [], 2000, false);
  capCommsItems(store.smsMessages ?? [], 1000, true);
  capCommsItems(store.callLogs ?? [], 1000, true);
  // Installed apps: drop rows the device has not reported in 90 days
  // (uninstalled / stale). Rows without lastSeenAt are kept.
  store.installedApps = (store.installedApps ?? []).filter(
    (a) => !a.lastSeenAt || now - new Date(a.lastSeenAt) < 90 * DAY,
  );
  // Agreements: keep the newest 50 per child (old proposals stay visible
  // in the audit log, which is not pruned here).
  store.agreements = keepLastPerKey(store.agreements ?? [], 50, (a) => a.childId);
  // Reward events: keep the newest 1000 per child. Totals are derived
  // from the kept events, so very old history ages out of the total —
  // at family scale (a few awards a week) this is decades away.
  store.rewardEvents = keepLastPerKey(store.rewardEvents ?? [], 1000, (e) => e.childId);
  // Keyword lists: one live list per child — drop stale duplicates and
  // keep the most recently updated row per child.
  {
    const latest = new Map();
    for (const row of store.keywordLists ?? []) {
      const prev = latest.get(row.childId);
      if (!prev || new Date(row.updatedAt ?? 0) >= new Date(prev.updatedAt ?? 0)) {
        latest.set(row.childId, row);
      }
    }
    store.keywordLists = [...latest.values()];
  }
  // Thumbnails + originals are capped per device at MAX_PREVIEWS (500).
  // Pruned entries also lose their file on disk (best effort, sync).
  const thumbsDir = path.join(
    path.dirname(fileURLToPath(new URL('.', import.meta.url))),
    '..',
    'uploads',
    'thumbs'
  );
  const originalsDir = path.join(
    path.dirname(fileURLToPath(new URL('.', import.meta.url))),
    '..',
    'uploads',
    'originals'
  );
  const pruneFiles = (before, after, dir) => {
    const kept = new Set(after.map((e) => `${e.deviceId}/${e.key}`));
    for (const e of before) {
      if (kept.has(`${e.deviceId}/${e.key}`) || !e.file) continue;
      try {
        unlinkSync(path.join(dir, e.deviceId, path.basename(e.file)));
      } catch {
        // Already gone — not an error.
      }
    }
  };
  const thumbsBefore = store.thumbnails;
  store.thumbnails = keepLastPerDevice(store.thumbnails, 500);
  pruneFiles(thumbsBefore, store.thumbnails, thumbsDir);
  const originalsBefore = store.originals ?? [];
  store.originals = keepLastPerDevice(store.originals ?? [], 500);
  pruneFiles(originalsBefore, store.originals, originalsDir);
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

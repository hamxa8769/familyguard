// Persistence: the file driver round-trips the store, writes only changes,
// and retention keeps collections bounded.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs/promises';
import { store, nextId } from '../src/config/store.js';
import { initPersistence, pickDriver, flush, prune } from '../src/config/persistence.js';

test('file driver saves and reloads state', async () => {
  const file = path.join(os.tmpdir(), `fg-test-${process.pid}.json`);
  await initPersistence(pickDriver({ DATA_FILE: file }));
  store.users.push({ id: nextId(), email: 'a@b.c' });
  assert.ok((await flush()) > 0);
  assert.equal(await flush(), 0, 'nothing written when unchanged');

  store.users = [];
  await initPersistence(pickDriver({ DATA_FILE: file }));
  assert.equal(store.users[0].email, 'a@b.c');
  await fs.rm(file, { force: true });
});

test('memory mode saves nothing', () => {
  assert.equal(pickDriver({ PERSIST: 'memory' }), null);
});

test('retention drops old usage and caps locations per device', () => {
  const now = Date.now();
  store.usageEvents = [
    { deviceId: 'd', startedAt: new Date(now - 40 * 864e5).toISOString(), durationSeconds: 1 },
    { deviceId: 'd', startedAt: new Date(now).toISOString(), durationSeconds: 1 },
  ];
  store.locations = Array.from({ length: 520 }, (_, i) => ({ deviceId: 'd', lat: i, lng: 0 }));
  prune(now);
  assert.equal(store.usageEvents.length, 1);
  assert.equal(store.locations.length, 500);
  assert.equal(store.locations.at(-1).lat, 519, 'keeps the newest points');
});

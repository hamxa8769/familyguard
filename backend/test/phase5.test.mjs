// Phase 5 tests: pagination, API hygiene (JSON 404, /health/ready,
// /api/me, change-password, refresh, logout/revoke), audit-log endpoint,
// prune rules, and purge-expired deleting the disk file.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store, same style as test/phase2.test.mjs.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/app.js';
import { store } from '../src/config/store.js';
import { prune } from '../src/config/persistence.js';

let server;
let base;
let parentToken;
let otherParentToken;
let deviceId;
let deviceToken;

async function pairDevice(name) {
  const child = await req('POST', '/api/children', parentToken, { displayName: name });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  const paired = await req('POST', '/api/pair', null, {
    code: child.data.pairingCode,
    platform: 'android',
    deviceName: name,
  });
  assert.equal(paired.status, 201, JSON.stringify(paired.data));
  return paired.data; // { token, device, child }
}

async function req(method, path, token, body) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => null);
  return { status: res.status, data, contentType: res.headers.get('content-type') };
}

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const parent = await req('POST', '/api/auth/register', null, {
    email: 'parent-p5@test.local',
    password: 'secret-password',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const other = await req('POST', '/api/auth/register', null, {
    email: 'parent-p5-other@test.local',
    password: 'secret-password',
    role: 'parent',
  });
  assert.equal(other.status, 201, JSON.stringify(other.data));
  otherParentToken = other.data.token;
  const paired = await pairDevice('p5-phone');
  deviceId = paired.device.id;
  deviceToken = paired.token;
});

after(() => server.close());

describe('API hygiene', () => {
  it('unknown route returns a JSON 404, never Express HTML', async () => {
    const res = await req('GET', '/api/no-such-route', parentToken);
    assert.equal(res.status, 404);
    assert.match(res.contentType, /application\/json/);
    assert.equal(res.data.code, 'not_found');
    assert.equal(typeof res.data.error, 'string');
  });

  it('GET /health/ready reports a real check', async () => {
    const res = await req('GET', '/health/ready', null);
    assert.equal(res.status, 200);
    assert.equal(res.data.status, 'ok');
    assert.equal(typeof res.data.db, 'string');
  });

  it('GET /health still works', async () => {
    const res = await req('GET', '/health', null);
    assert.equal(res.status, 200);
    assert.equal(res.data.status, 'ok');
  });

  it('error responses from the central handler carry a machine-readable code', async () => {
    // Duplicate registration throws with err.status 409, which flows
    // through the central error handler (unlike the controllers' direct
    // res.status(400) validation replies — see docs/API.md).
    const dup = await req('POST', '/api/auth/register', null, {
      email: 'parent-p5@test.local',
      password: 'secret-password',
      role: 'parent',
    });
    assert.equal(dup.status, 409);
    assert.equal(typeof dup.data.error, 'string');
    assert.equal(dup.data.code, 'conflict');
  });

  it('the same routes work under /api/v1 (dual mount)', async () => {
    const me = await req('GET', '/api/v1/me', parentToken);
    assert.equal(me.status, 200);
    assert.equal(me.data.role, 'parent');
    const sos = await req('GET', '/api/v1/sos', parentToken);
    assert.equal(sos.status, 200);
    assert.ok(Array.isArray(sos.data.alerts));
  });
});

describe('session endpoints (/api/me, change-password, refresh, logout)', () => {
  it('GET /api/me returns the current user; no token is 401', async () => {
    const me = await req('GET', '/api/me', parentToken);
    assert.equal(me.status, 200);
    assert.equal(me.data.email, 'parent-p5@test.local');
    assert.equal(me.data.role, 'parent');
    assert.equal(me.data.passwordHash, undefined);
    const anon = await req('GET', '/api/me', null);
    assert.equal(anon.status, 401);
  });

  it('change-password: missing fields 400, wrong old password 401', async () => {
    const missing = await req('POST', '/api/auth/change-password', parentToken, {
      oldPassword: 'secret-password',
    });
    assert.equal(missing.status, 400);
    const wrong = await req('POST', '/api/auth/change-password', parentToken, {
      oldPassword: 'not-the-password',
      newPassword: 'new-secret-password',
    });
    assert.equal(wrong.status, 401);
  });

  it('change-password works and the new password logs in', async () => {
    const user = await req('POST', '/api/auth/register', null, {
      email: 'parent-p5-pw@test.local',
      password: 'old-password-1',
      role: 'parent',
    });
    assert.equal(user.status, 201);
    const changed = await req('POST', '/api/auth/change-password', user.data.token, {
      oldPassword: 'old-password-1',
      newPassword: 'new-password-2',
    });
    assert.equal(changed.status, 200, JSON.stringify(changed.data));
    assert.equal(changed.data.ok, true);
    const oldLogin = await req('POST', '/api/auth/login', null, {
      email: 'parent-p5-pw@test.local',
      password: 'old-password-1',
    });
    assert.equal(oldLogin.status, 401);
    const newLogin = await req('POST', '/api/auth/login', null, {
      email: 'parent-p5-pw@test.local',
      password: 'new-password-2',
    });
    assert.equal(newLogin.status, 200);
  });

  it('refresh returns a fresh token that works', async () => {
    const refreshed = await req('POST', '/api/auth/refresh', parentToken, {});
    assert.equal(refreshed.status, 200);
    assert.equal(typeof refreshed.data.token, 'string');
    assert.notEqual(refreshed.data.token, parentToken);
    const me = await req('GET', '/api/me', refreshed.data.token);
    assert.equal(me.status, 200);
    assert.equal(me.data.email, 'parent-p5@test.local');
  });

  it('logout revokes the token: it then gets 401, other tokens keep working', async () => {
    const login = await req('POST', '/api/auth/login', null, {
      email: 'parent-p5@test.local',
      password: 'secret-password',
    });
    assert.equal(login.status, 200);
    const token = login.data.token;
    const out = await req('POST', '/api/auth/logout', token, {});
    assert.equal(out.status, 200);
    assert.equal(out.data.revoked, true);
    const me = await req('GET', '/api/me', token);
    assert.equal(me.status, 401);
    assert.equal(me.data.code, 'token_revoked');
    // The parent's original token (a different jti) is unaffected.
    const stillOk = await req('GET', '/api/me', parentToken);
    assert.equal(stillOk.status, 200);
  });
});

describe('pagination', () => {
  it('GET /api/usage pages without overlap (?limit=5&offset=5)', async () => {
    const events = Array.from({ length: 12 }, (_, i) => ({
      appName: `com.example.app${i}`,
      startedAt: new Date(Date.now() - i * 60000).toISOString(),
      durationSeconds: 60,
    }));
    const posted = await req('POST', '/api/usage', parentToken, {
      deviceId,
      events,
    });
    assert.equal(posted.status, 201, JSON.stringify(posted.data));
    const page1 = await req('GET', `/api/usage/${deviceId}?limit=5&offset=0`, parentToken);
    assert.equal(page1.status, 200);
    assert.equal(page1.data.total, 12);
    assert.equal(page1.data.limit, 5);
    assert.equal(page1.data.apps.length, 5);
    const page2 = await req('GET', `/api/usage/${deviceId}?limit=5&offset=5`, parentToken);
    assert.equal(page2.status, 200);
    assert.equal(page2.data.apps.length, 5);
    const names1 = new Set(page1.data.apps.map((a) => a.appName));
    for (const a of page2.data.apps) assert.ok(!names1.has(a.appName), 'pages overlap');
    // No params: default limit 500 returns everything.
    const all = await req('GET', `/api/usage/${deviceId}`, parentToken);
    assert.equal(all.data.apps.length, 12);
  });

  it('GET /api/sos pages without overlap (?limit=10&offset=10)', async () => {
    for (let i = 0; i < 12; i++) {
      const r = await req('POST', '/api/sos', deviceToken, {
        deviceId,
        message: `sos ${i}`,
      });
      assert.equal(r.status, 201, JSON.stringify(r.data));
    }
    const page1 = await req('GET', '/api/sos?limit=10&offset=0', parentToken);
    assert.equal(page1.status, 200);
    assert.equal(page1.data.total, 12);
    assert.equal(page1.data.alerts.length, 10);
    const page2 = await req('GET', '/api/sos?limit=10&offset=10', parentToken);
    assert.equal(page2.status, 200);
    assert.equal(page2.data.alerts.length, 2);
    const ids1 = new Set(page1.data.alerts.map((a) => a.id));
    for (const a of page2.data.alerts) assert.ok(!ids1.has(a.id), 'pages overlap');
    // limit clamps to 500.
    const clamped = await req('GET', '/api/sos?limit=9999', parentToken);
    assert.equal(clamped.data.limit, 500);
  });
});

describe('audit log', () => {
  it('audit endpoint returns entries; the transparency report includes them', async () => {
    // A screenshot request writes an audit entry (screenshot:requested).
    const shot = await req('POST', '/api/media/screenshot-request', parentToken, {
      deviceId,
    });
    assert.equal(shot.status, 201, JSON.stringify(shot.data));
    const audit = await req('GET', `/api/transparency/${deviceId}/audit`, parentToken);
    assert.equal(audit.status, 200);
    assert.ok(Array.isArray(audit.data.auditLog));
    assert.ok(audit.data.auditLog.some((e) => e.action === 'screenshot:requested'));
    const report = await req('GET', `/api/transparency/${deviceId}`, parentToken);
    assert.equal(report.status, 200);
    assert.ok(Array.isArray(report.data.report.auditLog));
    assert.ok(report.data.report.auditLog.some((e) => e.action === 'screenshot:requested'));
  });

  it('audit endpoint is 403 for a parent who does not own the device', async () => {
    const res = await req('GET', `/api/transparency/${deviceId}/audit`, otherParentToken);
    assert.equal(res.status, 403);
  });
});

describe('prune rules (Phase 5)', () => {
  it('caps browsing sessions, comms items, stale apps and duplicate keyword lists', () => {
    const dev = 'prune-device';
    for (let i = 0; i < 600; i++) {
      store.browsingSessions.push({
        id: String(i),
        deviceId: dev,
        packageName: 'com.example.browser',
        startedAt: new Date(Date.now() - i * 1000).toISOString(),
      });
    }
    store.smsMessages.push({
      deviceId: dev,
      items: Array.from({ length: 1005 }, (_, i) => ({
        address: '+1000',
        body: `m${i}`,
        date: i,
        type: 1,
      })),
    });
    store.installedApps.push(
      { deviceId: dev, packageName: 'com.example.stale', lastSeenAt: new Date(Date.now() - 100 * 86400000).toISOString() },
      { deviceId: dev, packageName: 'com.example.fresh', lastSeenAt: new Date().toISOString() },
    );
    store.keywordLists.push(
      { childId: 'prune-child', keywords: ['old'], updatedAt: '2026-01-01T00:00:00.000Z' },
      { childId: 'prune-child', keywords: ['new'], updatedAt: '2026-11-01T00:00:00.000Z' },
    );
    prune();
    assert.equal(store.browsingSessions.filter((s) => s.deviceId === dev).length, 500);
    assert.equal(store.smsMessages.find((r) => r.deviceId === dev).items.length, 1000);
    const apps = store.installedApps.filter((a) => a.deviceId === dev);
    assert.equal(apps.length, 1);
    assert.equal(apps[0].packageName, 'com.example.fresh');
    const lists = store.keywordLists.filter((k) => k.childId === 'prune-child');
    assert.equal(lists.length, 1);
    assert.deepEqual(lists[0].keywords, ['new']);
  });
});

describe('purge-expired deletes the disk file', () => {
  it('expired capture file is unlinked on purge', async () => {
    const shot = await req('POST', '/api/media/screenshot-request', parentToken, {
      deviceId,
    });
    assert.equal(shot.status, 201);
    const captureId = shot.data.capture.id;
    // 1x1 PNG, base64.
    const png = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      'base64',
    );
    const uploaded = await req('POST', `/api/media/${captureId}/upload`, deviceToken, {
      dataBase64: png.toString('base64'),
      mimeType: 'image/png',
    });
    assert.equal(uploaded.status, 200, JSON.stringify(uploaded.data));
    const uploadsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'uploads');
    const file = join(uploadsDir, `${captureId}.png`);
    assert.ok(existsSync(file), 'capture file should exist after upload');
    // Expire it, then purge.
    const capture = store.mediaCaptures.find((m) => m.id === captureId);
    capture.expiresAt = new Date(Date.now() - 1000).toISOString();
    const purged = await req('POST', '/api/media/purge-expired', parentToken, {});
    assert.equal(purged.status, 200);
    assert.ok(purged.data.purged.includes(captureId));
    assert.equal(existsSync(file), false, 'capture file should be deleted on purge');
    assert.equal(capture.status, 'expired');
  });
});

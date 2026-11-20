// Phase 2 tests: installed apps, browsing sessions, family agreement,
// rewards (incl. idempotent screen-time bonus), keyword alerts.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store, same style as test/remotecommands.test.mjs.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

let server;
let base;
let parentToken;
let childToken;
let childId;
// Real paired devices (with device tokens) for the apps/browsing syncs:
// sync routes are device-scoped, so a fake device id no longer passes.
let appsDeviceId;
let appsDeviceToken;
let browseDeviceId;
let browseDeviceToken;

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
  return { status: res.status, data };
}

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const parent = await req('POST', '/api/auth/register', null, {
    email: 'parent-p2@test.local',
    password: 'test-password',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const child = await req('POST', '/api/auth/register', null, {
    email: 'child-p2@test.local',
    password: 'test-password',
    role: 'child',
  });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  childToken = child.data.token;
  childId = child.data.user.id;
  const appsPaired = await pairDevice('apps-phone');
  appsDeviceId = appsPaired.device.id;
  appsDeviceToken = appsPaired.token;
  const browsePaired = await pairDevice('browse-phone');
  browseDeviceId = browsePaired.device.id;
  browseDeviceToken = browsePaired.token;
});

after(() => server.close());

describe('installed apps', () => {
  it('child syncs apps; parent lists them; re-sync upserts by packageName', async () => {
    const deviceId = appsDeviceId;
    const synced = await req('POST', `/api/apps/${deviceId}/sync`, appsDeviceToken, {
      apps: [
        {
          packageName: 'com.example.game',
          label: 'Example Game',
          versionName: '1.0',
          installedAt: '2026-11-01T00:00:00.000Z',
          systemApp: false,
        },
        { packageName: 'com.android.chrome', label: 'Chrome', versionName: '120', systemApp: true },
      ],
    });
    assert.equal(synced.status, 200, JSON.stringify(synced.data));
    assert.equal(synced.data.synced, 2);

    const listed = await req('GET', `/api/apps/${deviceId}`, parentToken);
    assert.equal(listed.status, 200);
    assert.equal(listed.data.apps.length, 2);
    assert.ok(listed.data.apps.every((a) => a.lastSeenAt));

    // Re-sync with a new version: still 2 rows, version updated.
    const resynced = await req('POST', `/api/apps/${deviceId}/sync`, appsDeviceToken, {
      apps: [{ packageName: 'com.example.game', label: 'Example Game', versionName: '1.1' }],
    });
    assert.equal(resynced.status, 200);
    assert.equal(resynced.data.apps.length, 2);
    const game = resynced.data.apps.find((a) => a.packageName === 'com.example.game');
    assert.equal(game.versionName, '1.1');
  });

  it('sync with an empty apps list is rejected (400)', async () => {
    const res = await req('POST', `/api/apps/${appsDeviceId}/sync`, appsDeviceToken, { apps: [] });
    assert.equal(res.status, 400);
  });

  it('a parent cannot sync apps', async () => {
    const res = await req('POST', `/api/apps/${appsDeviceId}/sync`, parentToken, {
      apps: [{ packageName: 'com.example.x' }],
    });
    assert.equal(res.status, 403);
  });
});

describe('browsing sessions', () => {
  it('child syncs sessions; parent lists them newest first (no URLs)', async () => {
    const deviceId = browseDeviceId;
    const synced = await req('POST', `/api/browsing/${deviceId}/sync`, browseDeviceToken, {
      sessions: [
        {
          packageName: 'com.android.chrome',
          browserLabel: 'Chrome',
          startedAt: '2026-11-20T08:00:00.000Z',
          endedAt: '2026-11-20T08:30:00.000Z',
          durationSeconds: 1800,
        },
        {
          packageName: 'com.android.chrome',
          browserLabel: 'Chrome',
          startedAt: '2026-11-20T10:00:00.000Z',
          endedAt: '2026-11-20T10:05:00.000Z',
          durationSeconds: 300,
        },
      ],
    });
    assert.equal(synced.status, 201, JSON.stringify(synced.data));
    assert.equal(synced.data.sessions.length, 2);
    assert.ok(!('url' in synced.data.sessions[0]), 'sessions must never carry URLs');

    const listed = await req('GET', `/api/browsing/${deviceId}`, parentToken);
    assert.equal(listed.status, 200);
    assert.equal(listed.data.sessions.length, 2);
    assert.equal(listed.data.sessions[0].startedAt, '2026-11-20T10:00:00.000Z');
    assert.equal(listed.data.sessions[1].startedAt, '2026-11-20T08:00:00.000Z');
  });

  it('sync with an empty sessions list is rejected (400)', async () => {
    const res = await req('POST', `/api/browsing/${browseDeviceId}/sync`, browseDeviceToken, {
      sessions: [],
    });
    assert.equal(res.status, 400);
  });
});

describe('family agreement', () => {
  let agreementId;

  it('parent proposes an agreement; child reads and signs it', async () => {
    const created = await req('POST', '/api/agreement', parentToken, {
      childId,
      rules: ['No phone after 9pm', 'Homework before games'],
      effectiveFrom: '2026-11-21',
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    assert.equal(created.data.status, 'proposed');
    agreementId = created.data.id;

    const latest = await req('GET', `/api/agreement/${childId}`, childToken);
    assert.equal(latest.status, 200);
    assert.equal(latest.data.id, agreementId);

    const signed = await req('POST', `/api/agreement/${agreementId}/sign`, childToken, {
      accepted: true,
      note: 'Agreed!',
    });
    assert.equal(signed.status, 200, JSON.stringify(signed.data));
    assert.equal(signed.data.status, 'accepted');
    assert.ok(signed.data.signedAt);
  });

  it('a signed agreement cannot be signed again', async () => {
    const res = await req('POST', `/api/agreement/${agreementId}/sign`, childToken, {
      accepted: false,
    });
    assert.equal(res.status, 409);
  });

  it('a child cannot create an agreement', async () => {
    const res = await req('POST', '/api/agreement', childToken, {
      childId,
      rules: ['Kids rule now'],
    });
    assert.equal(res.status, 403);
  });

  it('no agreement for an unknown child is a 404', async () => {
    const res = await req('GET', '/api/agreement/no-such-child', parentToken);
    assert.equal(res.status, 404);
  });
});

describe('rewards', () => {
  it('parent awards points with a badge; totals and badges derive from events', async () => {
    const awarded = await req('POST', `/api/rewards/${childId}/award`, parentToken, {
      points: 20,
      reason: 'Finished homework early',
      badge: 'homework-hero',
    });
    assert.equal(awarded.status, 201, JSON.stringify(awarded.data));
    assert.equal(awarded.data.points, 20);

    const rewards = await req('GET', `/api/rewards/${childId}`, childToken);
    assert.equal(rewards.status, 200);
    assert.equal(rewards.data.totalPoints, 20);
    assert.equal(rewards.data.events.length, 1);
    assert.deepEqual(rewards.data.badges, ['homework-hero']);
  });

  it('screen-time bonus awards 10 points only within the limit, once per date', async () => {
    const bonus = await req('POST', `/api/rewards/${childId}/screen-time-bonus`, parentToken, {
      date: '2026-11-20',
      minutesUsed: 55,
      limitMinutes: 60,
    });
    assert.equal(bonus.status, 201, JSON.stringify(bonus.data));
    assert.equal(bonus.data.awarded, true);
    assert.equal(bonus.data.points, 10);
    assert.equal(bonus.data.totalPoints, 30);

    // Second call for the same date must not double-award.
    const again = await req('POST', `/api/rewards/${childId}/screen-time-bonus`, parentToken, {
      date: '2026-11-20',
      minutesUsed: 40,
      limitMinutes: 60,
    });
    assert.equal(again.status, 200, JSON.stringify(again.data));
    assert.equal(again.data.awarded, false);
    assert.equal(again.data.alreadyAwarded, true);
    assert.equal(again.data.totalPoints, 30);

    // Over the limit: no award.
    const over = await req('POST', `/api/rewards/${childId}/screen-time-bonus`, parentToken, {
      date: '2026-11-19',
      minutesUsed: 90,
      limitMinutes: 60,
    });
    assert.equal(over.status, 200);
    assert.equal(over.data.awarded, false);
    assert.equal(over.data.totalPoints, 30);
  });
});

describe('keyword alerts', () => {
  it('parent sets the list; a matching scan creates an alert (case-insensitive)', async () => {
    const set = await req('POST', `/api/keywords/${childId}`, parentToken, {
      keywords: ['bully', 'secret meeting'],
    });
    assert.equal(set.status, 200, JSON.stringify(set.data));
    assert.deepEqual(set.data.keywords, ['bully', 'secret meeting']);

    const before = await req('GET', '/api/sos', parentToken);
    assert.equal(before.status, 200);

    const scan = await req('POST', `/api/keywords/${childId}/scan`, childToken, {
      text: 'A BULLY threatened me at school',
      source: 'chat',
    });
    assert.equal(scan.status, 200, JSON.stringify(scan.data));
    assert.deepEqual(scan.data.matched, ['bully']);
    assert.equal(scan.data.alertCreated, true);
    assert.equal(scan.data.alert.resolved, false);

    const after = await req('GET', '/api/sos', parentToken);
    assert.equal(after.data.alerts.length, before.data.alerts.length + 1);
    const created = after.data.alerts.find((a) => a.id === scan.data.alert.id);
    assert.ok(created, 'keyword alert is visible in the alerts list');
    assert.match(created.message, /bully/);
  });

  it('a scan with no match creates no alert', async () => {
    const before = await req('GET', '/api/sos', parentToken);
    const scan = await req('POST', `/api/keywords/${childId}/scan`, parentToken, {
      text: 'Had a lovely day at the park',
      source: 'chat',
    });
    assert.equal(scan.status, 200, JSON.stringify(scan.data));
    assert.deepEqual(scan.data.matched, []);
    assert.equal(scan.data.alertCreated, false);
    const after = await req('GET', '/api/sos', parentToken);
    assert.equal(after.data.alerts.length, before.data.alerts.length);
  });

  it('a child cannot set the keyword list', async () => {
    const res = await req('POST', `/api/keywords/${childId}`, childToken, {
      keywords: ['x'],
    });
    assert.equal(res.status, 403);
  });
});

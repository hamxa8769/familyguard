// Phase 3 tests: rule-version fast path (GET /api/devices/:id/rules-version,
// version bumps on every rule set) and minute-granular bedtime.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store, same style as test/phase2.test.mjs.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { isWithinBedtime } from '../src/modules/bedtime/bedtime.service.js';

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
  return { status: res.status, data };
}

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const parent = await req('POST', '/api/auth/register', null, {
    email: 'parent-p3@test.local',
    password: 'secret-1',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const other = await req('POST', '/api/auth/register', null, {
    email: 'parent-p3-other@test.local',
    password: 'secret-1',
    role: 'parent',
  });
  assert.equal(other.status, 201, JSON.stringify(other.data));
  otherParentToken = other.data.token;
  const paired = await pairDevice('rules-phone');
  deviceId = paired.device.id;
  deviceToken = paired.token;
});

after(() => server.close());

describe('rules-version endpoint', () => {
  it('starts at version 0 with no updatedAt for a fresh device', async () => {
    const res = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(res.status, 200, JSON.stringify(res.data));
    assert.equal(res.data.deviceId, deviceId);
    assert.equal(res.data.rulesVersion, 0);
    assert.equal(res.data.updatedAt, null);
  });

  it('bumps by exactly one on each rule set (appblocking, webfilter, bedtime, screentime)', async () => {
    const blocked = await req('PUT', `/api/appblocking/${deviceId}`, parentToken, { apps: ['com.example.game'] });
    assert.equal(blocked.status, 200, JSON.stringify(blocked.data));
    let v = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(v.data.rulesVersion, 1);
    assert.ok(v.data.updatedAt);

    const filter = await req('PUT', `/api/webfilter/${deviceId}`, parentToken, { blockedDomains: ['example.com'] });
    assert.equal(filter.status, 200);
    v = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(v.data.rulesVersion, 2);

    const bedtime = await req('PUT', `/api/bedtime/${deviceId}`, parentToken, { startHour: 22, startMinute: 30, endHour: 6, endMinute: 0 });
    assert.equal(bedtime.status, 200, JSON.stringify(bedtime.data));
    v = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(v.data.rulesVersion, 3);

    const limit = await req('PUT', `/api/screentime/${deviceId}`, parentToken, { dailyMinutes: 120 });
    assert.equal(limit.status, 200);
    v = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(v.data.rulesVersion, 4);
    // A failed set (400) must not bump the version.
    const bad = await req('PUT', `/api/appblocking/${deviceId}`, parentToken, { apps: 'not-an-array' });
    assert.equal(bad.status, 400);
    v = await req('GET', `/api/devices/${deviceId}/rules-version`, parentToken);
    assert.equal(v.data.rulesVersion, 4);
  });

  it('the device itself can read its own version; unknown device 404s', async () => {
    const own = await req('GET', `/api/devices/${deviceId}/rules-version`, deviceToken);
    assert.equal(own.status, 200);
    assert.equal(own.data.rulesVersion, 4);
    const missing = await req('GET', '/api/devices/999999/rules-version', parentToken);
    assert.equal(missing.status, 404);
  });

  it('another parent gets 403 and no token gets 401', async () => {
    const wrong = await req('GET', `/api/devices/${deviceId}/rules-version`, otherParentToken);
    assert.equal(wrong.status, 403);
    const anon = await req('GET', `/api/devices/${deviceId}/rules-version`, null);
    assert.equal(anon.status, 401);
  });
});

describe('minute-granular bedtime', () => {
  it('accepts and returns start/end minutes; rejects minutes outside 0-59', async () => {
    const set = await req('PUT', `/api/bedtime/${deviceId}`, parentToken, { startHour: 22, startMinute: 30, endHour: 6, endMinute: 15 });
    assert.equal(set.status, 200, JSON.stringify(set.data));
    assert.equal(set.data.startMinute, 30);
    assert.equal(set.data.endMinute, 15);
    const got = await req('GET', `/api/bedtime/${deviceId}`, parentToken);
    assert.equal(got.status, 200);
    assert.equal(got.data.schedule.startMinute, 30);
    assert.equal(got.data.schedule.endMinute, 15);
    const bad = await req('PUT', `/api/bedtime/${deviceId}`, parentToken, { startHour: 22, startMinute: 60, endHour: 6 });
    assert.equal(bad.status, 400);
  });

  it('isWithinBedtime: 22:30 blocks at 22:30 but not at 22:00-22:29', () => {
    const schedule = { startHour: 22, startMinute: 30, endHour: 6, endMinute: 0 };
    const at = (h, m) => new Date(2026, 10, 20, h, m);
    assert.equal(isWithinBedtime(schedule, at(22, 0)), false);
    assert.equal(isWithinBedtime(schedule, at(22, 29)), false);
    assert.equal(isWithinBedtime(schedule, at(22, 30)), true);
    assert.equal(isWithinBedtime(schedule, at(23, 59)), true);
    assert.equal(isWithinBedtime(schedule, at(5, 59)), true);
    assert.equal(isWithinBedtime(schedule, at(6, 0)), false);
    // Schedules saved before minutes existed still work (minutes default 0).
    assert.equal(isWithinBedtime({ startHour: 22, endHour: 6 }, at(22, 0)), true);
    assert.equal(isWithinBedtime({ startHour: 22, endHour: 6 }, at(21, 59)), false);
  });
});

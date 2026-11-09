// End-to-end API tests: start the real server (in memory) and call it over HTTP.
// Run: npm test
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

const PORT = 4600 + Math.floor(Math.random() * 300);
const B = `http://localhost:${PORT}`;
let server;

async function call(method, path, body, token) {
  const res = await fetch(B + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return [res.status, await res.json().catch(() => null)];
}

before(async () => {
  server = spawn(process.execPath, ['src/index.js'], {
    env: { ...process.env, PORT: String(PORT), PERSIST: 'memory', AUTH_RATE_LIMIT: '1000' },
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  let out = '';
  server.stdout.on('data', (d) => (out += d));
  for (let i = 0; i < 100 && !out.includes('listening'); i++) {
    await new Promise((r) => setTimeout(r, 100));
  }
  assert.ok(out.includes('listening'), 'server did not start');
});

after(async () => {
  server.kill();
  await once(server, 'exit');
});

// Fixtures built up by the tests in order.
const f = {};

test('parent signs up and adds a child with a pairing code', async () => {
  let [s, b] = await call('POST', '/api/auth/register', { email: 'p@test.io', password: 'password1', role: 'parent' });
  assert.equal(s, 201);
  f.parent = b.token;
  [, b] = await call('POST', '/api/auth/register', { email: 'other@test.io', password: 'password1', role: 'parent' });
  f.other = b.token;
  [s, b] = await call('POST', '/api/children', { displayName: 'Ali' }, f.parent);
  assert.equal(s, 201);
  assert.match(b.pairingCode, /^[A-Z2-9]{6}$/);
  f.code = b.pairingCode;
});

test('sign-up rejects weak passwords and bad emails', async () => {
  let [s] = await call('POST', '/api/auth/register', { email: 'x@test.io', password: 'short', role: 'parent' });
  assert.equal(s, 400);
  [s] = await call('POST', '/api/auth/register', { email: 'nope', password: 'password1', role: 'parent' });
  assert.equal(s, 400);
});

test('device pairs once with the code', async () => {
  let [s, b] = await call('POST', '/api/pair', { code: f.code, platform: 'android', deviceName: 'Pixel' });
  assert.equal(s, 201);
  f.device = b.token;
  f.id = b.device.id;
  [s] = await call('POST', '/api/pair', { code: f.code, platform: 'android' });
  assert.equal(s, 404, 'code is single-use');
});

test('usage snapshots replace today instead of double counting', async () => {
  const ev = (sec) => ({ deviceId: f.id, snapshot: true, events: [{ appName: 'yt', durationSeconds: sec }] });
  await call('POST', '/api/usage', ev(600), f.device);
  await call('POST', '/api/usage', ev(900), f.device);
  const [, b] = await call('GET', `/api/reports/${f.id}`, null, f.parent);
  assert.equal(b.usage.totalSeconds, 900);
});

test('only the owning parent or the device can read device data', async () => {
  await call('POST', `/api/comms/${f.id}`, { sms: [{ address: '1', body: 'hi', date: 1, type: 1 }] }, f.device);
  let [s] = await call('GET', `/api/comms/${f.id}`, null, f.parent);
  assert.equal(s, 200);
  [s] = await call('GET', `/api/comms/${f.id}`, null, f.other);
  assert.equal(s, 403);
  [s] = await call('PUT', `/api/screentime/${f.id}`, { dailyMinutes: 60 }, f.device);
  assert.equal(s, 403, 'device cannot change its own limit');
});

test('SOS is visible only to the owning parent', async () => {
  await call('POST', '/api/sos', { deviceId: f.id, message: 'help' }, f.device);
  let [, b] = await call('GET', '/api/sos', null, f.parent);
  assert.equal(b.alerts.length, 1);
  [, b] = await call('GET', '/api/sos', null, f.other);
  assert.equal(b.alerts.length, 0);
});

test('more-time request: approve adds minutes to today', async () => {
  await call('PUT', `/api/screentime/${f.id}`, { dailyMinutes: 60 }, f.parent);
  let [s, r] = await call('POST', '/api/requests', { deviceId: f.id, minutes: 30, reason: 'homework' }, f.device);
  assert.equal(s, 201);
  [s] = await call('POST', `/api/requests/${r.id}/decide`, { approve: true }, f.other);
  assert.equal(s, 404);
  [s] = await call('POST', `/api/requests/${r.id}/decide`, { approve: true }, f.parent);
  assert.equal(s, 200);
  const [, st] = await call('GET', `/api/screentime/${f.id}`, null, f.device);
  assert.equal(st.dailyMinutes, 90);
  assert.equal(st.bonusMinutes, 30);
});

test('safe zone: create, enter event on location, delete', async () => {
  let [s, z] = await call('POST', '/api/geofencing', { deviceId: f.id, name: 'Home', lat: 31.5, lng: 74.3, radiusM: 100 }, f.parent);
  assert.equal(s, 201);
  const [, loc] = await call('POST', '/api/location', { deviceId: f.id, lat: 31.5, lng: 74.3 }, f.device);
  assert.equal(loc.geofenceEvents[0].type, 'enter');
  [s] = await call('DELETE', `/api/geofencing/zone/${z.id}`, null, f.other);
  assert.equal(s, 404);
  [s] = await call('DELETE', `/api/geofencing/zone/${z.id}`, null, f.parent);
  assert.equal(s, 200);
});

test('daily usage history returns 7 days', async () => {
  const [s, b] = await call('GET', `/api/usage/${f.id}/daily?days=7`, null, f.parent);
  assert.equal(s, 200);
  assert.equal(b.days.length, 7);
  assert.equal(b.days[6].totalSeconds, 900);
});

test('feed returns new SOS, requests and zone events for the parent only', async () => {
  await call('POST', '/api/geofencing', { deviceId: f.id, name: 'School', lat: 10, lng: 10, radiusM: 100 }, f.parent);
  await call('POST', '/api/location', { deviceId: f.id, lat: 10, lng: 10 }, f.device);
  const [s, b] = await call('GET', '/api/feed?since=1970-01-01T00:00:00Z', null, f.parent);
  assert.equal(s, 200);
  const types = new Set(b.items.map((i) => i.type));
  assert.ok(types.has('sos') && types.has('request') && types.has('zone'));
  assert.match(b.items.find((i) => i.type === 'sos').title, /Ali/);
  const [, later] = await call('GET', `/api/feed?since=${b.now}`, null, f.parent);
  assert.equal(later.items.length, 0, 'nothing new after "now"');
  const [, other] = await call('GET', '/api/feed?since=1970-01-01T00:00:00Z', null, f.other);
  assert.equal(other.items.length, 0);
  const [d] = await call('GET', '/api/feed', null, f.device);
  assert.equal(d, 403, 'devices cannot read the parent feed');
});

test('device reports enforcement status; parent sees it on the child profile', async () => {
  const status = { usageAccess: true, overlay: false, appRulesActive: false, hasAppRules: true, evil: 'x' };
  let [s, b] = await call('PUT', `/api/devices/${f.id}/status`, { enforcement: status }, f.device);
  assert.equal(s, 200);
  assert.equal(b.enforcement.evil, undefined, 'unknown keys dropped');
  [s] = await call('PUT', `/api/devices/${f.id}/status`, { enforcement: status }, f.parent);
  assert.equal(s, 403, 'only the device reports its own status');
  [, b] = await call('GET', '/api/children', null, f.parent);
  const dev = b.children[0].devices.find((d) => d.id === f.id);
  assert.equal(dev.enforcement.overlay, false);
  assert.equal(dev.enforcement.hasAppRules, true);
});

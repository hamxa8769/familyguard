// Phase 1 smoke tests: remote commands + media captures + consent v2.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store (no DATABASE_URL, no FCM key) — the same code paths the
// Postgres repository falls back to.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

let server;
let base;
let parentToken;
let childToken;

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
    email: 'parent@test.local',
    password: 'test-password',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const child = await req('POST', '/api/auth/register', null, {
    email: 'child@test.local',
    password: 'test-password',
    role: 'child',
  });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  childToken = child.data.token;
});

after(() => server.close());

describe('remote commands', () => {
  it('parent creates a lock_now command; child polls it; child acks it', async () => {
    const device = await req('POST', '/api/devices', parentToken, {
      platform: 'android',
      deviceName: 'child-phone',
    });
    assert.equal(device.status, 201);
    const deviceId = device.data.id;

    const created = await req('POST', '/api/remotecommands', parentToken, {
      deviceId,
      type: 'lock_now',
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    assert.equal(created.data.status, 'pending');
    assert.equal(created.data.type, 'lock_now');

    // A child (any authenticated user) polls for pending commands.
    const polled = await req(
      'GET',
      `/api/remotecommands?deviceId=${deviceId}&status=pending`,
      childToken,
    );
    assert.equal(polled.status, 200);
    assert.equal(polled.data.commands.length, 1);

    const acked = await req('POST', `/api/remotecommands/${created.data.id}/ack`, childToken, {
      status: 'acknowledged',
    });
    assert.equal(acked.status, 200);
    assert.equal(acked.data.status, 'acknowledged');

    // A completed command cannot be acked again.
    const done = await req('POST', `/api/remotecommands/${created.data.id}/ack`, childToken, {
      status: 'completed',
    });
    assert.equal(done.status, 200);
    const again = await req('POST', `/api/remotecommands/${created.data.id}/ack`, childToken, {
      status: 'completed',
    });
    assert.equal(again.status, 409);
  });

  it('rejects unknown command types and empty messages', async () => {
    const bad = await req('POST', '/api/remotecommands', parentToken, {
      deviceId: 'x',
      type: 'spy_continuously',
    });
    assert.equal(bad.status, 400);
    const empty = await req('POST', '/api/remotecommands', parentToken, {
      deviceId: 'x',
      type: 'send_message',
      payload: { text: '   ' },
    });
    assert.equal(empty.status, 400);
  });

  it('a child cannot create commands', async () => {
    const res = await req('POST', '/api/remotecommands', childToken, {
      deviceId: 'x',
      type: 'lock_now',
    });
    assert.equal(res.status, 403);
  });
});

describe('media captures', () => {
  it('screenshot request creates a command + a 7-day capture, visible to the child', async () => {
    const device = await req('POST', '/api/devices', parentToken, {
      platform: 'android',
      deviceName: 'child-phone-2',
    });
    const deviceId = device.data.id;
    const res = await req('POST', '/api/media/screenshot-request', parentToken, { deviceId });
    assert.equal(res.status, 201, JSON.stringify(res.data));
    assert.equal(res.data.capture.kind, 'screenshot');
    assert.equal(res.data.capture.status, 'requested');
    assert.equal(res.data.capture.source, 'parent_request');
    const ttlDays =
      (new Date(res.data.capture.expiresAt) - new Date(res.data.capture.createdAt)) /
      (24 * 60 * 60_000);
    assert.ok(ttlDays > 6.9 && ttlDays < 7.1, `retention was ${ttlDays} days`);

    const list = await req('GET', `/api/media?deviceId=${deviceId}`, childToken);
    assert.equal(list.status, 200);
    assert.equal(list.data.captures.length, 1);
  });

  it('audio over 30 seconds is rejected', async () => {
    const device = await req('POST', '/api/devices', parentToken, {
      platform: 'android',
      deviceName: 'child-phone-3',
    });
    const deviceId = device.data.id;
    const reqAudio = await req('POST', '/api/media/audio-request', parentToken, {
      deviceId,
      source: 'sos',
    });
    assert.equal(reqAudio.status, 201);
    const tooLong = await req(
      'POST',
      `/api/media/${reqAudio.data.capture.id}/complete`,
      childToken,
      { durationSeconds: 31 },
    );
    assert.equal(tooLong.status, 400);
    const ok = await req('POST', `/api/media/${reqAudio.data.capture.id}/complete`, childToken, {
      durationSeconds: 12,
    });
    assert.equal(ok.status, 200);
    assert.equal(ok.data.status, 'captured');
  });
});

describe('consent v2 + transparency', () => {
  it('consent records a version and transparency lists the new features', async () => {
    const device = await req('POST', '/api/devices', parentToken, {
      platform: 'android',
      deviceName: 'child-phone-4',
    });
    const deviceId = device.data.id;
    const consent = await req('POST', '/api/consent', parentToken, {
      deviceId,
      acceptedText: 'v2 text incl. screenshot + SOS audio',
      consentVersion: '2',
    });
    assert.equal(consent.status, 201);
    assert.equal(consent.data.consentVersion, '2');

    const seen = await req('GET', `/api/transparency/${deviceId}`, parentToken);
    assert.equal(seen.status, 200);
    const joined = seen.data.collected.join(' ');
    assert.match(joined, /Screenshot/);
    assert.match(joined, /30 seconds/);
    assert.match(joined, /Remote commands/);
  });
});

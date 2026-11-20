// Phase 0 (v0.9.1) security tests: IDOR fixes, device-token sync,
// push-token for paired devices, login missing-field 400, storageRef
// traversal rejection, and the raised JSON body limit.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store, same style as test/remotecommands.test.mjs.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

let server;
let base;
let parentA;
let parentB;
let childToken;
let childA;
let deviceA;
let deviceAToken;
let deviceB;
let deviceBToken;

async function req(method, path, token, body, raw = false) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = raw ? await res.text() : await res.json().catch(() => null);
  return { status: res.status, data, headers: res.headers };
}

async function register(email, role) {
  const res = await req('POST', '/api/auth/register', null, {
    email,
    password: 'test-password',
    role,
  });
  assert.equal(res.status, 201, JSON.stringify(res.data));
  return res.data.token;
}

async function pairDevice(parent, name) {
  const child = await req('POST', '/api/children', parent, { displayName: name });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  const paired = await req('POST', '/api/pair', null, {
    code: child.data.pairingCode,
    platform: 'android',
    deviceName: name,
  });
  assert.equal(paired.status, 201, JSON.stringify(paired.data));
  return paired.data; // { token, device, child }
}

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  parentA = await register('parent-a-p0@test.local', 'parent');
  parentB = await register('parent-b-p0@test.local', 'parent');
  childToken = await register('child-p0@test.local', 'child');
  const pairedA = await pairDevice(parentA, 'child-a-phone');
  deviceA = pairedA.device;
  deviceAToken = pairedA.token;
  childA = pairedA.child;
  const pairedB = await pairDevice(parentB, 'child-b-phone');
  deviceB = pairedB.device;
  deviceBToken = pairedB.token;
});

after(() => server.close());

describe('IDOR: media captures', () => {
  let captureId;

  it('owning parent creates a capture; the other parent gets 403 everywhere', async () => {
    const created = await req('POST', '/api/media/screenshot-request', parentA, {
      deviceId: deviceA.id,
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    captureId = created.data.capture.id;

    // The other parent cannot request, list, get, download, complete or
    // delete a capture on a device they do not own.
    assert.equal((await req('POST', '/api/media/screenshot-request', parentB, { deviceId: deviceA.id })).status, 403);
    assert.equal((await req('POST', '/api/media/audio-request', parentB, { deviceId: deviceA.id, source: 'sos' })).status, 403);
    assert.equal((await req('GET', `/api/media?deviceId=${deviceA.id}`, parentB)).status, 403);
    assert.equal((await req('GET', `/api/media/${captureId}`, parentB)).status, 403);
    assert.equal((await req('GET', `/api/media/${captureId}/file`, parentB, null, true)).status, 403);
    assert.equal((await req('POST', `/api/media/${captureId}/complete`, parentB, { durationSeconds: 5 })).status, 403);
    assert.equal((await req('POST', `/api/media/${captureId}/upload`, parentB, { dataBase64: 'eA==', mimeType: 'image/png' })).status, 403);
    assert.equal((await req('POST', `/api/media/${captureId}/delete`, parentB, {})).status, 403);

    // The owning parent and the device itself still can.
    assert.equal((await req('GET', `/api/media?deviceId=${deviceA.id}`, parentA)).status, 200);
    assert.equal((await req('GET', `/api/media/${captureId}`, deviceAToken)).status, 200);
    // A child-user token (no device) cannot read another family's capture.
    assert.equal((await req('GET', `/api/media/${captureId}`, childToken)).status, 403);
  });

  it('requesting a screenshot for an unknown device is a 404, not a silent create', async () => {
    const res = await req('POST', '/api/media/screenshot-request', parentA, { deviceId: 'no-such-device' });
    assert.equal(res.status, 404);
  });
});

describe('IDOR: remote commands', () => {
  let commandId;

  it('owning parent creates a command; the other parent gets 403 everywhere', async () => {
    const created = await req('POST', '/api/remotecommands', parentA, {
      deviceId: deviceA.id,
      type: 'lock_now',
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    commandId = created.data.id;

    assert.equal((await req('POST', '/api/remotecommands', parentB, { deviceId: deviceA.id, type: 'lock_now' })).status, 403);
    assert.equal((await req('GET', `/api/remotecommands?deviceId=${deviceA.id}`, parentB)).status, 403);
    assert.equal((await req('GET', `/api/remotecommands/${commandId}`, parentB)).status, 403);
    assert.equal((await req('POST', `/api/remotecommands/${commandId}/ack`, parentB, { status: 'acknowledged' })).status, 403);
    assert.equal((await req('POST', `/api/remotecommands/${commandId}/cancel`, parentB, {})).status, 403);
    // Another family's device cannot poll or ack it either.
    assert.equal((await req('GET', `/api/remotecommands?deviceId=${deviceA.id}`, deviceBToken)).status, 403);
    assert.equal((await req('POST', `/api/remotecommands/${commandId}/ack`, deviceBToken, { status: 'acknowledged' })).status, 403);

    // The owning parent and the device itself still can.
    assert.equal((await req('GET', `/api/remotecommands?deviceId=${deviceA.id}`, parentA)).status, 200);
    assert.equal((await req('GET', `/api/remotecommands/${commandId}`, deviceAToken)).status, 200);
    const acked = await req('POST', `/api/remotecommands/${commandId}/ack`, deviceAToken, { status: 'acknowledged' });
    assert.equal(acked.status, 200);
  });

  it('creating a command for an unknown device is a 404', async () => {
    const res = await req('POST', '/api/remotecommands', parentA, {
      deviceId: 'no-such-device',
      type: 'lock_now',
    });
    assert.equal(res.status, 404);
  });
});

describe('IDOR: agreement / rewards / keywords', () => {
  it('the other parent gets 403 on another family’s child', async () => {
    const agreement = await req('POST', '/api/agreement', parentA, {
      childId: childA.id,
      rules: ['No phone after 9pm'],
    });
    assert.equal(agreement.status, 201, JSON.stringify(agreement.data));

    assert.equal((await req('GET', `/api/agreement/${childA.id}`, parentB)).status, 403);
    assert.equal((await req('POST', `/api/agreement/${agreement.data.id}/sign`, childToken, { accepted: true })).status, 403);
    assert.equal((await req('POST', `/api/rewards/${childA.id}/award`, parentB, { points: 5, reason: 'x' })).status, 403);
    assert.equal((await req('GET', `/api/rewards/${childA.id}`, parentB)).status, 403);
    assert.equal((await req('POST', `/api/rewards/${childA.id}/screen-time-bonus`, parentB, { date: '2026-11-20', minutesUsed: 10, limitMinutes: 60 })).status, 403);
    assert.equal((await req('POST', `/api/keywords/${childA.id}`, parentB, { keywords: ['x'] })).status, 403);
    assert.equal((await req('GET', `/api/keywords/${childA.id}`, parentB)).status, 403);
    assert.equal((await req('POST', `/api/keywords/${childA.id}/scan`, parentB, { text: 'hello' })).status, 403);

    // The owning parent still can.
    assert.equal((await req('GET', `/api/agreement/${childA.id}`, parentA)).status, 200);
    assert.equal((await req('GET', `/api/rewards/${childA.id}`, parentA)).status, 200);
    assert.equal((await req('GET', `/api/keywords/${childA.id}`, parentA)).status, 200);
  });
});

describe('device-token sync for apps / browsing', () => {
  it('a device token syncs apps and browsing for its own device', async () => {
    const synced = await req('POST', `/api/apps/${deviceA.id}/sync`, deviceAToken, {
      apps: [{ packageName: 'com.example.game', label: 'Game' }],
    });
    assert.equal(synced.status, 200, JSON.stringify(synced.data));
    assert.equal(synced.data.synced, 1);

    const sessions = await req('POST', `/api/browsing/${deviceA.id}/sync`, deviceAToken, {
      sessions: [{ packageName: 'com.android.chrome', startedAt: '2026-11-20T08:00:00.000Z' }],
    });
    assert.equal(sessions.status, 201, JSON.stringify(sessions.data));
    assert.equal(sessions.data.sessions.length, 1);

    const listed = await req('GET', `/api/apps/${deviceA.id}`, parentA);
    assert.equal(listed.status, 200);
    assert.equal(listed.data.apps.length, 1);
  });

  it('another family’s device or parent cannot sync or read them', async () => {
    assert.equal((await req('POST', `/api/apps/${deviceA.id}/sync`, deviceBToken, { apps: [{ packageName: 'com.evil.x' }] })).status, 403);
    assert.equal((await req('POST', `/api/browsing/${deviceA.id}/sync`, deviceBToken, { sessions: [{ packageName: 'com.android.chrome', startedAt: '2026-11-20T08:00:00.000Z' }] })).status, 403);
    assert.equal((await req('GET', `/api/apps/${deviceA.id}`, parentB)).status, 403);
    assert.equal((await req('GET', `/api/browsing/${deviceA.id}`, parentB)).status, 403);
  });
});

describe('push token for paired devices', () => {
  it('the owning parent can set a push token on a pairing-created device', async () => {
    const res = await req('POST', `/api/devices/${deviceA.id}/push-token`, parentA, {
      pushToken: 'fcm-token-a',
    });
    assert.equal(res.status, 200, JSON.stringify(res.data));
    assert.equal(res.data.pushToken, 'fcm-token-a');
  });

  it('the device itself can set its own push token', async () => {
    const res = await req('POST', `/api/devices/${deviceA.id}/push-token`, deviceAToken, {
      pushToken: 'fcm-token-a2',
    });
    assert.equal(res.status, 200, JSON.stringify(res.data));
    assert.equal(res.data.pushToken, 'fcm-token-a2');
  });

  it('another parent cannot set a push token on it', async () => {
    const res = await req('POST', `/api/devices/${deviceA.id}/push-token`, parentB, {
      pushToken: 'fcm-token-evil',
    });
    assert.equal(res.status, 404);
  });
});

describe('login validation', () => {
  it('login without a password returns 400, not 500', async () => {
    const res = await req('POST', '/api/auth/login', null, { email: 'parent-a-p0@test.local' });
    assert.equal(res.status, 400, JSON.stringify(res.data));
  });

  it('login without an email returns 400, not 500', async () => {
    const res = await req('POST', '/api/auth/login', null, { password: 'test-password' });
    assert.equal(res.status, 400, JSON.stringify(res.data));
  });

  it('login with a wrong password is still a 401', async () => {
    const res = await req('POST', '/api/auth/login', null, {
      email: 'parent-a-p0@test.local',
      password: 'wrong-password',
    });
    assert.equal(res.status, 401);
  });
});

describe('storageRef sanitisation', () => {
  let captureId;

  it('path traversal in storageRef is rejected', async () => {
    const created = await req('POST', '/api/media/screenshot-request', parentA, {
      deviceId: deviceA.id,
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    captureId = created.data.capture.id;

    for (const evil of ['../../etc/passwd', '../secret.png', 'a/b.png', 'a\\b.png', '..']) {
      const res = await req('POST', `/api/media/${captureId}/complete`, deviceAToken, {
        storageRef: evil,
      });
      assert.equal(res.status, 400, `${evil} was not rejected: ${JSON.stringify(res.data)}`);
    }
  });

  it('a plain file name is accepted', async () => {
    const res = await req('POST', `/api/media/${captureId}/complete`, deviceAToken, {
      storageRef: 'capture.png',
    });
    assert.equal(res.status, 200, JSON.stringify(res.data));
    assert.equal(res.data.status, 'captured');
    assert.equal(res.data.storageRef, 'capture.png');
  });
});

describe('JSON body limit vs the 8 MB media cap', () => {
  it('a 5 MB upload reaches the controller instead of being rejected by the body parser', async () => {
    const created = await req('POST', '/api/media/screenshot-request', parentA, {
      deviceId: deviceA.id,
    });
    assert.equal(created.status, 201, JSON.stringify(created.data));
    const captureId = created.data.capture.id;
    // 5 MB of bytes is ~6.7 MB of base64 JSON — over the old 5 MB
    // express.json limit, under the 8 MB file cap, so it must succeed.
    const big = Buffer.alloc(5 * 1024 * 1024, 0x61).toString('base64');
    const uploaded = await req('POST', `/api/media/${captureId}/upload`, deviceAToken, {
      dataBase64: big,
      mimeType: 'image/png',
    });
    assert.equal(uploaded.status, 200, JSON.stringify(uploaded.data));
    assert.equal(uploaded.data.sizeBytes, 5 * 1024 * 1024);
    const file = await req('GET', `/api/media/${captureId}/file`, parentA, null, true);
    assert.equal(file.status, 200);
    assert.equal(file.data.length, 5 * 1024 * 1024);
    // Clean up the 5 MB file the test wrote to backend/uploads/.
    const deleted = await req('POST', `/api/media/${captureId}/delete`, parentA, {});
    assert.equal(deleted.status, 200);
  });
});

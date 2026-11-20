// Phase 2 media upload tests: the child uploads a screenshot PNG or a
// 30 s audio clip as base64; the parent downloads it. Caps enforced:
// audio > 30 s rejected, file > 8 MB rejected, unknown mime rejected.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

let server;
let base;
let parentToken;
let childToken;

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

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const parent = await req('POST', '/api/auth/register', null, {
    email: 'parent2@test.local',
    password: 'secret123',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const child = await req('POST', '/api/auth/register', null, {
    email: 'child2@test.local',
    password: 'secret123',
    role: 'child',
  });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  childToken = child.data.token;
});

after(() => server.close());

// A real paired device: the child side of media upload acts with a device
// token, not a child-user token (capture routes now verify the caller's
// device).
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

describe('media upload', () => {
  it('child uploads a screenshot PNG; parent downloads it; delete removes it', async () => {
    const { token: deviceToken, device } = await pairDevice('child-phone-2');
    const deviceId = device.id;
    const requested = await req('POST', '/api/media/screenshot-request', parentToken, {
      deviceId,
    });
    assert.equal(requested.status, 201);
    const captureId = requested.data.capture.id;
    // A tiny valid PNG header (8 bytes) is enough to exercise the path.
    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).toString('base64');
    const uploaded = await req('POST', `/api/media/${captureId}/upload`, deviceToken, {
      dataBase64: png,
      mimeType: 'image/png',
    });
    assert.equal(uploaded.status, 200, JSON.stringify(uploaded.data));
    assert.equal(uploaded.data.status, 'captured');
    assert.equal(uploaded.data.sizeBytes, 8);
    const file = await req('GET', `/api/media/${captureId}/file`, parentToken, null, true);
    assert.equal(file.status, 200);
    assert.equal(file.headers.get('content-type'), 'image/png');
    assert.equal(file.data.length, 8);
    const deleted = await req('POST', `/api/media/${captureId}/delete`, parentToken, {});
    assert.equal(deleted.status, 200);
    const gone = await req('GET', `/api/media/${captureId}/file`, parentToken, null, true);
    assert.equal(gone.status, 404);
  });

  it('audio longer than 30 seconds is rejected on upload', async () => {
    const { token: deviceToken, device } = await pairDevice('child-phone-3');
    const deviceId = device.id;
    const requested = await req('POST', '/api/media/audio-request', parentToken, {
      deviceId,
      source: 'sos',
    });
    assert.equal(requested.status, 201);
    const captureId = requested.data.capture.id;
    const tooLong = await req('POST', `/api/media/${captureId}/upload`, deviceToken, {
      dataBase64: Buffer.from('x').toString('base64'),
      mimeType: 'audio/mp4',
      durationSeconds: 31,
    });
    assert.equal(tooLong.status, 400);
  });

  it('unknown mime type and oversized files are rejected', async () => {
    const { token: deviceToken, device } = await pairDevice('child-phone-4');
    const deviceId = device.id;
    const requested = await req('POST', '/api/media/screenshot-request', parentToken, {
      deviceId,
    });
    const captureId = requested.data.capture.id;
    const badMime = await req('POST', `/api/media/${captureId}/upload`, deviceToken, {
      dataBase64: Buffer.from('x').toString('base64'),
      mimeType: 'video/mp4',
    });
    assert.equal(badMime.status, 400);
    const big = Buffer.alloc(8 * 1024 * 1024 + 1).toString('base64');
    const tooBig = await req('POST', `/api/media/${captureId}/upload`, deviceToken, {
      dataBase64: big,
      mimeType: 'image/png',
    });
    assert.equal(tooBig.status, 413);
  });
});

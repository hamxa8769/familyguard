// Phase 2 (v0.9.1) tests: gallery quality/caps/pagination/originals and
// comms conversations/export/search/pagination.
// Runs with `npm test` (node --test, no extra dependencies). Uses the
// in-memory store, same style as test/phase2.test.mjs. Thumbnail/original
// files land on disk under src/uploads/ and are removed in `after()`.
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { rm } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/app.js';

const uploadsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'uploads');

let server;
let base;
let parentToken;
let otherToken;
let deviceId;
let deviceToken;

// req(method, path, token, body) — same order as test/phase2.test.mjs.
async function req(method, path, token, body) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: res.status, data, headers: res.headers, text };
}

async function rawGet(path, token) {
  const res = await fetch(`${base}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  return { status: res.status, headers: res.headers, buf: Buffer.from(await res.arrayBuffer()) };
}

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
  const parent = await req('POST', '/api/auth/register', null, {
    email: 'parent-p2g@test.local',
    password: 'password1',
    role: 'parent',
  });
  assert.equal(parent.status, 201, JSON.stringify(parent.data));
  parentToken = parent.data.token;
  const other = await req('POST', '/api/auth/register', null, {
    email: 'parent-p2g-other@test.local',
    password: 'password1',
    role: 'parent',
  });
  assert.equal(other.status, 201, JSON.stringify(other.data));
  otherToken = other.data.token;
  const child = await req('POST', '/api/children', parentToken, { displayName: 'Gallery Kid' });
  assert.equal(child.status, 201, JSON.stringify(child.data));
  const paired = await req('POST', '/api/pair', null, {
    code: child.data.pairingCode,
    platform: 'android',
    deviceName: 'gallery-phone',
  });
  assert.equal(paired.status, 201, JSON.stringify(paired.data));
  deviceId = paired.data.device.id;
  deviceToken = paired.data.token;
  await req('PUT', `/api/files/${deviceId}/settings`, parentToken, { previews: true });
});

after(async () => {
  server.close();
  await rm(join(uploadsDir, 'thumbs'), { recursive: true, force: true });
  await rm(join(uploadsDir, 'originals'), { recursive: true, force: true });
});

const photoItems = (n) =>
  Array.from({ length: n }, (_, i) => ({
    key: `m:${i + 1}`,
    name: `photo${i + 1}.jpg`,
    album: i % 2 === 0 ? 'Camera' : 'Screenshots',
    size: 1000 + i,
    date: 1000 - i,
    isImage: true,
  }));

describe('gallery: disk thumbnails, caps, pagination', () => {
  it('accepts a 300 KB thumb (old 200 KB cap would drop it) and serves it from disk', async () => {
    const synced = await req('POST', `/api/files/${deviceId}`, deviceToken, { items: photoItems(3) });
    assert.equal(synced.status, 201, JSON.stringify(synced.data));
    const big = Buffer.alloc(300 * 1024, 7).toString('base64');
    const up = await req('POST', `/api/files/${deviceId}/thumbs`, deviceToken, {
      items: [{ key: 'm:1', mime: 'image/jpeg', data: big }],
    });
    assert.equal(up.status, 201, JSON.stringify(up.data));
    assert.equal(up.data.saved, 1);
    const got = await rawGet(`/api/files/${deviceId}/thumb/m:1`, parentToken);
    assert.equal(got.status, 200);
    assert.equal(got.headers.get('content-type'), 'image/jpeg');
    assert.equal(got.buf.length, 300 * 1024);
  });

  it('drops thumbs over the 1 MB cap', async () => {
    const huge = Buffer.alloc(1024 * 1024 + 1, 7).toString('base64');
    const r = await req('POST', `/api/files/${deviceId}/thumbs`, deviceToken, {
      items: [{ key: 'm:2', mime: 'image/jpeg', data: huge }],
    });
    assert.equal(r.data.saved, 0);
  });

  it('paginates the file list and filters by album', async () => {
    await req('POST', `/api/files/${deviceId}`, deviceToken, { items: photoItems(5) });
    const page1 = await req('GET', `/api/files/${deviceId}?limit=2&offset=0`, parentToken);
    assert.equal(page1.data.total, 5);
    assert.equal(page1.data.limit, 2);
    assert.equal(page1.data.offset, 0);
    assert.equal(page1.data.items.length, 2);
    const page2 = await req('GET', `/api/files/${deviceId}?limit=2&offset=2`, parentToken);
    assert.equal(page2.data.items.length, 2);
    assert.notEqual(page2.data.items[0].key, page1.data.items[0].key);
    const album = await req('GET', `/api/files/${deviceId}?album=Camera`, parentToken);
    assert.equal(album.data.total, 3);
    assert.ok(album.data.items.every((i) => i.album === 'Camera'));
  });
});

describe('gallery: full-res original on parent request', () => {
  it('request -> needOriginals -> device upload -> parent download round-trip', async () => {
    await req('POST', `/api/files/${deviceId}`, deviceToken, { items: photoItems(3) });
    const requested = await req('POST', `/api/files/${deviceId}/original/m:2/request`, parentToken, {});
    assert.equal(requested.status, 201, JSON.stringify(requested.data));
    assert.equal(requested.data.requested, true);
    const missing = await rawGet(`/api/files/${deviceId}/original/m:2`, parentToken);
    assert.equal(missing.status, 404, 'not available before the child uploads');
    const synced = await req('POST', `/api/files/${deviceId}`, deviceToken, { items: photoItems(3) });
    assert.ok(synced.data.needOriginals.includes('m:2'), JSON.stringify(synced.data));
    const bytes = Buffer.from('ORIGINAL-BYTES-m2');
    const uploaded = await req('POST', `/api/files/${deviceId}/original/m:2`, deviceToken, {
      mime: 'image/jpeg',
      data: bytes.toString('base64'),
    });
    assert.equal(uploaded.status, 201, JSON.stringify(uploaded.data));
    const got = await rawGet(`/api/files/${deviceId}/original/m:2`, parentToken);
    assert.equal(got.status, 200);
    assert.equal(got.headers.get('content-disposition'), 'attachment; filename="photo2.jpg"');
    assert.equal(got.buf.toString(), 'ORIGINAL-BYTES-m2');
    const listed = await req('GET', `/api/files/${deviceId}`, parentToken);
    assert.equal(listed.data.items.find((i) => i.key === 'm:2').hasOriginal, true);
  });

  it('rejects original requests from another parent and when previews are off', async () => {
    const wrong = await req('POST', `/api/files/${deviceId}/original/m:1/request`, otherToken, {});
    assert.equal(wrong.status, 403);
    await req('PUT', `/api/files/${deviceId}/settings`, parentToken, { previews: false });
    const off = await req('POST', `/api/files/${deviceId}/original/m:1/request`, parentToken, {});
    assert.equal(off.status, 409);
    await req('PUT', `/api/files/${deviceId}/settings`, parentToken, { previews: true });
  });
});

describe('comms: export, pagination, search, conversations', () => {
  const seed = async () => {
    const r = await req('POST', `/api/comms/${deviceId}`, deviceToken, {
      contacts: [
        { name: 'Ammi', number: '+92 300 1234567' },
        { name: 'School', number: '+92 42 111222333' },
      ],
      sms: [
        { address: '+92 300 1234567', body: 'hello beta', date: 3000, type: 1, threadId: 7 },
        { address: '+92 300 1234567', body: 'ghar kab aao ge', date: 2000, type: 2, threadId: 7 },
        { address: '+92 42 111222333', body: 'hello school', date: 1000, type: 1, threadId: 9 },
      ],
      callLog: [
        { number: '+92 300 1234567', type: 1, date: 3000, duration: 95 },
        { number: '+92 42 111222333', type: 3, date: 1000, duration: 0 },
      ],
    });
    assert.equal(r.status, 201, JSON.stringify(r.data));
  };

  it('exports SMS as a parseable CSV with attachment headers and retained counts', async () => {
    await seed();
    const res = await rawGet(`/api/comms/${deviceId}/export?format=csv&type=sms`, parentToken);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/csv/);
    assert.match(res.headers.get('content-disposition'), /attachment; filename="familyguard-comms-.*-sms\.csv"/);
    assert.equal(res.headers.get('x-export-counts'), 'sms=3; contacts=2; calls=2');
    const text = res.buf.toString('utf8');
    assert.ok(text.startsWith('\ufeff'), 'UTF-8 BOM for Excel');
    const lines = text.replace(/^\ufeff/, '').trim().split('\r\n');
    assert.equal(lines[0], 'date_iso,address,contact_name,type,body');
    assert.equal(lines.length, 4, 'header + 3 SMS rows');
    assert.ok(lines.some((l) => l.includes('Ammi') && l.includes('hello beta')));
  });

  it('exports all types as JSON with counts, and rejects csv+all', async () => {
    const r = await req('GET', `/api/comms/${deviceId}/export?format=json&type=all`, parentToken);
    assert.equal(r.status, 200);
    assert.deepEqual(r.data.counts, { sms: 3, contacts: 2, calls: 2 });
    assert.equal(r.data.sms.length, 3);
    assert.match(r.data.note, /3 SMS/);
    const bad = await req('GET', `/api/comms/${deviceId}/export?format=csv&type=all`, parentToken);
    assert.equal(bad.status, 400);
  });

  it('rejects export without a token and for another parent', async () => {
    const anon = await rawGet(`/api/comms/${deviceId}/export?format=csv&type=sms`, null);
    assert.equal(anon.status, 401);
    const wrong = await rawGet(`/api/comms/${deviceId}/export?format=csv&type=sms`, otherToken);
    assert.equal(wrong.status, 403);
  });

  it('paginates SMS and filters with ?q= and ?type=', async () => {
    const p1 = await req('GET', `/api/comms/${deviceId}?limit=2&offset=0`, parentToken);
    assert.equal(p1.data.total, 3);
    assert.equal(p1.data.sms.length, 2);
    const p2 = await req('GET', `/api/comms/${deviceId}?limit=2&offset=2`, parentToken);
    assert.equal(p2.data.sms.length, 1);
    assert.notEqual(p2.data.sms[0].body, p1.data.sms[0].body);
    const q = await req('GET', `/api/comms/${deviceId}?q=school`, parentToken);
    assert.equal(q.data.total, 1);
    assert.equal(q.data.sms[0].body, 'hello school');
    const sent = await req('GET', `/api/comms/${deviceId}?type=2`, parentToken);
    assert.equal(sent.data.total, 1);
    assert.equal(sent.data.sms[0].body, 'ghar kab aao ge');
  });

  it('groups conversations by thread and returns one in date order', async () => {
    const groups = await req('GET', `/api/comms/${deviceId}/conversations`, parentToken);
    assert.equal(groups.data.conversations.length, 2);
    const ammi = groups.data.conversations.find((g) => g.contactName === 'Ammi');
    assert.equal(ammi.count, 2);
    assert.equal(ammi.threadId, 7);
    const thread = await req('GET', `/api/comms/${deviceId}/conversations/t:7`, parentToken);
    assert.equal(thread.data.count, 2);
    assert.equal(thread.data.messages[0].body, 'ghar kab aao ge', 'oldest first');
    assert.equal(thread.data.messages[1].body, 'hello beta');
    const missing = await req('GET', `/api/comms/${deviceId}/conversations/t:999`, parentToken);
    assert.equal(missing.status, 404);
  });

  it('per-permission sync: posting only SMS keeps stored contacts and calls', async () => {
    await req('POST', `/api/comms/${deviceId}`, deviceToken, {
      sms: [{ address: '+92 300 1234567', body: 'new only', date: 4000, type: 1 }],
    });
    const after = await req('GET', `/api/comms/${deviceId}`, parentToken);
    assert.equal(after.data.contacts.length, 2, 'contacts untouched by an SMS-only sync');
    assert.equal(after.data.callLog.length, 2, 'call log untouched by an SMS-only sync');
    assert.equal(after.data.total, 1);
  });
});

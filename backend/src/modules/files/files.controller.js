import { createReadStream, existsSync, unlinkSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, extname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { store } from '../../config/store.js';

// Photo previews: thumbnails of the child's most recent photos.
// OFF by default; the parent turns them on per device (and the child is told
// in the consent notice). Turning them off deletes every stored thumbnail.
//
// Thumbnails live on disk under backend/src/uploads/thumbs/<deviceId>/ —
// the store only keeps {deviceId, key, mime, file, at}. (v0.9.0 kept them
// base64 inside familyguard.json; 500 thumbs x ~300 KB would bloat that
// single JSON file to ~150 MB.) Entries with a legacy `data` (base64) field
// are still served until they are replaced or deleted.
const MAX_PREVIEWS = 500; // newest N photos get a preview
const MAX_PER_UPLOAD = 100; // thumbnails requested per sync
const MAX_THUMB_BYTES = 1024 * 1024; // 1 MB (1024 px, JPEG q85 thumbs)
const MAX_ORIGINAL_BYTES = 8 * 1024 * 1024; // 8 MB decoded (base64-in-JSON, 12 MB body limit)
const MAX_ITEMS = 1000; // metadata rows kept per device
const MIMES = new Set(['image/jpeg', 'image/png']);
const ORIGINAL_MIMES = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
};

const uploadsRoot = join(
  fileURLToPath(new URL('.', import.meta.url)),
  '..',
  '..',
  'uploads'
);
const thumbsDir = join(uploadsRoot, 'thumbs');
const originalsDir = join(uploadsRoot, 'originals');

const listing = (deviceId) => store.files.find((f) => f.deviceId === deviceId);
const thumbsOf = (deviceId) => store.thumbnails.filter((t) => t.deviceId === deviceId);
const originalsOf = (deviceId) => store.originals.filter((o) => o.deviceId === deviceId);

/** File name safe for disk (keys look like "m:123" / "v:45"). */
const safeKey = (key) => String(key).replace(/[^A-Za-z0-9_-]/g, '_');

function thumbPath(entry) {
  if (!entry.file) return null;
  // Defence in depth: only the stored device id + file name are ever used.
  return join(thumbsDir, entry.deviceId, basename(entry.file));
}

function originalPath(entry) {
  if (!entry.file) return null;
  return join(originalsDir, entry.deviceId, basename(entry.file));
}

function deleteFile(file) {
  if (!file) return;
  try {
    unlinkSync(file);
  } catch {
    // Already gone (or never written) — not an error.
  }
}

/** Keys of the newest photos/videos that may have a preview (poster). */
function previewKeys(items) {
  return items
    .filter((i) => i.key)
    .sort((a, b) => (b.date || 0) - (a.date || 0))
    .slice(0, MAX_PREVIEWS)
    .map((i) => String(i.key));
}

function dropThumbs(deviceId, keep = new Set()) {
  const dropped = store.thumbnails.filter(
    (t) => t.deviceId === deviceId && !keep.has(t.key)
  );
  for (const t of dropped) deleteFile(thumbPath(t));
  store.thumbnails = store.thumbnails.filter(
    (t) => t.deviceId !== deviceId || keep.has(t.key)
  );
}

function dropOriginals(deviceId, keep = new Set()) {
  const dropped = store.originals.filter(
    (o) => o.deviceId === deviceId && !keep.has(o.key)
  );
  for (const o of dropped) deleteFile(originalPath(o));
  store.originals = store.originals.filter(
    (o) => o.deviceId !== deviceId || keep.has(o.key)
  );
  store.originalRequests = store.originalRequests.filter(
    (r) => r.deviceId !== deviceId || keep.has(r.key)
  );
}

/** Pending original requests the child still has to fulfil. */
function pendingOriginalKeys(deviceId, items) {
  const known = new Set((items ?? []).map((i) => String(i.key)));
  const have = new Set(originalsOf(deviceId).map((o) => o.key));
  return (store.originalRequests ?? [])
    .filter((r) => r.deviceId === deviceId && !have.has(r.key) && known.has(r.key))
    .map((r) => r.key);
}

export async function syncFiles(req, res, next) {
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: 'items[] is required' });
    }
    const deviceId = req.params.deviceId;
    // Never store local file paths (they can contain the device user's name).
    const clean = items.slice(0, MAX_ITEMS).map((i) => ({
      name: String(i.name ?? ''),
      size: Number(i.size) || 0,
      date: Number(i.date) || 0,
      isImage: i.isImage !== false,
      duration: Number(i.duration) || 0,
      key: String(i.key ?? ''),
      album: String(i.album ?? ''),
    }));
    const existing = listing(deviceId);
    if (existing) existing.items = clean;
    else store.files.push({ deviceId, items: clean });

    const previews = req.device.photoPreviews === true;
    const keys = previewKeys(clean);
    // Forget previews of photos that are no longer among the newest.
    dropThumbs(deviceId, previews ? new Set(keys) : new Set());
    const have = new Set(thumbsOf(deviceId).map((t) => t.key));
    const needThumbs = previews ? keys.filter((k) => !have.has(k)).slice(0, MAX_PER_UPLOAD) : [];
    const needOriginals = previews ? pendingOriginalKeys(deviceId, clean) : [];

    res.status(201).json({ deviceId, count: clean.length, previews, needThumbs, needOriginals });
  } catch (err) {
    next(err);
  }
}

export async function getFiles(req, res, next) {
  try {
    const deviceId = req.params.deviceId;
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 200, 1), 500);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
    const album = typeof req.query.album === 'string' && req.query.album !== '' ? req.query.album : null;
    const haveThumbs = new Set(thumbsOf(deviceId).map((t) => t.key));
    const haveOriginals = new Set(originalsOf(deviceId).map((o) => o.key));
    let items = listing(deviceId)?.items ?? [];
    if (album) items = items.filter((i) => i.album === album);
    const total = items.length;
    const page = items
      .slice(offset, offset + limit)
      .map((i) => ({
        ...i,
        hasThumb: haveThumbs.has(i.key),
        hasOriginal: haveOriginals.has(i.key),
      }));
    res.json({
      deviceId,
      total,
      limit,
      offset,
      previews: req.device.photoPreviews === true,
      items: page,
    });
  } catch (err) {
    next(err);
  }
}

// Parent: turn photo previews on/off for this device.
export async function setSettings(req, res, next) {
  try {
    if (typeof req.body?.previews !== 'boolean') {
      return res.status(400).json({ error: 'previews must be true or false' });
    }
    req.device.photoPreviews = req.body.previews;
    // Turning previews off deletes every stored preview AND original.
    if (!req.body.previews) {
      dropThumbs(req.params.deviceId);
      dropOriginals(req.params.deviceId);
    }
    res.json({ deviceId: req.params.deviceId, previews: req.device.photoPreviews });
  } catch (err) {
    next(err);
  }
}

// Device: upload previews the server asked for (base64).
export async function uploadThumbs(req, res, next) {
  try {
    if (req.user.role !== 'device') {
      return res.status(403).json({ error: 'Only the device uploads its previews' });
    }
    if (req.device.photoPreviews !== true) {
      return res.status(409).json({ error: 'Photo previews are turned off' });
    }
    const deviceId = req.params.deviceId;
    const allowed = new Set(previewKeys(listing(deviceId)?.items ?? []));
    const incoming = Array.isArray(req.body?.items) ? req.body.items.slice(0, MAX_PER_UPLOAD) : [];
    let saved = 0;
    for (const t of incoming) {
      const key = String(t?.key ?? '');
      const mime = String(t?.mime ?? '');
      if (!allowed.has(key) || !MIMES.has(mime) || typeof t.data !== 'string') continue;
      const bytes = Buffer.from(t.data, 'base64');
      if (bytes.length === 0 || bytes.length > MAX_THUMB_BYTES) continue;
      const ext = mime === 'image/png' ? '.png' : '.jpg';
      const rel = `${deviceId}/${safeKey(key)}${ext}`;
      const file = join(thumbsDir, deviceId, `${safeKey(key)}${ext}`);
      try {
        await mkdir(join(thumbsDir, deviceId), { recursive: true });
        await writeFile(file, bytes);
      } catch {
        continue;
      }
      const old = store.thumbnails.find((x) => x.deviceId === deviceId && x.key === key);
      if (old && old.file !== rel) deleteFile(thumbPath(old));
      store.thumbnails = store.thumbnails.filter(
        (x) => !(x.deviceId === deviceId && x.key === key)
      );
      store.thumbnails.push({ deviceId, key, mime, file: rel, at: new Date().toISOString() });
      saved++;
    }
    res.status(201).json({ deviceId, saved });
  } catch (err) {
    next(err);
  }
}

// Parent (or the device itself): one preview image (1024 px longest side).
export async function getThumb(req, res, next) {
  try {
    const t = store.thumbnails.find(
      (x) => x.deviceId === req.params.deviceId && x.key === req.params.key
    );
    if (!t) return res.status(404).json({ error: 'No preview' });
    res.set('Content-Type', t.mime);
    res.set('Cache-Control', 'private, max-age=3600');
    const file = thumbPath(t);
    if (file && existsSync(file)) return createReadStream(file).pipe(res);
    if (typeof t.data === 'string') {
      // Legacy entry stored before thumbs moved to disk.
      return res.send(Buffer.from(t.data, 'base64'));
    }
    return res.status(404).json({ error: 'Preview file not found on disk' });
  } catch (err) {
    next(err);
  }
}

// Parent: ask the child to upload the original file for one photo/video.
// The child fulfils it on its next sync (see needOriginals in syncFiles) —
// a gallery download is a parent request the child fulfils, never a silent
// exfiltration. Requires photo previews to be ON for the device.
export async function requestOriginal(req, res, next) {
  try {
    if (req.device.photoPreviews !== true) {
      return res.status(409).json({ error: 'Photo previews are turned off' });
    }
    const deviceId = req.params.deviceId;
    const key = req.params.key;
    const item = (listing(deviceId)?.items ?? []).find((i) => i.key === key);
    if (!item) return res.status(404).json({ error: 'Unknown photo' });
    const available = originalsOf(deviceId).some((o) => o.key === key);
    if (!available) {
      const pending = (store.originalRequests ?? []).some(
        (r) => r.deviceId === deviceId && r.key === key
      );
      if (!pending) {
        store.originalRequests.push({ deviceId, key, requestedAt: new Date().toISOString() });
      }
    }
    res.status(201).json({ deviceId, key, requested: !available, available });
  } catch (err) {
    next(err);
  }
}

// Device: upload the original file for one photo/video (base64, <= 8 MB).
export async function uploadOriginal(req, res, next) {
  try {
    if (req.user.role !== 'device') {
      return res.status(403).json({ error: 'Only the device uploads originals' });
    }
    if (req.device.photoPreviews !== true) {
      return res.status(409).json({ error: 'Photo previews are turned off' });
    }
    const deviceId = req.params.deviceId;
    const key = req.params.key;
    const item = (listing(deviceId)?.items ?? []).find((i) => i.key === key);
    if (!item) return res.status(404).json({ error: 'Unknown photo' });
    const mime = String(req.body?.mime ?? '');
    const ext = ORIGINAL_MIMES[mime];
    if (!ext || typeof req.body?.data !== 'string') {
      return res.status(400).json({ error: 'mime + base64 data are required' });
    }
    const bytes = Buffer.from(req.body.data, 'base64');
    if (bytes.length === 0) return res.status(400).json({ error: 'Empty file' });
    if (bytes.length > MAX_ORIGINAL_BYTES) {
      return res.status(413).json({ error: 'Original is larger than 8 MB' });
    }
    const rel = `${deviceId}/${safeKey(key)}${ext}`;
    const file = join(originalsDir, deviceId, `${safeKey(key)}${ext}`);
    try {
      await mkdir(join(originalsDir, deviceId), { recursive: true });
      await writeFile(file, bytes);
    } catch {
      return res.status(500).json({ error: 'Could not store the original' });
    }
    const old = store.originals.find((o) => o.deviceId === deviceId && o.key === key);
    if (old && old.file !== rel) deleteFile(originalPath(old));
    store.originals = store.originals.filter(
      (o) => !(o.deviceId === deviceId && o.key === key)
    );
    store.originals.push({
      deviceId,
      key,
      mime,
      file: rel,
      sizeBytes: bytes.length,
      at: new Date().toISOString(),
    });
    store.originalRequests = (store.originalRequests ?? []).filter(
      (r) => !(r.deviceId === deviceId && r.key === key)
    );
    res.status(201).json({ deviceId, key, saved: true, sizeBytes: bytes.length });
  } catch (err) {
    next(err);
  }
}

// Parent: download the original file (only after the child uploaded it).
export async function getOriginal(req, res, next) {
  try {
    if (req.device.photoPreviews !== true) {
      return res.status(409).json({ error: 'Photo previews are turned off' });
    }
    const deviceId = req.params.deviceId;
    const key = req.params.key;
    const o = store.originals.find((x) => x.deviceId === deviceId && x.key === key);
    if (!o) return res.status(404).json({ error: 'Original not available yet' });
    const file = originalPath(o);
    if (!file || !existsSync(file)) {
      return res.status(404).json({ error: 'Original file not found on disk' });
    }
    const item = (listing(deviceId)?.items ?? []).find((i) => i.key === key);
    const name = (item?.name || `${safeKey(key)}${extname(file)}`).replace(/["\r\n]/g, '');
    res.setHeader('Content-Type', o.mime);
    res.setHeader('Content-Disposition', `attachment; filename="${name}"`);
    createReadStream(file).pipe(res);
  } catch (err) {
    next(err);
  }
}

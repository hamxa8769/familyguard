import { store } from '../../config/store.js';

// Photo previews: small thumbnails of the child's most recent photos.
// OFF by default; the parent turns them on per device (and the child is told
// in the consent notice). Turning them off deletes every stored thumbnail.
const MAX_PREVIEWS = 100; // newest N photos get a preview
const MAX_PER_UPLOAD = 30; // thumbnails requested per sync
const MAX_THUMB_BYTES = 200 * 1024;
const MIMES = new Set(['image/jpeg', 'image/png']);

const listing = (deviceId) => store.files.find((f) => f.deviceId === deviceId);
const thumbsOf = (deviceId) => store.thumbnails.filter((t) => t.deviceId === deviceId);

/** Keys of the newest photos that may have a preview. */
function previewKeys(items) {
  return items
    .filter((i) => i.isImage !== false && i.key)
    .sort((a, b) => (b.date || 0) - (a.date || 0))
    .slice(0, MAX_PREVIEWS)
    .map((i) => String(i.key));
}

function dropThumbs(deviceId, keep = new Set()) {
  store.thumbnails = store.thumbnails.filter(
    (t) => t.deviceId !== deviceId || keep.has(t.key)
  );
}

export async function syncFiles(req, res, next) {
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: 'items[] is required' });
    }
    const deviceId = req.params.deviceId;
    // Never store local file paths (they can contain the device user's name).
    const clean = items.slice(0, 500).map((i) => ({
      name: String(i.name ?? ''),
      size: Number(i.size) || 0,
      date: Number(i.date) || 0,
      isImage: i.isImage !== false,
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

    res.status(201).json({ deviceId, count: clean.length, previews, needThumbs });
  } catch (err) {
    next(err);
  }
}

export async function getFiles(req, res, next) {
  try {
    const deviceId = req.params.deviceId;
    const have = new Set(thumbsOf(deviceId).map((t) => t.key));
    const items = (listing(deviceId)?.items ?? []).map((i) => ({ ...i, hasThumb: have.has(i.key) }));
    res.json({ deviceId, previews: req.device.photoPreviews === true, items });
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
    if (!req.body.previews) dropThumbs(req.params.deviceId); // delete them all
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
      store.thumbnails = store.thumbnails.filter((x) => !(x.deviceId === deviceId && x.key === key));
      store.thumbnails.push({ deviceId, key, mime, data: bytes.toString('base64'), at: new Date().toISOString() });
      saved++;
    }
    res.status(201).json({ deviceId, saved });
  } catch (err) {
    next(err);
  }
}

// Parent (or the device itself): one preview image.
export async function getThumb(req, res, next) {
  try {
    const t = store.thumbnails.find(
      (x) => x.deviceId === req.params.deviceId && x.key === req.params.key
    );
    if (!t) return res.status(404).json({ error: 'No preview' });
    res.set('Content-Type', t.mime);
    res.set('Cache-Control', 'private, max-age=3600');
    res.send(Buffer.from(t.data, 'base64'));
  } catch (err) {
    next(err);
  }
}

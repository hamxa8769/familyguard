import { store } from '../../config/store.js';

export async function syncFiles(req, res, next) {
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: 'items[] is required' });
    }
    const existing = store.files.find((f) => f.deviceId === req.params.deviceId);
    if (existing) {
      existing.items = items;
    } else {
      store.files.push({ deviceId: req.params.deviceId, items });
    }
    res.status(201).json({ deviceId: req.params.deviceId, count: items.length });
  } catch (err) {
    next(err);
  }
}

export async function getFiles(req, res, next) {
  try {
    const items =
      store.files.find((f) => f.deviceId === req.params.deviceId)?.items ?? [];
    res.json({ deviceId: req.params.deviceId, items });
  } catch (err) {
    next(err);
  }
}

import { store } from '../../config/store.js';

// List of app identifiers the device should block.
export async function setBlocked(req, res, next) {
  try {
    const { apps } = req.body;
    if (!Array.isArray(apps)) {
      return res.status(400).json({ error: 'apps must be an array of app names' });
    }
    const existing = store.blockedApps.find((b) => b.deviceId === req.params.deviceId);
    if (existing) {
      existing.apps = apps;
    } else {
      store.blockedApps.push({ deviceId: req.params.deviceId, apps });
    }
    res.json({ deviceId: req.params.deviceId, apps });
  } catch (err) {
    next(err);
  }
}

export async function getBlocked(req, res, next) {
  try {
    const entry = store.blockedApps.find((b) => b.deviceId === req.params.deviceId);
    res.json({ deviceId: req.params.deviceId, apps: entry?.apps ?? [] });
  } catch (err) {
    next(err);
  }
}

import { store } from '../../config/store.js';
import { parseLimitOffset, pageOf } from '../../middleware/pagination.js';

// Installed-apps inventory: the child device reports which apps are
// installed; the parent reads the list. Upserted by packageName so a
// re-sync updates versions instead of duplicating rows. lastSeenAt records
// the most recent sync that still listed the app.
export async function syncApps(req, res, next) {
  try {
    const { deviceId } = req.params;
    const { apps } = req.body;
    if (!Array.isArray(apps) || apps.length === 0) {
      return res.status(400).json({ error: 'apps must be a non-empty array' });
    }
    for (const app of apps) {
      if (!app || typeof app.packageName !== 'string' || !app.packageName.trim()) {
        return res.status(400).json({ error: 'each app requires a packageName' });
      }
    }
    const now = new Date().toISOString();
    for (const app of apps) {
      const existing = store.installedApps.find(
        (a) => a.deviceId === deviceId && a.packageName === app.packageName,
      );
      if (existing) {
        existing.label = app.label ?? existing.label;
        existing.versionName = app.versionName ?? existing.versionName;
        existing.installedAt = app.installedAt ?? existing.installedAt;
        existing.systemApp = app.systemApp ?? existing.systemApp;
        existing.lastSeenAt = now;
      } else {
        store.installedApps.push({
          deviceId,
          packageName: app.packageName,
          label: app.label ?? null,
          versionName: app.versionName ?? null,
          installedAt: app.installedAt ?? null,
          systemApp: app.systemApp ?? false,
          lastSeenAt: now,
        });
      }
    }
    const deviceApps = store.installedApps.filter((a) => a.deviceId === deviceId);
    res.json({ deviceId, synced: apps.length, apps: deviceApps });
  } catch (err) {
    next(err);
  }
}

export async function listApps(req, res, next) {
  try {
    const { deviceId } = req.params;
    const apps = store.installedApps.filter((a) => a.deviceId === deviceId);
    const { items, total, limit, offset } = pageOf(apps, parseLimitOffset(req));
    res.json({ deviceId, apps: items, total, limit, offset });
  } catch (err) {
    next(err);
  }
}

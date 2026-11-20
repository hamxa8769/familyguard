import { store, nextId } from '../../config/store.js';

// Browsing history — browser-app sessions only (which browser was used,
// when, for how long). Full URL history is NOT accessible on Android
// without a VPN/proxy, so this module deliberately never claims to
// collect URLs: there is no url field anywhere in the session shape.
export async function syncSessions(req, res, next) {
  try {
    const { deviceId } = req.params;
    const { sessions } = req.body;
    if (!Array.isArray(sessions) || sessions.length === 0) {
      return res.status(400).json({ error: 'sessions must be a non-empty array' });
    }
    for (const session of sessions) {
      if (!session || typeof session.packageName !== 'string' || !session.packageName.trim()) {
        return res.status(400).json({ error: 'each session requires a packageName' });
      }
      if (!session.startedAt) {
        return res.status(400).json({ error: 'each session requires a startedAt' });
      }
    }
    const now = new Date().toISOString();
    const created = sessions.map((session) => {
      const row = {
        id: nextId(),
        deviceId,
        packageName: session.packageName,
        browserLabel: session.browserLabel ?? null,
        startedAt: session.startedAt,
        endedAt: session.endedAt ?? null,
        durationSeconds: session.durationSeconds ?? null,
        syncedAt: now,
      };
      store.browsingSessions.push(row);
      return row;
    });
    res.status(201).json({ deviceId, sessions: created });
  } catch (err) {
    next(err);
  }
}

export async function listSessions(req, res, next) {
  try {
    const { deviceId } = req.params;
    const sessions = store.browsingSessions
      .filter((s) => s.deviceId === deviceId)
      .slice()
      .sort((a, b) => new Date(b.startedAt) - new Date(a.startedAt));
    res.json({ deviceId, sessions });
  } catch (err) {
    next(err);
  }
}

import { store } from '../../config/store.js';
import { accessibleDeviceIds } from '../../middleware/access.js';

// Everything a parent should be notified about since a point in time:
// SOS alerts, "more time" requests and safe-zone arrive/leave events.
// Cheap to poll; the parent app turns new items into notifications.
export async function getFeed(req, res, next) {
  try {
    const since = new Date(req.query.since || 0);
    if (Number.isNaN(since.getTime())) {
      return res.status(400).json({ error: 'since must be an ISO date' });
    }
    const ids = new Set(accessibleDeviceIds(req.user));
    const after = (at) => new Date(at) > since;
    const childName = (deviceId) => {
      const d = store.devices.find((x) => x.id === deviceId);
      return store.children.find((c) => c.id === d?.childId)?.displayName || 'Your child';
    };

    const items = [
      ...store.sosAlerts
        .filter((a) => ids.has(a.deviceId) && after(a.at))
        .map((a) => ({ type: 'sos', id: a.id, deviceId: a.deviceId, at: a.at,
          title: `SOS from ${childName(a.deviceId)}`, body: a.message })),
      ...store.timeRequests
        .filter((r) => ids.has(r.deviceId) && after(r.at))
        .map((r) => ({ type: 'request', id: r.id, deviceId: r.deviceId, at: r.at,
          title: `${childName(r.deviceId)} asks for +${r.minutes} min`,
          body: r.reason || 'More screen time' })),
      ...store.geofenceEvents
        .filter((e) => ids.has(e.deviceId) && after(e.at))
        .map((e) => ({ type: 'zone', id: e.id, deviceId: e.deviceId, at: e.at,
          title: `${childName(e.deviceId)} ${e.type === 'enter' ? 'arrived at' : 'left'} ${e.zoneName}`,
          body: 'Safe zone' })),
    ].sort((a, b) => new Date(a.at) - new Date(b.at));

    res.json({ now: new Date().toISOString(), items: items.slice(-50) });
  } catch (err) {
    next(err);
  }
}

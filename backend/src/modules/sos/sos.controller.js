import { store, nextId } from '../../config/store.js';
import { accessibleDeviceIds } from '../../middleware/access.js';
import { parseLimitOffset, pageOf } from '../../middleware/pagination.js';
import { notifyParentOfSos } from '../../services/pushService.js';

export async function triggerSos(req, res, next) {
  try {
    const { deviceId, message, lat, lng } = req.body;
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    const alert = {
      id: nextId(),
      deviceId,
      message: message || 'SOS triggered',
      lat: lat ?? null,
      lng: lng ?? null,
      at: new Date().toISOString(),
      resolved: false,
    };
    store.sosAlerts.push(alert);
    // Best-effort push to the parent (see notifyParentOfSos in
    // services/pushService.js for the targeting limits). The alert is
    // already stored, so the parent also sees it by polling GET /api/feed
    // even when no parent push token exists yet. Never fails the request.
    await notifyParentOfSos({ deviceId, message: alert.message });
    res.status(201).json(alert);
  } catch (err) {
    next(err);
  }
}

export async function listAlerts(req, res, next) {
  try {
    const allowed = new Set(accessibleDeviceIds(req.user));
    // Device alerts the caller may see, plus keyword alerts owned by the
    // calling parent (those have deviceId null; see keywords controller).
    const alerts = store.sosAlerts
      .filter(
        (a) =>
          allowed.has(a.deviceId) ||
          (req.user.role === 'parent' && a.parentId === req.user.id),
      )
      .reverse();
    const { items, total, limit, offset } = pageOf(alerts, parseLimitOffset(req));
    res.json({ alerts: items, total, limit, offset });
  } catch (err) {
    next(err);
  }
}

export async function resolveAlert(req, res, next) {
  try {
    const alert = store.sosAlerts.find((a) => a.id === req.params.id);
    const visible =
      alert &&
      (accessibleDeviceIds(req.user).includes(alert.deviceId) ||
        (req.user.role === 'parent' && alert.parentId === req.user.id));
    if (!visible) {
      return res.status(404).json({ error: 'Alert not found' });
    }
    alert.resolved = true;
    res.json(alert);
  } catch (err) {
    next(err);
  }
}

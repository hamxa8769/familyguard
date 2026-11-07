import { store, nextId } from '../../config/store.js';

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
    // In the full app this also fires a push notification to the parent.
    res.status(201).json(alert);
  } catch (err) {
    next(err);
  }
}

export async function listAlerts(req, res, next) {
  try {
    const alerts = store.sosAlerts.slice().reverse();
    res.json({ alerts });
  } catch (err) {
    next(err);
  }
}

export async function resolveAlert(req, res, next) {
  try {
    const alert = store.sosAlerts.find((a) => a.id === req.params.id);
    if (!alert) return res.status(404).json({ error: 'Alert not found' });
    alert.resolved = true;
    res.json(alert);
  } catch (err) {
    next(err);
  }
}

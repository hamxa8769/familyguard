import { store, nextId } from '../../config/store.js';
import { checkGeofences } from '../geofencing/geofencing.service.js';

export async function reportLocation(req, res, next) {
  try {
    const { deviceId, lat, lng } = req.body;
    if (!deviceId || typeof lat !== 'number' || typeof lng !== 'number') {
      return res.status(400).json({ error: 'deviceId, lat and lng are required' });
    }
    const point = { id: nextId(), deviceId, lat, lng, at: new Date().toISOString() };
    store.locations.push(point);

    // Geofencing hooks into every new location report.
    const events = checkGeofences(deviceId, lat, lng);
    res.status(201).json({ point, geofenceEvents: events });
  } catch (err) {
    next(err);
  }
}

export async function getLocation(req, res, next) {
  try {
    const history = store.locations
      .filter((p) => p.deviceId === req.params.deviceId)
      .slice(-50);
    res.json({
      deviceId: req.params.deviceId,
      current: history.at(-1) || null,
      history,
    });
  } catch (err) {
    next(err);
  }
}

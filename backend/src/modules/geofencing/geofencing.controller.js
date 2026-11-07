import { store, nextId } from '../../config/store.js';

export async function createZone(req, res, next) {
  try {
    const { deviceId, name, lat, lng, radiusM } = req.body;
    if (!deviceId || !name || typeof lat !== 'number' || typeof lng !== 'number') {
      return res.status(400).json({ error: 'deviceId, name, lat, lng are required' });
    }
    const zone = {
      id: nextId(),
      deviceId,
      name,
      lat,
      lng,
      radiusM: radiusM || 150,
    };
    store.geofences.push(zone);
    res.status(201).json(zone);
  } catch (err) {
    next(err);
  }
}

export async function listZones(req, res, next) {
  try {
    const zones = store.geofences.filter((z) => z.deviceId === req.params.deviceId);
    res.json({ deviceId: req.params.deviceId, zones });
  } catch (err) {
    next(err);
  }
}

export async function listEvents(req, res, next) {
  try {
    const events = store.geofenceEvents
      .filter((e) => e.deviceId === req.params.deviceId)
      .slice(-50);
    res.json({ deviceId: req.params.deviceId, events });
  } catch (err) {
    next(err);
  }
}

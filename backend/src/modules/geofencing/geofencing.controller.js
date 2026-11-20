import { store, nextId } from '../../config/store.js';
import { canAccessDevice } from '../../middleware/access.js';

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

// Parent removes a zone (and its event history).
export async function deleteZone(req, res, next) {
  try {
    const zone = store.geofences.find((z) => z.id === req.params.id);
    const device = zone && store.devices.find((d) => d.id === zone.deviceId);
    if (!zone || !canAccessDevice(req.user, device, { parentOnly: true })) {
      return res.status(404).json({ error: 'Zone not found' });
    }
    store.geofences = store.geofences.filter((z) => z.id !== zone.id);
    store.geofenceEvents = store.geofenceEvents.filter((e) => e.geofenceId !== zone.id);
    res.json({ deleted: zone.id });
  } catch (err) {
    next(err);
  }
}

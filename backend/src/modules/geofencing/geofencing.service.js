import { store, nextId } from '../../config/store.js';

// Haversine distance in metres between two lat/lng points.
function distanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// Called on every location report: emits enter/exit events when the device
// crosses a geofence boundary compared with its last known state.
export function checkGeofences(deviceId, lat, lng) {
  const zones = store.geofences.filter((z) => z.deviceId === deviceId);
  const emitted = [];

  for (const zone of zones) {
    const inside = distanceMeters(lat, lng, zone.lat, zone.lng) <= zone.radiusM;
    const lastEvent = store.geofenceEvents
      .filter((e) => e.geofenceId === zone.id)
      .at(-1);
    const wasInside = lastEvent?.type === 'enter';

    if (inside && !wasInside) {
      emitted.push(record(zone, deviceId, 'enter'));
    } else if (!inside && wasInside) {
      emitted.push(record(zone, deviceId, 'exit'));
    }
  }
  return emitted;
}

function record(zone, deviceId, type) {
  const event = {
    id: nextId(),
    geofenceId: zone.id,
    zoneName: zone.name,
    deviceId,
    type,
    at: new Date().toISOString(),
  };
  store.geofenceEvents.push(event);
  return event;
}

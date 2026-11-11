import { store } from '../config/store.js';

// Device-level authorisation. A request may touch a device's data only if:
//   - the caller is the parent who owns the child the device is paired to, or
//   - the caller IS that device (device token issued at pairing).
// The deviceId is read from :deviceId, or from the JSON body for POST routes.
//
// Options:
//   parentOnly — only the owning parent may call (e.g. changing rules).
export function requireDeviceAccess({ parentOnly = false } = {}) {
  return (req, res, next) => {
    const deviceId = String(req.params.deviceId ?? req.body?.deviceId ?? '');
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    const device = store.devices.find((d) => d.id === deviceId);
    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }
    if (!canAccessDevice(req.user, device, { parentOnly })) {
      return res.status(403).json({ error: 'No access to this device' });
    }
    // Heartbeat: any request from the device itself marks it as seen.
    if (req.user.role === 'device') device.lastSeenAt = new Date().toISOString();
    req.device = device;
    next();
  };
}

export function canAccessDevice(user, device, { parentOnly = false } = {}) {
  if (!user || !device) return false;
  if (user.role === 'parent') return device.parentId === user.id;
  if (parentOnly) return false;
  return user.role === 'device' && user.deviceId === device.id;
}

// Device ids a user may see (all devices of a parent's children, or itself).
export function accessibleDeviceIds(user) {
  if (user?.role === 'parent') {
    return store.devices.filter((d) => d.parentId === user.id).map((d) => d.id);
  }
  if (user?.role === 'device') return [user.deviceId];
  return [];
}

import { store } from '../config/store.js';

// Device-level authorisation. A request may touch a device's data only if:
//   - the caller is the parent who owns the child the device is paired to, or
//   - the caller IS that device (device token issued at pairing).
// The deviceId is read from :deviceId, or from the JSON body for POST routes,
// or from the query string for GET list routes (?deviceId=...).
//
// Options:
//   parentOnly — only the owning parent may call (e.g. changing rules).
export function requireDeviceAccess({ parentOnly = false } = {}) {
  return (req, res, next) => {
    const deviceId = String(req.params.deviceId ?? req.body?.deviceId ?? req.query?.deviceId ?? '');
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

// For routes addressed by a stored resource id (e.g. GET /api/media/:id,
// POST /api/remotecommands/:id/ack) where the deviceId lives on the
// resource, not in the URL/body/query: load the resource, then verify its
// device belongs to the caller with the same ownership check as above.
// `load` is an async (id) => resource | null; `pickDeviceId` reads the
// resource's deviceId. Missing resource → 404 (same message as the
// controller would return); wrong owner → 403.
export function requireResourceDeviceAccess(load, pickDeviceId, notFoundMessage = 'Not found') {
  return async (req, res, next) => {
    const resource = await load(req.params.id);
    if (!resource) {
      return res.status(404).json({ error: notFoundMessage });
    }
    const device = store.devices.find((d) => d.id === pickDeviceId(resource));
    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }
    if (!canAccessDevice(req.user, device)) {
      return res.status(403).json({ error: 'No access to this device' });
    }
    if (req.user.role === 'device') device.lastSeenAt = new Date().toISOString();
    req.device = device;
    next();
  };
}

export function canAccessDevice(user, device, { parentOnly = false } = {}) {
  if (!user || !device) return false;
  // Parent owns the device if it was paired to one of their children
  // (parentId) or registered directly by them (userId, pre-v0.9.0 shape).
  if (user.role === 'parent') {
    return device.parentId === user.id || device.userId === user.id;
  }
  if (parentOnly) return false;
  return user.role === 'device' && user.deviceId === device.id;
}

// Device ids a user may see (all devices of a parent's children, or itself).
export function accessibleDeviceIds(user) {
  if (user?.role === 'parent') {
    return store.devices
      .filter((d) => d.parentId === user.id || d.userId === user.id)
      .map((d) => d.id);
  }
  if (user?.role === 'device') return [user.deviceId];
  return [];
}

// Child-level authorisation, for the child-scoped modules (agreement,
// rewards, keywords): the childId is read from :childId, or from the JSON
// body for POST routes that create for a child.
//   - the owning parent: a child profile with this id must have
//     parentId === the caller's id. No profile exists for the id (legacy /
//     test shape where the id is a child user id): there is no owned child
//     to protect, so the parent role check alone applies.
//   - the child themself: a child-user token may only touch its own id.
//   - the child's device: a device token may only touch its own childId.
// A child profile owned by another parent is never accessible (403).
export function canAccessChild(user, childId) {
  if (!user || childId == null || String(childId) === '') return false;
  const id = String(childId);
  if (user.role === 'device') return user.childId === id;
  if (user.role === 'child') return user.id === id;
  if (user.role === 'parent') {
    const child = store.children.find((c) => c.id === id);
    return !child || child.parentId === user.id;
  }
  return false;
}

export function requireChildAccess() {
  return (req, res, next) => {
    const childId = String(req.params.childId ?? req.body?.childId ?? '');
    if (!childId) {
      return res.status(400).json({ error: 'childId is required' });
    }
    if (!canAccessChild(req.user, childId)) {
      return res.status(403).json({ error: 'No access to this child' });
    }
    next();
  };
}

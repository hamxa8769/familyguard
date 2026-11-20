import { store, nextId } from '../../config/store.js';
import { accessibleDeviceIds, canAccessDevice } from '../../middleware/access.js';
import { parseLimitOffset, pageOf } from '../../middleware/pagination.js';

// Phase 3 (rule-version fast path): every rule set bumps the owning
// device's rules version, so the child can poll the cheap
// GET /api/devices/:id/rules-version every minute and fetch the full rules
// only when something actually changed. The counter (not just the
// timestamp) is the version: two sets in the same millisecond must still
// be visible to the child.
export function bumpRulesVersion(device) {
  if (!device) return;
  device.rulesVersion = (device.rulesVersion ?? 0) + 1;
  device.rulesUpdatedAt = new Date().toISOString();
}

// GET /api/devices/:id/rules-version — cheap poll target for the child.
// The device is looked up by :id (not :deviceId), so the ownership check
// is done here, mirroring setPushToken below.
export async function getRulesVersion(req, res, next) {
  try {
    const device = store.devices.find((d) => d.id === req.params.id);
    if (!device) return res.status(404).json({ error: 'Device not found' });
    if (!canAccessDevice(req.user, device)) {
      return res.status(403).json({ error: 'No access to this device' });
    }
    res.json({
      deviceId: device.id,
      rulesVersion: device.rulesVersion ?? 0,
      updatedAt: device.rulesUpdatedAt ?? null,
    });
  } catch (err) {
    next(err);
  }
}

// Devices can also register directly (POST /api/devices) — the pairing flow
// (POST /api/pair, v0.8.0) creates them the same way. This lists the ones the
// caller may see: all of a parent's paired devices, or the device itself.
export async function registerDevice(req, res, next) {
  try {
    const { platform, deviceName, pushToken, pushPlatform } = req.body;
    if (!platform) {
      return res.status(400).json({ error: 'platform is required (android/ios/windows)' });
    }
    const device = {
      id: nextId(),
      userId: req.user.id,
      // A parent registering a device directly owns it (same shape as the
      // pairing flow, which sets parentId from the child record). Devices
      // created before parentId existed only carry userId — access checks
      // accept either field (see middleware/access.js).
      parentId: req.user.role === 'parent' ? req.user.id : null,
      platform,
      deviceName: deviceName || `${platform}-device`,
      // Push token is optional: without it the device polls for commands.
      pushToken: pushToken || null,
      pushPlatform: pushPlatform || null,
      registeredAt: new Date().toISOString(),
    };
    store.devices.push(device);
    res.status(201).json(device);
  } catch (err) {
    next(err);
  }
}

// A device (re-)registers its push token after FCM gives it one, or when
// the token refreshes. The token is only used to *notify* the device that
// a remote command is waiting — the command itself is fetched by polling.
export async function setPushToken(req, res, next) {
  try {
    const { pushToken, pushPlatform } = req.body;
    if (!pushToken) {
      return res.status(400).json({ error: 'pushToken is required' });
    }
    // Pairing-created devices carry parentId/childId but no userId, so
    // matching only userId 404d for every paired device. Accept the
    // owning parent (via userId or parentId) or the device itself
    // (device token issued at pairing).
    const device = store.devices.find(
      (d) =>
        d.id === req.params.id &&
        (d.userId === req.user.id ||
          d.parentId === req.user.id ||
          (req.user.role === 'device' && req.user.deviceId === d.id)),
    );
    if (!device) return res.status(404).json({ error: 'Device not found' });
    device.pushToken = pushToken;
    device.pushPlatform = pushPlatform || 'fcm';
    res.json(device);
  } catch (err) {
    next(err);
  }
}
export async function listDevices(req, res, next) {
  try {
    const ids = new Set(accessibleDeviceIds(req.user));
    const devices = store.devices.filter((d) => ids.has(d.id));
    const { items, total, limit, offset } = pageOf(devices, parseLimitOffset(req));
    res.json({ devices: items, total, limit, offset });
  } catch (err) {
    next(err);
  }
}

const STATUS_KEYS = [
  'supported', 'usageAccess', 'overlay', 'vpnApproved', 'notifications',
  'appRulesActive', 'webFilterActive', 'hasAppRules', 'hasWebRules',
];

// String-valued status fields (not booleans): the Private-DNS mode the
// child reports, so the parent can warn when it bypasses the web filter.
const STATUS_STRING_KEYS = ['privateDnsMode', 'privateDnsHostname'];

// The device reports what it can actually enforce (permissions granted,
// services running), so the parent knows whether rules really apply.
export async function reportStatus(req, res, next) {
  try {
    if (req.user.role !== 'device') {
      return res.status(403).json({ error: 'Only the device itself can report its status' });
    }
    const input = req.body?.enforcement;
    if (!input || typeof input !== 'object') {
      return res.status(400).json({ error: 'enforcement object is required' });
    }
    const enforcement = {};
    for (const k of STATUS_KEYS) {
      if (typeof input[k] === 'boolean') enforcement[k] = input[k];
    }
    for (const k of STATUS_STRING_KEYS) {
      if (typeof input[k] === 'string') enforcement[k] = input[k];
    }
    req.device.enforcement = enforcement;
    req.device.statusAt = new Date().toISOString();
    res.json({ deviceId: req.device.id, enforcement, statusAt: req.device.statusAt });
  } catch (err) {
    next(err);
  }
}

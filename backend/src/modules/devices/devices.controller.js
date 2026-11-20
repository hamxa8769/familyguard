import { store, nextId } from '../../config/store.js';
import { accessibleDeviceIds } from '../../middleware/access.js';

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
    const device = store.devices.find(
      (d) => d.id === req.params.id && d.userId === req.user.id,
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
    res.json({ devices });
  } catch (err) {
    next(err);
  }
}

const STATUS_KEYS = [
  'supported', 'usageAccess', 'overlay', 'vpnApproved', 'notifications',
  'appRulesActive', 'webFilterActive', 'hasAppRules', 'hasWebRules',
];

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
    req.device.enforcement = enforcement;
    req.device.statusAt = new Date().toISOString();
    res.json({ deviceId: req.device.id, enforcement, statusAt: req.device.statusAt });
  } catch (err) {
    next(err);
  }
}

import { store } from '../../config/store.js';
import { accessibleDeviceIds } from '../../middleware/access.js';

// Devices are created by pairing (POST /api/pair). This lists the ones the
// caller may see: all of a parent's paired devices, or the device itself.
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

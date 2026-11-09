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

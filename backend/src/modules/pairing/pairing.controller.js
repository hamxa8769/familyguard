import jwt from 'jsonwebtoken';
import { store, nextId } from '../../config/store.js';
import { newPairingCode } from './pairing.service.js';
import { jwtSecret } from '../../config/secrets.js';

const PLATFORMS = ['android', 'windows', 'ios'];

// Child device redeems the one-time code shown in the parent app.
// Returns a device-scoped token: it can only read/write this one device's data.
export async function pairDevice(req, res, next) {
  try {
    const code = String(req.body.code || '').trim().toUpperCase();
    const { platform, deviceName } = req.body;
    if (!code) return res.status(400).json({ error: 'code is required' });
    if (!PLATFORMS.includes(platform)) {
      return res.status(400).json({ error: `platform must be one of ${PLATFORMS.join(', ')}` });
    }
    const child = store.children.find((c) => c.pairingCode === code);
    if (!child) return res.status(404).json({ error: 'Invalid or used pairing code' });

    const device = {
      id: nextId(),
      childId: child.id,
      parentId: child.parentId,
      platform,
      deviceName: deviceName || `${platform}-device`,
      registeredAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
    };
    store.devices.push(device);
    // Codes are single-use; issue a fresh one for the next device.
    child.pairingCode = newPairingCode();

    const token = jwt.sign(
      { id: device.id, role: 'device', deviceId: device.id, childId: child.id, parentId: child.parentId },
      jwtSecret(),
      { expiresIn: '365d' }
    );
    res.status(201).json({
      token,
      device,
      child: { id: child.id, displayName: child.displayName },
    });
  } catch (err) {
    next(err);
  }
}

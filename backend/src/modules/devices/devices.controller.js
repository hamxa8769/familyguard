import { store, nextId } from '../../config/store.js';

export async function registerDevice(req, res, next) {
  try {
    const { platform, deviceName } = req.body;
    if (!platform) {
      return res.status(400).json({ error: 'platform is required (android/ios/windows)' });
    }
    const device = {
      id: nextId(),
      userId: req.user.id,
      platform,
      deviceName: deviceName || `${platform}-device`,
      registeredAt: new Date().toISOString(),
    };
    store.devices.push(device);
    res.status(201).json(device);
  } catch (err) {
    next(err);
  }
}

export async function listDevices(req, res, next) {
  try {
    const devices = store.devices.filter((d) => d.userId === req.user.id);
    res.json({ devices });
  } catch (err) {
    next(err);
  }
}

import { store, nextId } from '../../config/store.js';

export async function registerDevice(req, res, next) {
  try {
    const { platform, deviceName, pushToken, pushPlatform } = req.body;
    if (!platform) {
      return res.status(400).json({ error: 'platform is required (android/ios/windows)' });
    }
    const device = {
      id: nextId(),
      userId: req.user.id,
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
    const devices = store.devices.filter((d) => d.userId === req.user.id);
    res.json({ devices });
  } catch (err) {
    next(err);
  }
}

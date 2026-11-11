import { store, nextId } from '../../config/store.js';
import { accessibleDeviceIds } from '../../middleware/access.js';
import { startOfToday } from '../screentime/screentime.service.js';

// Child asks for extra screen time today; the parent approves or denies.
export async function createRequest(req, res, next) {
  try {
    const { deviceId, minutes, reason } = req.body;
    const mins = Number(minutes);
    if (!Number.isInteger(mins) || mins < 5 || mins > 240) {
      return res.status(400).json({ error: 'minutes must be a whole number from 5 to 240' });
    }
    // One open request per device at a time.
    const open = store.timeRequests.find((r) => r.deviceId === deviceId && r.status === 'pending');
    if (open) return res.status(409).json({ error: 'You already have a request waiting', request: open });
    const request = {
      id: nextId(),
      deviceId,
      minutes: mins,
      reason: String(reason || '').slice(0, 200),
      status: 'pending',
      at: new Date().toISOString(),
      decidedAt: null,
    };
    store.timeRequests.push(request);
    res.status(201).json(request);
  } catch (err) {
    next(err);
  }
}

// Parent: requests for all their devices. Device: its own requests.
export async function listRequests(req, res, next) {
  try {
    const ids = new Set(accessibleDeviceIds(req.user));
    const requests = store.timeRequests
      .filter((r) => ids.has(r.deviceId))
      .filter((r) => !req.query.status || r.status === req.query.status)
      .slice(-50)
      .reverse();
    res.json({ requests });
  } catch (err) {
    next(err);
  }
}

export async function decideRequest(req, res, next) {
  try {
    const request = store.timeRequests.find((r) => r.id === req.params.id);
    if (!request || !accessibleDeviceIds(req.user).includes(request.deviceId)) {
      return res.status(404).json({ error: 'Request not found' });
    }
    if (request.status !== 'pending') {
      return res.status(409).json({ error: `Request already ${request.status}` });
    }
    const approve = req.body.approve === true;
    request.status = approve ? 'approved' : 'denied';
    request.decidedAt = new Date().toISOString();
    if (approve) {
      store.bonusTime.push({
        deviceId: request.deviceId,
        day: startOfToday().toISOString(),
        minutes: request.minutes,
        requestId: request.id,
      });
    }
    res.json(request);
  } catch (err) {
    next(err);
  }
}

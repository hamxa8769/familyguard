import { store } from '../../config/store.js';
import { isWithinBedtime } from './bedtime.service.js';

// Bedtime window during which the device should be locked (e.g. 22 -> 6).
export async function setSchedule(req, res, next) {
  try {
    const { startHour, endHour } = req.body;
    if (!isHour(startHour) || !isHour(endHour)) {
      return res.status(400).json({ error: 'startHour and endHour must be 0-23' });
    }
    const existing = store.bedtimeSchedules.find((b) => b.deviceId === req.params.deviceId);
    if (existing) {
      Object.assign(existing, { startHour, endHour });
    } else {
      store.bedtimeSchedules.push({ deviceId: req.params.deviceId, startHour, endHour });
    }
    res.json({ deviceId: req.params.deviceId, startHour, endHour });
  } catch (err) {
    next(err);
  }
}

export async function getSchedule(req, res, next) {
  try {
    const schedule = store.bedtimeSchedules.find((b) => b.deviceId === req.params.deviceId) || null;
    res.json({
      deviceId: req.params.deviceId,
      schedule,
      lockedNow: schedule ? isWithinBedtime(schedule, new Date()) : false,
    });
  } catch (err) {
    next(err);
  }
}

const isHour = (h) => Number.isInteger(h) && h >= 0 && h <= 23;

import { store } from '../../config/store.js';
import { bumpRulesVersion } from '../devices/devices.controller.js';
import { isWithinBedtime } from './bedtime.service.js';
import { notifyRuleChange } from '../../services/pushService.js';

// Bedtime window during which the device should be locked (e.g. 22:30 -> 6:00).
// Minutes are optional (default 0): a 22:30 bedtime must not block at 22:00.
export async function setSchedule(req, res, next) {
  try {
    const { startHour, endHour, startMinute = 0, endMinute = 0 } = req.body;
    if (!isHour(startHour) || !isHour(endHour)) {
      return res.status(400).json({ error: 'startHour and endHour must be 0-23' });
    }
    if (!isMinute(startMinute) || !isMinute(endMinute)) {
      return res.status(400).json({ error: 'startMinute and endMinute must be 0-59' });
    }
    const existing = store.bedtimeSchedules.find((b) => b.deviceId === req.params.deviceId);
    if (existing) {
      Object.assign(existing, { startHour, endHour, startMinute, endMinute });
    } else {
      store.bedtimeSchedules.push({ deviceId: req.params.deviceId, startHour, endHour, startMinute, endMinute });
    }
    // Best-effort push so the child applies the new rules at once instead
    // of waiting for its next 15-minute poll; never fails the request.
    await notifyRuleChange(req.params.deviceId);
    bumpRulesVersion(req.device);
    res.json({ deviceId: req.params.deviceId, startHour, endHour, startMinute, endMinute });
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
const isMinute = (m) => Number.isInteger(m) && m >= 0 && m <= 59;

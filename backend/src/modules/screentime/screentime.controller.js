import { store } from '../../config/store.js';

// Daily screen-time cap (minutes) per device.
export async function setLimit(req, res, next) {
  try {
    const { dailyMinutes } = req.body;
    if (typeof dailyMinutes !== 'number' || dailyMinutes < 0) {
      return res.status(400).json({ error: 'dailyMinutes must be a non-negative number' });
    }
    const existing = store.screenTimeLimits.find((l) => l.deviceId === req.params.deviceId);
    if (existing) {
      existing.dailyMinutes = dailyMinutes;
    } else {
      store.screenTimeLimits.push({ deviceId: req.params.deviceId, dailyMinutes });
    }
    res.json({ deviceId: req.params.deviceId, dailyMinutes });
  } catch (err) {
    next(err);
  }
}

export async function getLimit(req, res, next) {
  try {
    const limit = store.screenTimeLimits.find((l) => l.deviceId === req.params.deviceId);
    // Minutes consumed today, derived from usage events.
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const consumedSeconds = store.usageEvents
      .filter((e) => e.deviceId === req.params.deviceId && new Date(e.startedAt) >= startOfDay)
      .reduce((sum, e) => sum + e.durationSeconds, 0);
    const dailyMinutes = limit?.dailyMinutes ?? null;
    const consumedMinutes = Math.round(consumedSeconds / 60);
    res.json({
      deviceId: req.params.deviceId,
      dailyMinutes,
      consumedMinutes,
      remainingMinutes: dailyMinutes == null ? null : Math.max(0, dailyMinutes - consumedMinutes),
      limitReached: dailyMinutes != null && consumedMinutes >= dailyMinutes,
    });
  } catch (err) {
    next(err);
  }
}

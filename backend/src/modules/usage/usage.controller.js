import * as usageService from './usage.service.js';
import { parseLimitOffset, pageOf } from '../../middleware/pagination.js';

export async function reportUsage(req, res, next) {
  try {
    const { deviceId, events, snapshot } = req.body;
    if (!deviceId || !Array.isArray(events)) {
      return res.status(400).json({ error: 'deviceId and events[] are required' });
    }
    const saved = await usageService.addEvents(deviceId, events, { snapshot: snapshot === true });
    res.status(201).json({ saved });
  } catch (err) {
    next(err);
  }
}

export async function getDaily(req, res, next) {
  try {
    const days = Math.min(Math.max(Number(req.query.days) || 7, 1), 31);
    res.json({ deviceId: req.params.deviceId, days: await usageService.daily(req.params.deviceId, days) });
  } catch (err) {
    next(err);
  }
}

export async function getUsage(req, res, next) {
  try {
    const summary = await usageService.summarise(req.params.deviceId);
    // The summary is an aggregate per app; paginate the per-app rows so a
    // device with very many apps stays bounded. Default limit 500 returns
    // the whole list at family scale (see middleware/pagination.js).
    const { items, total, limit, offset } = pageOf(
      summary.apps,
      parseLimitOffset(req),
    );
    res.json({ ...summary, apps: items, total, limit, offset });
  } catch (err) {
    next(err);
  }
}

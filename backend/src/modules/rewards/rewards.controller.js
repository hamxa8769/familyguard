import { store, nextId } from '../../config/store.js';

// Rewards: points (and optional badges) for healthy habits. Every award is
// stored as an event so the total is always derived, never a bare counter.
// The daily screen-time bonus is the one automatic rule: 10 points when the
// child stayed within their limit, idempotent per child+date so a retry or
// a double-submit can never double-award.
export const SCREEN_TIME_BONUS_POINTS = 10;
export const SCREEN_TIME_BONUS_REASON = 'Screen time within limit';

function totalPointsFor(childId) {
  return store.rewardEvents
    .filter((e) => e.childId === childId)
    .reduce((sum, e) => sum + e.points, 0);
}

function summarize(childId) {
  const events = store.rewardEvents.filter((e) => e.childId === childId);
  return {
    childId,
    totalPoints: events.reduce((sum, e) => sum + e.points, 0),
    events,
    badges: [...new Set(events.map((e) => e.badge).filter(Boolean))],
  };
}

export async function awardPoints(req, res, next) {
  try {
    const { childId } = req.params;
    const { points, reason, badge } = req.body;
    if (!Number.isFinite(points) || points <= 0) {
      return res.status(400).json({ error: 'points must be a positive number' });
    }
    if (typeof reason !== 'string' || !reason.trim()) {
      return res.status(400).json({ error: 'reason is required' });
    }
    const event = {
      id: nextId(),
      childId,
      points,
      reason,
      badge: badge ?? null,
      date: null,
      createdAt: new Date().toISOString(),
    };
    store.rewardEvents.push(event);
    res.status(201).json(event);
  } catch (err) {
    next(err);
  }
}

export async function getRewards(req, res, next) {
  try {
    res.json(summarize(req.params.childId));
  } catch (err) {
    next(err);
  }
}

export async function screenTimeBonus(req, res, next) {
  try {
    const { childId } = req.params;
    const { date, minutesUsed, limitMinutes } = req.body;
    if (typeof date !== 'string' || !date.trim()) {
      return res.status(400).json({ error: 'date is required' });
    }
    if (!Number.isFinite(minutesUsed) || !Number.isFinite(limitMinutes)) {
      return res.status(400).json({ error: 'minutesUsed and limitMinutes must be numbers' });
    }
    if (minutesUsed > limitMinutes) {
      return res.json({
        awarded: false,
        points: 0,
        reason: 'Screen time exceeded the limit',
        totalPoints: totalPointsFor(childId),
      });
    }
    const already = store.rewardEvents.find(
      (e) =>
        e.childId === childId &&
        e.date === date &&
        e.reason === SCREEN_TIME_BONUS_REASON,
    );
    if (already) {
      return res.json({
        awarded: false,
        alreadyAwarded: true,
        points: 0,
        reason: SCREEN_TIME_BONUS_REASON,
        totalPoints: totalPointsFor(childId),
      });
    }
    const event = {
      id: nextId(),
      childId,
      points: SCREEN_TIME_BONUS_POINTS,
      reason: SCREEN_TIME_BONUS_REASON,
      badge: null,
      date,
      createdAt: new Date().toISOString(),
    };
    store.rewardEvents.push(event);
    res.status(201).json({
      awarded: true,
      points: event.points,
      reason: event.reason,
      event,
      totalPoints: totalPointsFor(childId),
    });
  } catch (err) {
    next(err);
  }
}

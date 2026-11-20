import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { awardPoints, getRewards, screenTimeBonus } from './rewards.controller.js';

const router = Router();

// Only a parent awards points. Either role may read a child's totals.
// The screen-time bonus is automatic (10 points when within the limit)
// and idempotent per child+date.
router.post('/:childId/award', requireAuth, requireRole('parent'), awardPoints);
router.get('/:childId', requireAuth, getRewards);
router.post(
  '/:childId/screen-time-bonus',
  requireAuth,
  requireRole('parent'),
  screenTimeBonus,
);

export default router;

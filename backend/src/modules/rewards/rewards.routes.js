import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireChildAccess } from '../../middleware/access.js';
import { awardPoints, getRewards, screenTimeBonus } from './rewards.controller.js';

const router = Router();

// Only a parent awards points. Either role may read a child's totals —
// but only for a child they own / themself (requireChildAccess).
// The screen-time bonus is automatic (10 points when within the limit)
// and idempotent per child+date.
router.post('/:childId/award', requireAuth, requireRole('parent'), requireChildAccess(), awardPoints);
router.get('/:childId', requireAuth, requireChildAccess(), getRewards);
router.post(
  '/:childId/screen-time-bonus',
  requireAuth,
  requireRole('parent'),
  requireChildAccess(),
  screenTimeBonus,
);

export default router;

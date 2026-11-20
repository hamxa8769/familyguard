import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireChildAccess } from '../../middleware/access.js';
import {
  createAgreement,
  getLatestAgreement,
  signAgreement,
} from './agreement.controller.js';

const router = Router();

// The parent proposes the joint rules; the child signs (accepts/declines).
// Either role may read the latest agreement for a child — but only for a
// child they own / themself (requireChildAccess). Signing is checked
// in-controller: the route is addressed by agreement id, not childId.
router.post('/', requireAuth, requireRole('parent'), requireChildAccess(), createAgreement);
router.get('/:childId', requireAuth, requireChildAccess(), getLatestAgreement);
router.post('/:id/sign', requireAuth, requireRole('child'), signAgreement);

export default router;

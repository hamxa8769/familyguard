import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import {
  createAgreement,
  getLatestAgreement,
  signAgreement,
} from './agreement.controller.js';

const router = Router();

// The parent proposes the joint rules; the child signs (accepts/declines).
// Either role may read the latest agreement for a child.
router.post('/', requireAuth, requireRole('parent'), createAgreement);
router.get('/:childId', requireAuth, getLatestAgreement);
router.post('/:id/sign', requireAuth, requireRole('child'), signAgreement);

export default router;

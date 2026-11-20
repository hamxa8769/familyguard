import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { syncApps, listApps } from './apps.controller.js';

const router = Router();

// The child device syncs its installed-apps inventory; the parent reads it.
router.post('/:deviceId/sync', requireAuth, requireRole('child'), syncApps);
router.get('/:deviceId', requireAuth, requireRole('parent'), listApps);

export default router;

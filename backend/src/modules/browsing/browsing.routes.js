import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { syncSessions, listSessions } from './browsing.controller.js';

const router = Router();

// The child device syncs browser-app sessions; the parent reads them,
// newest first. No URLs are ever collected (see the controller header).
router.post('/:deviceId/sync', requireAuth, requireRole('child'), syncSessions);
router.get('/:deviceId', requireAuth, requireRole('parent'), listSessions);

export default router;

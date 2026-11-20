import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { syncSessions, listSessions } from './browsing.controller.js';

const router = Router();

// The child device syncs browser-app sessions; the parent reads them,
// newest first. No URLs are ever collected (see the controller header).
// Sync accepts the device's own token (role 'device') as well as a child
// user token; requireDeviceAccess proves the caller owns / is the device.
router.post('/:deviceId/sync', requireAuth, requireRole('child', 'device'), requireDeviceAccess(), syncSessions);
router.get('/:deviceId', requireAuth, requireRole('parent'), requireDeviceAccess(), listSessions);

export default router;

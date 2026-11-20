import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { syncApps, listApps } from './apps.controller.js';

const router = Router();

// The child device syncs its installed-apps inventory; the parent reads it.
// Sync accepts the device's own token (role 'device') as well as a child
// user token; requireDeviceAccess proves the caller owns / is the device.
router.post('/:deviceId/sync', requireAuth, requireRole('child', 'device'), requireDeviceAccess(), syncApps);
router.get('/:deviceId', requireAuth, requireRole('parent'), requireDeviceAccess(), listApps);

export default router;

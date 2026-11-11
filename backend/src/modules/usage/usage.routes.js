import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { reportUsage, getUsage, getDaily } from './usage.controller.js';

const router = Router();

// Child device reports usage events; parent queries them.
router.post('/', requireAuth, requireDeviceAccess(), reportUsage);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getUsage);
router.get('/:deviceId/daily', requireAuth, requireDeviceAccess(), getDaily);

export default router;

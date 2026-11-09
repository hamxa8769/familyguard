import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { listDevices, reportStatus } from './devices.controller.js';
import { requireDeviceAccess } from '../../middleware/access.js';

const router = Router();

router.get('/', requireAuth, listDevices);
router.put('/:deviceId/status', requireAuth, requireDeviceAccess(), reportStatus);

export default router;

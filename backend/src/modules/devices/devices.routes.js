import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { registerDevice, listDevices, setPushToken, reportStatus } from './devices.controller.js';
import { requireDeviceAccess } from '../../middleware/access.js';

const router = Router();

router.post('/', requireAuth, registerDevice);
router.get('/', requireAuth, listDevices);
router.post('/:id/push-token', requireAuth, setPushToken);
router.put('/:deviceId/status', requireAuth, requireDeviceAccess(), reportStatus);

export default router;

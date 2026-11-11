import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { setSchedule, getSchedule } from './bedtime.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, requireDeviceAccess({ parentOnly: true }), setSchedule);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getSchedule);

export default router;

import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { setBlocked, getBlocked } from './appblocking.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, requireDeviceAccess({ parentOnly: true }), setBlocked);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getBlocked);

export default router;

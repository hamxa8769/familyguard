import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { setLimit, getLimit } from './screentime.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, requireDeviceAccess({ parentOnly: true }), setLimit);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getLimit);

export default router;

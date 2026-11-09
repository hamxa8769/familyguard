import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { setFilter, getFilter, checkDomain } from './webfilter.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, requireDeviceAccess({ parentOnly: true }), setFilter);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getFilter);
router.get('/:deviceId/check', requireAuth, requireDeviceAccess(), checkDomain);

export default router;

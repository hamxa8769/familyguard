import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { deviceReport } from './reports.controller.js';

const router = Router();

// Aggregated summary a parent sees for one device.
router.get('/:deviceId', requireAuth, requireDeviceAccess(), deviceReport);

export default router;

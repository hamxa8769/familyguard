import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { reportLocation, getLocation } from './location.controller.js';

const router = Router();

// Child device reports its location; parent reads current + recent history.
router.post('/', requireAuth, requireDeviceAccess(), reportLocation);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getLocation);

export default router;

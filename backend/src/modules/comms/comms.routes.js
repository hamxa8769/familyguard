import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { syncComms, getComms } from './comms.controller.js';

const router = Router();

// Child device syncs its contacts + SMS; parent reads them.
// Sensitive data — always disclosed to the child in the app's transparency screen.
router.post('/:deviceId', requireAuth, requireDeviceAccess(), syncComms);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getComms);

export default router;

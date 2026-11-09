import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { createZone, listZones, listEvents } from './geofencing.controller.js';

const router = Router();

router.post('/', requireAuth, requireDeviceAccess({ parentOnly: true }), createZone);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), listZones);
router.get('/:deviceId/events', requireAuth, requireDeviceAccess(), listEvents);

export default router;

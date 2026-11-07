import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { createZone, listZones, listEvents } from './geofencing.controller.js';

const router = Router();

router.post('/', requireAuth, createZone);
router.get('/:deviceId', requireAuth, listZones);
router.get('/:deviceId/events', requireAuth, listEvents);

export default router;

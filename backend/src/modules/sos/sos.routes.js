import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { triggerSos, listAlerts, resolveAlert } from './sos.controller.js';

const router = Router();

// Child triggers an SOS; parent lists and resolves alerts.
router.post('/', requireAuth, requireDeviceAccess(), triggerSos);
router.get('/', requireAuth, listAlerts);
router.post('/:id/resolve', requireAuth, requireRole('parent'), resolveAlert);

export default router;

import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { triggerSos, listAlerts, resolveAlert } from './sos.controller.js';

const router = Router();

// Child triggers an SOS; parent lists and resolves alerts.
router.post('/', requireAuth, triggerSos);
router.get('/', requireAuth, listAlerts);
router.post('/:id/resolve', requireAuth, resolveAlert);

export default router;

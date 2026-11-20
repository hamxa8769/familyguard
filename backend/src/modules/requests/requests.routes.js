import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { createRequest, listRequests, decideRequest } from './requests.controller.js';

const router = Router();

// "Ask for more time": child device creates, parent decides.
router.post('/', requireAuth, requireDeviceAccess(), createRequest);
router.get('/', requireAuth, listRequests);
router.post('/:id/decide', requireAuth, requireRole('parent'), decideRequest);

export default router;

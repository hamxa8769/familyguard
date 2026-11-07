import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { recordConsent, getConsent } from './consent.controller.js';

const router = Router();

// Monitoring must not begin until consent is recorded — core to transparency.
router.post('/', requireAuth, recordConsent);
router.get('/:deviceId', requireAuth, getConsent);

export default router;

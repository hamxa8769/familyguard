import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { reportUsage, getUsage } from './usage.controller.js';

const router = Router();

// Child device reports usage events; parent queries them.
router.post('/', requireAuth, reportUsage);
router.get('/:deviceId', requireAuth, getUsage);

export default router;

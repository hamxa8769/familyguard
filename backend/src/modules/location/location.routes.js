import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { reportLocation, getLocation } from './location.controller.js';

const router = Router();

// Child device reports its location; parent reads current + recent history.
router.post('/', requireAuth, reportLocation);
router.get('/:deviceId', requireAuth, getLocation);

export default router;

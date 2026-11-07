import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { setSchedule, getSchedule } from './bedtime.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, setSchedule);
router.get('/:deviceId', requireAuth, getSchedule);

export default router;

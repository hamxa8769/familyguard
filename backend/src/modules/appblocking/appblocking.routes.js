import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { setBlocked, getBlocked } from './appblocking.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, setBlocked);
router.get('/:deviceId', requireAuth, getBlocked);

export default router;

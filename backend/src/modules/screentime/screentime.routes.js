import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { setLimit, getLimit } from './screentime.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, setLimit);
router.get('/:deviceId', requireAuth, getLimit);

export default router;

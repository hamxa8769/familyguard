import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { setFilter, getFilter, checkDomain } from './webfilter.controller.js';

const router = Router();

router.put('/:deviceId', requireAuth, setFilter);
router.get('/:deviceId', requireAuth, getFilter);
router.get('/:deviceId/check', requireAuth, checkDomain);

export default router;

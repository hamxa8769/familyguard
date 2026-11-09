import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { listDevices } from './devices.controller.js';

const router = Router();

router.get('/', requireAuth, listDevices);

export default router;

import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { registerDevice, listDevices } from './devices.controller.js';

const router = Router();

router.post('/', requireAuth, registerDevice);
router.get('/', requireAuth, listDevices);

export default router;

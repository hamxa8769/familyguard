import { Router } from 'express';
import { pairDevice } from './pairing.controller.js';
import { rateLimit } from '../../middleware/rateLimit.js';

const router = Router();

// Public: the code itself is the credential (single-use, generated per child).
router.post('/', rateLimit({ max: Number(process.env.AUTH_RATE_LIMIT) || 20 }), pairDevice);

export default router;

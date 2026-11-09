import { Router } from 'express';
import { register, login } from './auth.controller.js';
import { rateLimit } from '../../middleware/rateLimit.js';

const router = Router();

const limit = rateLimit({ max: Number(process.env.AUTH_RATE_LIMIT) || 20 });
router.post('/register', limit, register);
router.post('/login', limit, login);

export default router;

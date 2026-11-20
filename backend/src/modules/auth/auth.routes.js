import { Router } from 'express';
import { register, login, changePassword, refresh, logout } from './auth.controller.js';
import { requireAuth } from '../../middleware/auth.js';
import { rateLimit } from '../../middleware/rateLimit.js';

const router = Router();

const limit = rateLimit({ max: Number(process.env.AUTH_RATE_LIMIT) || 20 });
router.post('/register', limit, register);
router.post('/login', limit, login);
// Phase 5: session endpoints. All need a valid token; logout revokes it.
router.post('/change-password', requireAuth, changePassword);
router.post('/refresh', requireAuth, refresh);
router.post('/logout', requireAuth, logout);

export default router;

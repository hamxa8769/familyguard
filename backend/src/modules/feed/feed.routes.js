import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { getFeed } from './feed.controller.js';

const router = Router();

// GET /api/feed?since=ISO — new things to notify the parent about.
router.get('/', requireAuth, requireRole('parent'), getFeed);

export default router;

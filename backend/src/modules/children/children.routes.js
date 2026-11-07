import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { addChild, listChildren } from './children.controller.js';

const router = Router();

// Multi-child support: a parent manages several child profiles.
router.post('/', requireAuth, addChild);
router.get('/', requireAuth, listChildren);

export default router;

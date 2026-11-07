import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { whatParentSees } from './transparency.controller.js';

const router = Router();

// Two-way transparency: the child can see EXACTLY what the parent sees.
// Deliberately returns the same report payload used on the parent side.
router.get('/:deviceId', requireAuth, whatParentSees);

export default router;

import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { whatParentSees } from './transparency.controller.js';

const router = Router();

// Two-way transparency: the child can see EXACTLY what the parent sees.
// Deliberately returns the same report payload used on the parent side.
router.get('/:deviceId', requireAuth, requireDeviceAccess(), whatParentSees);

export default router;

import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { whatParentSees, listAuditLog } from './transparency.controller.js';

const router = Router();

// Two-way transparency: the child can see EXACTLY what the parent sees.
// Deliberately returns the same report payload used on the parent side.
router.get('/:deviceId', requireAuth, requireDeviceAccess(), whatParentSees);
// The audit log itself, newest first (Phase 5): every remote command and
// capture is logged here, so the transparency screen's promise is true.
router.get('/:deviceId/audit', requireAuth, requireDeviceAccess(), listAuditLog);

export default router;

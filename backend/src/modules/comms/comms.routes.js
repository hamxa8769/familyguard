import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import {
  syncComms,
  getComms,
  getConversations,
  getConversation,
  exportComms,
} from './comms.controller.js';

const router = Router();

// Child device syncs its contacts + SMS; parent reads them.
// Sensitive data — always disclosed to the child in the app's transparency screen.
router.post('/:deviceId', requireAuth, requireDeviceAccess(), syncComms);
router.get('/:deviceId/conversations', requireAuth, requireDeviceAccess(), getConversations);
router.get('/:deviceId/conversations/:address', requireAuth, requireDeviceAccess(), getConversation);
router.get('/:deviceId/export', requireAuth, requireDeviceAccess({ parentOnly: true }), exportComms);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getComms);

export default router;

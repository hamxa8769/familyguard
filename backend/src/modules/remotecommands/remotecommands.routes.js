import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import {
  acknowledgeCommand,
  cancelCommand,
  createCommand,
  getCommand,
  listCommands,
} from './remotecommands.controller.js';

const router = Router();

// Only a parent can create/cancel commands. The child polls the list and
// acknowledges them — push is best-effort only, polling is the contract.
router.post('/', requireAuth, requireRole('parent'), createCommand);
router.get('/', requireAuth, listCommands);
router.get('/:id', requireAuth, getCommand);
router.post('/:id/ack', requireAuth, acknowledgeCommand);
router.post('/:id/cancel', requireAuth, requireRole('parent'), cancelCommand);

export default router;

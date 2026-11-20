import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import {
  requireDeviceAccess,
  requireResourceDeviceAccess,
} from '../../middleware/access.js';
import { getRemoteCommand } from '../../db/repository.js';
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
// Creating/listing is device-scoped (deviceId in body/query); single
// commands are checked against the device on the stored command.
router.post('/', requireAuth, requireRole('parent'), requireDeviceAccess({ parentOnly: true }), createCommand);
router.get('/', requireAuth, requireDeviceAccess(), listCommands);
const commandAccess = requireResourceDeviceAccess(
  getRemoteCommand,
  (command) => command.deviceId,
  'Command not found',
);
router.get('/:id', requireAuth, commandAccess, getCommand);
router.post('/:id/ack', requireAuth, commandAccess, acknowledgeCommand);
// Cancel keeps its createdBy check in the controller, on top of the
// device-ownership check here.
router.post('/:id/cancel', requireAuth, requireRole('parent'), commandAccess, cancelCommand);

export default router;

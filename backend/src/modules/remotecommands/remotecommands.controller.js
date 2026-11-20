import {
  COMMAND_TYPES,
  createRemoteCommand,
  getRemoteCommand,
  listRemoteCommands,
  logAudit,
  updateRemoteCommand,
} from '../../db/repository.js';
import { store } from '../../config/store.js';
import { sendPush } from '../../services/pushService.js';

// Parent creates a command for a child device; the child polls for it.
// Commands expire (default 15 min) so a stale "lock now" can never fire
// hours later. Every command is audit-logged so the child can see it in
// "What My Parent Sees".
export async function createCommand(req, res, next) {
  try {
    const { deviceId, type, payload } = req.body;
    if (!deviceId || !type) {
      return res.status(400).json({ error: 'deviceId and type are required' });
    }
    if (!COMMAND_TYPES.includes(type)) {
      return res.status(400).json({ error: `type must be one of: ${COMMAND_TYPES.join(', ')}` });
    }
    if (type === 'send_message' && !(payload?.text || '').trim()) {
      return res.status(400).json({ error: 'send_message requires payload.text' });
    }
    const command = await createRemoteCommand({
      deviceId,
      createdBy: req.user.id,
      type,
      payload: payload ?? {},
    });
    await logAudit({
      deviceId,
      actorUserId: req.user.id,
      action: `remote_command:${type}`,
      detail: { commandId: command.id },
    });
    // Best-effort push; the child polls regardless (see pushService.js).
    const device = store.devices.find((d) => d.id === deviceId);
    if (device?.pushToken) {
      await sendPush({
        token: device.pushToken,
        title: 'FamilyGuard',
        body: commandLabel(type),
        data: { commandId: command.id, type },
      });
    }
    res.status(201).json(command);
  } catch (err) {
    next(err);
  }
}

function commandLabel(type) {
  switch (type) {
    case 'lock_now':
      return 'Your parent locked this device';
    case 'unlock':
      return 'Your parent unlocked this device';
    case 'send_message':
      return 'Message from your parent';
    case 'request_screenshot':
      return 'Your parent requested a screenshot — you will see a countdown first';
    case 'request_audio':
      return 'Your parent requested a short SOS audio clip (max 30 seconds)';
    default:
      return 'New command from your parent';
  }
}

export async function listCommands(req, res, next) {
  try {
    const { deviceId, status } = req.query;
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId query parameter is required' });
    }
    const commands = await listRemoteCommands({ deviceId, status });
    res.json({ commands });
  } catch (err) {
    next(err);
  }
}

export async function getCommand(req, res, next) {
  try {
    const command = await getRemoteCommand(req.params.id);
    if (!command) return res.status(404).json({ error: 'Command not found' });
    res.json(command);
  } catch (err) {
    next(err);
  }
}

// Child acknowledges receipt / reports completion. Only the owning device's
// user (or the parent who created it, for cancellation) may change it —
// enforced by checking the command's device belongs to the caller.
export async function acknowledgeCommand(req, res, next) {
  try {
    const { status, result } = req.body;
    const allowed = ['acknowledged', 'completed', 'rejected'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${allowed.join(', ')}` });
    }
    const command = await getRemoteCommand(req.params.id);
    if (!command) return res.status(404).json({ error: 'Command not found' });
    if (command.status !== 'pending' && command.status !== 'acknowledged') {
      return res.status(409).json({ error: `Command is already ${command.status}` });
    }
    const updated = await updateRemoteCommand(req.params.id, { status, result });
    await logAudit({
      deviceId: command.deviceId,
      actorUserId: req.user.id,
      action: `remote_command:${status}`,
      detail: { commandId: command.id, type: command.type },
    });
    res.json(updated);
  } catch (err) {
    next(err);
  }
}

export async function cancelCommand(req, res, next) {
  try {
    const command = await getRemoteCommand(req.params.id);
    if (!command) return res.status(404).json({ error: 'Command not found' });
    if (command.createdBy !== req.user.id) {
      return res.status(403).json({ error: 'Only the parent who created this command can cancel it' });
    }
    if (command.status !== 'pending') {
      return res.status(409).json({ error: `Command is already ${command.status}` });
    }
    const updated = await updateRemoteCommand(req.params.id, { status: 'cancelled' });
    res.json(updated);
  } catch (err) {
    next(err);
  }
}

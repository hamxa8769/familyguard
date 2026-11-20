import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import {
  requireDeviceAccess,
  requireResourceDeviceAccess,
} from '../../middleware/access.js';
import { getMediaCapture } from '../../db/repository.js';
import {
  completeCapture,
  deleteCapture,
  getCapture,
  getFile,
  listCaptures,
  purgeExpired,
  requestAudio,
  requestScreenshot,
  uploadCapture,
} from './media.controller.js';

const router = Router();

// Only a parent can request a screenshot or an audio clip, and only the
// two consented kinds exist: on-request screenshot, SOS/parent-requested
// audio capped at 30 seconds. See the controller header for the hard limits.
// Only the parent who owns the device may request (deviceId in the body).
router.post('/screenshot-request', requireAuth, requireRole('parent'), requireDeviceAccess({ parentOnly: true }), requestScreenshot);
router.post('/audio-request', requireAuth, requireRole('parent'), requireDeviceAccess({ parentOnly: true }), requestAudio);
// Every other capture endpoint verifies the capture's device belongs to
// the caller (owning parent or the device itself); a bare requireAuth let
// any authenticated user list/get/download/delete any capture by ID.
const captureAccess = requireResourceDeviceAccess(
  getMediaCapture,
  (capture) => capture.deviceId,
  'Capture not found',
);
router.get('/', requireAuth, requireDeviceAccess(), listCaptures);
router.get('/:id', requireAuth, captureAccess, getCapture);
router.get('/:id/file', requireAuth, captureAccess, getFile);
router.post('/:id/complete', requireAuth, captureAccess, completeCapture);
router.post('/:id/upload', requireAuth, captureAccess, uploadCapture);
router.post('/:id/delete', requireAuth, captureAccess, deleteCapture);
// Global purge: no single device to check, parent role only (unchanged).
router.post('/purge-expired', requireAuth, requireRole('parent'), purgeExpired);

export default router;

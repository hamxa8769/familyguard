import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
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
router.post('/screenshot-request', requireAuth, requireRole('parent'), requestScreenshot);
router.post('/audio-request', requireAuth, requireRole('parent'), requestAudio);
router.get('/', requireAuth, listCaptures);
router.get('/:id', requireAuth, getCapture);
router.get('/:id/file', requireAuth, getFile);
router.post('/:id/complete', requireAuth, completeCapture);
router.post('/:id/upload', requireAuth, uploadCapture);
router.post('/:id/delete', requireAuth, deleteCapture);
router.post('/purge-expired', requireAuth, requireRole('parent'), purgeExpired);

export default router;

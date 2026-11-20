import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import {
  syncFiles,
  getFiles,
  setSettings,
  uploadThumbs,
  getThumb,
  requestOriginal,
  uploadOriginal,
  getOriginal,
} from './files.controller.js';

const router = Router();

// Child device syncs photo/file metadata; parent reads it.
// Sensitive — always disclosed to the child in the app's transparency screen.
router.post('/:deviceId', requireAuth, requireDeviceAccess(), syncFiles);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getFiles);

// Photo previews (off by default; parent opts in per device).
router.put('/:deviceId/settings', requireAuth, requireDeviceAccess({ parentOnly: true }), setSettings);
router.post('/:deviceId/thumbs', requireAuth, requireDeviceAccess(), uploadThumbs);
router.get('/:deviceId/thumb/:key', requireAuth, requireDeviceAccess(), getThumb);

// Full-resolution originals, on parent request only: the parent requests,
// the child uploads on its next sync, then the parent downloads. Requires
// photo previews to be ON (the same opt-in as thumbnails).
router.post('/:deviceId/original/:key/request', requireAuth, requireDeviceAccess({ parentOnly: true }), requestOriginal);
router.post('/:deviceId/original/:key', requireAuth, requireDeviceAccess(), uploadOriginal);
router.get('/:deviceId/original/:key', requireAuth, requireDeviceAccess(), getOriginal);

export default router;

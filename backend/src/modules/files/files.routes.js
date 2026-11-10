import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { requireDeviceAccess } from '../../middleware/access.js';
import { syncFiles, getFiles, setSettings, uploadThumbs, getThumb } from './files.controller.js';

const router = Router();

// Child device syncs photo/file metadata; parent reads it.
// Sensitive — always disclosed to the child in the app's transparency screen.
router.post('/:deviceId', requireAuth, requireDeviceAccess(), syncFiles);
router.get('/:deviceId', requireAuth, requireDeviceAccess(), getFiles);

// Photo previews (off by default; parent opts in per device).
router.put('/:deviceId/settings', requireAuth, requireDeviceAccess({ parentOnly: true }), setSettings);
router.post('/:deviceId/thumbs', requireAuth, requireDeviceAccess(), uploadThumbs);
router.get('/:deviceId/thumb/:key', requireAuth, requireDeviceAccess(), getThumb);

export default router;

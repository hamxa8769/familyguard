import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.js';
import { syncFiles, getFiles } from './files.controller.js';

const router = Router();

// Child device syncs gallery/file metadata; parent reads it.
// Sensitive — always disclosed to the child in the app's transparency screen.
router.post('/:deviceId', requireAuth, syncFiles);
router.get('/:deviceId', requireAuth, getFiles);

export default router;

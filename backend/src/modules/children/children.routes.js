import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { addChild, listChildren, regeneratePairingCode } from './children.controller.js';

const router = Router();

// Multi-child support: a parent manages several child profiles.
router.use(requireAuth, requireRole('parent'));
router.post('/', addChild);
router.get('/', listChildren);
router.post('/:id/pairing-code', regeneratePairingCode);

export default router;

import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { setKeywords, getKeywords, scanText } from './keywords.controller.js';

const router = Router();

// The parent owns the keyword list (set/get). Either role may scan text
// against it — a match raises an alert in the existing alerts collection.
// Simple substring matching only; there is no ML model here.
router.post('/:childId', requireAuth, requireRole('parent'), setKeywords);
router.get('/:childId', requireAuth, requireRole('parent'), getKeywords);
router.post('/:childId/scan', requireAuth, scanText);

export default router;

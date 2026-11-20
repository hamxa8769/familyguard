import { Router } from 'express';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { requireChildAccess } from '../../middleware/access.js';
import { setKeywords, getKeywords, scanText } from './keywords.controller.js';

const router = Router();

// The parent owns the keyword list (set/get). Either role may scan text
// against it — a match raises an alert in the existing alerts collection.
// Simple substring matching only; there is no ML model here.
// All three routes are child-scoped (requireChildAccess): a parent may
// only touch their own child's list.
router.post('/:childId', requireAuth, requireRole('parent'), requireChildAccess(), setKeywords);
router.get('/:childId', requireAuth, requireRole('parent'), requireChildAccess(), getKeywords);
router.post('/:childId/scan', requireAuth, requireChildAccess(), scanText);

export default router;

import { Router } from 'express';
import { pairDevice } from './pairing.controller.js';

const router = Router();

// Public: the code itself is the credential (single-use, generated per child).
router.post('/', pairDevice);

export default router;

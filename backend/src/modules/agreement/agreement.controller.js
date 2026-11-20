import { store, nextId } from '../../config/store.js';
import { canAccessChild } from '../../middleware/access.js';

// Family agreement: the parent proposes a set of joint rules and the child
// signs them (accepts or declines). Only the latest agreement per child is
// active; signing is a one-way transition out of 'proposed'.
export async function createAgreement(req, res, next) {
  try {
    const { childId, rules, effectiveFrom } = req.body;
    if (!childId) {
      return res.status(400).json({ error: 'childId is required' });
    }
    if (
      !Array.isArray(rules) ||
      rules.length === 0 ||
      rules.some((r) => typeof r !== 'string' || !r.trim())
    ) {
      return res.status(400).json({ error: 'rules must be a non-empty array of strings' });
    }
    const agreement = {
      id: nextId(),
      childId,
      createdBy: req.user.id,
      rules,
      status: 'proposed',
      effectiveFrom: effectiveFrom ?? null,
      createdAt: new Date().toISOString(),
      signedAt: null,
      signedNote: null,
    };
    store.agreements.push(agreement);
    res.status(201).json(agreement);
  } catch (err) {
    next(err);
  }
}

export async function getLatestAgreement(req, res, next) {
  try {
    const { childId } = req.params;
    const agreements = store.agreements.filter((a) => a.childId === childId);
    if (agreements.length === 0) {
      return res.status(404).json({ error: 'No agreement found for this child' });
    }
    res.json(agreements[agreements.length - 1]);
  } catch (err) {
    next(err);
  }
}

export async function signAgreement(req, res, next) {
  try {
    const { accepted, note } = req.body;
    if (typeof accepted !== 'boolean') {
      return res.status(400).json({ error: 'accepted must be true or false' });
    }
    const agreement = store.agreements.find((a) => a.id === req.params.id);
    if (!agreement) return res.status(404).json({ error: 'Agreement not found' });
    // The route is addressed by agreement id, so the child check lives
    // here: only the child the agreement belongs to may sign it.
    if (!canAccessChild(req.user, agreement.childId)) {
      return res.status(403).json({ error: 'No access to this child' });
    }
    if (agreement.status !== 'proposed') {
      return res.status(409).json({ error: `Agreement is already ${agreement.status}` });
    }
    agreement.status = accepted ? 'accepted' : 'declined';
    agreement.signedAt = new Date().toISOString();
    agreement.signedNote = note ?? null;
    res.json(agreement);
  } catch (err) {
    next(err);
  }
}

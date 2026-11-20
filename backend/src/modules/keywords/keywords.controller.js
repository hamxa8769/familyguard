import { store, nextId } from '../../config/store.js';

// Keyword alerts — a SIMPLE keyword list, no ML model. The parent keeps a
// per-child list of concerning words/phrases; scanning a piece of text is
// a case-insensitive substring match against that list. On a match an
// alert is created in the existing alerts collection (store.sosAlerts —
// the same shape the SOS module uses: { id, deviceId, message, at,
// resolved }, plus childId/source/matchedKeywords context). There is no
// backend/src/modules/alerts module; sosAlerts is the alerts collection
// this codebase has. A scan with no match creates nothing.
export async function setKeywords(req, res, next) {
  try {
    const { childId } = req.params;
    const { keywords } = req.body;
    if (
      !Array.isArray(keywords) ||
      keywords.some((k) => typeof k !== 'string' || !k.trim())
    ) {
      return res.status(400).json({ error: 'keywords must be an array of strings' });
    }
    const cleaned = [...new Set(keywords.map((k) => k.trim()))];
    const existing = store.keywordLists.find((l) => l.childId === childId);
    if (existing) {
      existing.keywords = cleaned;
      existing.updatedAt = new Date().toISOString();
      existing.updatedBy = req.user.id;
      return res.json(existing);
    }
    const list = {
      childId,
      keywords: cleaned,
      updatedAt: new Date().toISOString(),
      updatedBy: req.user.id,
    };
    store.keywordLists.push(list);
    res.json(list);
  } catch (err) {
    next(err);
  }
}

export async function getKeywords(req, res, next) {
  try {
    const { childId } = req.params;
    const list = store.keywordLists.find((l) => l.childId === childId);
    res.json({ childId, keywords: list?.keywords ?? [] });
  } catch (err) {
    next(err);
  }
}

export async function scanText(req, res, next) {
  try {
    const { childId } = req.params;
    const { text, source } = req.body;
    if (typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'text is required' });
    }
    const list = store.keywordLists.find((l) => l.childId === childId);
    const haystack = text.toLowerCase();
    const matched = (list?.keywords ?? []).filter((k) => haystack.includes(k.toLowerCase()));
    if (matched.length === 0) {
      return res.json({ matched: [], alertCreated: false });
    }
    // Same shape as the SOS alerts collection, plus keyword context.
    // deviceId is null: a text scan has no single device attached. The
    // owning parent is recorded from the keyword list so the alert is
    // visible in that parent's SOS list (which is filtered per parent).
    const alert = {
      id: nextId(),
      deviceId: null,
      childId,
      parentId: list?.updatedBy ?? null,
      message: `Keyword match: ${matched.join(', ')}`,
      source: source ?? null,
      matchedKeywords: matched,
      at: new Date().toISOString(),
      resolved: false,
    };
    store.sosAlerts.push(alert);
    res.json({ matched, alertCreated: true, alert });
  } catch (err) {
    next(err);
  }
}

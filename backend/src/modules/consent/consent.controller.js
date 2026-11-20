import { store, nextId } from '../../config/store.js';

// Records that the person using the child device acknowledged the consent notice.
export async function recordConsent(req, res, next) {
  try {
    const { deviceId, acceptedText, consentVersion } = req.body;
    if (!deviceId || !acceptedText) {
      return res.status(400).json({ error: 'deviceId and acceptedText are required' });
    }
    const consent = {
      id: nextId(),
      deviceId,
      acceptedText,
      // v2 covers the new features (remote commands, on-request screenshot,
      // SOS-only short audio). Old v1 consent must be re-confirmed in-app.
      consentVersion: consentVersion || '1',
      acceptedBy: req.user.id,
      acceptedAt: new Date().toISOString(),
    };
    store.consents.push(consent);
    res.status(201).json(consent);
  } catch (err) {
    next(err);
  }
}

export async function getConsent(req, res, next) {
  try {
    const consent = store.consents
      .filter((c) => c.deviceId === req.params.deviceId)
      .at(-1);
    res.json({ deviceId: req.params.deviceId, consent: consent || null });
  } catch (err) {
    next(err);
  }
}

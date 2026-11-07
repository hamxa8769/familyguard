import { store } from '../../config/store.js';

export async function setFilter(req, res, next) {
  try {
    const { blockedDomains } = req.body;
    if (!Array.isArray(blockedDomains)) {
      return res.status(400).json({ error: 'blockedDomains must be an array' });
    }
    const existing = store.webFilters.find((f) => f.deviceId === req.params.deviceId);
    if (existing) {
      existing.blockedDomains = blockedDomains;
    } else {
      store.webFilters.push({ deviceId: req.params.deviceId, blockedDomains });
    }
    res.json({ deviceId: req.params.deviceId, blockedDomains });
  } catch (err) {
    next(err);
  }
}

export async function getFilter(req, res, next) {
  try {
    const entry = store.webFilters.find((f) => f.deviceId === req.params.deviceId);
    res.json({ deviceId: req.params.deviceId, blockedDomains: entry?.blockedDomains ?? [] });
  } catch (err) {
    next(err);
  }
}

// Device asks whether a domain is allowed before navigating.
export async function checkDomain(req, res, next) {
  try {
    const domain = String(req.query.domain || '').toLowerCase();
    const entry = store.webFilters.find((f) => f.deviceId === req.params.deviceId);
    const list = entry?.blockedDomains ?? [];
    const blocked = list.some((d) => domain === d || domain.endsWith(`.${d}`));
    res.json({ domain, blocked });
  } catch (err) {
    next(err);
  }
}

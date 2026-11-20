import jwt from 'jsonwebtoken';
import { jwtSecret } from '../config/secrets.js';
import { store } from '../config/store.js';

// Verifies the Bearer JWT and attaches { id, role, ... } to req.user.
//
// Phase 5: tokens issued since v0.9.1 carry a `jti` (see
// modules/auth/auth.service.js). A jti on the revoked list
// (store.revokedTokenIds, added by POST /api/auth/logout) is rejected.
// Tokens issued before jtis existed have no jti and are grandfathered —
// they stay valid until they expire (documented in docs/API.md).
export function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token', code: 'unauthorized' });
  }

  try {
    const payload = jwt.verify(token, jwtSecret());
    if (payload.jti && (store.revokedTokenIds ?? []).includes(payload.jti)) {
      return res.status(401).json({ error: 'Token revoked', code: 'token_revoked' });
    }
    req.user = payload;
    req.tokenJti = payload.jti ?? null;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token', code: 'unauthorized' });
  }
}

// Optional role guard, e.g. requireRole('parent') or
// requireRole('child', 'device') when either caller may use the route.
export function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: `Requires ${roles.join(' or ')} role`, code: 'forbidden' });
    }
    next();
  };
}

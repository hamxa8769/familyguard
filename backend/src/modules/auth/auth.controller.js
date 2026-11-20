import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import * as authService from './auth.service.js';
import { store } from '../../config/store.js';
import { jwtSecret } from '../../config/secrets.js';

export async function register(req, res, next) {
  try {
    const { email, password, displayName, role } = req.body;
    if (!email || !password || !role) {
      return res.status(400).json({ error: 'email, password and role are required' });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email))) {
      return res.status(400).json({ error: 'Enter a valid email address' });
    }
    if (String(password).length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }
    const result = await authService.register({ email, password, displayName, role });
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function login(req, res, next) {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required' });
    }
    const result = await authService.login({ email, password });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

// GET /api/me — the caller behind the Bearer token. User tokens return
// the public user profile; device tokens return the device identity
// (there is no user row for a paired device).
export async function me(req, res, next) {
  try {
    if (req.user.role === 'device') {
      const device = store.devices.find((d) => d.id === req.user.deviceId);
      if (!device) return res.status(404).json({ error: 'Device not found' });
      return res.json({
        id: device.id,
        role: 'device',
        deviceId: device.id,
        childId: device.childId ?? null,
        parentId: device.parentId ?? null,
        platform: device.platform,
        deviceName: device.deviceName,
      });
    }
    const user = store.users.find((u) => u.id === req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(authService.publicUser(user));
  } catch (err) {
    next(err);
  }
}

export async function changePassword(req, res, next) {
  try {
    const { oldPassword, newPassword } = req.body ?? {};
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: 'oldPassword and newPassword are required' });
    }
    if (String(newPassword).length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters' });
    }
    if (req.user.role === 'device') {
      return res.status(403).json({ error: 'Device tokens cannot change a password' });
    }
    const user = await authService.changePassword({
      userId: req.user.id,
      oldPassword,
      newPassword,
    });
    res.json({ ok: true, user });
  } catch (err) {
    next(err);
  }
}

// POST /api/auth/refresh — a still-valid token buys a fresh 7-day one
// (device tokens: a fresh 365-day one for the same device).
export async function refresh(req, res, next) {
  try {
    if (req.user.role === 'device') {
      const token = jwt.sign(
        {
          id: req.user.deviceId,
          role: 'device',
          deviceId: req.user.deviceId,
          childId: req.user.childId,
          parentId: req.user.parentId,
          jti: crypto.randomUUID(),
        },
        jwtSecret(),
        { expiresIn: '365d' },
      );
      return res.json({ token });
    }
    const user = store.users.find((u) => u.id === req.user.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(authService.refreshToken(user));
  } catch (err) {
    next(err);
  }
}

// POST /api/auth/logout — revokes exactly this token (by jti). Tokens
// issued before jtis existed have no jti, so logout cannot revoke them:
// `revoked` is false for those and they stay valid until they expire.
export async function logout(req, res, next) {
  try {
    const jti = req.tokenJti ?? req.user?.jti ?? null;
    if (!jti) return res.json({ ok: true, revoked: false });
    store.revokedTokenIds = store.revokedTokenIds ?? [];
    if (!store.revokedTokenIds.includes(jti)) {
      store.revokedTokenIds.push(jti);
      // Bound the list: a revoked jti only matters until the token would
      // have expired anyway (7 days for users, 365 for devices).
      if (store.revokedTokenIds.length > 1000) {
        store.revokedTokenIds = store.revokedTokenIds.slice(-1000);
      }
    }
    res.json({ ok: true, revoked: true });
  } catch (err) {
    next(err);
  }
}

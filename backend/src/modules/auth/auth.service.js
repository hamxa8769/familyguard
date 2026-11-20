import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import { store, nextId } from '../../config/store.js';
import { jwtSecret } from '../../config/secrets.js';

// NOTE: uses the in-memory store for now. Replace with db.js query() for Postgres.

const ROLES = ['parent', 'child'];

export async function register({ email, password, displayName, role }) {
  if (!ROLES.includes(role)) {
    const err = new Error('role must be "parent" or "child"');
    err.status = 400;
    throw err;
  }
  if (store.users.some((u) => u.email === email)) {
    const err = new Error('Email already registered');
    err.status = 409;
    throw err;
  }
  const passwordHash = await bcrypt.hash(password, 10);
  const user = {
    id: nextId(),
    email,
    displayName: displayName || email.split('@')[0],
    role,
    passwordHash,
  };
  store.users.push(user);
  return { token: issueToken(user), user: publicUser(user) };
}

export async function login({ email, password }) {
  const user = store.users.find((u) => u.email === email);
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    const err = new Error('Invalid credentials');
    err.status = 401;
    throw err;
  }
  return { token: issueToken(user), user: publicUser(user) };
}

// Verifies the old password, then replaces the hash. Wrong old password
// is 401 (not 400): the credentials are wrong, the request is well-formed.
export async function changePassword({ userId, oldPassword, newPassword }) {
  const user = store.users.find((u) => u.id === userId);
  if (!user) {
    const err = new Error('User not found');
    err.status = 404;
    throw err;
  }
  if (!(await bcrypt.compare(oldPassword, user.passwordHash))) {
    const err = new Error('Old password is incorrect');
    err.status = 401;
    throw err;
  }
  user.passwordHash = await bcrypt.hash(newPassword, 10);
  return publicUser(user);
}

// Issues a fresh token for the same user (same 7-day lifetime).
export function refreshToken(user) {
  return { token: issueToken(user), user: publicUser(user) };
}

export function issueToken(user) {
  // jti (Phase 5): a unique id per token so POST /api/auth/logout can
  // revoke exactly this token. Tokens issued before this change have no
  // jti and are grandfathered by the auth middleware.
  return jwt.sign(
    { id: user.id, role: user.role, jti: crypto.randomUUID() },
    jwtSecret(),
    { expiresIn: '7d' }
  );
}

export function publicUser(user) {
  return { id: user.id, email: user.email, displayName: user.displayName, role: user.role };
}

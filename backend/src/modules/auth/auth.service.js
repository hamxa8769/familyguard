import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
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

function issueToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role },
    jwtSecret(),
    { expiresIn: '7d' }
  );
}

function publicUser(user) {
  return { id: user.id, email: user.email, displayName: user.displayName, role: user.role };
}

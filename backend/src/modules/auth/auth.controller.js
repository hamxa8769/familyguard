import * as authService from './auth.service.js';

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
    const { email, password } = req.body;
    const result = await authService.login({ email, password });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

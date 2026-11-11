// Tiny in-memory rate limiter for brute-force sensitive endpoints
// (login, pairing codes). Per client IP, sliding window.
export function rateLimit({ windowMs = 10 * 60 * 1000, max = 20 } = {}) {
  const hits = new Map(); // ip -> [timestamps]
  return (req, res, next) => {
    const now = Date.now();
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';
    const recent = (hits.get(ip) || []).filter((t) => now - t < windowMs);
    if (recent.length >= max) {
      const retry = Math.ceil((windowMs - (now - recent[0])) / 1000);
      res.set('Retry-After', String(retry));
      return res.status(429).json({ error: `Too many attempts. Try again in ${Math.ceil(retry / 60)} min.` });
    }
    recent.push(now);
    hits.set(ip, recent);
    // Keep the map from growing forever.
    if (hits.size > 10000) hits.clear();
    next();
  };
}

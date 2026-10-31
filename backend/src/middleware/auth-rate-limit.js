// Small, process-local development limiter. A shared store is needed for
// multi-instance deployment; passwords/tokens are never part of its keys.
export function authRateLimit({ limit = 20, windowMs = 15 * 60 * 1000 } = {}) {
  const clients = new Map();
  return (request, response, next) => {
    const now = Date.now();
    for (const [key, value] of clients) if (value.resetAt <= now) clients.delete(key);
    const key = request.ip;
    let entry = clients.get(key);
    if (!entry && clients.size < 10000) {
      entry = { count: 0, resetAt: now + windowMs };
      clients.set(key, entry);
    }
    if (!entry || ++entry.count > limit) {
      response.set('Retry-After', String(Math.ceil(((entry?.resetAt ?? now + windowMs) - now) / 1000)));
      return response.status(429).json({ error: { code: 'TOO_MANY_REQUESTS', message: 'Too many attempts. Please try again later.' } });
    }
    next();
  };
}

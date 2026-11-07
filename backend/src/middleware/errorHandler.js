// Centralised error handler. Controllers can `next(err)` or throw in async
// wrappers; this returns a consistent JSON shape.
export function errorHandler(err, _req, res, _next) {
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
  });
}

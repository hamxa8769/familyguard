// Centralised error handler. Controllers can `next(err)` or throw in async
// wrappers; this returns a consistent JSON shape.
//
// Error envelope (Phase 5): { error, code }. `error` is the human-readable
// message clients already read; `code` is the machine-readable type added
// in v0.9.1. Success responses are NOT enveloped yet — standardising them
// (and 201-on-create everywhere) is documented remaining work in
// docs/API.md; no success shape was changed in this round.
const CODE_BY_STATUS = {
  400: 'bad_request',
  401: 'unauthorized',
  403: 'forbidden',
  404: 'not_found',
  409: 'conflict',
  429: 'rate_limited',
};

export function errorCodeFor(status) {
  return CODE_BY_STATUS[status] || 'internal_error';
}

export function errorHandler(err, _req, res, _next) {
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
    code: err.code || errorCodeFor(status),
  });
}

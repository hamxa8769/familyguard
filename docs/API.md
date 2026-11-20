# FamilyGuard API (v0.9.1)

Base URL: `http://<server>:4000`. Every route is mounted under **both**
`/api` and `/api/v1` (dual mount, same handlers) — new clients should use
`/api/v1`, existing clients on `/api` keep working unchanged.

Auth: `Authorization: Bearer <token>` on every route except
`POST /api/auth/register`, `POST /api/auth/login`, `POST /api/pair`,
`GET /health`, `GET /health/ready`. User tokens last 7 days, device
tokens (from pairing) 365 days.

## Conventions (Phase 5)

- **Pagination:** list endpoints accept `?limit=` (clamped 1–500) and
  `?offset=` (≥ 0). When no limit is passed the default is **500** — at
  family scale that returns the whole list, so clients that display
  everything keep working unchanged. Paginated responses add `total`
  (full filtered count), `limit` and `offset` next to the existing list
  key. Endpoints: `GET /api/sos`, `/api/usage/:deviceId` (per-app rows),
  `/api/apps/:deviceId`, `/api/browsing/:deviceId`, `/api/rewards/:childId`
  (`totalPoints`/`badges` are always computed over all events),
  `/api/children`, `/api/devices`, `/api/requests`, `/api/feed`,
  `/api/media?deviceId=`, `/api/comms/:deviceId` (default limit 200,
  SMS page only — pre-existing Phase 2 behaviour),
  `/api/files/:deviceId` (default limit 200 — pre-existing Phase 2
  behaviour).
- **Errors:** the central error handler, the JSON 404 handler and the
  rate limiter return `{ error, code }` — `error` is the human-readable
  message clients already read, `code` is machine-readable
  (`bad_request`, `unauthorized`, `forbidden`, `not_found`, `conflict`,
  `rate_limited`, `token_revoked`, `internal_error`). Direct validation
  replies inside controllers still return bare `{ error }` (see
  Remaining work).
- **Rate limits:** global 1000 req / 15 min per IP, plus 20 / 10 min on
  login/register/pairing. The child's 60 s rule-version check and 15-min
  sync are far below the global limit.
- **CORS:** requests with no `Origin` (native mobile apps, curl) are
  always allowed. Browser origins must be listed in `ALLOWED_ORIGINS`
  (comma-separated) when it is set; when unset, any origin is allowed
  and the server logs a startup warning.
- **Security headers:** `helmet` is on; `trust proxy` is set (1).
  Request logging is `morgan` (`tiny` format).
- **Tokens:** user and device tokens issued since v0.9.1 carry a `jti`.
  `POST /api/auth/logout` revokes exactly that token. Tokens issued
  before this change have no `jti` and are grandfathered — logout cannot
  revoke them and they stay valid until they expire.

## Endpoints

| Method + path | Auth | Notes |
|---|---|---|
| `GET /health` | public | `{ status: 'ok', service }` |
| `GET /health/ready` | public | `{ status, db }`; `db` is `postgres` (runs `SELECT 1`), `file` (data file readable) or `memory`. 503 + `status: 'degraded'` when the DB/file check fails |
| `POST /api/auth/register` | public + RL | `{ email, password, displayName, role }` → 201 `{ token, user }` |
| `POST /api/auth/login` | public + RL | → `{ token, user }` |
| `GET /api/me` | auth | Current user (or device identity for device tokens) |
| `POST /api/auth/change-password` | auth | `{ oldPassword, newPassword }` (min 8 chars). Missing fields → 400, wrong old password → 401 |
| `POST /api/auth/refresh` | auth | Valid token → fresh token (7 d user, 365 d device) |
| `POST /api/auth/logout` | auth | Revokes this token. `{ ok, revoked }`; `revoked: false` for pre-jti tokens |
| `POST /api/pair` | public + RL | One-time pairing code → `{ token, device, child }` |
| `GET /api/children` · `POST /api/children` | parent | Paginated list; create returns 201 |
| `GET /api/devices` · `POST /api/devices` | auth | Paginated list |
| `GET /api/devices/:id/rules-version` | auth | Cheap poll target for the child (60 s) |
| `GET /api/transparency/:deviceId` | auth + device | What the parent sees, incl. `report.auditLog` (newest 100) |
| `GET /api/transparency/:deviceId/audit?limit=` | auth + device | Audit log, newest first; `limit` clamps 1–500, default 100 |
| `GET /api/reports/:deviceId` | auth + device | Parent-facing report, incl. `auditLog` |
| `GET /api/sos` · `POST /api/sos` | auth | Paginated list; create returns 201 |
| `GET /api/usage/:deviceId` | auth + device | Per-app aggregates, paginated |
| `GET /api/usage/:deviceId/daily?days=` | auth + device | `days` 1–31, default 7 |
| `GET /api/apps/:deviceId` · `POST /api/apps/:deviceId/sync` | auth + device | Paginated list |
| `GET /api/browsing/:deviceId` · `POST /api/browsing/:deviceId/sync` | auth + device | Paginated list |
| `GET /api/rewards/:childId` | auth + child | Paginated events; totals over all events |
| `GET /api/requests` · `POST /api/requests` | auth | Paginated; `?status=` filter |
| `GET /api/feed?since=` | parent | Paginated; `since` is an ISO date |
| `GET /api/comms/:deviceId` | auth + device | `?q=`, `?type=`, `?address=`, `?limit=`, `?offset=` |
| `GET /api/files/:deviceId` | auth + device | `?limit=`, `?offset=` |
| `GET /api/media?deviceId=` | auth + device | Paginated captures |
| `GET /api/media/:id/file` | auth + capture | Download bytes (`Content-Disposition: attachment`) |
| `POST /api/media/purge-expired` | parent | Expires captures **and deletes their disk files** |

All other pre-existing endpoints are unchanged (see `AUDIT_0.9.1.md`
Appendix A for the full inventory; `GET /api/feed`, rules, geofencing,
consent, keywords, agreement, remote commands, location, web filter,
bedtime, screen time, app blocking).

## Retention (prune rules, `config/persistence.js`)

`prune()` runs on every flush: usage events 35 d; locations 500/device;
geofence events 300/device; thumbnails/originals 500/device (disk files
deleted too); resolved SOS 90 d; time requests 30 d; bonus time 3 d;
browsing sessions newest 500/device; SMS/call-log items newest 1000 per
device; contacts 2000 per device; installed apps not seen in 90 d are
dropped; agreements newest 50 per child; reward events newest 1000 per
child (totals are derived from kept events); keyword lists deduped to the
newest row per child. The audit log is not pruned.

## Remaining work (deliberately not done in this round)

- **Postgres split-brain (audit §6/§9, item 18b).** Only remote
  commands, media and the audit log use normalised Postgres tables
  (`src/db/repository.js`); the other ~24 modules read/write the
  in-process `store` directly, and in Postgres mode the JSONB `fg_state`
  snapshot is a second copy of the same data — so in Postgres mode
  `store.remoteCommands` / `store.mediaCaptures` stay empty while the
  tables hold the truth. A full migration needs: move every module to
  the repository (same `isPostgres()` dual path), replace the
  in-process `nextId()` counter with DB sequences / UUIDs (two server
  instances currently issue colliding sequential IDs), and either drop
  the `fg_state` JSONB snapshot or keep it only for modules not yet
  migrated. The JSON-file mode (the default) is unaffected and is the
  mode that is tested.
- **Full success-envelope standardisation.** Success responses still
  use their historical shapes (bare objects vs `{ devices }` /
  `{ children }` / `{ alerts }` wrappers; some creates return 200
  instead of 201). Changing them would break the Flutter clients,
  which parse the current shapes — standardise only together with a
  client update. Likewise the `{ error, code }` envelope currently
  covers the central error handler, the JSON 404 handler, the rate
  limiter and the auth middleware; the controllers' direct validation
  replies still return bare `{ error }`.
- **Comms/files pagination defaults (200) differ from the new 500
  default** — pre-existing Phase 2 behaviour, left alone so the
  Phase 2 clients keep paging exactly as they do today.
- **Media files live on local disk** (`backend/src/uploads/`); a
  production deployment should swap this for object storage (S3/GCS)
  with signed URLs. Files are lost on redeploy/VM rebuild.
- **No pagination yet on** `GET /api/remotecommands`,
  `GET /api/location/:deviceId` and `GET /api/geofencing/:deviceId/events`
  (the last two are hard-capped at 50) — same treatment as the Phase 5
  lists when a client needs it.
- **No password reset flow** (email-based) — change-password covers the
  signed-in case only. No `DELETE /api/devices/:id`, no user/parent
  settings endpoint.

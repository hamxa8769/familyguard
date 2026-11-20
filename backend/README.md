# FamilyGuard Backend

Modular Node.js + Express API.

## Run

```bash
cd backend
npm install
cp .env.example .env   # then edit values
npm run dev
```

Server starts on `http://localhost:4000`. Health check: `GET /health`.

```bash
npm test     # API + persistence tests (starts its own in-memory server)
npm run public  # server + public HTTPS address (Cloudflare quick tunnel) for testing from any network
```

## Data storage

`config/persistence.js` keeps the store across restarts:

| Setting | Where data goes |
|---------|-----------------|
| *(default)* | `./data/familyguard.json` (or `DATA_FILE`) |
| `DATABASE_URL=postgresql://…` | PostgreSQL table `fg_state` (one JSONB row per collection, created automatically) |
| `PERSIST=memory` | nowhere — lost on restart (tests/demos) |

Writes are debounced (~1 s), only changed collections are written, and the
server flushes on Ctrl+C / SIGTERM. Old data is trimmed automatically (usage
35 days, last 500 locations per device, resolved SOS 90 days, …).
Good for one server instance; a normalised schema is the next step for scale.

The JWT signing secret comes from `JWT_SECRET`, or is generated on first start
and saved with the data. Login and pairing are rate-limited per IP
(`AUTH_RATE_LIMIT`, default 20 per 10 minutes).

## Add a new feature module

1. Create `src/modules/<feature>/` with `<feature>.routes.js`,
   `<feature>.controller.js`, and (optionally) `<feature>.service.js`.
2. Register it once in `src/routes.js`.

That's it — nothing else changes.

## Access rules

- A **parent** signs in with email/password and adds children (`POST /api/children`);
  each child gets a single-use 6-character `pairingCode`.
- The **child app** sends that code to `POST /api/pair` and gets a token scoped to
  that one device (role `device`).
- Every device route checks `middleware/access.js`: only the owning parent or the
  device itself may read its data, and only the parent may change its rules.

## Modules included

| Module    | Purpose                                            |
|-----------|----------------------------------------------------|
| `auth`    | Register / login, JWT issue.                       |
| `consent` | Record and check on-device consent (transparency). |
| `pairing` | Child device redeems a one-time code → device token. |
| `devices` | Register/list child/parent devices (+ push tokens); list shows only devices the caller may see. |
| `usage`   | Receive and query app-usage events.                |
| `requests` | Child asks for more time; parent approves/declines. |
| `feed`    | Parent activity feed (alerts, requests, events).   |
| `remotecommands` | Parent → child commands (lock, message, screenshot/audio requests). Child polls; commands expire. |
| `media`   | Screenshot / SOS-audio captures, 7-day expiry, audit-logged. File upload (`POST /:id/upload`, base64, 8 MB cap) + download (`GET /:id/file`). |
| `apps`    | Installed-apps inventory sync + list. |
| `browsing` | Browser-app sessions (which browser, when, how long — no URLs). |
| `agreement` | Family agreement: propose rules, child sign-off. |
| `rewards` | Points/badges + idempotent screen-time bonus. |
| `keywords` | Keyword list + substring scan → alert. Simple list only, no ML model. |
| `transparency` | What the parent sees, shown to the child.      |

## Persistence

The API runs on an in-memory store by default. To use Postgres:

```bash
npm run db:migrate   # applies backend/src/db/migrations/*.sql (needs DATABASE_URL)
```

New modules go through `src/db/repository.js`, which uses Postgres when
`DATABASE_URL` is set and falls back to the in-memory store otherwise.
Older modules still use the store directly; they migrate one at a time.

## Push notifications

Set `FCM_SERVER_KEY` in `.env` to enable FCM push (see
`src/services/pushService.js`). Without it, push is skipped and the child
app polls for remote commands instead — push is best-effort only.

## Tests

```bash
npm test   # node --test, no extra dependencies
```

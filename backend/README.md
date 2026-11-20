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

## Add a new feature module

1. Create `src/modules/<feature>/` with `<feature>.routes.js`,
   `<feature>.controller.js`, and (optionally) `<feature>.service.js`.
2. Register it once in `src/routes.js`.

That's it — nothing else changes.

## Modules included

| Module    | Purpose                                            |
|-----------|----------------------------------------------------|
| `auth`    | Register / login, JWT issue.                       |
| `consent` | Record and check on-device consent (transparency). |
| `devices` | Register child/parent devices (+ push tokens).     |
| `usage`   | Receive and query app-usage events.                |
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

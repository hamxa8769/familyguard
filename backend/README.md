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
| `devices` | Register child/parent devices.                     |
| `usage`   | Receive and query app-usage events.                |

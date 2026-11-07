# FamilyGuard — Cross-Platform Parental Control

A **transparent, consent-based** parental-control application (final-year project).
One **Flutter** codebase targets **Windows, Android, and iOS**, backed by a modular
**Node.js** API. Built feature-first so new features plug in without touching
existing code.

> **Transparency by design.** This is parental control software, *not* covert
> monitoring. The app is always visible on the child device, requires an on-device
> consent step, is intended only for a parent monitoring their own minor child on a
> device they own or share, and stores the minimum data needed. No stealth mode.
> See [docs/ETHICS.md](docs/ETHICS.md).

## Features (Phase 1 — implemented)

| # | Feature | What it does |
|---|---------|--------------|
| 1 | **App usage tracking** | Which apps are used and for how long |
| 2 | **Screen time limit** | Daily usage cap with remaining-time tracking |
| 3 | **App blocking** | Block selected apps on the child device |
| 4 | **Location tracking** | Current location + recent history |
| 5 | **Geofencing (safe zones)** | Enter/exit alerts for zones like home/school |
| 6 | **SOS / panic button** | Child sends an emergency alert to the parent |
| 7 | **Web content filtering** | Block unsafe domains |
| 8 | **Bedtime / schedule lock** | Lock the device during a nightly window |
| 9 | **Parent dashboard + reports** | Per-child daily summary |
| 10 | **Multi-child support** | One parent, many child profiles |
| 11 | **Two-way transparency** *(unique)* | Child sees exactly what the parent sees |

See the full plan and **Coming Soon** list in [docs/ROADMAP.md](docs/ROADMAP.md).

> **Scope note.** The cross-platform logic (API + Flutter UI + rules engine) runs
> end-to-end on sample/stub data. The native OS collectors that read real
> usage/location and enforce real locks are wired as `MethodChannel` stubs with
> TODOs, since they need per-platform Kotlin/Swift/Win32 code (see
> [docs/ADDING_A_FEATURE.md](docs/ADDING_A_FEATURE.md)).

## Repository layout

```
.
├── backend/     Node.js + Express API — one folder per feature module
├── client/      Flutter app (Windows / Android / iOS), feature-first
└── docs/        ARCHITECTURE, ROADMAP, ETHICS, ADDING_A_FEATURE
```

## Tech stack

| Layer    | Choice            | Why                                                      |
|----------|-------------------|----------------------------------------------------------|
| Client   | Flutter (Dart)    | One codebase → Windows, Android, iOS.                    |
| Backend  | Node.js + Express | Modular REST API — a new feature is a new module folder. |
| Database | In-memory → PostgreSQL | Runs instantly now; swap to Postgres for persistence. |

## Quick start

**Backend**
```bash
cd backend
npm install
cp .env.example .env
npm run dev          # http://localhost:4000  (GET /health)
```

**Client**
```bash
cd client
flutter pub get
flutter run -d windows   # or -d android / -d ios / chrome
```

## API overview

| Module | Base route | Key endpoints |
|--------|-----------|---------------|
| Auth | `/api/auth` | `POST /register`, `POST /login` |
| Consent | `/api/consent` | `POST /`, `GET /:deviceId` |
| Children | `/api/children` | `POST /`, `GET /` |
| Devices | `/api/devices` | `POST /`, `GET /` |
| Usage | `/api/usage` | `POST /`, `GET /:deviceId` |
| Screen time | `/api/screentime` | `PUT /:deviceId`, `GET /:deviceId` |
| App blocking | `/api/appblocking` | `PUT /:deviceId`, `GET /:deviceId` |
| Location | `/api/location` | `POST /`, `GET /:deviceId` |
| Geofencing | `/api/geofencing` | `POST /`, `GET /:deviceId`, `GET /:deviceId/events` |
| SOS | `/api/sos` | `POST /`, `GET /`, `POST /:id/resolve` |
| Web filter | `/api/webfilter` | `PUT /:deviceId`, `GET /:deviceId`, `GET /:deviceId/check` |
| Bedtime | `/api/bedtime` | `PUT /:deviceId`, `GET /:deviceId` |
| Reports | `/api/reports` | `GET /:deviceId` |
| Transparency | `/api/transparency` | `GET /:deviceId` |

## Adding a feature

See [docs/ADDING_A_FEATURE.md](docs/ADDING_A_FEATURE.md) — add one backend module
folder + one Flutter module file, register each in one line, done.

## License

For educational use as a final-year project.

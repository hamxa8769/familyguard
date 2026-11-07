# Architecture

## 1. High-level

```
┌─────────────────┐      HTTPS/JSON      ┌──────────────┐      ┌──────────────────┐
│  CHILD CLIENT   │ ───────────────────▶ │   BACKEND    │ ◀─── │  PARENT CLIENT   │
│  (Flutter)      │                      │  (Node API)  │      │   (Flutter)      │
│  - collectors   │                      │  - auth      │      │  - dashboard     │
│  - consent UI   │                      │  - modules   │      │  - limits/alerts │
│  - visible      │                      │  - storage   │      │                  │
└─────────────────┘                      └──────────────┘      └──────────────────┘
```

The **same Flutter app** runs in two roles — `child` or `parent` — chosen at
onboarding and stored in the account profile. This keeps one codebase.

## 2. Backend module pattern

Every feature is a self-contained folder under `backend/src/modules/<feature>`:

```
modules/usage/
├── usage.routes.js       route definitions (URL → controller)
├── usage.controller.js   request/response handling
└── usage.service.js      business logic + DB access
```

Adding a feature = add a folder + register it once in `src/routes.js`. No existing
module is touched. This is the extensibility the project is built around.

## 3. Client feature-first structure

```
client/lib/
├── core/        cross-cutting: config, network, auth, consent
├── features/    one folder per feature; each exposes a FeatureModule
└── shared/      reusable widgets/utils
```

New feature = new folder in `features/` + register it in `feature_registry.dart`.

## 4. Consent & transparency flow

1. On first launch in `child` role, the app shows a full-screen **consent notice**
   explaining exactly what is collected and that a parent will see it.
2. Monitoring does **not** start until consent is recorded (locally + server).
3. A persistent, visible indicator shows the app is active. No hidden/stealth mode.

## 5. Data model (initial)

| Entity        | Key fields                                              |
|---------------|---------------------------------------------------------|
| `families`    | id, name, created_at                                    |
| `users`       | id, family_id, role (parent/child), email, display_name |
| `devices`     | id, user_id, platform, device_name, consent_at          |
| `usage_events`| id, device_id, app_name, started_at, duration_seconds   |
| `rules`       | id, family_id, type, target, config (JSON)              |

## 6. Security baseline

- JWT-based auth; child devices get scoped tokens.
- All transport over HTTPS.
- Store the minimum; no message/photo content in the MVP.
- Consent timestamp retained as an audit record.

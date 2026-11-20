# Architecture

## 1. High-level

```
┌──────────────────┐     HTTPS/JSON      ┌──────────────┐     ┌──────────────────┐
│  CHILD APP       │ ──────────────────▶ │   BACKEND    │ ◀── │  PARENT APP      │
│  familyguard_    │                     │  (Node API)  │     │  familyguard_    │
│  child           │                     │  - auth      │     │  parent          │
│  - consent gate  │                     │  - modules   │     │  - dashboard     │
│  - collectors    │                     │  - storage   │     │  - controls      │
│  - transparency  │                     └──────────────┘     │  - alerts        │
└──────────────────┘                                          └──────────────────┘
         \                                                            /
          \________________ packages/core (shared) __________________/
             models · ApiClient · AuthService · ConsentService
```

Instead of one app with a role switch, there are **two apps** (like Google Family
Link, Qustodio, etc.). They share **`packages/core`** so the API contract, auth and
models exist in exactly one place.

## 2. Monorepo layout

```
client/
├── packages/core/          familyguard_core (a Flutter package, not an app)
│   └── lib/src/{config,network,auth,consent,models}
└── apps/
    ├── child/              familyguard_child
    │   ├── android/.../MainActivity.kt   native collectors (usage stats)
    │   └── lib/{consent,features/{usage,location,sos,transparency}}
    └── parent/             familyguard_parent
        └── lib/features/{dashboard,children,screen_time,app_blocking,
                           web_filter,geofencing,bedtime,alerts}
```

Apps reference core with a path dependency; no publishing needed.

## 3. Which app owns which feature

| Capability            | Child app | Parent app |
|-----------------------|:---------:|:----------:|
| Consent gate          | ✅        |            |
| App-usage collection  | ✅ (native)|           |
| Location sharing      | ✅        |            |
| SOS trigger           | ✅        |            |
| Two-way transparency  | ✅        |            |
| Dashboard / reports   |           | ✅         |
| Manage children       |           | ✅         |
| Screen-time limit     |           | ✅ (set)   |
| App blocking / filter |           | ✅ (set)   |
| Geofencing / bedtime  |           | ✅ (set)   |
| Remote commands       | ✅ (polls, can accept/reject) | ✅ (create) |
| Screenshots (on-request) | ✅ (countdown, can reject) | ✅ (request/view) |
| SOS audio (≤ 30 s)    | ✅ (indicator + sound) | ✅ (request/view) |

The child app **collects/acts**; the parent app **configures/views**. The backend
stores the shared state both talk to.

## 4. Parent app feature pattern

Each parent feature implements `FeatureModule` (id/title/description/icon +
`buildScreen`) and is listed once in `feature_registry.dart`; the dashboard builds
itself from that list.

## 5. Consent & transparency (child app)

1. First launch shows a full-screen consent notice.
2. No collector runs until consent is recorded (`ConsentService`).
3. A visible "Monitoring: ON" indicator; a "What My Parent Sees" screen mirrors
   exactly what the parent can view. No hidden/stealth mode.

## 6. Backend
Unchanged and shared: modular Express API, one folder per feature under
`backend/src/modules/`. See [backend/README.md](../backend/README.md).

New in v0.7.1 (see [ROADMAP.md](ROADMAP.md) §Phase 1.1):

- **Persistence:** `backend/src/db/migrations/001_init.sql` + `src/db/migrate.js`
  (`npm run db:migrate`). `src/db/repository.js` is the pattern new modules
  use: Postgres when `DATABASE_URL` is set, in-memory store otherwise.
- **Remote commands:** `backend/src/modules/remotecommands/` — parent
  creates `lock_now | unlock | send_message | request_screenshot |
  request_audio`; the child polls `GET /api/remotecommands?status=pending`
  every 30 s. Commands expire after 15 min (`COMMAND_TTL_MINUTES`).
- **Push:** `backend/src/services/pushService.js` (FCM, best-effort only).
  Push notifies; polling delivers. Device tokens:
  `POST /api/devices/:id/push-token`.
- **Media:** `backend/src/modules/media/` — on-request screenshots and
  SOS-only short audio (kind `screenshot | sos_audio`, source
  `sos | parent_request`, 7-day expiry, audit-logged). **Phase 2:** the
  child uploads the file bytes as base64 to `POST /api/media/:id/upload`
  (8 MB cap, PNG or AAC/M4A only), stored under `backend/uploads/`
  (git-ignored; swap for object storage in production); the parent
  downloads via `GET /api/media/:id/file`.
- **Phase 2 modules:** `apps` (installed-apps inventory),
  `browsing` (browser sessions — no URLs), `agreement` (family
  agreement sign-off), `rewards` (points/badges + idempotent
  screen-time bonus), `keywords` (simple keyword list + substring
  scan; **no ML model**). Migration `002_phase2.sql` adds their tables;
  the modules themselves use the in-memory store directly (the codebase
  norm) until the older-module Postgres migration lands.
- **Android native (child app):** `MainActivity.kt` hosts the
  MethodChannels (`familyguard/usage`, `comms`, `location`, `files`,
  `apps`, `browsing`, `lock`, `screen`, `audio`, `enforcement`).
  `CaptureService` does MediaProjection screenshots (countdown +
  system approval) and MediaRecorder SOS audio (30 s cap, beep +
  notification). `BlockWatcherService` enforces bedtime/app-blocking
  with a visible overlay; rules sync from `/api/appblocking` +
  `/api/bedtime` via `EnforcementSync` in Dart. `GuardDeviceAdminReceiver`
  is a device admin with only the `force-lock` policy. All of this is
  Kotlin-compiled and verified (see ROADMAP.md §Build verification);
  the full `flutter build apk --release` could not run in this VM
  because the sandbox blocks Java loopback TCP for the Gradle daemon.
- **Windows native:** still TODO. The Dart collectors degrade to
  documented no-ops on Windows (`NativeCollectors` returns empty
  results) instead of pretending to work. Missing: screenshot (Win32
  BitBlt via FFI), installed-apps inventory (registry/PowerShell),
  browser sessions, lock enforcement.
- **Android:** `client/apps/{child,parent}/android/` is committed (see
  [SIGNING.md](SIGNING.md)). Distinct applicationIds
  (`com.familyguard.familyguard_child` /
  `com.familyguard.familyguard_parent`), minSdk 24, targetSdk 36, release
  signing from GitHub Secrets. Never regenerate these folders with
  `flutter create` in CI again.

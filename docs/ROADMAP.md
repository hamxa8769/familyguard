# FamilyGuard — Development Roadmap

A transparent, consent-based parental-control app. One Flutter codebase for
**Windows / Android / iOS**, backed by a modular Node.js API.

> Every feature follows the project's core rule: **visible app, recorded consent,
> data minimisation.** No stealth/hidden mode. See [ETHICS.md](ETHICS.md).

---

## Phase 0 — Foundation ✅ (done)

- [x] Modular backend (Express, one folder per feature)
- [x] Feature-first Flutter client (plug-in `FeatureModule` registry)
- [x] Auth (JWT) + consent gate + device registration
- [x] In-memory store (swap to Postgres later)

## Phase 0.1 — Install fix ✅ (v0.7.1, 2026-11-20)

The Parent app showed "App not installed" on Android. Root cause: no
`android/` folder was committed — the release workflow regenerated it on
every run with `flutter create`, and the APK was built with no signing
config, so it was debug-signed and could not reliably install/update.

- [x] `android/` folders committed for both apps, with distinct
  applicationIds: child `com.familyguard.familyguard_child`, parent
  `com.familyguard.familyguard_parent`; minSdk 24 / targetSdk 36 (Flutter
  3.50 defaults).
- [x] Release signing via GitHub Secrets (keystore never committed) —
  see [SIGNING.md](SIGNING.md). The release job fails loudly if the
  secrets are missing, instead of publishing another uninstallable APK.
- [x] Universal APK (not `--split-per-abi`) for sideloading.
- [x] Version bumped to 0.7.1+8.
- [ ] Still needs the user: create the keystore and add the four
  `ANDROID_*` secrets (docs/SIGNING.md), then cut the v0.7.1 tag and
  install the Parent APK fresh on the phone to confirm the fix.

## Phase 1 — Core features (this build) — 11 features

| #  | Feature | Backend | Client | Native note |
|----|---------|:-------:|:------:|-------------|
| 1  | **App usage tracking** | ✅ | ✅ | Android UsageStatsManager / Win foreground sampling |
| 2  | **Screen time limit** | ✅ | ✅ | daily cap per device |
| 3  | **App blocking** | ✅ | ✅ | block list enforced on device |
| 4  | **Location tracking** | ✅ | ✅ | last-known + history |
| 5  | **Geofencing** | ✅ | ✅ | enter/exit zone → alert |
| 6  | **SOS / panic button** | ✅ | ✅ | child triggers, parent alerted |
| 7  | **Web content filtering** | ✅ | ✅ | blocked-domain list |
| 8  | **Bedtime / schedule lock** | ✅ | ✅ | time-window device lock |
| 9  | **Parent dashboard + reports** | ✅ | ✅ | per-child summaries |
| 10 | **Multi-child support** | ✅ | ✅ | one family, many children |
| 11 | **Two-way transparency** (unique) | ✅ | ✅ | child sees exactly what parent sees |

## Phase 1.1 — Foundation for screen control, screenshots & SOS audio 🚧 (v0.7.1)

The remaining features the user asked for are **not** built as silent
surveillance. The rules are in [ETHICS.md](ETHICS.md) §2b and are enforced
in code: no continuous/ambient mic listening, no secret screenshots, no
stealth mode. Mic is SOS-triggered or parent-requested only, max 30
seconds, with a visible indicator + sound. Screenshots are on-request
only, after a notification + countdown on the child device. Both
auto-expire after 7 days and are listed in "What My Parent Sees".

- [x] Postgres schema (`backend/src/db/migrations/001_init.sql`) + runner
  (`npm run db:migrate`); repository layer that uses Postgres when
  `DATABASE_URL` is set and falls back to the in-memory store otherwise.
  New modules (remote commands, media) already use it; older modules
  migrate one at a time.
- [x] Remote commands (`POST/GET /api/remotecommands`): `lock_now`,
  `unlock`, `send_message`, `request_screenshot`, `request_audio`.
  Commands expire after 15 min; the child polls every 30 s.
- [x] Push notifications (FCM, best-effort only) via
  `src/services/pushService.js`; without `FCM_SERVER_KEY` push is
  skipped and polling still delivers commands. Device push tokens:
  `POST /api/devices/:id/push-token`.
- [x] Media captures (`/api/media`): screenshot/audio metadata, 7-day
  auto-expiry, audit-logged. **Phase 2 adds the file bytes:** the child
  uploads the PNG / 30 s clip as base64 to `POST /api/media/:id/upload`
  (8 MB cap, PNG or AAC/M4A only), stored under `backend/uploads/`
  (git-ignored; a production deployment should swap this for object
  storage); the parent downloads it via `GET /api/media/:id/file`.
  Deleting a capture deletes its file too.
- [x] Consent v2: consent gate + transparency screen now list remote
  commands, on-request screenshots and SOS-only short audio; old v1
  consent must be re-confirmed. Parent dashboard gains Remote Commands
  and Screenshots & Audio modules; child app gains a Remote Commands
  screen where screenshot/audio requests can be accepted or rejected.

### What "implemented" means here
The **cross-platform logic** (API endpoints + Flutter UI + rules engine) is fully
built and runs end-to-end on sample/stub data. The **native Android collectors**
are implemented in Kotlin (`client/apps/child/android/...`): UsageStats,
contacts/SMS/call log, gallery, installed apps (PackageManager), browser
sessions (UsageEvents), device-admin lock, MediaProjection screenshots and
MediaRecorder SOS audio, and the bedtime/app-blocking watcher service.
Windows native collectors are still TODOs (see below).

## Phase 2 — Screen control, capture & the remaining standard features ✅ (v0.7.1)

Implemented in the same 0.7.1 branch (2026-11-20). Everything below is
behind the same consent + transparency rules as Phase 1.1.

### Screen control (real enforcement, Android)

- [x] **Lock now** via `DevicePolicyManager.lockNow()` — the child app is a
  device admin with **only** the `force-lock` policy (see
  `res/xml/device_admin.xml`); the admin is activated by the user in a
  visible system screen and can be removed there at any time. No wipe,
  no password policy, no camera/mic disable.
- [x] **Bedtime + app-blocking enforcement** — `BlockWatcherService`, a
  foreground service with a persistent "FamilyGuard monitoring is ON"
  notification. It polls UsageStats every 5 s; when a blocked app is in
  the foreground, or bedtime is active, it covers the screen with a
  visible overlay ("This app is blocked by a family rule" / "It is
  bedtime") with a button to go home. Rules come from the existing
  `/api/appblocking/:deviceId` and `/api/bedtime/:deviceId` endpoints,
  synced into SharedPreferences by the child app (`EnforcementSync`)
  whenever it polls remote commands. Needs usage access + "Draw over
  other apps" permission, both granted in visible system screens.
- [x] **Unlock** stops the watcher (lifts the overlay). Android has no
  remote-unlock API — the device is already unlocked when the child uses
  it, so the command means "the parent lifted the lock".
- **OS limits (not worked around):** no Device Owner / lock-task mode —
  a determined user can force-stop the app. Full kiosk enforcement needs
  an Android Enterprise device-owner setup, which is out of scope.

### Native capture (Android)

- [x] **Screenshot** — `CaptureService` (MediaProjection): the child sees
  a countdown notification, then Android's own screen-capture dialog.
  The child can deny it there; a denial is reported as `rejected`.
  One frame is saved as PNG and uploaded to the capture the parent
  created. No silent screenshot exists anywhere in the code.
- [x] **SOS / parent-requested audio** — `CaptureService` (MediaRecorder):
  max 30 s hard cap (`setMaxDuration(30000)` + a safety timer), a
  persistent notification, a beep at start and stop. Never starts on its
  own.
- [x] Child Remote Commands screen now **executes** commands: lock now,
  unlock, accept/reject screenshot & audio (with upload), mark message
  as read.

### Remaining standard features

| Feature | Backend | Client | Note |
|---------|---------|:------:|------|
| **Installed-apps inventory** | ✅ `/api/apps` | ✅ | Android PackageManager; child syncs on demand, parent views. |
| **Browsing history** | ✅ `/api/browsing` | ✅ | Browser-app sessions only (which browser, when, how long). **No URLs** — Android does not expose them to third-party apps; no VPN/proxy is used. |
| **Family agreement** | ✅ `/api/agreement` | ✅ | Parent proposes rules; child accepts/declines; status + signed time visible to both. |
| **Reward system** | ✅ `/api/rewards` | ✅ | Parent awards points/badges; automatic 10-pt screen-time bonus, idempotent per child+date. |
| **AI keyword alerts** | ✅ `/api/keywords` | ✅ | **Simple keyword list + substring match only. No ML model, no sentiment analysis** — the screen and the model say so. A match creates an alert (in the SOS alerts list — see note below). |
| **Postgres migration 002** | ✅ | — | Tables for all five modules above (`002_phase2.sql`). Older modules still use the in-memory store via the repository fallback. |

> **Keyword-alert storage note:** the task brief said alerts should go into
> "the existing alerts collection", but no `alerts` module or collection
> exists in this repo — the only alerts collection is `store.sosAlerts`
> (SOS module). Keyword matches are stored there with the SOS shape plus
> `matchedKeywords`/`source` context, and are visible via `GET /api/sos`.
> If a separate alerts collection is wanted, that is a follow-up decision.

### Still open after Phase 2

- [ ] **Windows native collectors** — screenshot (Win32 BitBlt via FFI),
  installed-apps inventory (registry/PowerShell), browser sessions,
  lock enforcement. The Dart code degrades to documented no-ops on
  Windows instead of pretending to work; see ARCHITECTURE.md §6.
- [ ] **Postgres migration of the older modules** (usage, screentime,
  appblocking, bedtime, etc.) — one module at a time via the repository
  layer. The new modules use the in-memory store directly (the codebase
  norm) with migration 002 tables ready.
- [ ] **FCM credentials** (`FCM_SERVER_KEY`) in the backend `.env` — push
  is best-effort; polling already delivers commands.
- [ ] **ML/sentiment alerts** — design only. No model is bundled or
  claimed; the keyword list is the whole mechanism for now.
- [ ] **Device-owner setup** for kiosk-grade enforcement (Android
  Enterprise) — out of scope for the sideloaded build.
- [ ] **Release verification on a real phone** — the release APK build
  could not be verified in this VM (see "Build verification" below);
  the v0.7.1 tag + fresh install test still need the user.

### Build verification (honest status, 2026-11-20)

- `flutter analyze` (core, child, parent): **no errors, no warnings** —
  only `info`-level deprecation notices that `package:flutter/material.dart`
  is deprecated in Flutter 3.50 in favour of `material_ui` (affects every
  file in the repo, pre-existing pattern, not introduced here).
- `flutter test` (child + parent widget tests): **4/4 pass**.
- Backend `npm test`: **23/23 pass** (remote commands, media + upload,
  consent v2, and the five Phase 2 modules).
- Kotlin native code: **compiles clean** with standalone `kotlinc 2.1.20`
  against API 36 + the Flutter embedding + androidx (exit 0; only
  deprecation warnings for `UsageEvents` constants and
  `getParcelableExtra`).
- `flutter build apk --release` **could NOT be completed in this VM**:
  the sandbox blocks Java's loopback TCP (`other_tcp: Deny`), which the
  Gradle daemon protocol needs, so every build fails with "Could not
  dispatch a message to the daemon" — an environment restriction, not a
  code error. The Gradle distribution itself was downloaded fine via
  curl. To verify the APK build, either run it on a machine without that
  restriction, or ask the user to switch `other_tcp` from Deny to Ask in
  Muse settings → Permissions → Direct network protocols. CI (GitHub
  Actions) is unaffected and is the other path to a verified APK.
  The local throwaway test keystore (`~/familyguard-test.keystore`) and
  local `android/key.properties` files exist only on this machine and are
  not committed; the real release keystore + secrets are still needed
  from the user (docs/SIGNING.md).

## Phase 3 — Hardening

- [ ] Postgres migrations for the older modules (via the repository layer)
- [x] Automated tests (backend: `npm test` — 23 tests: remote commands, media + upload, consent v2, apps, browsing, agreement, rewards, keywords)
- [x] Widget tests (Flutter — child + parent, 4 tests)
- [x] CI (GitHub Actions) — analyze + backend tests + widget tests on push; release job runs analyze before building
- [x] Per-platform native collector implementations (Android: screenshot, SOS audio, lock, installed apps, browsing sessions; Windows still TODO)

---

## Milestones

1. **M1 — Demo-ready** (Phase 1): all 11 features clickable end-to-end.
2. **M2 — Persistent**: Postgres + push notifications.
3. **M3 — Native**: real Android collectors + enforcement ✅ (Android done; Windows TODO).
4. **M4 — Intelligent**: AI alerts + reward system ✅ (keyword list + rewards done; ML model is design-only).

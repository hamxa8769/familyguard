# Changelog

All notable changes to FamilyGuard are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

## [Unreleased]

## [0.7.1] - 2026-11-20

### Fixed
- **Parent app "App not installed" (Android).** The `android/` folders are
  now committed for both apps (distinct applicationIds
  `com.familyguard.familyguard_child` /
  `com.familyguard.familyguard_parent`, minSdk 24, targetSdk 36), and
  release APKs are signed with one stable keystore from GitHub Secrets
  (see [SIGNING.md](docs/SIGNING.md)). The release job now fails loudly
  if the signing secrets are missing, instead of publishing another
  debug-signed APK. Universal APK (not split-per-abi) for sideloading.
  Users updating from v0.7.0 should uninstall the old Parent app first,
  then install v0.7.1 fresh (different signing key).

### Added
- **Remote commands** (`POST/GET /api/remotecommands`): `lock_now`,
  `unlock`, `send_message`, `request_screenshot`, `request_audio`.
  Child polls every 30 s; commands expire after 15 min. Parent dashboard
  gains a Remote Commands module; child app gains a Remote Commands
  screen (screenshot/audio requests can be accepted or rejected).
- **Media captures** (`/api/media`): on-request screenshots and SOS-only
  short audio (max 30 s), metadata only in this phase, 7-day auto-expiry,
  audit-logged. Parent dashboard gains a Screenshots & Audio module.
- **Postgres foundation:** schema `backend/src/db/migrations/001_init.sql`
  + `npm run db:migrate`, and a repository layer that uses Postgres when
  `DATABASE_URL` is set and falls back to the in-memory store otherwise.
- **Push notifications (FCM, best-effort):** `src/services/pushService.js`;
  without `FCM_SERVER_KEY` push is skipped and polling still delivers
  commands. Device push tokens: `POST /api/devices/:id/push-token`.
- **Consent v2:** consent gate + "What My Parent Sees" now list remote
  commands, on-request screenshots and SOS-only short audio. Old v1
  consent must be re-confirmed. ETHICS §2b documents the hard limits:
  no continuous/ambient listening, no secret screenshots, no live camera.
- **Backend tests:** `npm test` (23 tests: remote commands, media +
  upload, consent v2, apps, browsing, agreement, rewards, keywords).
- **Screen control (Android, real enforcement).** `lock_now` now locks
  via `DevicePolicyManager` (device admin, `force-lock` policy only,
  user-activated in a visible system screen). Bedtime + app-blocking
  enforcement via `BlockWatcherService` (foreground service, visible
  overlay, rules synced from `/api/appblocking` + `/api/bedtime`).
  `unlock` stops the watcher. Child Remote Commands screen executes
  commands instead of only listing them.
- **Native capture (Android).** MediaProjection screenshot (countdown
  notification + Android's own screen-capture dialog; denial reported
  as rejected) and MediaRecorder SOS audio (30 s hard cap, notification
  + beep). Capture files upload as base64 to
  `POST /api/media/:id/upload` (8 MB cap) and download via
  `GET /api/media/:id/file`; deleting a capture deletes its file.
- **Installed-apps inventory** (`/api/apps`): Android PackageManager;
  child syncs on demand, parent views.
- **Browsing history** (`/api/browsing`): browser-app sessions only
  (which browser, when, how long) — **no URLs**, by Android design.
- **Family agreement** (`/api/agreement`): parent proposes rules, child
  accepts/declines, both see the same status.
- **Reward system** (`/api/rewards`): parent awards points/badges;
  automatic 10-point screen-time bonus, idempotent per child+date.
- **AI keyword alerts** (`/api/keywords`): simple keyword list +
  substring match only — **no ML model, no sentiment analysis** (a match
  creates an alert in the SOS alerts list; see ROADMAP.md note).
- **Postgres migration 002** (`002_phase2.sql`): tables for the five
  modules above.
- **Consent + transparency updated** for every new feature (installed
  apps, browser sessions, bedtime/app-blocking, agreement, rewards,
  keyword alerts; "Not collected" now also lists URLs and live camera).
- **Widget tests** (child + parent, 4 tests) and **CI completion**:
  `ci.yml` now runs backend tests and Flutter widget tests on push/PR,
  in addition to analyze.
- **Kotlin verification:** native Android code compiles clean with
  standalone `kotlinc 2.1.20` against API 36 + Flutter embedding +
  androidx. `flutter build apk --release` could **not** be verified in
  this VM — the sandbox blocks Java loopback TCP (`other_tcp: Deny`),
  which the Gradle daemon needs (see ROADMAP.md §Build verification).
  The APK build must be verified on a machine without that restriction
  or via CI before the v0.7.1 release is cut.

### Planned (see docs/ROADMAP.md — Phase 2/3)

- Windows native collectors (screenshot, installed apps, browsing, lock).
- Postgres migration of the older backend modules.
- FCM credentials (`FCM_SERVER_KEY`) for push.
- ML/sentiment alerts (design only — no model bundled).
- Device-owner setup for kiosk-grade enforcement (out of scope for sideload).
- v0.7.1 tag + fresh install test on a real phone (needs the keystore
  secrets from the user first).

## [0.7.0] - 2026-11-07

### Added
- **Gallery & Files (Android + Windows, child app).** Android lists images via
  MediaStore (READ_MEDIA_IMAGES); Windows lists the Pictures folder via dart:io.
  Child Gallery screen shows real thumbnails of its own device; parent app gains a
  Gallery & Files viewer (metadata grid; image-byte sync is a TODO); backend `files`
  module syncs/serves the listing.

### Changed
- **Transparency updated honestly.** Consent + "What My Parent Sees" now disclose
  photos/files; the "not collected" note is corrected to live camera/microphone;
  ETHICS notes photos may contain images of third parties.

## [0.6.0] - 2026-11-07

### Added
- **Location (Android GPS, child app).** Native last-known GPS via LocationManager
  with ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION runtime permission; child
  Location screen shows the current shared point; parent app gains a Location
  viewer (current + recent history, map placeholder). Location was already in the
  consent notice and the transparency screen.

## [0.5.0] - 2026-11-07

### Added
- **Call Log (Android, child app).** Native reading of call history (number, type
  incoming/outgoing/missed, time, duration) via `CallLog.Calls` with the
  READ_CALL_LOG runtime permission; parent app gains a Call Log viewer; backend
  `comms` module extended to sync/serve call logs. Disclosed to the child in the
  consent notice and "What My Parent Sees".

## [0.4.0] - 2026-11-07

### Added
- **Messages & Contacts (Android, child app).** Native reading of SMS (sender,
  text, time) and contacts via ContentResolver with READ_SMS / READ_CONTACTS
  runtime permissions; parent app gains a Messages & Contacts viewer; backend
  `comms` module syncs/serves them.

### Changed
- **Transparency updated honestly.** The child consent notice and "What My Parent
  Sees" screen now disclose that SMS and contacts are visible to the parent; the
  "not collected" note is corrected to photos/camera/microphone. ETHICS doc gains
  a "Messages & contacts" section (third-party privacy, Play policy, minor-only).

## [0.3.0] - 2026-11-07

### Changed
- **Restructured into a monorepo with two apps.** Replaced the single role-switch
  app with `client/packages/core` (shared models, API client, auth, consent) plus
  `client/apps/child` and `client/apps/parent`, mirroring real parental-control
  products (e.g. Google Family Link).

### Added
- **Child app** — consent gate, native app-usage tracking, location sharing,
  SOS button, and the two-way transparency screen.
- **Parent app** — dashboard/reports, children, screen-time limit, app blocking,
  web filter, geofencing, bedtime, and an alerts inbox.
- Release pipeline now builds four artifacts (child/parent × Android/Windows);
  CI analyzes the core package and both apps.

## [0.2.0] - 2026-11-07

### Added
- **Android native app-usage tracking** — real foreground-time per app via
  `UsageStatsManager` over the `familyguard/usage` MethodChannel, with an
  in-app Usage Access permission prompt that links to system settings.

## [0.1.0] - 2026-11-07

### Added
- Cross-platform Flutter client (Windows / Android / iOS), feature-first.
- Modular Node.js backend (one folder per feature).
- Consent gate + transparency base (visible app, recorded consent).
- 11 Phase-1 features: app usage, screen time, app blocking, location,
  geofencing, SOS, web filter, bedtime lock, dashboard/reports, multi-child,
  two-way transparency.
- CI (flutter analyze + backend syntax check) and release pipeline
  (APK + Windows EXE published to GitHub Releases on each `v*` tag).
- Docs: README, ARCHITECTURE, ROADMAP, ETHICS, ADDING_A_FEATURE, RELEASING.

[Unreleased]: https://github.com/hamxa8769/familyguard/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.7.0
[0.6.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.6.0
[0.5.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.5.0
[0.4.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.4.0
[0.3.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.3.0
[0.2.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.2.0
[0.1.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.1.0

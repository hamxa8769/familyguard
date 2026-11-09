# Changelog

All notable changes to FamilyGuard are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

## [Unreleased]

### Added (UI/UX Phase 2 — parent app)
- App usage: 7-day bar chart (days over the limit in red, limit line),
  today / average / limit stats, per-app breakdown (`fl_chart`).
- Location: OpenStreetMap map (`flutter_map`, dark tiles in dark mode) with
  current position, recent trail and safe-zone circles.
- Safe zones: tap the map to place a zone, size it with a slider, remove zones.
- Alerts: All / SOS / Safe-zone filters, grouped by day, inline Resolve.
- Screen time (ring + presets) and Bedtime (start/end tiles) redesigned.
- Family: pairing QR code (`qr_flutter`) with server URL + code for the
  child app; device rows show last-seen status.
- Backend: `GET /api/usage/:deviceId/daily`, `DELETE /api/geofencing/zone/:id`.

### Fixed
- Daily report counted usage from all days as "today".
- Release APKs had no INTERNET permission and blocked plain http://, so they
  could not reach the server (or load map tiles). The release workflow now adds
  INTERNET and allows cleartext for the LAN/dev server.

### Added (UI/UX Phase 1 — parent app)
- Design system: dark-first theme with light/auto mode, colour tokens
  (accent + safe/warn/danger only), spacing scale, flat GPU-cheap surfaces.
- Shared widgets: animated screen-time ring, usage bars, pulsing status dot,
  skeleton loaders, quick actions, feature tiles.
- 5-tab navigation (Home, Activity, Rules, Alerts, Family) built from the
  feature registry; Settings screen with theme switch and sign out.
- New Home: child switcher, live device status, SOS banner, screen-time ring
  with top apps, location / safe-zone card, quick actions, rules summary.
  Shows the cached report instantly and refreshes every minute.
- Backend: devices report a `lastSeenAt` heartbeat.


### Added
- **Apps connected to the backend.** Parent sign-in/sign-up; children with
  single-use pairing codes; child app pairs with the code, records consent on
  the server and syncs usage, location, SMS/contacts/call log and file metadata
  (on start, every 15 min while open, and "Sync now"). SOS is sent for real.
- Every parent screen now reads/writes real data for the selected child device
  (dashboard, location, screen time, app blocking, web filter, safe zones,
  bedtime, messages, call log, gallery, alerts with resolve). Sample data removed.
- Child "What My Parent Sees" loads the actual parent-side report.

### Security
- Device-level access control: only the owning parent or the device itself can
  read a device's data; only the parent can change its rules. SOS list is
  filtered per parent (previously returned every family's alerts).

### Fixed
- Usage sync no longer double-counts (today's totals are replaced, not appended).
- JSON body limit raised to 5 MB so SMS/contacts/gallery syncs aren't rejected.
- `.gitignore` paths updated for the monorepo layout.


### Planned (see docs/ROADMAP.md — Phase 2)

- AI keyword / sentiment alerts
- Reward system
- Remote commands (lock now / send message)
- Native OS collectors (Android UsageStatsManager, Windows foreground sampling)
- Postgres persistence + push notifications

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

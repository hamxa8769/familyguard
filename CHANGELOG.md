# Changelog

All notable changes to FamilyGuard are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

## [Unreleased]

### Planned (see docs/ROADMAP.md — Phase 2)

- AI keyword / sentiment alerts
- Reward system
- Remote commands (lock now / send message)
- Native OS collectors (Android UsageStatsManager, Windows foreground sampling)
- Postgres persistence + push notifications

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

[Unreleased]: https://github.com/hamxa8769/familyguard/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.5.0
[0.4.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.4.0
[0.3.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.3.0
[0.2.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.2.0
[0.1.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.1.0

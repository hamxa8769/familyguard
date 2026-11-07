# Changelog

All notable changes to FamilyGuard are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

## [Unreleased]

### Added
- **Android native app-usage tracking** — real foreground-time per app via
  `UsageStatsManager` over the `familyguard/usage` MethodChannel, with an
  in-app Usage Access permission prompt that links to system settings.

### Planned (see docs/ROADMAP.md — Phase 2)
- AI keyword / sentiment alerts
- Reward system
- Remote commands (lock now / send message)
- Native OS collectors (Android UsageStatsManager, Windows foreground sampling)
- Postgres persistence + push notifications

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

[Unreleased]: https://github.com/hamxa8769/familyguard/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hamxa8769/familyguard/releases/tag/v0.1.0

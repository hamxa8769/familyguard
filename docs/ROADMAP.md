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

### What "implemented" means here
The **cross-platform logic** (API endpoints + Flutter UI + rules engine) is fully
built and runs end-to-end on sample/stub data. The **native OS collectors**
(reading real usage/location, enforcing real locks) are wired as `MethodChannel`
stubs with clear TODOs, because those require per-platform Kotlin/Swift/Win32 code.
This is the honest, demonstrable scope for a cross-platform project.

## Phase 2 — Coming soon 🚧

| Feature | Why later | Difficulty |
|---------|-----------|------------|
| **AI keyword / sentiment alerts** | Needs an ML model + moderation pipeline | Hard |
| **Reward system** (points/badges for healthy habits) | Design-heavy, positive-reinforcement UX | Medium |
| **Remote commands** (lock now / send message) | Needs push (FCM/APNs) infra | Medium |
| **Call & SMS metadata log** | Android-only, sensitive — extra consent | Medium |
| **Browsing history** | Browser-dependent capture | Medium |
| **Installed-apps inventory** | Simple, queued behind core | Easy |
| **Family agreement** (joint rules sign-off) | Nice onboarding polish | Easy |
| **Postgres persistence** | Replaces in-memory store | Medium |
| **Push notifications** (FCM / APNs) | Infra for alerts/remote cmds | Medium |

## Phase 3 — Hardening

- [ ] Postgres migrations + real persistence
- [ ] Automated tests (backend + widget tests)
- [ ] CI (GitHub Actions)
- [ ] Per-platform native collector implementations

---

## Milestones

1. **M1 — Demo-ready** (Phase 1): all 11 features clickable end-to-end.
2. **M2 — Persistent**: Postgres + push notifications.
3. **M3 — Native**: real Android/Windows collectors + enforcement.
4. **M4 — Intelligent**: AI alerts + reward system.

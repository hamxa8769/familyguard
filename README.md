# FamilyGuard — Cross-Platform Parental Control

A **transparent, consent-based** parental-control system built like real products:
a **Child app** (runs on the child's device, collects data and shows full
transparency) and a **Parent app** (dashboard and controls), sharing one code
core, backed by a modular **Node.js** API. Targets **Android + Windows**
(iOS out of scope — Apple restricts third-party monitoring).

> **Transparency by design.** Not covert monitoring: the child app is always
> visible, requires an on-device consent step, is for a parent monitoring their
> own minor child on a device they own or share, and stores the minimum data.
> No stealth mode. See [docs/ETHICS.md](docs/ETHICS.md).

## Structure

```
.
├── client/
│   ├── packages/core/   Shared: models, API client, auth, consent
│   └── apps/
│       ├── child/       Child/companion app (+ native Android collectors)
│       └── parent/      Parent dashboard & controls
├── backend/             Node.js + Express API (one folder per feature)
└── docs/                ARCHITECTURE, ROADMAP, ETHICS, RELEASING, ADDING_A_FEATURE
```

Why two apps + a shared core: each app stays small and focused, and common code
(API contract, auth, models) lives in one place — easy to understand and extend.

## Features by app

**Child app** — consent gate · real app-usage (Android `UsageStatsManager`) ·
location sharing · SOS button · "what my parent sees" (two-way transparency).

**Parent app** — dashboard/reports · multiple children · screen-time limit ·
app blocking · web filter · geofencing (safe zones) · bedtime lock · alerts inbox.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full plan and **Coming Soon** list.

> **Scope note.** Cross-platform logic (API + Flutter UI + rules) runs end-to-end.
> Android app-usage uses real native data; other collectors/enforcement are being
> added per platform, one feature at a time (see ROADMAP).

## Downloads

Each version tag publishes installable builds (child + parent, Android + Windows)
to **[Releases](https://github.com/hamxa8769/familyguard/releases)**.

## Run from source

**Backend**
```bash
cd backend && npm install && cp .env.example .env && npm run dev
```

**Child app** (and likewise `apps/parent`)
```bash
cd client/apps/child && flutter pub get && flutter run -d windows   # or -d android
```

## Docs
[ARCHITECTURE](docs/ARCHITECTURE.md) · [ROADMAP](docs/ROADMAP.md) ·
[ETHICS](docs/ETHICS.md) · [RELEASING](docs/RELEASING.md) ·
[ADDING_A_FEATURE](docs/ADDING_A_FEATURE.md)

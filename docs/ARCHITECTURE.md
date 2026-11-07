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
| Alerts inbox          |           | ✅         |

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

# FamilyGuard Client (Flutter monorepo)

Two apps that share one core package.

```
client/
├── packages/core/   familyguard_core — models, API client, auth, consent
└── apps/
    ├── child/        familyguard_child — on the child's device
    └── parent/       familyguard_parent — on the parent's device
```

Apps depend on the core via a path dependency, e.g. in `apps/child/pubspec.yaml`:

```yaml
dependencies:
  familyguard_core:
    path: ../../packages/core
```

## Run

```bash
# Parent app
cd client/apps/parent && flutter pub get && flutter run -d windows

# Child app (real usage data on Android)
cd client/apps/child && flutter pub get && flutter run -d android
```

## Analyze (what CI runs)

```bash
cd client/packages/core && flutter pub get && flutter analyze
cd client/apps/child    && flutter pub get && flutter analyze
cd client/apps/parent   && flutter pub get && flutter analyze
```

## Add a feature
See [../docs/ADDING_A_FEATURE.md](../docs/ADDING_A_FEATURE.md).

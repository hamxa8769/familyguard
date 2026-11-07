# FamilyGuard Client (Flutter)

One Flutter app for **Windows, Android, and iOS**, running in either a `parent`
or `child` role.

## Run

```bash
cd client
flutter pub get
flutter run -d windows   # or: -d android / -d ios / chrome
```

## Structure (feature-first)

```
lib/
├── core/        config, network, auth, consent — cross-cutting base
├── features/    one folder per feature; each implements FeatureModule
└── shared/      reusable widgets/utils
```

## Add a new feature

1. Create `lib/features/<feature>/<feature>_module.dart` implementing `FeatureModule`.
2. Add it to the list in `lib/features/feature_registry.dart`.

The dashboard/menu builds itself from the registry, so nothing else changes.

## Platform capabilities

Data collectors (usage, location, etc.) are platform-specific. On platforms where
an OS API is restricted (notably iOS), the collector degrades gracefully and the
feature shows a "limited on this platform" state rather than failing.

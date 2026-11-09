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

### Connecting the apps

1. Start the backend (`cd backend && npm install && npm start`, port 4000).
2. Parent app → create an account → **My Children** → add a child → note the code.
3. Child app → enter the code (set **Server** to your PC's LAN address, e.g.
   `http://192.168.1.10:4000`; `localhost` only works on the same machine and
   `10.0.2.2` from the Android emulator) → accept consent.
4. The child app shares data on start, every 15 minutes while open, and on
   **Sync now**. The parent app reads it per selected child device.

You can also bake in a default server: `flutter run --dart-define=API_BASE_URL=http://…`.

## Analyze (what CI runs)

```bash
cd client/packages/core && flutter pub get && flutter analyze
cd client/apps/child    && flutter pub get && flutter analyze
cd client/apps/parent   && flutter pub get && flutter analyze
```

## Add a feature
See [../docs/ADDING_A_FEATURE.md](../docs/ADDING_A_FEATURE.md).

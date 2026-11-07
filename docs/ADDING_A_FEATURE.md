# Adding a Feature

A feature plugs in without touching existing code. First decide **which app** it
belongs to: the **child app** collects data / acts on the device; the **parent
app** configures and views.

## 1. Backend module (shared by both apps)

Create `backend/src/modules/<feature>/` with `<feature>.routes.js`,
`<feature>.controller.js`, and optionally `<feature>.service.js`, then register it
with one line in `backend/src/routes.js`:

```js
import locationRoutes from './modules/location/location.routes.js';
app.use('/api/location', locationRoutes);
```

## 2a. Parent-side feature (view / configure)

Create `client/apps/parent/lib/features/<feature>/<feature>_module.dart`
implementing `FeatureModule` (copy `dashboard/` as a template), then add it to
`client/apps/parent/lib/feature_registry.dart`:

```dart
static final List<FeatureModule> all = [
  DashboardModule(),
  MyNewModule(), // <- appears in the dashboard automatically
];
```

## 2b. Child-side feature (collect / act)

Add a screen under `client/apps/child/lib/features/<feature>/` and a tile in
`client/apps/child/lib/main.dart`. Put OS-specific data behind a `MethodChannel`
with a native implementation in `apps/child/android/.../MainActivity.kt`.

## 3. Shared code goes in core

Models, API calls, auth and consent live in `client/packages/core`. Add a model
there and export it from `lib/familyguard_core.dart` so both apps use the same type.

## 4. Native collectors (per platform)

| Feature     | Android                | Windows                  | iOS            |
|-------------|------------------------|--------------------------|----------------|
| App usage   | UsageStatsManager ✅    | foreground-window sample | not available  |
| Location    | FusedLocationProvider  | Win32 location API       | CoreLocation   |
| Screen time | DevicePolicyManager    | app-level lock           | Screen Time    |

Collectors degrade gracefully where an OS blocks access (return empty/limited).

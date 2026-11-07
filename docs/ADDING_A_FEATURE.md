# Adding a Feature

This is the whole point of the architecture — a feature plugs in without touching
existing code. Example: adding **Location**.

## 1. Backend module

Create `backend/src/modules/location/`:

- `location.routes.js` — define routes, guard with `requireAuth`.
- `location.controller.js` — parse request, call service, respond.
- `location.service.js` — logic + storage.

Then register it with **one line** in `backend/src/routes.js`:

```js
import locationRoutes from './modules/location/location.routes.js';
app.use('/api/location', locationRoutes);
```

## 2. Client feature

Create `client/lib/features/location/location_module.dart` implementing
`FeatureModule` (copy `usage_tracker/` as a template). Put any OS-specific data
collection in a `*_collector.dart` behind a `MethodChannel`.

Then add it to the list in `client/lib/features/feature_registry.dart`:

```dart
static final List<FeatureModule> all = [
  UsageTrackerModule(),
  LocationModule(), // <- new
];
```

The dashboard rebuilds from the registry automatically.

## 3. Native collectors (per platform)

| Feature     | Android                | Windows                  | iOS                         |
|-------------|------------------------|--------------------------|-----------------------------|
| App usage   | UsageStatsManager      | foreground-window sample | not available (3rd-party)   |
| Location    | FusedLocationProvider  | Win32 location API       | CoreLocation (with prompt)  |
| Screen time | DevicePolicyManager    | app-level lock           | Screen Time / Family Controls|

Collectors should **degrade gracefully** where an OS blocks access, returning an
empty/limited state the UI can show.

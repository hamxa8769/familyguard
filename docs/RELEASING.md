# Releasing

The app updates through **versioned GitHub Releases**, built automatically by CI.
You never build the APK/EXE by hand — pushing a version tag does it.

## How versioning works

- Source of truth for a release is the **git tag** `vMAJOR.MINOR.PATCH` (e.g. `v0.2.0`).
- `client/pubspec.yaml` holds `version: X.Y.Z+BUILD`. Bump it to match the tag.
- Follow [SemVer](https://semver.org/):
  - **PATCH** (`v0.1.1`) — bug fixes.
  - **MINOR** (`v0.2.0`) — new feature, backward compatible.
  - **MAJOR** (`v1.0.0`) — breaking change.

## Cut a release (one app, continuously updated)

```bash
# 1. Finish your changes and update the CHANGELOG [Unreleased] section.
# 2. Bump the version in client/pubspec.yaml (e.g. 0.2.0+2).
git add -A && git commit -m "Release v0.2.0"
git push

# 3. Tag and push the tag — this triggers the release build.
git tag v0.2.0
git push origin v0.2.0
```

CI (`.github/workflows/release.yml`) then:
1. Builds the **Android APK** on an Ubuntu runner.
2. Builds the **Windows EXE** (zipped) on a Windows runner.
3. Creates a GitHub **Release** for the tag and attaches both artifacts.

Download links appear at:
`https://github.com/hamxa8769/familyguard/releases`

## Continuous checks

Every push / PR runs `.github/workflows/ci.yml`:
- `flutter analyze` on the client.
- Node syntax check on the backend.

Keep `main` green; cut a tag only from a green commit.

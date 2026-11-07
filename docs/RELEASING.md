# Releasing

The apps update through **versioned GitHub Releases**, built automatically by CI.
You never build by hand — pushing a version tag builds everything.

## What a release contains

Each `vX.Y.Z` tag publishes **four** artifacts:

- `familyguard-child-vX.Y.Z.apk` — child app, Android
- `familyguard-parent-vX.Y.Z.apk` — parent app, Android
- `familyguard-child-vX.Y.Z-windows.zip` — child app, Windows
- `familyguard-parent-vX.Y.Z-windows.zip` — parent app, Windows

Install the **child** app on the child's device and the **parent** app on yours.

## Versioning

- The git tag `vMAJOR.MINOR.PATCH` drives the release.
- Keep both app versions in step: `client/apps/child/pubspec.yaml` and
  `client/apps/parent/pubspec.yaml` (`version: X.Y.Z+BUILD`).
- [SemVer](https://semver.org/): PATCH = fixes, MINOR = new feature, MAJOR = breaking.

## Cut a release

```bash
# 1. Update CHANGELOG [Unreleased]; bump version in both apps' pubspec.yaml.
git add -A && git commit -m "Release v0.3.0"
git push

# 2. Tag and push the tag — this triggers the build.
git tag v0.3.0
git push origin v0.3.0
```

CI (`.github/workflows/release.yml`) then builds both apps for Android + Windows
and attaches all four artifacts to the release at:
`https://github.com/hamxa8769/familyguard/releases`

## Continuous checks

Every push / PR runs `.github/workflows/ci.yml`:
- `flutter analyze` on `packages/core`, `apps/child`, and `apps/parent`.
- Node syntax check on the backend.

Keep `main` green; cut a tag only from a green commit.

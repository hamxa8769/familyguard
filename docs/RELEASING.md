# Releasing

The apps update through **versioned GitHub Releases**, built automatically by CI.
You never build by hand — pushing a version tag builds everything.

## What a release contains

Each `vX.Y.Z` tag publishes:

| File | What |
|------|------|
| `familyguard-child-lite-vX.Y.Z.apk` | Child app, Android — **no SMS / contacts / call log** (recommended) |
| `familyguard-child-full-vX.Y.Z.apk` | Child app, Android — everything incl. SMS / contacts / call log |
| `familyguard-parent-vX.Y.Z.apk` | Parent app, Android |
| `familyguard-child-vX.Y.Z-windows.zip` | Child app, Windows |
| `familyguard-parent-vX.Y.Z-windows.zip` | Parent app, Windows |

Install a **child** app on the child's device and the **parent** app on yours.

## Google Play Protect

Play Protect warns about or blocks sideloaded apps that ask for very sensitive
access. For FamilyGuard that is mainly **SMS, call log and contacts**.

1. **Use the lite child APK** unless you really need messages/calls. It does
   not even declare those permissions.
2. **Sign releases with your own key** (below). Debug-signed APKs (the default
   without secrets) look like throwaway builds and are flagged more often.
3. If a signed build is still blocked, ask Google to review it:
   Play Protect appeals / "Submit an app for analysis" in the Google Play
   Console help center. Re-submit after each signing-key change.
4. Testing only: on the block dialog choose *More details → Install anyway*,
   or turn off *Scan apps with Play Protect* temporarily.

## Release signing (one-time setup)

```bash
keytool -genkeypair -v -keystore familyguard-release.jks -alias familyguard \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 familyguard-release.jks > keystore.b64   # macOS: base64 -i ... -o ...
```

Add four repository secrets (GitHub → Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | contents of `keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `familyguard` |
| `ANDROID_KEY_PASSWORD` | key password |

Keep the `.jks` file and passwords somewhere safe and **never commit them**.
Losing the key means existing installs can't be updated in place.
Without the secrets CI still builds, but signs with the debug key and prints a
warning.

## Versioning

- The git tag `vMAJOR.MINOR.PATCH` drives the release.
- Keep both app versions in step: `client/apps/child/pubspec.yaml` and
  `client/apps/parent/pubspec.yaml` (`version: X.Y.Z+BUILD`).
- [SemVer](https://semver.org/): PATCH = fixes, MINOR = new feature, MAJOR = breaking.

## Cut a release

```bash
# 1. Update CHANGELOG [Unreleased]; bump version in both apps' pubspec.yaml.
git add -A && git commit -m "Release v0.8.0"
git push

# 2. Tag and push the tag — this triggers the build.
git tag v0.8.0
git push origin v0.8.0
```

CI (`.github/workflows/release.yml`) then builds the apps and attaches the
artifacts to `https://github.com/hamxa8769/familyguard/releases`.

## Continuous checks

Every push / PR runs `.github/workflows/ci.yml`:
- `flutter analyze` on `packages/core`, `apps/child`, and `apps/parent`.
- Backend syntax check and `npm test` (API + persistence tests).

Keep `main` green; cut a tag only from a green commit.

# Signing a release APK (FamilyGuard)

The release APKs are **sideloaded** (distributed from GitHub Releases, not
Google Play). Android refuses to install an update whose signing key differs
from the already-installed app, and shows only the generic
"App not installed" error. That is what happened to the v0.7.0 Parent app:
the release workflow regenerated the `android/` folder on every run with
`flutter create` and built with no signing config, so the APK was signed
with Flutter's throwaway debug key and could not reliably update/replace
any earlier build.

From v0.7.1 the `android/` folders are committed, and release builds use
one stable release keystore supplied **only through GitHub Secrets**.
The keystore and its passwords are never committed to the repo.

## 1. Create the keystore (once, on your own machine)

```bash
keytool -genkeypair -v \
  -keystore familyguard-release.keystore \
  -alias familyguard \
  -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore file and its passwords safe — losing it means already
installed apps can never be updated in place again (users must uninstall
and reinstall, losing local data).

## 2. Add the secrets (repo Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded: `base64 -w0 familyguard-release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password you chose at creation |
| `ANDROID_KEY_ALIAS` | `familyguard` (or the alias you chose) |
| `ANDROID_KEY_PASSWORD` | The key password you chose at creation |

## 3. How the release workflow uses them

`.github/workflows/release.yml` (Android job):

1. Decodes `ANDROID_KEYSTORE_BASE64` to `android/app/familyguard-release.keystore`
   in each app — only inside the CI runner, never committed.
2. Writes `android/key.properties` from the secrets (store/key passwords
   and alias). `key.properties` is git-ignored.
3. Runs `flutter build apk --release`. The committed
   `android/app/build.gradle.kts` reads `key.properties` and applies the
   release signing config. If the secrets are missing, the job **fails
   loudly** instead of silently publishing another debug-signed APK.
4. Builds a **universal** APK (not `--split-per-abi`), so one file installs
   on any Android device — important for sideloading.

## 4. Local release build

```bash
# Put your keystore at client/apps/parent/android/app/familyguard-release.keystore
# and copy key.properties.example to key.properties with real values.
cd client/apps/parent
flutter build apk --release
```

## 5. If "App not installed" still appears

1. Confirm the APK is the `familyguard-parent-vX.Y.Z.apk` from the
   matching release (not the child APK — the two apps have different
   package names and cannot be installed over each other).
2. Uninstall any older Parent app first, then install fresh. An update
   signed with a different key can only be fixed by a fresh install.
3. Allow "Install unknown apps" for the browser/files app you download
   with, and check Play Protect did not block the install.
4. Check the phone's Android version against `minSdk` (24) in
   `android/app/build.gradle.kts`.

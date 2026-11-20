#!/usr/bin/env bash
# Signs an APK with the project's release key when the GitHub secrets exist;
# otherwise copies it as-is (Flutter signs release builds with the debug key).
#
# Secrets: ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD,
#          ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
# Usage:   sign_apk.sh <input.apk> <output.apk>
set -euo pipefail
in="$1"
out="$2"

if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  echo "::warning::No release keystore secret — $out is signed with the DEBUG key (Play Protect is more likely to block it)."
  cp "$in" "$out"
  exit 0
fi

ks="$RUNNER_TEMP/release.jks"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$ks"
apksigner="$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)apksigner"
"$apksigner" sign \
  --ks "$ks" \
  --ks-pass "pass:$ANDROID_KEYSTORE_PASSWORD" \
  --ks-key-alias "$ANDROID_KEY_ALIAS" \
  --key-pass "pass:$ANDROID_KEY_PASSWORD" \
  --out "$out" "$in"
"$apksigner" verify --print-certs "$out" | head -3
rm -f "$ks"

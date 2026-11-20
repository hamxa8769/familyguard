#!/usr/bin/env python3
"""Writes FamilyGuard's permissions into a generated Flutter AndroidManifest.

Usage: android_manifest.py <AndroidManifest.xml> <child-full|child-lite|parent>

Idempotent: the block between the fg-perms markers is replaced each run, so
the same checkout can build the lite and the full child APK one after another.
Also allows plain http:// (cleartext) for a LAN/dev server.
"""
import re
import sys

BASE = ["android.permission.INTERNET"]
CHILD = BASE + [
    "android.permission.PACKAGE_USAGE_STATS",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.READ_MEDIA_IMAGES",
    'android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32',
]
# SMS / contacts / call log: the permissions Play Protect flags most.
COMMS = [
    "android.permission.READ_CONTACTS",
    "android.permission.READ_SMS",
    "android.permission.READ_CALL_LOG",
]
VARIANTS = {
    "parent": BASE,
    "child-lite": CHILD,
    "child-full": CHILD + COMMS,
}


def main(path: str, variant: str) -> None:
    perms = VARIANTS[variant]
    xml = open(path, encoding="utf-8").read()
    xml = re.sub(r"\s*<!-- fg-perms -->.*?<!-- /fg-perms -->", "", xml, flags=re.S)
    block = "\n    <!-- fg-perms -->\n" + "".join(
        f'    <uses-permission android:name="{p}" />\n' for p in perms
    ) + "    <!-- /fg-perms -->"
    xml = re.sub(r"(<manifest[^>]*>)", r"\1" + block.replace("\\", "\\\\"), xml, count=1)
    if "usesCleartextTraffic" not in xml:
        xml = xml.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
    open(path, "w", encoding="utf-8").write(xml)
    print(f"{path}: {variant} ({len(perms)} permissions)")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[2] not in VARIANTS:
        sys.exit(f"usage: {sys.argv[0]} <manifest> <{'|'.join(VARIANTS)}>")
    main(sys.argv[1], sys.argv[2])

#!/bin/bash
# Builds the AltStore source artifacts:
#   dist/TrueCaller-<ver>.ipa   (ad-hoc signed; AltStore re-signs on-device)
#   dist/icon.png               (app icon)
#   dist/source.json            (AltStore source)
# Set ALTSOURCE_BASE_URL to the public base where dist/* will be hosted,
# otherwise a __HOST__ placeholder is used (publish-source.sh fills it in).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist build

BASE_URL="${ALTSOURCE_BASE_URL:-__HOST__}"

echo "--- building device app ---"
xcodebuild -project TrueCaller.xcodeproj -scheme TrueCaller \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/altstore \
  CODE_SIGNING_ALLOWED=NO build >/dev/null
APP=build/altstore/Build/Products/Release-iphoneos/TrueCaller.app

BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Info.plist")
BUILD=$(plutil -extract CFBundleVersion raw "$APP/Info.plist")
IPA="dist/TrueCaller-${VERSION}.ipa"

echo "bundle=$BUNDLE_ID version=$VERSION build=$BUILD"

echo "--- packaging $IPA ---"
rm -rf /tmp/altipa && mkdir -p /tmp/altipa/Payload
rm -f "$IPA"   # zip appends; ensure a clean archive
cp -R "$APP" /tmp/altipa/Payload/
codesign --force --sign - /tmp/altipa/Payload/TrueCaller.app
( cd /tmp/altipa && zip -qry "$OLDPWD/$IPA" Payload )
SIZE=$(stat -f%z "$IPA")

echo "--- icon ---"
if [ ! -f dist/icon.png ]; then
  swift scripts/gen_icon.swift dist/icon.png
fi

echo "--- writing dist/source.json ---"
IPA_BASENAME=$(basename "$IPA")
python3 - "$BASE_URL" "$IPA_BASENAME" "$SIZE" "$VERSION" "$BUILD" > dist/source.json <<'EOF'
import json, sys
base, ipa, size, ver, build = sys.argv[1:]
src = {
  "name": "Dmytro's Sources",
  "subtitle": "Unofficial Truecaller lookup and contact export",
  "description": "Look up unknown callers against the Truecaller database. Paste the numbers, get names, carrier and spam flags. Review successful results in Apple's new-contact editor and save them to Contacts. Uses your own Truecaller installationId token.",
  "tintColor": "#0F70F5",
  "apps": [
    {
      "name": "TrueCaller Lookup",
      "bundleIdentifier": "com.dmytrostanchiev.truecaller-lookup",
      "developerName": "Dmytro Stanchiev",
      "subtitle": "Look up callers and add contacts",
      "localizedDescription": "Paste or type phone numbers to look them up against the Truecaller database: see the caller's name, location, carrier, spam status and report count. Review successful results in Apple's native new-contact editor and save them to Contacts. Add your Truecaller installationId token in Settings (stored on-device, using Keychain when available). Numbers are looked up one at a time to stay within the API's rate limits.",
      "iconURL": f"{base}/icon.png",
      "tintColor": "#0F70F5",
      "category": "utilities",
      "versions": [
        {
          "version": ver,
          "buildVersion": build,
          "date": "2026-08-13",
          "localizedDescription": "First release: look up callers and add successful results to Contacts using Apple's native editor.",
          "downloadURL": f"{base}/{ipa}",
          "size": int(size),
          "minOSVersion": "17.0"
        }
      ],
      "appPermissions": {
        "entitlements": [],
        "privacy": {}
      }
    }
  ],
  "news": []
}
json.dump(src, sys.stdout, indent=2)
print()
EOF

echo "--- validate ---"
python3 -m json.tool dist/source.json >/dev/null && echo "source.json valid"
echo ""
echo "Artifacts ready in dist/:"
ls -la dist/
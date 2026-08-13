#!/bin/bash
# Builds and installs TrueCaller to a connected iPhone.
# MUST be run from a GUI session (Terminal.app on the Mac), NOT over SSH:
# code signing needs the keychain, and macOS blocks keychain access from
# Background/SSH sessions.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV=$(xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin).get('result', {}).get('devices', [])
conn = [x for x in d if x.get('connectionProperties', {}).get('pairingState') == 'paired']
print(conn[0]['identifier'] if conn else '')
")

if [ -z "$DEV" ]; then
  echo "No connected iPhone found." >&2
  echo "Plug it in, unlock it, accept 'Trust This Computer', then retry." >&2
  exit 1
fi
echo "Device: $DEV"

echo "--- building (signing with your Apple Development identity) ---"
xcodebuild -project TrueCaller.xcodeproj -scheme TrueCaller \
  -destination "id=$DEV" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  build

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*TrueCaller-*/Build/Products/Debug-iphoneos/TrueCaller.app' -type d 2>/dev/null | head -1)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "Could not locate the built app bundle." >&2
  exit 1
fi
echo "App: $APP"

echo "--- installing ---"
xcrun devicectl device install app --device "$DEV" "$APP"

echo ""
echo "Install complete. First launch on the phone:"
echo "  Settings > General > VPN & Device Management > your Apple ID > Trust"
echo "Then open TrueCaller and add your installationId token in the Settings tab."
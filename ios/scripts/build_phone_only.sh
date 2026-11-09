#!/bin/bash
# Build and install a Release app for a physical iPhone without the Watch
# companion. The Watch app needs a watchOS provisioning profile; until Xcode
# can register the watch, embedding it makes iOS reject the whole bundle at
# launch with "invalid code signature / profile not trusted".
#
# Usage:
#   ios/scripts/build_phone_only.sh "Wu-Tang"
#   FITAI_DEVICE="00008120-..." ios/scripts/build_phone_only.sh
#
# Optional environment:
#   FITAI_CONFIGURATION=Release
#   FITAI_DERIVED_DATA=/path/to/derived-data
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS="$ROOT/ios"
DEVICE="${1:-${FITAI_DEVICE:-}}"
CONFIG="${FITAI_CONFIGURATION:-Release}"

if [ -z "$DEVICE" ]; then
  echo "usage: $0 <device-name-or-udid>" >&2
  echo "example: $0 Wu-Tang" >&2
  exit 1
fi

# The Mac can have CommandLineTools selected; prefer the newest full Xcode.
if ! xcodebuild -version >/dev/null 2>&1; then
  XCODE_APP="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$XCODE_APP" ]; then
    export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
  fi
fi
xcodebuild -version >/dev/null

resolve_device() {
  local target="$1"
  if [[ "$target" =~ ^[0-9A-Fa-f]{8}- ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  xcrun devicectl list devices --json-output - 2>/dev/null \
    | python3 -c '
import json
import sys

target = sys.argv[1]
data = json.load(sys.stdin)
for device in data.get("result", {}).get("devices", []):
    properties = device.get("deviceProperties") or {}
    hardware = device.get("hardwareProperties") or {}
    if properties.get("name") == target:
        print(hardware.get("udid") or device.get("identifier", ""))
        break
' "$target"
}

DEVICE_UDID="$(resolve_device "$DEVICE")"
if [ -z "$DEVICE_UDID" ]; then
  echo "device not found: $DEVICE (connect/unlock it first)" >&2
  exit 1
fi
echo "device: $DEVICE ($DEVICE_UDID)"

cd "$IOS"
xcodegen generate

DERIVED="${FITAI_DERIVED_DATA:-$IOS/build/phone-only-derived}"
OUT="$IOS/build/phone-only/FitAI.app"
rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"

xcodebuild \
  -project FitAI.xcodeproj \
  -scheme FitAI \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_ENTITLEMENTS=FitAI/Resources/FitAI-Debug.entitlements \
  -allowProvisioningUpdates \
  build

BUILT="$DERIVED/Build/Products/$CONFIG-iphoneos/FitAI.app"
if [ ! -d "$BUILT" ]; then
  echo "built app not found: $BUILT" >&2
  exit 1
fi

ditto "$BUILT" "$OUT"
rm -rf "$OUT/PlugIns/FitAIWatch.app"

ENTITLEMENTS="$(mktemp -t fitai-entitlements).plist"
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign -d --entitlements :- "$OUT" > "$ENTITLEMENTS" 2>/dev/null

SIGNING_INFO="$(codesign -dv --verbose=4 "$OUT" 2>&1)"
IDENTITY="$(
  awk -F= '/^Authority=/{print $2; exit}' <<< "$SIGNING_INFO"
)"
if [ -z "$IDENTITY" ]; then
  echo "could not read the app signing identity" >&2
  exit 1
fi

codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" \
  --timestamp=none "$OUT"
codesign --verify --deep --strict "$OUT"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$OUT/Info.plist")"
echo "phone-only app: $OUT"
echo "bundle: $BUNDLE_ID"

xcrun devicectl device install app --device "$DEVICE_UDID" "$OUT"
xcrun devicectl device process launch --device "$DEVICE_UDID" \
  --terminate-existing "$BUNDLE_ID"

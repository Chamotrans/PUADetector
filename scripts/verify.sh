#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DESTINATION="${DESTINATION:-}"
INCLUDE_UI_TESTS="${INCLUDE_UI_TESTS:-1}"

if [[ "${REGENERATE_PROJECT:-0}" == "1" ]]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required. Install with: brew install xcodegen" >&2
    exit 127
  fi

  echo "==> Generating Xcode project"
  xcodegen generate
elif [[ ! -d PUADetector.xcodeproj ]]; then
  echo "error: PUADetector.xcodeproj is missing. Run REGENERATE_PROJECT=1 scripts/verify.sh after installing xcodegen." >&2
  exit 1
fi

if [[ -z "$DESTINATION" ]]; then
  echo "==> Selecting an available iPhone simulator"
  DESTINATION="$(DEVELOPER_DIR="$DEVELOPER_DIR" xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin).get("devices", {})
for runtime in sorted(devices.keys(), reverse=True):
    for device in devices[runtime]:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print("platform=iOS Simulator,id=" + device["udid"])
            raise SystemExit
raise SystemExit("error: no available iPhone simulator found")
')"
fi

echo "==> Parsing Swift sources"
swiftc -parse PUADetector/Sources/*.swift

echo "==> Linting privacy manifest"
plutil -lint PUADetector/Resources/PrivacyInfo.xcprivacy

echo "==> Running tests"
echo "Destination: $DESTINATION"
SCHEME="PUADetector"
if [[ "$INCLUDE_UI_TESTS" != "1" ]]; then
  SCHEME="PUADetectorUnitTests"
fi

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild test \
  -project PUADetector.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"

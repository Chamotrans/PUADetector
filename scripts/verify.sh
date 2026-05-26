#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.5}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required. Install with: brew install xcodegen" >&2
  exit 127
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Parsing Swift sources"
swiftc -parse PUADetector/Sources/*.swift

echo "==> Linting privacy manifest"
plutil -lint PUADetector/Resources/PrivacyInfo.xcprivacy

echo "==> Running tests"
DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild test \
  -project PUADetector.xcodeproj \
  -scheme PUADetector \
  -destination "$DESTINATION"

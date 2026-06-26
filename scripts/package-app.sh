#!/usr/bin/env bash
# Build a Release NotchPulse.app and package it as the website's download.
# Usage: scripts/package-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "▶ Generating project…"
( cd "$ROOT" && xcodegen generate >/dev/null )

echo "▶ Building Release…"
xcodebuild -project "$ROOT/NotchPulse.xcodeproj" -scheme NotchPulse \
  -configuration Release build CODE_SIGNING_ALLOWED=NO >/dev/null

APP="$(xcodebuild -project "$ROOT/NotchPulse.xcodeproj" -scheme NotchPulse \
  -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2}')"

OUT="$ROOT/web/public/downloads"
mkdir -p "$OUT"
echo "▶ Zipping $APP"
/usr/bin/ditto -c -k --keepParent "$APP" "$OUT/NotchPulse.zip"

SIZE="$(du -h "$OUT/NotchPulse.zip" | cut -f1)"
echo "✓ Packaged → web/public/downloads/NotchPulse.zip ($SIZE)"
echo "  The website's Download button now serves this build."

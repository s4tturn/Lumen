#!/bin/bash
set -euo pipefail

DEVICE="11CD2D1E-FA1D-5811-ACC7-70E0520714AB"
APP="Lumen.app"
BUNDLE="s4tturn.Lumen"

# Build
xcodebuild build \
  -project Lumen.xcodeproj \
  -scheme Release \
  -destination 'generic/platform=iOS' \
  -quiet

# Resolve app path
APP_PATH=$(
  xcodebuild -project Lumen.xcodeproj -scheme Release \
    -destination 'generic/platform=iOS' -showBuildSettings \
  | grep -m1 'BUILT_PRODUCTS_DIR' \
  | sed 's/.* = //')/"$APP"

# Install and launch
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE"

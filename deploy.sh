#!/bin/bash
set -euo pipefail

# Build
xcodebuild build \
  -project Lumen.xcodeproj \
  -scheme Lumen \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM=NT4KZ9P8FX \
  CODE_SIGN_STYLE=Automatic \
  2>&1

# Get app path
APP_PATH=$(xcodebuild -project Lumen.xcodeproj -scheme Lumen -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR/{print $NF"/Lumen.app"; exit}')

# Install
xcrun devicectl device install app \
  --device 11CD2D1E-FA1D-5811-ACC7-70E0520714AB \
  "$APP_PATH"

# Launch
xcrun devicectl device process launch \
  --device 11CD2D1E-FA1D-5811-ACC7-70E0520714AB \
  s4tturn.Lumen

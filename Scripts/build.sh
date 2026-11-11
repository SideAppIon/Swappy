#!/bin/bash
# Builds a universal (Apple Silicon + Intel) build/Swappy.app with its widget extension.
set -euo pipefail
cd "$(dirname "$0")/.."

# The Xcode project is generated from project.yml; regenerate it when xcodegen is installed.
if command -v xcodegen >/dev/null; then xcodegen generate --quiet; fi
[ -f Resources/AppIcon.icns ] || swift Scripts/make_icon.swift

# Build straight into build/ so macOS sees exactly one copy of the app and its widget.
rm -rf build/Swappy.app
xcodebuild -project Swappy.xcodeproj -scheme Swappy -configuration Release \
  -derivedDataPath .build/xcode ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CONFIGURATION_BUILD_DIR="$PWD/build" -quiet build
rm -rf build/SwappyWidget.appex build/*.dSYM build/*.swiftmodule

APP=build/Swappy.app
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Swappy"))"

# Let macOS discover the widget right away (it happens on its own once the app is in /Applications).
pluginkit -a "$APP/Contents/PlugIns/SwappyWidget.appex" 2>/dev/null || true

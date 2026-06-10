#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_CONFIG_PATH="$ROOT_DIR/.build/swiftpm-config"
SWIFTPM_SECURITY_PATH="$ROOT_DIR/.build/swiftpm-security"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_CACHE_PATH" "$SWIFTPM_CONFIG_PATH" "$SWIFTPM_SECURITY_PATH"

swift build \
  --disable-sandbox \
  --manifest-cache local \
  --cache-path "$SWIFTPM_CACHE_PATH" \
  --config-path "$SWIFTPM_CONFIG_PATH" \
  --security-path "$SWIFTPM_SECURITY_PATH" \
  -c release

APP_DIR="$ROOT_DIR/dist/AwayLock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/AwayLock" "$MACOS_DIR/AwayLock"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/AwayLock"
codesign --force --deep --sign - --timestamp=none "$APP_DIR"

echo "$APP_DIR"

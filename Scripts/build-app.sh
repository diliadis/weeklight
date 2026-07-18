#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST_ARCH="$(uname -m)"
TARGET_TRIPLE="${WEEKLIGHT_TARGET_TRIPLE:-${HOST_ARCH}-apple-macosx14.0}"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
COMPATIBLE_CLT_SDK="$(dirname "$SDK_PATH")/MacOSX15.sdk"
if [[ -z "${SDKROOT:-}" && "$(basename "$SDK_PATH")" == "MacOSX.sdk" && -d "$COMPATIBLE_CLT_SDK" ]]; then
  SDK_PATH="$COMPATIBLE_CLT_SDK"
fi
CACHE_PATH="$PROJECT_DIR/.build/cache"
MODULE_CACHE="$PROJECT_DIR/.build/clang"
APP_PATH="$PROJECT_DIR/dist/Weeklight.app"
ICON_SOURCE="$PROJECT_DIR/Support/AppIcon/WeeklightIcon.png"
ICON_RESOURCE="$PROJECT_DIR/Support/AppIcon/Weeklight.icns"

mkdir -p "$CACHE_PATH" "$MODULE_CACHE" "$PROJECT_DIR/dist"

SDKROOT="$SDK_PATH" CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swift build \
  --configuration release \
  --disable-sandbox \
  --sdk "$SDK_PATH" \
  --triple "$TARGET_TRIPLE" \
  --cache-path "$CACHE_PATH" \
  --scratch-path "$PROJECT_DIR/.build" \
  --manifest-cache local

BINARY_DIRECTORY="$(
  SDKROOT="$SDK_PATH" CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" swift build \
    --configuration release \
    --disable-sandbox \
    --sdk "$SDK_PATH" \
    --triple "$TARGET_TRIPLE" \
    --cache-path "$CACHE_PATH" \
    --scratch-path "$PROJECT_DIR/.build" \
    --manifest-cache local \
    --show-bin-path
)"
BINARY_PATH="$BINARY_DIRECTORY/Weeklight"
if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Weeklight release binary was not produced at $BINARY_PATH" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Weeklight icon source was not found at $ICON_SOURCE" >&2
  exit 1
fi
if [[ ! -f "$ICON_RESOURCE" ]]; then
  echo "Weeklight icon resource was not found at $ICON_RESOURCE" >&2
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/Weeklight"
cp "$PROJECT_DIR/Support/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ICON_RESOURCE" "$APP_PATH/Contents/Resources/Weeklight.icns"

codesign \
  --force \
  --sign - \
  --entitlements "$PROJECT_DIR/Support/Weeklight.entitlements" \
  "$APP_PATH"

echo "Created $APP_PATH"

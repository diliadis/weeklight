#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/Weeklight.app"
RELEASE_DIRECTORY="${WEEKLIGHT_RELEASE_DIR:-$PROJECT_DIR/release}"
RELEASE_LABEL="${1:-}"
RELEASE_ARCH="${2:-$(uname -m)}"

if [[ -z "$RELEASE_LABEL" ]]; then
  echo "Usage: $0 <release-label> [arm64|x86_64]" >&2
  exit 1
fi

if [[ ! "$RELEASE_LABEL" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]]; then
  echo "Release label contains unsupported characters: $RELEASE_LABEL" >&2
  exit 1
fi

case "$RELEASE_ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported release architecture: $RELEASE_ARCH" >&2
    exit 1
    ;;
esac

if [[ ! -d "$APP_PATH" ]]; then
  echo "Application bundle was not found at $APP_PATH; run Scripts/build-app.sh first" >&2
  exit 1
fi

BINARY_PATH="$APP_PATH/Contents/MacOS/Weeklight"
if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Weeklight executable was not found at $BINARY_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_PATH"

BINARY_ARCHITECTURES="$(lipo -archs "$BINARY_PATH")"
if [[ " $BINARY_ARCHITECTURES " != *" $RELEASE_ARCH "* ]]; then
  echo "Expected a $RELEASE_ARCH binary, but found: $BINARY_ARCHITECTURES" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIRECTORY"
ARCHIVE_NAME="Weeklight-${RELEASE_LABEL}-macos-${RELEASE_ARCH}.zip"
ARCHIVE_PATH="$RELEASE_DIRECTORY/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

CHECKSUM="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$CHECKSUM" "$ARCHIVE_NAME" > "$CHECKSUM_PATH"

echo "Created $ARCHIVE_PATH"
echo "Created $CHECKSUM_PATH"

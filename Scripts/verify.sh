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
OUTPUT_PATH="$PROJECT_DIR/.build/weeklight-verification"
MODULE_CACHE="$PROJECT_DIR/.build/clang"

mkdir -p "$PROJECT_DIR/.build" "$MODULE_CACHE"

swiftc \
  -sdk "$SDK_PATH" \
  -target "$TARGET_TRIPLE" \
  -D DEBUG \
  -module-cache-path "$MODULE_CACHE" \
  -parse-as-library \
  "$PROJECT_DIR/Sources/Weeklight/Models/Project.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Models/WeeklyAllocation.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Models/FocusTag.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Models/FocusSession.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Models/TimeEntry.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Persistence/PersistenceFactory.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/WeekMath.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/TrackingMath.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/FocusMetadata.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/TimerNotificationPolicy.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/DurationText.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Domain/TimerActivityState.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Notifications/TimerNotificationScheduling.swift" \
  "$PROJECT_DIR/Sources/Weeklight/Notifications/SystemTimerNotificationScheduler.swift" \
  "$PROJECT_DIR/Sources/Weeklight/System/LaunchAtLoginController.swift" \
  "$PROJECT_DIR/Sources/Weeklight/App/AppModel.swift" \
  "$PROJECT_DIR/Verification/main.swift" \
  -o "$OUTPUT_PATH"

"$OUTPUT_PATH"

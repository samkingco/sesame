#!/bin/bash
set -euo pipefail

DEVICES=(
    "iPhone 17 Pro Max"   # 6.9" (1320x2868) — mandatory for App Store
    "iPhone 17 Pro"       # 6.3" (1206x2622) — optional, distinct size class
    "iPhone 16e"          # 6.1" (1170x2532) — optional, smallest supported
)

SCHEME="SesameScreenshots"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/app/screenshots"

# Clean previous screenshots
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for device in "${DEVICES[@]}"; do
    echo ""
    echo "=== $device ==="
    echo ""

    # Boot simulator (no-op if already booted)
    xcrun simctl boot "$device" 2>/dev/null || true

    # Clean status bar
    xcrun simctl status_bar "$device" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --wifiBars 3 \
        --cellularBars 4 \
        --cellularMode active \
        --dataNetwork wifi

    # Run screenshot tests
    xcodebuild test \
        -project "$PROJECT_DIR/app/Sesame.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$device" \
        -only-testing:"$SCHEME/ScreenshotTests" \
        2>&1 | grep -E "(Test Suite|TEST SUCCEEDED|TEST FAILED|\*\*)" || true

    # Clear status bar override
    xcrun simctl status_bar "$device" clear

    # Shutdown simulator
    xcrun simctl shutdown "$device" 2>/dev/null || true
done

echo ""
echo "=== Screenshots ==="
ls -1 "$OUTPUT_DIR"
echo ""
echo "Done. $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots in screenshots/"

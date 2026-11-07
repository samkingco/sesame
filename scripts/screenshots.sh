#!/bin/bash
set -euo pipefail

DEVICES=(
    "iPhone 17 Pro Max"   # 6.9" (1320x2868) — mandatory for App Store
    "iPhone 17 Pro"       # 6.3" (1206x2622) — optional, distinct size class
    "iPhone 16e"          # 6.1" (1170x2532) — optional, smallest supported
    "iPad Pro 13-inch (M5)" # 13" (2064x2752) — mandatory for App Store iPad
    "iPhone Duo"          # inner (2853x2007) open, outer (1398x2034) closed — "Made for iPhone Duo" badge
)

SCHEME="SesameScreenshots"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/media/appstore"
HINGE_DIR=""
trap '[[ -n "$HINGE_DIR" ]] && rm -rf "$HINGE_DIR"' EXIT

# Folds or opens the iPhone Duo simulator. See scripts/duo-hinge.m.
set_hinge_angle() {
    if [[ -z "$HINGE_DIR" ]]; then
        HINGE_DIR="$(mktemp -d)"
    fi
    HINGE_BIN="$HINGE_DIR/duo-hinge"
    if [[ ! -x "$HINGE_BIN" ]]; then
        xcrun -sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=18.0 -fobjc-arc \
            -framework IOKit -framework Foundation \
            -o "$HINGE_BIN" "$SCRIPT_DIR/duo-hinge.m"
    fi
    xcrun simctl spawn "$1" "$HINGE_BIN" "$2"
    sleep 5 # The fold animation takes up to 5 seconds
}

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

    # Run screenshot tests. iPhone Duo runs once open (inner screen, hinge at 180°)
    # and once closed (outer screen, hinge at 0°).
    hinge_angles=("")
    if [[ "$device" == "iPhone Duo" ]]; then
        hinge_angles=(180 0)
    fi

    for angle in "${hinge_angles[@]}"; do
        if [[ -n "$angle" ]]; then
            set_hinge_angle "$device" "$angle"
        fi

        xcodebuild test \
            -project "$PROJECT_DIR/app/Sesame.xcodeproj" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$device" \
            -only-testing:"$SCHEME/ScreenshotTests" \
            2>&1 | grep -E "(Test Suite|TEST SUCCEEDED|TEST FAILED|\*\*)" || true
    done

    # A pose that did not change writes the other screen's files, so check both sets exist.
    if [[ "$device" == "iPhone Duo" ]]; then
        for prefix in duo-inner duo-outer; do
            if ! compgen -G "$OUTPUT_DIR/$prefix-*.png" >/dev/null; then
                echo "error: no $prefix screenshots. Check that the iPhone Duo opened and closed."
                exit 1
            fi
        done
    fi

    # Clear status bar override
    xcrun simctl status_bar "$device" clear

    # Shutdown simulator
    xcrun simctl shutdown "$device" 2>/dev/null || true
done

echo ""
echo "=== Screenshots ==="
ls -1 "$OUTPUT_DIR"
echo ""
echo "Done. $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots in media/appstore/"

#!/bin/bash
set -euo pipefail

DEVICES=("iPhone 17 Pro")
SCHEME="SesameScreenshots"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/app/videos"

FILTER_DEVICE=""
FILTER_FLOW=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device) FILTER_DEVICE="$2"; shift 2 ;;
        --flow) FILTER_FLOW="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

FLOWS=("testMainFlow:main")

if [[ -n "$FILTER_DEVICE" ]]; then DEVICES=("$FILTER_DEVICE"); fi
if [[ -n "$FILTER_FLOW" ]]; then FLOWS=("$FILTER_FLOW"); fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

timestamp() {
    if command -v gdate &>/dev/null; then
        gdate +%s.%N
    else
        python3 -c 'import time; print(f"{time.time():.6f}")'
    fi
}

for device in "${DEVICES[@]}"; do
    echo "=== $device ==="

    xcrun simctl boot "$device" 2>/dev/null || true
    xcrun simctl status_bar "$device" override \
        --time "9:41" --batteryState charged --batteryLevel 100 \
        --wifiBars 3 --cellularBars 4 --cellularMode active --dataNetwork wifi

    for flow_pair in "${FLOWS[@]}"; do
        TEST_METHOD="${flow_pair%%:*}"
        FLOW_NAME="${flow_pair##*:}"
        RAW="$OUTPUT_DIR/.raw.mov"
        FINAL="$OUTPUT_DIR/${device}-${FLOW_NAME}.mov"
        TIMING="$OUTPUT_DIR/.timing"
        RECORD_START_FILE="$OUTPUT_DIR/.record-start"

        echo "--- $TEST_METHOD ---"

        # Start recording, capture timestamp when active
        READY="$OUTPUT_DIR/.ready"
        rm -f "$READY" "$RECORD_START_FILE"
        xcrun simctl io "$device" recordVideo --codec hevc --force "$RAW" 2> >(
            while IFS= read -r line; do
                echo "$line" >&2
                [[ "$line" == *"Recording started"* ]] && touch "$READY"
            done
        ) &
        PID=$!
        while [[ ! -f "$READY" ]]; do sleep 0.05; done
        RECORD_START=$(timestamp)
        echo "$RECORD_START" > "$RECORD_START_FILE"
        rm -f "$READY"

        echo "  recording started at $RECORD_START"

        # Run test
        xcodebuild test \
            -project "$PROJECT_DIR/app/Sesame.xcodeproj" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$device" \
            -only-testing:"$SCHEME/VideoFlowTests/$TEST_METHOD" \
            2>&1 | grep -E "(TEST SUCCEEDED|TEST FAILED|\*\*)" || true

        # Stop recording
        kill -INT "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true

        # Trim and convert
        if [[ ! -f "$RAW" ]]; then
            echo "ERROR: No raw recording found"
            continue
        fi

        if [[ ! -f "$TIMING" ]]; then
            mv "$RAW" "$OUTPUT_DIR/${device}-${FLOW_NAME}-raw.mov"
            echo "ERROR: Timing file not written — test may have failed"
            echo "  raw video saved for debugging"
            continue
        fi

        # Timing file contains offsets relative to RECORD_START — use directly
        SS=$(jq -r '.start' "$TIMING")
        TO=$(jq -r '.end' "$TIMING")
        DURATION=$(awk "BEGIN { printf \"%.6f\", $TO - $SS }")

        echo "  trim: ${SS}s → ${TO}s (${DURATION}s)"

        # fps=30 first: normalize VFR to CFR so PTS aligns with wall clock time
        # trim: cut on the CFR timeline (frame-accurate, immune to VFR drift)
        # setpts: reset timestamps so output starts at 0
        # -bf 0: no B-frames (avoids QuickTime black frame bug)
        # -tag:v hvc1: Apple-required HEVC tag
        ffmpeg -y -loglevel warning \
            -i "$RAW" \
            -map 0:v:0 -an \
            -vf "fps=30,trim=start=$SS:duration=$DURATION,setpts=PTS-STARTPTS" \
            -c:v hevc_videotoolbox -tag:v hvc1 \
            -bf 0 -g 30 \
            -video_track_timescale 600 \
            -movflags +faststart+negative_cts_offsets \
            -use_editlist 0 \
            "$FINAL"

        # Validate trim produced a reasonable file
        ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FINAL" 2>/dev/null || echo "0")
        if (( $(awk "BEGIN { print ($ACTUAL_DURATION < 1) }") )); then
            echo "ERROR: Trimmed video is ${ACTUAL_DURATION}s — trim likely failed"
            mv "$RAW" "$OUTPUT_DIR/${device}-${FLOW_NAME}-raw.mov"
            continue
        fi

        # 1080p downscale for web
        DOWNSCALED="${FINAL%.mov}-1080p.mp4"
        ffmpeg -y -loglevel warning \
            -i "$FINAL" \
            -vf "scale=1080:-2" \
            -c:v libx264 -crf 20 -pix_fmt yuv420p \
            -bf 0 \
            -movflags +faststart+negative_cts_offsets \
            -use_editlist 0 \
            "$DOWNSCALED"

        mv "$RAW" "$OUTPUT_DIR/${device}-${FLOW_NAME}-raw.mov"
        echo "  trimmed: $FINAL (${ACTUAL_DURATION}s)"
        echo "  downscaled: $DOWNSCALED"

        rm -f "$TIMING" "$RECORD_START_FILE" "$OUTPUT_DIR/.video-date"
    done

    xcrun simctl status_bar "$device" clear
    xcrun simctl shutdown "$device" 2>/dev/null || true
done

echo ""
ls -lh "$OUTPUT_DIR"/*.mov 2>/dev/null

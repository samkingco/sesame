#!/bin/bash
set -euo pipefail

SCHEME="SesameScreenshots"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/media/recipes"
DEVICE="${RECIPE_DEVICE:-iPhone 16}"

usage() {
    echo "Usage: recipe.sh [OPTIONS] [recipe-name ...]"
    echo ""
    echo "Run screenshot recipes and save results to media/recipes/"
    echo ""
    echo "Options:"
    echo "  --all       Run all recipes"
    echo "  --list      List available recipe names"
    echo "  --clean     Remove previous recipe screenshots before running"
    echo "  --device X  Simulator device (default: iPhone 16)"
    echo "  --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  recipe.sh enlarged-code-warning"
    echo "  recipe.sh enlarged-code-fresh enlarged-code-critical"
    echo "  recipe.sh --all"
    echo "  recipe.sh --list"
    echo "  recipe.sh --device 'iPhone 16 Pro' --all"
}

# Convert kebab-case recipe name to test function name
# enlarged-code-fresh → testEnlargedCodeFresh
to_test_name() {
    local recipe="$1"
    # Split on hyphens, capitalize each word, join, prepend "test"
    echo "$recipe" | awk -F'-' '{
        printf "test"
        for(i=1;i<=NF;i++) {
            first=toupper(substr($i,1,1))
            rest=substr($i,2)
            printf "%s%s", first, rest
        }
        print ""
    }'
}

# List all recipe test functions by scanning RecipeTests.swift
list_recipes() {
    grep -oE 'func test[A-Za-z0-9]+\(\)' "$PROJECT_DIR/app/SesameScreenshots/RecipeTests.swift" \
        | sed 's/func test//; s/()//' \
        | perl -pe 's/([A-Z])/-\L$1/g; s/^-//' \
        | sort
}

run_recipes() {
    local only_testing=""
    for arg in "$@"; do
        local test_name
        test_name=$(to_test_name "$arg")
        if [ -n "$only_testing" ]; then
            only_testing="$only_testing -only-testing:$SCHEME/RecipeTests/$test_name"
        else
            only_testing="-only-testing:$SCHEME/RecipeTests/$test_name"
        fi
    done

    # Boot simulator
    xcrun simctl boot "$DEVICE" 2>/dev/null || true

    # Clean status bar
    xcrun simctl status_bar "$DEVICE" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --wifiBars 3 \
        --cellularBars 4 \
        --cellularMode active \
        --dataNetwork wifi

    echo "Running recipes on $DEVICE..."
    echo ""

    # shellcheck disable=SC2086
    xcodebuild test \
        -project "$PROJECT_DIR/app/Sesame.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        $only_testing \
        2>&1 | grep -E "(✔|✘|Test Suite|TEST SUCCEEDED|TEST FAILED|\*\*)" || true

    # Clear status bar override
    xcrun simctl status_bar "$DEVICE" clear

    echo ""
    if [ -d "$OUTPUT_DIR" ]; then
        echo "=== Recipe Screenshots ==="
        ls -1 "$OUTPUT_DIR"
        echo ""
        echo "$(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots in media/recipes/"
    else
        echo "No screenshots generated."
    fi
}

# Parse arguments
CLEAN=false
RUN_ALL=false
RECIPES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            usage
            exit 0
            ;;
        --list)
            list_recipes
            exit 0
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        *)
            RECIPES+=("$1")
            shift
            ;;
    esac
done

if $CLEAN && [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo "Cleaned $OUTPUT_DIR"
fi

if $RUN_ALL; then
    while IFS= read -r recipe; do
        RECIPES+=("$recipe")
    done < <(list_recipes)
    run_recipes "${RECIPES[@]}"
elif [ ${#RECIPES[@]} -gt 0 ]; then
    run_recipes "${RECIPES[@]}"
else
    usage
    exit 1
fi

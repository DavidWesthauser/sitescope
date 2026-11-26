#!/usr/bin/env bash
# Records the ScreenshotTour UI test in several appearance, text-size and device variants (T-012).
# Usage: scripts/screenshots.sh <out-dir> [variant ...]
# Variants: light dark ax-light ax-dark small-light small-dark large-light large-dark (default: all)
# Output: <out-dir>/<variant>/<screen>.png. Each device is reset to light mode and default text size afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$1"
out="$(cd "$1" && pwd)"
shift
variants=(light dark ax-light ax-dark small-light small-dark large-light large-dark)
[[ $# -gt 0 ]] && variants=("$@")
regular="${REGULAR_DEVICE:-iPhone 18 Pro}"
small="${SMALL_DEVICE:-iPhone SE (3rd generation)}"
large="${LARGE_DEVICE:-iPhone 18 Pro Max}"
derived="${DERIVED_DATA:-build/screenshots}"
# Space-separated test names inside ScreenshotTour; TOUR=testAppearanceSetting records the in-app setting.
read -r -a tour <<<"${TOUR:-testEmptyStates testRecoveryScreen testTour}"
only=()
for test in "${tour[@]}"; do only+=("-only-testing:sitescopeUITests/ScreenshotTour/$test"); done

udid() { xcrun simctl list devices available | grep -F "$1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }

xcodebuild -project sitescope.xcodeproj -scheme sitescope -destination "id=$(udid "$regular")" \
    -derivedDataPath "$derived" build-for-testing -quiet

for variant in "${variants[@]}"; do
    case "$variant" in
        small-*) device="$small" ;;
        large-*) device="$large" ;;
        *) device="$regular" ;;
    esac
    case "$variant" in *dark) appearance=dark ;; *) appearance=light ;; esac
    case "$variant" in ax-*) size=accessibility-extra-extra-extra-large ;; *) size=large ;; esac
    id="$(udid "$device")"
    xcrun simctl boot "$id" 2>/dev/null || true
    xcrun simctl bootstatus "$id" >/dev/null
    xcrun simctl ui "$id" appearance "$appearance"
    xcrun simctl ui "$id" content_size "$size"
    xcrun simctl status_bar "$id" override --time 9:41 --batteryState charged --batteryLevel 100 >/dev/null
    [[ -z "${TOUR:-}" ]] && rm -rf "${out:?}/$variant"
    echo "== $variant on $device ($appearance, $size)"
    TEST_RUNNER_SITESCOPE_SCREENSHOT_DIR="$out/$variant" xcodebuild test-without-building \
        -project sitescope.xcodeproj -scheme sitescope -destination "id=$id" -derivedDataPath "$derived" \
        "${only[@]}" -quiet || echo "!! $variant: some tour steps failed"
    xcrun simctl ui "$id" appearance light
    xcrun simctl ui "$id" content_size large
    xcrun simctl status_bar "$id" clear
done
rm -rf "$out"/.seed-*
echo "Screenshots in $out"

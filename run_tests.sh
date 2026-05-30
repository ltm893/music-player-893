#!/usr/bin/env bash
# run_tests.sh — build and run MusicPlayerTests, print a clean summary
# Usage: ./run_tests.sh [simulator name]
# Example: ./run_tests.sh "iPhone 16 Pro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/ios/MusicPlayer/MusicPlayer.xcodeproj"
SCHEME="MusicPlayer"
TEST_TARGET="MusicPlayerTests"
SIMULATOR="${1:-iPhone 16}"
DERIVED_DATA="/tmp/MusicPlayer-DerivedData"
LOG_FILE="/tmp/xcodebuild-test.log"
RESULT_BUNDLE="/tmp/MusicPlayer-TestResults.xcresult"

# ── clean up stale artifacts before anything else ─────────────────────────────
[ -e "$RESULT_BUNDLE" ] && rm -rf "$RESULT_BUNDLE"
[ -e "$LOG_FILE" ]      && rm -f  "$LOG_FILE"

set -uo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

separator() { printf '%s\n' "────────────────────────────────────────────────"; }

# ── check dependencies ─────────────────────────────────────────────────────────
if ! command -v xcodebuild &>/dev/null; then
  echo -e "${RED}error: xcodebuild not found. Install Xcode and try again.${RESET}" >&2
  exit 1
fi

if command -v xcbeautify &>/dev/null; then
  FORMATTER="xcbeautify"
elif command -v xcpretty &>/dev/null; then
  FORMATTER="xcpretty"
else
  FORMATTER="cat"
fi

# ── resolve simulator by device ID ────────────────────────────────────────────
DEST_LINE=$(xcodebuild -showdestinations -scheme "$SCHEME" -project "$PROJECT" 2>/dev/null \
  | grep "platform:iOS Simulator" \
  | grep "arch:arm64" \
  | grep "name:${SIMULATOR} }" \
  | sort -t: -k6 -V \
  | tail -1)

SIM_ID=$(echo "$DEST_LINE" | grep -oE 'id:[A-F0-9-]+' | cut -d: -f2)
SIM_OS=$(echo "$DEST_LINE" | grep -oE 'OS:[0-9]+\.[0-9]+' | cut -d: -f2)

if [ -z "$SIM_ID" ]; then
  echo -e "${RED}error: No simulator found matching '${SIMULATOR}'.${RESET}"
  echo -e "\nAvailable iOS Simulator devices (arm64):\n"
  xcodebuild -showdestinations -scheme "$SCHEME" -project "$PROJECT" 2>/dev/null \
    | grep "platform:iOS Simulator" \
    | grep "arch:arm64" \
    | sed "s/.*name:\(.*\) }/\1/" \
    | sort -u \
    | sed 's/^/  /'
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=${SIM_ID}"

echo ""
echo -e "${BOLD}${CYAN}MusicPlayer Test Runner${RESET}"
separator
echo -e "  Project:    MusicPlayer.xcodeproj"
echo -e "  Scheme:     ${SCHEME}"
echo -e "  Target:     ${TEST_TARGET}"
echo -e "  Simulator:  ${SIMULATOR} (iOS ${SIM_OS}, id: ${SIM_ID})"
echo -e "  Log:        ${LOG_FILE}"
separator
echo ""

START_TIME=$(date +%s)

# ── run tests ──────────────────────────────────────────────────────────────────
set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -only-testing:"$TEST_TARGET" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -enableCodeCoverage NO \
  IPHONEOS_DEPLOYMENT_TARGET="${SIM_OS}" \
  2>&1 | tee "$LOG_FILE" | $FORMATTER
EXIT_CODE="${PIPESTATUS[0]}"
set -e

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# ── parse results ──────────────────────────────────────────────────────────────
# The test suite uses Swift Testing which emits lowercase "Test case '...' passed/failed"
# (vs XCTest's "Test Case '...' passed/failed"). Match both formats.
PASSED=$(grep -ciE "test case .* passed"  "$LOG_FILE" 2>/dev/null || true)
FAILED=$(grep -ciE "test case .* failed"  "$LOG_FILE" 2>/dev/null || true)
SKIPPED=$(grep -ciE "test case .* skipped" "$LOG_FILE" 2>/dev/null || true)

PASSED=$(echo  "${PASSED:-0}"  | tr -d '[:space:]')
FAILED=$(echo  "${FAILED:-0}"  | tr -d '[:space:]')
SKIPPED=$(echo "${SKIPPED:-0}" | tr -d '[:space:]')

TOTAL=$(( PASSED + FAILED + SKIPPED ))

# ── collect failed test names ──────────────────────────────────────────────────
FAILED_LINES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && FAILED_LINES+=("$line")
done < <(grep -iE "test case .* failed" "$LOG_FILE" 2>/dev/null \
  | sed "s/.*[Tt]est [Cc]ase '\(.*\)' failed.*/\1/" || true)

# ── print summary ──────────────────────────────────────────────────────────────
echo ""
separator
echo -e "${BOLD}  Test Summary${RESET}"
separator
printf "  %-12s ${GREEN}%s${RESET}\n"  "Passed:"  "$PASSED"
if [ "$FAILED" -gt 0 ]; then
  printf "  %-12s ${RED}%s${RESET}\n" "Failed:"  "$FAILED"
else
  printf "  %-12s %s\n"               "Failed:"  "$FAILED"
fi
printf "  %-12s %s\n"  "Skipped:"  "$SKIPPED"
printf "  %-12s %s\n"  "Total:"    "$TOTAL"
printf "  %-12s %ds\n" "Duration:" "$ELAPSED"
separator

if [ ${#FAILED_LINES[@]} -gt 0 ]; then
  echo ""
  echo -e "${BOLD}  Failed tests:${RESET}"
  for name in "${FAILED_LINES[@]}"; do
    echo -e "  ${RED}✗${RESET}  $name"
  done
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  echo -e "\n  ${GREEN}${BOLD}✓ All tests passed${RESET}\n"
else
  echo -e "\n  ${RED}${BOLD}✗ Tests failed — see ${LOG_FILE} for full output${RESET}\n"
fi

separator
echo ""
exit "$EXIT_CODE"

#!/usr/bin/env bash
# Run the app's tests from the command line.
#
# Usage:
#   run-tests.sh                      # whole unit test target
#   run-tests.sh Clients/ClientTests  # one suite (or Suite/testName)
#   run-tests.sh --ui                 # UI test target
#   SCHEME=Floor-Prod run-tests.sh    # override the scheme (default: first *-Dev scheme)
#   SIM="iPhone 17 Pro" run-tests.sh  # override the simulator name
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

PROJECT=$(ls -d *.xcodeproj | head -1)
[[ -n "$PROJECT" ]] || { echo "No .xcodeproj found in $(pwd)" >&2; exit 1; }

# Prefer a Dev scheme, else the first scheme named like the project.
# Scheme names can contain spaces ("FloorMobile Dev"), so keep the whole line
# and only strip xcodebuild's leading indentation — never split on $1.
SCHEMES=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | awk '/Schemes:/{f=1;next} f && NF{sub(/^[[:space:]]+/,"");print}')
SCHEME=${SCHEME:-$(echo "$SCHEMES" | grep -E '[- ]Dev$' | head -1)}
SCHEME=${SCHEME:-$(echo "$SCHEMES" | grep -x "${PROJECT%.xcodeproj}" | head -1)}
SCHEME=${SCHEME:-$(echo "$SCHEMES" | head -1)}
[[ -n "$SCHEME" ]] || { echo "No scheme found; set SCHEME=..." >&2; exit 1; }

SIM=${SIM:-$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [0-9]+( Pro| Pro Max| Plus| Air| e)?' | head -1)}
[[ -n "$SIM" ]] || { echo "No available iPhone simulator" >&2; exit 1; }

UNIT_TARGET=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | awk '/Targets:/{f=1;next} /^$/{f=0} f && /Tests$/ && !/UITests$/{print $1; exit}')
UI_TARGET=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | awk '/Targets:/{f=1;next} /^$/{f=0} f && /UITests$/{print $1; exit}')

FILTER="${UNIT_TARGET}"
if [[ "${1:-}" == "--ui" ]]; then
  FILTER="${UI_TARGET}"
elif [[ -n "${1:-}" ]]; then
  FILTER="${UNIT_TARGET}/$1"
fi

echo "▶ $PROJECT · scheme $SCHEME · $SIM · -only-testing:$FILTER"

set +e
OUTPUT=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM" \
  -only-testing:"$FILTER" test 2>&1)
STATUS=$?
set -e

# Keep the useful lines only: compile errors, test results, summary.
echo "$OUTPUT" | grep -E "error:|Test Suite|Test Case|Executed|passed|failed|isn't a member|TEST" | grep -v "^$" | tail -60

if echo "$OUTPUT" | grep -q "isn't a member of the specified test plan or scheme"; then
  cat >&2 <<MSG

✖ The test target is not attached to scheme "$SCHEME".
  Fix in Xcode: Product ▸ Scheme ▸ Edit Scheme… ▸ Test ▸ + add "$FILTER"
  then Manage Schemes… ▸ tick "Shared" so xcodebuild sees it (creates xcshareddata/xcschemes/$SCHEME.xcscheme).
MSG
fi

exit $STATUS

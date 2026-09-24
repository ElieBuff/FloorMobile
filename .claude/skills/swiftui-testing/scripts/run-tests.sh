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

# Resolve a UDID, and take it from xcodebuild's own destination list rather
# than from simctl. Two reasons a name is not enough: with several runtimes
# installed, xcodebuild only matches a name against the newest one — "iPhone 17
# Pro" exists on iOS 26.5 but not on 27.0, so it resolves to nothing and the
# run dies on "Unable to find a device matching the provided destination
# specifier" — and the same name can exist on two runtimes. An id is exact.
DESTINATIONS=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
  | grep 'platform:iOS Simulator' | grep -v 'placeholder')
if [[ -n "${SIM:-}" ]]; then
  CANDIDATES=$(echo "$DESTINATIONS" | grep "name:$SIM }")
  [[ -n "$CANDIDATES" ]] || { echo "No iOS simulator named \"$SIM\" for scheme \"$SCHEME\"" >&2; exit 1; }
else
  CANDIDATES=$(echo "$DESTINATIONS" | grep 'name:iPhone')
  [[ -n "$CANDIDATES" ]] || { echo "No iPhone simulator available for scheme \"$SCHEME\"" >&2; exit 1; }
fi

# Newest runtime wins, first device of that runtime otherwise.
MAX_OS=$(echo "$CANDIDATES" | grep -oE 'OS:[0-9.]+' | cut -d: -f2 | sort -V | tail -1)
CHOSEN=$(echo "$CANDIDATES" | grep "OS:$MAX_OS," | head -1)
SIM_ID=$(echo "$CHOSEN" | sed -E 's/.*id:([0-9A-Fa-f-]+).*/\1/')
SIM=$(echo "$CHOSEN" | sed -E 's/.*name:(.*) \}.*/\1/')
[[ -n "$SIM_ID" ]] || { echo "Could not read a simulator id out of: $CHOSEN" >&2; exit 1; }

UNIT_TARGET=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | awk '/Targets:/{f=1;next} /^$/{f=0} f && /Tests$/ && !/UITests$/{print $1; exit}')
UI_TARGET=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | awk '/Targets:/{f=1;next} /^$/{f=0} f && /UITests$/{print $1; exit}')

FILTER="${UNIT_TARGET}"
if [[ "${1:-}" == "--ui" ]]; then
  FILTER="${UI_TARGET}"
elif [[ -n "${1:-}" ]]; then
  FILTER="${UNIT_TARGET}/$1"
fi

echo "▶ $PROJECT · scheme $SCHEME · $SIM (iOS $MAX_OS) · -only-testing:$FILTER"

set +e
OUTPUT=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=$SIM_ID" \
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

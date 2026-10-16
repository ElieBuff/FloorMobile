#!/usr/bin/env bash
# The cases qa-bash-allowlist.sh must let through (with its "allow" decision) and must refuse (exit 2). Run it after
# any change to the list:
#   bash .claude/hooks/qa-bash-allowlist.test.sh
set -u

hook="$(cd "$(dirname "$0")" && pwd)/qa-bash-allowlist.sh"
passed=0
failed=0

# expect <allow|refuse> <command>: feeds the command to the hook as Claude Code does, and checks its answer.
expect() {
    local expected=$1 command=$2 output code
    output=$(jq -n --arg command "$command" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $command}}' \
        | "$hook" 2>/dev/null)
    code=$?
    if [[ $expected == allow && $code == 0 && $output == *'"permissionDecision":"allow"'* ]] \
        || [[ $expected == refuse && $code == 2 ]]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "FAIL: should $expected (exit $code): $command"
    fi
}

run="xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Dev\" -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/floormobile-qa/DerivedData -resultBundlePath /tmp/floormobile-qa"

# The isolated build and the unit tests.
expect allow "$run/tour1-build.xcresult -quiet build"
expect allow "$run/tour1-tests.xcresult -quiet -only-testing:FloorMobileTests test"
expect allow "$run/tour2-tests.xcresult -quiet -only-testing:FloorMobileTests/ClientWireTests test"
expect allow "$run/tour2-tests.2.xcresult -quiet -only-testing:FloorMobileTests/ClientWireTests -only-testing:FloorMobileTests/ClientServiceTests test"
expect allow "$run/t3.xcresult -quiet '-only-testing:FloorMobileTests/ClientWireTests/pageDecodes()' test"
expect allow "$run/t4.xcresult -quiet -only-testing:'FloorMobileTests/ClientWireTests/decodes(fixture:)' test"
# Reading the results, the repos and the simulators.
expect allow "xcrun xcresulttool get test-results summary --path /tmp/floormobile-qa/tour1-tests.xcresult"
expect allow "xcrun xcresulttool get test-results tests --compact --path /tmp/floormobile-qa/tour1-tests.xcresult"
expect allow "xcrun xcresulttool get build-results --path /tmp/floormobile-qa/tour1-build.xcresult"
expect allow "xcrun xcresulttool get test-results test-details --test-id 'ClientWireTests/pageDecodes()' --path /tmp/floormobile-qa/tour1-tests.xcresult"
expect allow 'git diff 1a2b 3c4d -- FloorMobile/'
expect allow 'git status --porcelain'
expect allow 'git log --oneline -5'
expect allow 'git show HEAD:CLAUDE.md'
expect allow 'git -C ../FloorPlatform diff -- floor/mobile/bff'
expect allow 'git -C ../FloorPlatform show HEAD:floor/packages/types/src/select/client.select.ts'
expect allow 'xcrun simctl list devices available'
expect allow 'xcrun simctl list'
expect allow 'xcodebuild -list -project FloorMobile.xcodeproj'

# The UI tests, or every target (the scheme's test action includes the UI tests).
expect refuse "$run/x.xcresult -quiet -only-testing:FloorMobileUITests test"
expect refuse "$run/x.xcresult -quiet -only-testing:FloorMobileUITests/LoginJourneyTests test"
expect refuse "$run/x.xcresult -quiet test"
# A test function unquoted: the shell would read its parentheses.
expect refuse "$run/x.xcresult -quiet -only-testing:FloorMobileTests/ClientWireTests/pageDecodes() test"
# Another build: clean, archive, another scheme, simulator, DerivedData or bundle place, provisioning.
expect refuse "$run/x.xcresult -quiet clean build"
expect refuse "$run/x.xcresult -quiet build -allowProvisioningUpdates"
expect refuse 'xcodebuild -project FloorMobile.xcodeproj -scheme "FloorMobile Dev" archive'
expect refuse "xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Prod\" -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/floormobile-qa/DerivedData -resultBundlePath /tmp/floormobile-qa/x.xcresult -quiet build"
expect refuse "xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Dev\" -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/floormobile-qa/DerivedData -resultBundlePath /tmp/floormobile-qa/x.xcresult -quiet build"
expect refuse "xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Dev\" -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build"
expect refuse "xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Dev\" -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/floormobile-qa/DerivedData -resultBundlePath FloorMobile/x.xcresult -quiet build"
expect refuse "$run/../../Users/x.xcresult -quiet build"
expect refuse '.claude/skills/swiftui-testing/scripts/run-tests.sh'
# Simulators, results and files changed.
expect refuse 'xcrun simctl erase all'
expect refuse 'xcrun simctl boot 5B72D97F-B4E0-41A6-A142-4BBBC2FE963F'
expect refuse 'xcrun xcresulttool export --path /tmp/floormobile-qa/x.xcresult --output-path /tmp/out'
expect refuse 'xcrun xcresulttool get build-results --path /Users/eliebuff/x.xcresult'
expect refuse 'rm -rf /tmp/floormobile-qa/x.xcresult'
expect refuse 'xcrun swift-format format -i FloorMobile/App/FloorMobileApp.swift'
# Git that writes, in either repo.
expect refuse 'git stash'
expect refuse 'git checkout .'
expect refuse 'git add -A'
expect refuse 'git -C ../FloorPlatform checkout .'
expect refuse 'git -C /tmp diff'
expect refuse 'git diff --output=x'
# Chained, piped, redirected or substituted.
expect refuse "$run/x.xcresult -quiet build && rm -rf FloorMobile"
expect refuse 'git status; touch y'
expect refuse 'git log | sh'
expect refuse 'git log > f'
expect refuse 'git log $(touch y)'
expect refuse $'git status\ntouch y'
# Anything else.
expect refuse 'touch f'
expect refuse 'cd FloorMobile && git status'
expect refuse ''

echo "$passed passed, $failed failed"
[[ $failed == 0 ]]

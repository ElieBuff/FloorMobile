#!/usr/bin/env bash
# The qa-reviewer's shell, reduced to building, testing and reading (.claude/agents/qa-reviewer.md). A PreToolUse hook
# on Bash, declared in that agent's frontmatter, so it applies to that agent alone. A command on the list is allowed
# without asking the user (permissionDecision "allow"; the user's own deny and ask rules still come first); any other
# command is refused (exit 2), with the reason on stderr for the agent. Because an allowed command runs unasked, the
# list only ever grows with commands that write nothing the user owns: an xcodebuild confined to /tmp/floormobile-qa/
# and to the iPhone 17 simulator, a result bundle read, a git read, a simulator listing. A command that cannot be read
# (no jq, no input) is refused. The cases it must allow and refuse: qa-bash-allowlist.test.sh, next to it.
#
# Kept in step with the machine: the simulator name below must exist (`xcrun simctl list devices available`); after an
# Xcode update that drops it, change it here, in the agent and in the test, together.
set -uo pipefail

command=$(jq -r '.tool_input.command // ""' 2>/dev/null) || command=""

allow() {
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
}

refuse() {
    cat >&2 <<EOF
qa-reviewer: refused — $1.
Allowed, one command per call, from the repository root:
  $build_prefix<name>.xcresult -quiet build
  $build_prefix<name>.xcresult -quiet -only-testing:FloorMobileTests[/<Suite>] [...] test
    (a test function, single-quoted: '-only-testing:FloorMobileTests/<Suite>/<test>()'; never FloorMobileUITests)
  xcrun xcresulttool get test-results summary|tests [--compact] --path /tmp/floormobile-qa/<name>.xcresult
  xcrun xcresulttool get test-results test-details --test-id '<Suite>/<test>()' --path /tmp/floormobile-qa/<name>.xcresult
  xcrun xcresulttool get build-results [--compact] --path /tmp/floormobile-qa/<name>.xcresult
  git [-C ../FloorPlatform] diff|show|log|status|ls-files [args]
  xcrun simctl list [devices|runtimes|devicetypes] [available] [-j]
  xcodebuild -list -project FloorMobile.xcodeproj
EOF
    exit 2
}

# The only build the agent may run: the Dev scheme, the iPhone 17 simulator, a DerivedData of its own (never the
# user's Xcode one, which a second build would lock) and a result bundle under /tmp/floormobile-qa/.
build_prefix="xcodebuild -project FloorMobile.xcodeproj -scheme \"FloorMobile Dev\" -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/floormobile-qa/DerivedData -resultBundlePath /tmp/floormobile-qa/"
bundle='[A-Za-z0-9._-]+\.xcresult'
# The unit tests only: FloorMobileUITests signs the simulator's session out and logs in for real. A test function
# carries parentheses, which the shell reads unless they are single-quoted.
suite_filter='FloorMobileTests(/[A-Za-z0-9_]+)?'
any_filter='FloorMobileTests(/[A-Za-z0-9_]+(/[A-Za-z0-9_]+\([A-Za-z0-9_:]*\))?)?'
only_testing="(-only-testing:${suite_filter}|-only-testing:'${any_filter}'|'-only-testing:${any_filter}')"

# One command at a time: nothing chained, piped, redirected or substituted.
case $command in
    *[\;\&\|\<\>\`]* | *'$('* | *$'\n'*)
        refuse "no chaining, pipe, redirection or substitution (; & | < > \` \$( or a new line)"
        ;;
esac
[[ $command == *--output* ]] && refuse "--output writes a file"

if [[ $command == "$build_prefix"* ]]; then
    rest=${command#"$build_prefix"}
    [[ $rest =~ ^${bundle}\ -quiet\ build$ ]] && allow
    [[ $rest =~ ^${bundle}\ -quiet(\ ${only_testing})+\ test$ ]] && allow
    refuse "after the result bundle: -quiet build, or -quiet, one or more -only-testing:FloorMobileTests… and test"
fi
[[ $command == xcodebuild* && $command != "xcodebuild -list -project FloorMobile.xcodeproj" ]] \
    && refuse "xcodebuild runs only as the build above: Dev scheme, iPhone 17, /tmp/floormobile-qa/"

result_path="--path /tmp/floormobile-qa/${bundle}"
[[ $command =~ ^xcrun\ xcresulttool\ get\ (test-results\ (summary|tests)|build-results)(\ --compact)?\ ${result_path}(\ --compact)?$ ]] && allow
[[ $command =~ ^xcrun\ xcresulttool\ get\ test-results\ test-details\ --test-id\ \'[^\']+\'\ ${result_path}$ ]] && allow
[[ $command =~ ^xcrun\ simctl\ list(\ (devices|runtimes|devicetypes))?(\ available)?(\ (-j|--json))?$ ]] && allow
[[ $command == "xcodebuild -list -project FloorMobile.xcodeproj" ]] && allow
[[ $command =~ ^git\ (-C\ \.\./FloorPlatform\ )?(diff|show|log|status|ls-files)(\ .*)?$ ]] && allow

refuse "not on the qa-reviewer's list"

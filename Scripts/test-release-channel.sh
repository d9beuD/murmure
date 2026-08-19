#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
fixture="$script_directory/../Tests/Fixtures/appcast.xml"
validator="$script_directory/validate-release-channel.sh"

"$validator" stable 0.3.3 8 "$fixture"
"$validator" rc 0.4.0-rc.1 9 "$fixture"
"$validator" dev 0.4.0-dev.1 9 "$fixture"

if "$validator" stable 0.3.3 7 "$fixture" >/dev/null 2>&1; then
    print -u2 "Expected a non-monotonic build number to fail."
    exit 1
fi
if "$validator" rc 0.4.0 9 "$fixture" >/dev/null 2>&1; then
    print -u2 "Expected an RC without a prerelease suffix to fail."
    exit 1
fi

print "Release channel validation tests passed."

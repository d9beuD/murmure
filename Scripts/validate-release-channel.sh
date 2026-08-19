#!/bin/zsh

set -euo pipefail

if (( $# != 4 )); then
    print -u2 "Usage: validate-release-channel.sh <stable|rc|dev> <version> <build-number> <appcast>"
    exit 2
fi

channel=$1
version=$2
build_number=$3
appcast=$4

case "$channel" in
    stable)
        [[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 "Stable versions must use x.y.z."; exit 1; }
        ;;
    rc)
        [[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$' ]] || { print -u2 "RC versions must use x.y.z-rc.N."; exit 1; }
        ;;
    dev)
        [[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+-dev\.[0-9]+$' ]] || { print -u2 "Development versions must use x.y.z-dev.N."; exit 1; }
        ;;
    *)
        print -u2 "Unknown update channel: $channel"
        exit 1
        ;;
esac

[[ "$build_number" =~ '^[0-9]+$' ]] || { print -u2 "Build number must be an integer."; exit 1; }
[[ -f "$appcast" ]] || { print -u2 "Appcast does not exist: $appcast"; exit 1; }

max_build=$(
    {
        sed -n 's/.*<sparkle:version>\([0-9][0-9]*\)<\/sparkle:version>.*/\1/p' "$appcast"
        sed -n 's/.*sparkle:version="\([0-9][0-9]*\)".*/\1/p' "$appcast"
    } | sort -n | tail -n 1
)
if [[ -n "$max_build" ]] && (( 10#$build_number <= 10#$max_build )); then
    print -u2 "Build number $build_number must be greater than existing build $max_build."
    exit 1
fi

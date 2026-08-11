#!/bin/zsh

set -euo pipefail

application_path=${1:-}
if [[ -z "$application_path" ]]; then
    print -u2 "Usage: $0 /path/to/Murmure.app"
    exit 64
fi

contents_path="$application_path/Contents"
executable_path="$contents_path/MacOS/Murmure"
sparkle_binary="$contents_path/Frameworks/Sparkle.framework/Versions/B/Sparkle"

[[ -d "$application_path" ]] || { print -u2 "Missing application bundle: $application_path"; exit 1; }
[[ -x "$executable_path" ]] || { print -u2 "Missing executable: $executable_path"; exit 1; }
[[ -x "$sparkle_binary" ]] || { print -u2 "Missing Sparkle framework binary: $sparkle_binary"; exit 1; }

if ! /usr/bin/otool -L "$executable_path" | /usr/bin/grep -Fq '@rpath/Sparkle.framework/Versions/B/Sparkle'; then
    print -u2 "Murmure does not link against Sparkle through @rpath."
    exit 1
fi

if ! /usr/bin/otool -l "$executable_path" | /usr/bin/grep -A3 'cmd LC_RPATH' | /usr/bin/grep -Fq '@executable_path/../Frameworks'; then
    print -u2 "Murmure is missing the Frameworks rpath."
    exit 1
fi

/usr/bin/codesign --verify --deep --strict "$application_path"
print "Verified app bundle: $application_path"

#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_directory=${script_directory:h}
checkout_directory="$repository_directory/.build/checkouts/KeyboardShortcuts"
utilities_path="$checkout_directory/Sources/KeyboardShortcuts/Utilities.swift"
patch_path="$repository_directory/Patches/KeyboardShortcuts-resources.patch"

[[ -f "$utilities_path" ]] || {
    print -u2 "KeyboardShortcuts sources are unavailable at $utilities_path"
    exit 1
}

if /usr/bin/grep -Fq 'KeyboardShortcuts_KeyboardShortcuts' "$utilities_path"; then
    exit 0
fi

/usr/bin/patch --batch --silent --reject-file=/dev/null -d "$checkout_directory" -p0 -i "$patch_path"
/usr/bin/grep -Fq 'KeyboardShortcuts_KeyboardShortcuts' "$utilities_path" || {
    print -u2 "Failed to patch KeyboardShortcuts resource lookup."
    exit 1
}

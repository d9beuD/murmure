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
localization_bundle="$contents_path/Resources/Murmure_Murmure.bundle"
binary_directory="$application_path:h"
raw_resource_bundle="$binary_directory/Murmure_Murmure.bundle"
disabled_resource_bundle="$raw_resource_bundle.integration-disabled"

restore_raw_bundle() {
    if [[ -d "$disabled_resource_bundle" && ! -e "$raw_resource_bundle" ]]; then
        /bin/mv "$disabled_resource_bundle" "$raw_resource_bundle"
    fi
}
trap restore_raw_bundle EXIT

[[ -d "$application_path" ]] || { print -u2 "Missing application bundle: $application_path"; exit 1; }
[[ -x "$executable_path" ]] || { print -u2 "Missing executable: $executable_path"; exit 1; }
[[ -x "$sparkle_binary" ]] || { print -u2 "Missing Sparkle framework binary: $sparkle_binary"; exit 1; }
for localization in en fr-FR; do
    [[ -f "$localization_bundle/$localization.lproj/Localizable.strings" ]] || {
        print -u2 "Missing compiled localization: $localization_bundle/$localization.lproj/Localizable.strings"
        exit 1
    }
done

if ! /usr/bin/otool -L "$executable_path" | /usr/bin/grep -Fq '@rpath/Sparkle.framework/Versions/B/Sparkle'; then
    print -u2 "Murmure does not link against Sparkle through @rpath."
    exit 1
fi

if ! /usr/bin/otool -l "$executable_path" | /usr/bin/grep -A3 'cmd LC_RPATH' | /usr/bin/grep -Fq '@executable_path/../Frameworks'; then
    print -u2 "Murmure is missing the Frameworks rpath."
    exit 1
fi

/usr/bin/codesign --verify --deep --strict "$application_path"

if [[ -d "$raw_resource_bundle" && "$raw_resource_bundle" != "$contents_path/Resources/Murmure_Murmure.bundle" ]]; then
    /bin/mv "$raw_resource_bundle" "$disabled_resource_bundle"
fi

executable_output() {
    "$executable_path" --verify-localization "$1" "${@:2}"
}

assert_output() {
    local mode="$1"
    local expected="$2"
    shift 2
    local actual
    actual="$(executable_output "$mode" "$@")"
    if [[ "$actual" != "$expected" ]]; then
        print -u2 "Unexpected localization output for $mode:"
        print -u2 "$actual"
        print -u2 "Expected:"
        print -u2 "$expected"
        exit 1
    fi
}

assert_output "french" $'locale=fr-FR\nonboarding.welcome.title=Bienvenue dans Murmure\nmenu.settings=Réglages\naction.next=Suivant'
assert_output "english" $'locale=en\nonboarding.welcome.title=Welcome to Murmure\nmenu.settings=Settings\naction.next=Next'
assert_output "automatic" $'locale=fr-FR\nonboarding.welcome.title=Bienvenue dans Murmure\nmenu.settings=Réglages\naction.next=Suivant' \
    -AppleLanguages '(fr-FR)'
assert_output "automatic" $'locale=en\nonboarding.welcome.title=Welcome to Murmure\nmenu.settings=Settings\naction.next=Next' \
    -AppleLanguages '(de-DE)'

print "Verified app bundle: $application_path"

#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_directory=${script_directory:h}

swift build --package-path "$repository_directory"
binary_directory=$(swift build --package-path "$repository_directory" --show-bin-path)
application_path="$binary_directory/Murmure.app"
contents_path="$application_path/Contents"

if [[ "$application_path" != "$binary_directory/Murmure.app" || "$binary_directory" != *"/.build/"* ]]; then
    print -u2 "Unexpected bundle path: $application_path"
    exit 1
fi

if /usr/bin/pgrep -f "$application_path/Contents/MacOS/Murmure" >/dev/null; then
    print -u2 "Murmure is running. Quit it before rebuilding the development app so macOS can retain its permissions."
    exit 1
fi

/bin/rm -rf -- "$application_path"
/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Frameworks" "$contents_path/Resources"
/usr/bin/install -m 755 "$binary_directory/Murmure" "$contents_path/MacOS/Murmure"
/bin/cp "$repository_directory/Configuration/Info.plist" "$contents_path/Info.plist"

sparkle_framework="$binary_directory/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    print -u2 "Missing Sparkle framework: $sparkle_framework"
    exit 1
fi
/usr/bin/ditto "$sparkle_framework" "$contents_path/Frameworks/Sparkle.framework"
/usr/bin/install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$contents_path/MacOS/Murmure"

if ! xcstringstool_path=$(/usr/bin/xcrun --find xcstringstool 2>/dev/null); then
    print -u2 "A full Xcode installation is required to compile Murmure localization catalogs."
    exit 1
fi

localization_bundle="$contents_path/Resources/Murmure_Murmure.bundle"
if [[ ! -d "$binary_directory/Murmure_Murmure.bundle" ]]; then
    print -u2 "Missing Murmure resource bundle: $binary_directory/Murmure_Murmure.bundle"
    exit 1
fi
/usr/bin/ditto "$binary_directory/Murmure_Murmure.bundle" "$localization_bundle"
"$xcstringstool_path" compile "$localization_bundle/Localizable.xcstrings" --output-directory "$localization_bundle"
"$xcstringstool_path" compile "$localization_bundle/InfoPlist.xcstrings" --output-directory "$localization_bundle"

for localization_directory in "$localization_bundle"/*.lproj; do
    [[ -d "$localization_directory" ]] || continue
    localization_name=${localization_directory:t}
    /bin/mkdir -p "$contents_path/Resources/$localization_name"
    if [[ -f "$localization_directory/InfoPlist.strings" ]]; then
        /bin/cp "$localization_directory/InfoPlist.strings" "$contents_path/Resources/$localization_name/InfoPlist.strings"
    fi
done

for required_resource in \
    "$localization_bundle/en.lproj/Localizable.strings" \
    "$localization_bundle/fr-FR.lproj/Localizable.strings" \
    "$contents_path/Resources/fr-FR.lproj/InfoPlist.strings"; do
    [[ -f "$required_resource" ]] || { print -u2 "Missing localized resource: $required_resource"; exit 1; }
done

resource_bundle="$binary_directory/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ -d "$resource_bundle" ]]; then
    /usr/bin/ditto "$resource_bundle" "$contents_path/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
fi

codesign_identity=${MURMURE_CODESIGN_IDENTITY-}
if [[ -z "$codesign_identity" ]]; then
    codesign_identity=$(
        /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
            | /usr/bin/sed -n 's/^[[:space:]]*[0-9][0-9]*) \([0-9A-F][0-9A-F]*\) .*/\1/p' \
            | /usr/bin/sed -n '1p'
    )
fi
if [[ -z "$codesign_identity" ]]; then
    codesign_identity=-
    print "No signing identity found; using an ad hoc signature. Accessibility permission may need to be renewed after rebuilds."
else
    print "Signing development app with stable identity $codesign_identity"
fi

/usr/bin/codesign --force --deep --options runtime --timestamp --sign "$codesign_identity" \
    --entitlements "$repository_directory/Configuration/Murmure.entitlements" \
    "$application_path"
"$repository_directory/Scripts/verify-app-bundle.sh" "$application_path"
if [[ "${MURMURE_SKIP_OPEN:-0}" != "1" ]]; then
    /usr/bin/open "$application_path"
fi

print "Murmure launched from $application_path"

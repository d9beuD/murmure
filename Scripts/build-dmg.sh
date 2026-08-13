#!/bin/zsh

set -euo pipefail

version=${MURMURE_VERSION:-}
build_number=${MURMURE_BUILD_NUMBER:-1}
signing_identity=${MURMURE_SIGNING_IDENTITY:--}

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
    print -u2 "MURMURE_VERSION must use the x.y.z format."
    exit 1
fi

script_directory=${0:A:h}
repository_directory=${script_directory:h}
binary_directory=$(swift build --package-path "$repository_directory" -c release --show-bin-path)
application_path="$binary_directory/Murmure.app"
contents_path="$application_path/Contents"
release_directory="$repository_directory/.build/release-artifacts"
dmg_path="$release_directory/Murmure-$version-macos.dmg"
staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/murmure-release.XXXXXX")

cleanup() {
    /bin/rm -rf -- "$staging_directory"
}
trap cleanup EXIT

if [[ "$application_path" != "$binary_directory/Murmure.app" || "$binary_directory" != *"/.build/"* ]]; then
    print -u2 "Unexpected bundle path: $application_path"
    exit 1
fi

swift build --package-path "$repository_directory" -c release
/bin/rm -rf -- "$application_path"
/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Frameworks" "$contents_path/Resources" "$release_directory" "$staging_directory"
/usr/bin/install -m 755 "$binary_directory/Murmure" "$contents_path/MacOS/Murmure"
/bin/cp "$repository_directory/Configuration/Info.plist" "$contents_path/Info.plist"
/usr/bin/ditto "$repository_directory/Configuration/AppIcon/Murmure.icon" "$contents_path/Resources/Murmure.icon"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$contents_path/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$contents_path/Info.plist"

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

if [[ "$signing_identity" == "-" ]]; then
    /usr/bin/codesign --force --deep --sign - "$application_path"
else
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$signing_identity" \
        --entitlements "$repository_directory/Configuration/Murmure.entitlements" \
        "$application_path"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$application_path"
"$repository_directory/Scripts/verify-app-bundle.sh" "$application_path"

/bin/mv "$application_path" "$staging_directory/Murmure.app"
/bin/ln -s /Applications "$staging_directory/Applications"
/bin/rm -f -- "$dmg_path" "$dmg_path.sha256"
/usr/bin/hdiutil create -volname "Murmure $version" -srcfolder "$staging_directory" -ov -format UDZO "$dmg_path"
dmg_checksum=$(/usr/bin/shasum -a 256 "$dmg_path" | /usr/bin/cut -d ' ' -f 1)

print "DMG: $dmg_path"
print "DMG SHA-256: $dmg_checksum"

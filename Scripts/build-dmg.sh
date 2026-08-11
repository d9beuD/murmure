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
checksum_path="$dmg_path.sha256"
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
/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources" "$release_directory" "$staging_directory"
/usr/bin/install -m 755 "$binary_directory/Murmure" "$contents_path/MacOS/Murmure"
/bin/cp "$repository_directory/Configuration/Info.plist" "$contents_path/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$contents_path/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$contents_path/Info.plist"

resource_bundle="$binary_directory/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ -d "$resource_bundle" ]]; then
    /usr/bin/ditto "$resource_bundle" "$contents_path/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
fi

if [[ "$signing_identity" == "-" ]]; then
    /usr/bin/codesign --force --deep --sign - "$application_path"
else
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$application_path"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$application_path"

/bin/mv "$application_path" "$staging_directory/Murmure.app"
/bin/ln -s /Applications "$staging_directory/Applications"
/bin/rm -f -- "$dmg_path" "$checksum_path"
/usr/bin/hdiutil create -volname "Murmure $version" -srcfolder "$staging_directory" -ov -format UDZO "$dmg_path"
/usr/bin/shasum -a 256 "$dmg_path" > "$checksum_path"

print "DMG: $dmg_path"
print "Checksum: $checksum_path"

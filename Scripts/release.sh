#!/bin/zsh

set -euo pipefail

if [[ -z "${MURMURE_SIGNING_IDENTITY:-}" ]]; then
    print -u2 "Définissez MURMURE_SIGNING_IDENTITY avec votre identité Developer ID Application."
    exit 1
fi

script_directory=${0:A:h}
repository_directory=${script_directory:h}
binary_directory=$(swift build --package-path "$repository_directory" -c release --show-bin-path)
application_path="$binary_directory/Murmure.app"
contents_path="$application_path/Contents"
release_directory="$repository_directory/.build/release-artifacts"
archive_path="$release_directory/Murmure-0.1.0-macos.zip"
checksum_path="$archive_path.sha256"

if [[ "$application_path" != "$binary_directory/Murmure.app" || "$binary_directory" != *"/.build/"* ]]; then
    print -u2 "Chemin de bundle inattendu : $application_path"
    exit 1
fi

swift build --package-path "$repository_directory" -c release
/bin/rm -rf -- "$application_path"
/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources" "$release_directory"
/usr/bin/install -m 755 "$binary_directory/Murmure" "$contents_path/MacOS/Murmure"
/bin/cp "$repository_directory/Configuration/Info.plist" "$contents_path/Info.plist"

resource_bundle="$binary_directory/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ -d "$resource_bundle" ]]; then
    /usr/bin/ditto "$resource_bundle" "$contents_path/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
fi

/usr/bin/codesign --force --deep --options runtime --timestamp --sign "$MURMURE_SIGNING_IDENTITY" "$application_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$application_path"
/usr/bin/ditto -c -k --keepParent "$application_path" "$archive_path"
/usr/bin/shasum -a 256 "$archive_path" > "$checksum_path"

if [[ -n "${MURMURE_NOTARY_PROFILE:-}" ]]; then
    /usr/bin/xcrun notarytool submit "$archive_path" --keychain-profile "$MURMURE_NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$application_path"
    /usr/bin/ditto -c -k --keepParent "$application_path" "$archive_path"
    /usr/bin/shasum -a 256 "$archive_path" > "$checksum_path"
else
    print "Archive signée créée sans notarisation. Définissez MURMURE_NOTARY_PROFILE pour soumettre à notarytool."
fi

print "Archive : $archive_path"
print "Checksum : $checksum_path"

#!/bin/zsh

set -euo pipefail

required_variables=(
    MURMURE_VERSION
    MURMURE_BUILD_NUMBER
    DEVELOPER_ID_CERTIFICATE_BASE64
    DEVELOPER_ID_CERTIFICATE_PASSWORD
    BUILD_KEYCHAIN_PASSWORD
    APP_STORE_CONNECT_KEY_BASE64
    APP_STORE_CONNECT_KEY_ID
    APP_STORE_CONNECT_ISSUER_ID
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${(P)variable:-}" ]]; then
        print -u2 "Required environment variable: $variable"
        exit 1
    fi
done

script_directory=${0:A:h}
repository_directory=${script_directory:h}
info_plist_path="$repository_directory/Configuration/Info.plist"
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/murmure-signing.XXXXXX")
certificate_path="$temporary_directory/developer-id.p12"
keychain_path="$temporary_directory/murmure-signing.keychain-db"
api_key_path="$temporary_directory/AuthKey_$APP_STORE_CONNECT_KEY_ID.p8"
original_keychains=("${(@f)$(security list-keychains -d user | sed 's/^[[:space:]]*"\(.*\)"$/\1/')}")

sparkle_feed_url=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$info_plist_path" 2>/dev/null || true)
sparkle_public_ed_key=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$info_plist_path" 2>/dev/null || true)
if [[ -z "$sparkle_feed_url" || "$sparkle_feed_url" == "https://example.com/murmure/appcast.xml" || "$sparkle_feed_url" != "https://github.com/d9beuD/murmure/releases/latest/download/appcast.xml" ]]; then
    print -u2 "Set SUFeedURL in Configuration/Info.plist to https://github.com/d9beuD/murmure/releases/latest/download/appcast.xml before release. Sparkle appcast feed URL required."
    exit 1
fi
if [[ -z "$sparkle_public_ed_key" || "$sparkle_public_ed_key" == "REPLACE_WITH_SPARKLE_ED25519_PUBLIC_KEY" || "$sparkle_public_ed_key" == "TODO_REPLACE_WITH_PRODUCTION_SPARKLE_ED25519_PUBLIC_KEY_DO_NOT_RELEASE" || "$sparkle_public_ed_key" == TODO_* ]]; then
    print -u2 "Set SUPublicEDKey in Configuration/Info.plist before release. Sparkle EdDSA public key required."
    exit 1
fi

cleanup() {
    security list-keychain -d user -s "${original_keychains[@]}" >/dev/null 2>&1 || true
    security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
    /bin/rm -rf -- "$temporary_directory"
}
trap cleanup EXIT

printf '%s' "$DEVELOPER_ID_CERTIFICATE_BASE64" | /usr/bin/base64 -D > "$certificate_path"
security create-keychain -p "$BUILD_KEYCHAIN_PASSWORD" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$BUILD_KEYCHAIN_PASSWORD" "$keychain_path"
security import "$certificate_path" -k "$keychain_path" -P "$DEVELOPER_ID_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$BUILD_KEYCHAIN_PASSWORD" "$keychain_path"
security list-keychain -d user -s "$keychain_path" "${original_keychains[@]}"

signing_identity=$(security find-identity -v -p codesigning "$keychain_path" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)
if [[ -z "$signing_identity" ]]; then
    print -u2 "The supplied certificate contains no valid Developer ID Application identity."
    exit 1
fi

export MURMURE_SIGNING_IDENTITY="$signing_identity"
"$script_directory/build-dmg.sh"

dmg_path="$repository_directory/.build/release-artifacts/Murmure-$MURMURE_VERSION-macos.dmg"
checksum_path="$dmg_path.sha256"
printf '%s' "$APP_STORE_CONNECT_KEY_BASE64" | /usr/bin/base64 -D > "$api_key_path"

xcrun notarytool submit "$dmg_path" \
    --key "$api_key_path" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
/usr/bin/shasum -a 256 "$dmg_path" > "$checksum_path"

print "Notarized DMG: $dmg_path"
print "Checksum: $checksum_path"
print "Sparkle feed URL: $sparkle_feed_url"
print "Appcast publication: GitHub Actions workflow signs and uploads appcast.xml as a release asset. Do not publish appcast manually."

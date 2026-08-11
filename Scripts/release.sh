#!/bin/zsh

set -euo pipefail

required_variables=(
    MURMURE_VERSION
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
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/murmure-signing.XXXXXX")
certificate_path="$temporary_directory/developer-id.p12"
keychain_path="$temporary_directory/murmure-signing.keychain-db"
api_key_path="$temporary_directory/AuthKey_$APP_STORE_CONNECT_KEY_ID.p8"
original_keychains=("${(@f)$(security list-keychains -d user | sed 's/^[[:space:]]*"\(.*\)"$/\1/')}")

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
export MURMURE_BUILD_NUMBER="${MURMURE_BUILD_NUMBER:-1}"
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

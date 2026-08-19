#!/bin/zsh

set -euo pipefail

: "${ENTREVOIX_VERSION:?ENTREVOIX_VERSION is required}"
: "${ENTREVOIX_CHANNEL:?ENTREVOIX_CHANNEL is required}"
: "${ENTREVOIX_TAG:?ENTREVOIX_TAG is required}"
: "${SPARKLE_BIN_DIRECTORY:?SPARKLE_BIN_DIRECTORY is required}"
: "${SPARKLE_EDDSA_PRIVATE_KEY:?SPARKLE_EDDSA_PRIVATE_KEY is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

case "$ENTREVOIX_CHANNEL" in
    stable)
        [[ "$ENTREVOIX_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 "Stable versions must use x.y.z."; exit 1; }
        channel_args=()
        ;;
    rc)
        [[ "$ENTREVOIX_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$' ]] || { print -u2 "RC versions must use x.y.z-rc.N."; exit 1; }
        channel_args=(--channel rc)
        ;;
    dev)
        [[ "$ENTREVOIX_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+-dev\.[0-9]+$' ]] || { print -u2 "Development versions must use x.y.z-dev.N."; exit 1; }
        channel_args=(--channel dev)
        ;;
    *)
        print -u2 "Unknown update channel: $ENTREVOIX_CHANNEL"
        exit 1
        ;;
esac

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/entrevoix-appcast.XXXXXX")
pages_directory="$temporary_directory/gh-pages"
artifacts_directory="$temporary_directory/artifacts"
private_key_path="$temporary_directory/sparkle_ed25519_private_key"
release_appcast_path="$temporary_directory/release-appcast.xml"
remote_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

cleanup() {
    /bin/rm -rf -- "$temporary_directory"
}
trap cleanup EXIT

/bin/mkdir -p "$pages_directory" "$artifacts_directory"
curl --fail --location --silent --show-error \
    "https://github.com/${GITHUB_REPOSITORY}/releases/download/${ENTREVOIX_TAG}/appcast.xml" \
    -o "$release_appcast_path"
release_build_number=$(
    {
        sed -n 's/.*<sparkle:version>\([0-9][0-9]*\)<\/sparkle:version>.*/\1/p' "$release_appcast_path"
        sed -n 's/.*sparkle:version="\([0-9][0-9]*\)".*/\1/p' "$release_appcast_path"
    } | sort -n | tail -n 1
)
[[ "$release_build_number" =~ '^[0-9]+$' ]] || { print -u2 "The release appcast has no numeric Sparkle build number."; exit 1; }
git -C "$pages_directory" init -q -b gh-pages
git -C "$pages_directory" remote add origin "$remote_url"
if git -C "$pages_directory" fetch -q origin gh-pages; then
    git -C "$pages_directory" reset -q --hard origin/gh-pages
else
    # Bootstrap the Pages feed from the last stable release while the first
    # gh-pages publication is being created.
    curl --fail --location --silent --show-error \
        "https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/appcast.xml" \
        -o "$pages_directory/appcast.xml"
fi

if [[ -f "$pages_directory/appcast.xml" ]]; then
    cp "$pages_directory/appcast.xml" "$artifacts_directory/appcast.xml"

    max_build=$(
        {
            sed -n 's/.*<sparkle:version>\([0-9][0-9]*\)<\/sparkle:version>.*/\1/p' "$pages_directory/appcast.xml"
            sed -n 's/.*sparkle:version="\([0-9][0-9]*\)".*/\1/p' "$pages_directory/appcast.xml"
        } | sort -n | tail -n 1
    )
    if [[ -n "$max_build" ]] && (( 10#$release_build_number <= 10#$max_build )); then
        if (( 10#$release_build_number == 10#$max_build )) && grep -Fq "Entrevoix-${ENTREVOIX_VERSION}-macos.dmg" "$pages_directory/appcast.xml"; then
            print "Sparkle appcast is already current."
            exit 0
        fi
        print -u2 "Build number ${release_build_number} is not greater than the cumulative appcast's latest build ${max_build}."
        exit 1
    fi
fi

curl --fail --location --silent --show-error \
    "https://github.com/${GITHUB_REPOSITORY}/releases/download/${ENTREVOIX_TAG}/Entrevoix-${ENTREVOIX_VERSION}-macos.dmg" \
    -o "$artifacts_directory/Entrevoix-${ENTREVOIX_VERSION}-macos.dmg"

printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" > "$private_key_path"
chmod 600 "$private_key_path"

"$SPARKLE_BIN_DIRECTORY/generate_appcast" \
    --ed-key-file "$private_key_path" \
    "${channel_args[@]}" \
    --maximum-versions 3 \
    --download-url-prefix "https://github.com/${GITHUB_REPOSITORY}/releases/download/${ENTREVOIX_TAG}/" \
    "$artifacts_directory"

cp "$artifacts_directory/appcast.xml" "$pages_directory/appcast.xml"
touch "$pages_directory/.nojekyll"
git -C "$pages_directory" config user.name "github-actions[bot]"
git -C "$pages_directory" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$pages_directory" add appcast.xml .nojekyll
if git -C "$pages_directory" diff --cached --quiet; then
    print "Sparkle appcast is already current."
    exit 0
fi
git -C "$pages_directory" commit -q -m "chore: publish Sparkle appcast for ${ENTREVOIX_VERSION}"
git -C "$pages_directory" push -q origin HEAD:gh-pages
print "Published cumulative Sparkle appcast for ${ENTREVOIX_VERSION} (${ENTREVOIX_CHANNEL})."

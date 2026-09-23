#!/bin/sh
# Seeds the Game Center achievements in App Store Connect from Tools/GameCenterSeed.
#
# Needs an App Store Connect API key with the App Manager role. Keep the .p8 outside this
# repo: it is a credential and .gitignore does not cover it.
#
#   ASC_KEY=/path/to/AuthKey.p8 ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxx-xxxx \
#       Tools/seed-achievements.sh
#
# Re-running is safe: existing achievements are updated in place and finished artwork is
# left alone.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
bundle=${SEED_BUNDLE_ID:-com.quentinvedrenne.scopa}
art=${1:-"$root/Artwork/Achievements"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/seed-achievements" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/GameCenterSeed/main.swift"
"$build/seed-achievements" "$bundle" "$art"

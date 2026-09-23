#!/bin/sh
# Seeds the Game Center achievements in App Store Connect from Tools/GameCenterSeed.
#
# Needs an App Store Connect API key with the App Manager role. Keep the .p8 outside this
# repo. ASC_KEY (its path), ASC_KEY_ID and ASC_ISSUER_ID come from .env, which
# `whisper-secrets pull` writes, or from the environment.
#
# Re-running is safe: existing achievements are updated in place and finished artwork is
# left alone.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
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

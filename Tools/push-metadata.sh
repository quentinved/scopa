#!/bin/sh
# Pushes the App Store listing from Tools/StoreMetadata/copy.swift to App Store Connect.
#
# Needs the same App Store Connect API key as Tools/seed-achievements.sh, read from .env
# (`whisper-secrets pull`) or the environment.
#
# SCOPA_SUPPORT_URL overrides the support link, SCOPA_CONTACT_PHONE adds the review
# contact number. Nothing here submits the app for review.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SCOPA_BUNDLE_ID:-com.quentinvedrenne.scopa}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/push-metadata" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/StoreMetadata/copy.swift" \
    "$root/Tools/StoreMetadata/main.swift"
"$build/push-metadata" "$bundle"

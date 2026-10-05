#!/bin/sh
# Sets up the no-ads purchase in App Store Connect from Tools/NoAdsSeed: the product, its
# names, the €2.99 price, its storefronts, the review screenshot and the promotional image.
#
# Needs the same App Store Connect key as the other store tools (ASC_KEY, ASC_KEY_ID,
# ASC_ISSUER_ID from .env or the environment). Re-running is safe.
#
# The review screenshot must be opaque: a PNG with an alpha channel comes back as
# IMAGE_INCORRECT_DIMENSIONS whatever its size. Artwork/Review/no-ads.png is 1320x2868.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SEED_BUNDLE_ID:-com.quentinvedrenne.scopa}
shot=${1:-"$root/Artwork/Review/no-ads.png"}
promo=${2:-"$root/Artwork/Review/no-ads-promo.png"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/seed-no-ads" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/NoAdsSeed/main.swift"
"$build/seed-no-ads" "$bundle" "$shot" "$promo"

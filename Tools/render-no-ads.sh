#!/bin/sh
# Draws the no-ads purchase's promotional image from Design/NoAdsArtwork.swift into
# Artwork/Review/no-ads-promo.png, 1024 square and opaque, as App Store Connect wants it.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/render-no-ads" \
    "$root/Scopa/Design/NoAdsArtwork.swift" \
    "$root/Tools/NoAdsRenderer/main.swift"
"$build/render-no-ads" 1024 "${1:-$root/Artwork/Review/no-ads-promo.png}"

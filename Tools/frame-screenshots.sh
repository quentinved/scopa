#!/bin/sh
# Captions the raw shots in Artwork/Screenshots and puts each in a device frame, ready for
# the App Store. The captions live in Tools/ScreenshotFramer/captions.swift.
#
#   Tools/frame-screenshots.sh [raw shots] [framed output]
#
# Cheap and needs no simulator: reframe after editing a caption, reshoot only when the app
# itself changed. Tools/push-screenshots.sh uploads the framed set.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
raw=${1:-"$root/Artwork/Screenshots"}
out=${2:-"$root/Artwork/StoreScreenshots"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/frame-screenshots" \
    "$root/Tools/ScreenshotFramer/captions.swift" \
    "$root/Tools/ScreenshotFramer/main.swift"
"$build/frame-screenshots" "$raw" "$out"

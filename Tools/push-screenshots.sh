#!/bin/sh
# Uploads the screenshots in Artwork/Screenshots to App Store Connect.
#
# Take them first with Tools/shoot-screenshots.sh. Needs the same API key as the other
# store tools. Re-running replaces what is there rather than adding to it.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SCOPA_BUNDLE_ID:-com.quentinvedrenne.scopa}
shots=${1:-"$root/Artwork/Screenshots"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/push-screenshots" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/ScreenshotUpload/main.swift"
"$build/push-screenshots" "$bundle" "$shots"

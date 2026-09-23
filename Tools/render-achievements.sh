#!/bin/sh
# Redraws the twelve Game Center badges from Scopa/Design/AchievementArtwork.swift.
#
# Each PNG is named after its App Store Connect achievement id, so uploading is a matter of
# matching names: App Store Connect -> Scopa -> Game Center -> the achievement -> its
# localization -> Choose File.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-"$root/Artwork/Achievements"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/render-achievements" \
    "$root/Scopa/Design/AchievementArtwork.swift" \
    "$root/Tools/AchievementRenderer/main.swift"
"$build/render-achievements" 512 "$out"

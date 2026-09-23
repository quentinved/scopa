#!/bin/sh
# Redraws the app icon from Design/IconArtwork.swift: the light icon, the dark one, and the
# grey one iOS runs the player's tint through. All three land in AppIcon.appiconset.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/render-icon" \
    "$root/Scopa/Design/IconArtwork.swift" \
    "$root/Tools/IconRenderer/main.swift"
icons="$root/Scopa/Assets.xcassets/AppIcon.appiconset"
"$build/render-icon" 1024 "$icons/AppIcon.png" light
"$build/render-icon" 1024 "$icons/AppIcon-Dark.png" dark
"$build/render-icon" 1024 "$icons/AppIcon-Tinted.png" tinted

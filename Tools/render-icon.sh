#!/bin/sh
# Redraws the app icon from Design/IconArtwork.swift: the light icon, the dark one, and the
# grey one iOS runs the player's tint through. All three land in AppIcon.appiconset.
# Then the ranked ladder's icons, one per league from Silver up, each in its own set. Their
# names are listed again in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
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
for finish in silver gold platinum diamond maestro; do
    name="AppIcon-$(printf %s "$finish" | cut -c1 | tr a-z A-Z)$(printf %s "$finish" | cut -c2-)"
    set="$root/Scopa/Assets.xcassets/$name.appiconset"
    mkdir -p "$set"
    "$build/render-icon" 1024 "$set/$name.png" light "$finish"
    cat > "$set/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
done

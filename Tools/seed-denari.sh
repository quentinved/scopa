#!/bin/sh
# Sets up the three bags of denari in App Store Connect from Tools/DenariSeed: consumables,
# their names, the euro prices, every storefront but Belgium and the Netherlands, and the
# review screenshot.
#
# Needs the same App Store Connect key as the other store tools (ASC_KEY, ASC_KEY_ID,
# ASC_ISSUER_ID from .env or the environment). Re-running is safe.
#
# The review screenshot must be opaque, see seed-no-ads.sh. Artwork/Review/denari.png is
# 1320x2868, shot with `SCOPA_SHOT_FULL=1 ./Tools/dev.sh shot … -noGameCenter -denariSheet`
# and flattened to opaque. An uploaded one is kept; `ASC_REPLACE_IMAGES=1` replaces it, for
# when the bags it shows changed.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SEED_BUNDLE_ID:-com.quentinvedrenne.scopa}
shot=${1:-"$root/Artwork/Review/denari.png"}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/seed-denari" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/ASC/Purchase.swift" \
    "$root/Tools/DenariSeed/main.swift"
"$build/seed-denari" "$bundle" "$shot"

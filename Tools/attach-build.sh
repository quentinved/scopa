#!/bin/sh
# Attaches an uploaded build to the iOS version being prepared, waiting for App Store
# Connect to finish processing it first. Never submits for review.
#
#   Tools/attach-build.sh 1.4 6     attach 1.4 (6)
#   Tools/attach-build.sh --status  the versions, their builds and the purchases, read only
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SCOPA_BUNDLE_ID:-com.quentinvedrenne.scopa}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/attach-build" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/ASC/Purchase.swift" \
    "$root/Tools/AttachBuild/main.swift"
"$build/attach-build" "$bundle" "$@"

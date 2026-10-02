#!/bin/sh
# Sets the App Store "What's New" text on the version being prepared, from
# Tools/ReleaseNotes/notes.swift. The version's own string picks the notes, so write an
# entry for it there first.
#
# `--check [version]` prints the notes and their lengths and touches nothing. Otherwise it
# needs the same App Store Connect API key as Tools/push-metadata.sh. Nothing here submits
# the app for review.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/Tools/asc-env.sh"
bundle=${SCOPA_BUNDLE_ID:-com.quentinvedrenne.scopa}
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc -O -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -o "$build/push-release-notes" \
    "$root/Tools/ASC/Client.swift" \
    "$root/Tools/ReleaseNotes/notes.swift" \
    "$root/Tools/ReleaseNotes/main.swift"
if [ "$1" = "--check" ]; then
    "$build/push-release-notes" "$@"
else
    "$build/push-release-notes" "$bundle"
fi

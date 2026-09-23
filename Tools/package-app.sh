#!/usr/bin/env bash
#
# Package Scopa into a distributable artifact.
#
#   ./Tools/package-app.sh                     # dev-signed .ipa (default)
#   ./Tools/package-app.sh --method ad-hoc     # .ipa for registered UDIDs (paid account)
#   ./Tools/package-app.sh --method app-store-connect  # .ipa to upload for TestFlight
#   ./Tools/package-app.sh --method simulator  # .app.zip, drag onto a Simulator
#
# Output lands in dist/.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Scopa.xcodeproj"
SCHEME="Scopa"
CONFIG="Release"
METHOD="development"
TEAM="${DEVELOPMENT_TEAM:-7WBNUC3KR9}"
DIST="dist"
DERIVED="build/package"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) METHOD="$2"; shift 2 ;;
    --team)   TEAM="$2";   shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$DIST"

# On a CI runner there is no Xcode account signed in: with an App Store Connect API key in
# the environment, Xcode signs through the cloud instead. BUILD_NUMBER overrides the
# project's, since every upload to App Store Connect needs a higher one.
AUTH=()
if [[ -n "${ASC_KEY:-}" ]]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY" -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
VERSION=()
[[ -n "${BUILD_NUMBER:-}" ]] && VERSION=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

if [[ "$METHOD" == "simulator" ]]; then
  echo "==> Building for iOS Simulator (unsigned)"
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO | tail -5

  APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name '*.app' -print -quit)
  [[ -n "$APP" ]] || { echo "no .app produced" >&2; exit 1; }
  rm -f "$DIST"/*.app.zip
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$(basename "$APP").zip"
  echo
  echo "==> $DIST/$(basename "$APP").zip"
  echo "    Unzip, then drag the .app onto a running Simulator window."
  exit 0
fi

ARCHIVE="$DERIVED/$SCHEME.xcarchive"
rm -rf "$ARCHIVE"

echo "==> Archiving ($METHOD, team $TEAM)"
xcodebuild archive \
  -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
  DEVELOPMENT_TEAM="$TEAM" ${VERSION[@]+"${VERSION[@]}"} | tail -5

# Xcode 15+ renamed the export methods. The familiar names are kept as aliases.
case "$METHOD" in
  development) EXPORT_METHOD="debugging" ;;
  ad-hoc)      EXPORT_METHOD="release-testing" ;;
  *)           EXPORT_METHOD="$METHOD" ;;
esac

# UserMessagingPlatform, Google's consent SDK, pulled in by AdMob, ships claiming
# `MinimumOSVersion` 100.0. Xcode carries that into the built framework's Info.plist and
# its LC_BUILD_VERSION alike, and App Store Connect rejects the upload with ITMS-90208.
#
# Repaired in the archive rather than in the .xcframework, which is signed by Google and
# fails Xcode's signature check if edited. Both the plist and the load command need
# rewriting: correcting only the plist leaves 100.0 in the binary, which is the form Apple
# rejects. The export re-signs every embedded framework afterwards.
APP="$ARCHIVE/Products/Applications/$SCHEME.app"
APP_MIN=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$APP/Info.plist")

version_of() {  # version_of <binary> <minos|sdk>
  otool -l "$1" | awk -v k="$2" '/LC_BUILD_VERSION/ { f = 1 }
                                 f && $1 == k && !s { print $2; s = 1 }'
}

echo "==> Checking embedded frameworks (the app itself needs iOS $APP_MIN)"
for FRAMEWORK in "$APP"/Frameworks/*.framework; do
  [[ -d "$FRAMEWORK" ]] || continue
  NAME=$(basename "$FRAMEWORK" .framework)
  MIN=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$FRAMEWORK/Info.plist" 2>/dev/null) || continue

  if awk -v a="$MIN" -v b="$APP_MIN" 'BEGIN { exit !(a + 0 > b + 0) }'; then
    echo "    $NAME: claims iOS $MIN, rewriting to $APP_MIN"
    /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $APP_MIN" "$FRAMEWORK/Info.plist"
    SDK=$(version_of "$FRAMEWORK/$NAME" sdk)
    xcrun vtool -set-build-version ios "$APP_MIN" "$SDK" -replace \
      -output "$FRAMEWORK/$NAME.patched" "$FRAMEWORK/$NAME" 2>/dev/null
    mv "$FRAMEWORK/$NAME.patched" "$FRAMEWORK/$NAME"
  fi

  PLIST_MIN=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$FRAMEWORK/Info.plist")
  BINARY_MIN=$(version_of "$FRAMEWORK/$NAME" minos)
  echo "    $NAME: plist $PLIST_MIN, binary $BINARY_MIN"
  for VALUE in "$PLIST_MIN" "$BINARY_MIN"; do
    if awk -v a="$VALUE" -v b="$APP_MIN" 'BEGIN { exit !(a + 0 > b + 0) }'; then
      echo "    ^ above the app's own minimum; Apple rejects that with ITMS-90208" >&2
      exit 1
    fi
  done
done

# A privacy manifest that declares tracking has to name the domains it tracks through, or
# App Store Connect rejects the build with ITMS-91064.
echo "==> Checking privacy manifests"
while IFS= read -r MANIFEST; do
  TRACKING=$(plutil -extract NSPrivacyTracking raw "$MANIFEST" 2>/dev/null) || TRACKING=false
  DOMAINS=$(/usr/libexec/PlistBuddy -c "Print :NSPrivacyTrackingDomains" "$MANIFEST" 2>/dev/null |
    sed '1d;$d' | grep -c '[^[:space:]]') || DOMAINS=0
  echo "    ${MANIFEST#"$APP"/}: tracking $TRACKING, $DOMAINS domain(s)"
  if [[ "$TRACKING" == true && "$DOMAINS" -eq 0 ]]; then
    echo "    ^ tracking is declared with no domains listed; Apple rejects that (ITMS-91064)" >&2
    exit 1
  fi
done < <(find "$APP" -name PrivacyInfo.xcprivacy)

OPTS="$DERIVED/ExportOptions.plist"
cat > "$OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$EXPORT_METHOD</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
PLIST

rm -f "$DIST"/*.ipa
echo "==> Exporting .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$DIST" \
  -exportOptionsPlist "$OPTS" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} | tail -5

echo
ls -lh "$DIST"/*.ipa
case "$METHOD" in
  development)
    echo "    Install: xcrun devicectl device install app --device <udid> $DIST/*.ipa"
    echo "    (or drag onto the device in Xcode > Window > Devices and Simulators)" ;;
  ad-hoc)
    echo "    Hand this file to anyone whose UDID is registered on team $TEAM." ;;
  app-store-connect)
    echo "    Upload: xcrun altool --upload-app -f $DIST/*.ipa -t ios --apiKey ... --apiIssuer ..." ;;
esac

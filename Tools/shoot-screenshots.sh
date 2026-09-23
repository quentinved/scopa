#!/bin/sh
# Takes the App Store screenshots by driving a simulator through the launch flags in
# Scopa/Game/DebugLaunch.swift, so a shot is a real frame of the real app rather than a
# mockup. Debug build only: the flags are compiled out of Release.
#
#   Tools/shoot-screenshots.sh <Scopa.app> "<simulator name>" <output directory> [languages]
#
# Apple wants one 6.9" iPhone set and, because the app runs on iPad, one 13" iPad set. The
# languages default to the three the app speaks, and each one lands in its own subdirectory
# named for the App Store locale it belongs to.
set -e
app=$1
device=$2
out=$3
languages=${4:-"en-US fr-FR it"}
bundle=com.quentinvedrenne.scopa
[ -n "$app" ] && [ -n "$device" ] && [ -n "$out" ] || {
    echo "usage: shoot-screenshots.sh <Scopa.app> <simulator name> <output directory>" >&2
    exit 2
}
mkdir -p "$out"

# Terminating an app that is not running can hang indefinitely on a freshly erased device.
# Nothing downstream cares whether it worked, so it is given ten seconds and then cut loose.
terminate_quietly() {
    xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 &
    pid=$!
    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 10 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    kill -9 "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

case "$device" in
    *iPad*) shopAds=-noAds ;;
    *)      shopAds=-placeholderAds ;;
esac

# Erased first: a tracking prompt left unanswered by an earlier launch stays queued on
# the device and will sit in front of every shot, however the app is launched.
if [ -z "${SCOPA_KEEP_DEVICE:-}" ]; then
    xcrun simctl shutdown "$device" >/dev/null 2>&1 || true
    xcrun simctl erase "$device"
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
fi
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl install "$device" "$app"

# A name already chosen and the walkthrough already seen, so no first-launch sheet stands
# in front of a shot.
xcrun simctl spawn "$device" defaults write "$bundle" playerName -string Quentin
xcrun simctl spawn "$device" defaults write "$bundle" hasSeenRules -bool true

# The status bar Apple's own screenshots use.
xcrun simctl status_bar "$device" override \
    --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() {
    name=$1
    wait_for=$2
    shift 2
    mkdir -p "$out/$locale"
    terminate_quietly
    # -noGameCenter keeps Apple's sign-in sheet off every shot, and the ad flags skip the
    # consent form and the tracking prompt. -AppleLanguages and -AppleLocale are read from
    # the launch arguments, so one install can be shot in every language.
    xcrun simctl launch "$device" "$bundle" \
        -AppleLanguages "($language)" -AppleLocale "$region" \
        -noGameCenter "$@" >/dev/null
    sleep "$wait_for"
    xcrun simctl io "$device" screenshot --type=png "$out/$locale/$name.png" >/dev/null 2>&1
    echo "  $locale/$name.png"
}

for locale in $languages; do
    # The App Store locale and the language the app is launched in are not spelled the same.
    case "$locale" in
        en-US) language=en; region=en_US ;;
        fr-FR) language=fr; region=fr_FR ;;
        it)    language=it; region=it_IT ;;
        *)     language=${locale%%-*}; region=$(echo "$locale" | tr - _) ;;
    esac

    # The order they appear on the product page. $rank plants a league on the chair: a
    # rating belongs to a real account, and a fresh simulator has none.
    rank="-rank 1480 -rankGames 42"
    # Ten seconds: at seven the deal is not finished and the shot is of the lobby. Check
    # what landed, and shoot it again if the bot swept first and left a bare cloth.
    shot 1-table   10 -noAds -quickGame -selectFirst
    # Long enough for the bot to have played and the coach to be explaining your
    # card rather than saying the bot is thinking.
    shot 2-coach   14 -noAds -coach -selectFirst
    # Sixteen seconds: three bots deal themselves in one after another, and under about
    # fifteen a card is still in the air over the cloth.
    shot 3-teams   16 -noAds -startTable -seats 4 -teams -bots 3 -selectFirst
    shot 4-ranked  10 -noAds -online $rank
    shot 5-lobby   11 -noAds $rank
    # On the phone the shop sheet covers the screen and no ad slot shows, so the drawn
    # stand-ins are safe. On an iPad the sheet floats over the lobby and the stand-in
    # banner would show underneath, so that shot takes -noAds instead.
    shot 6-shop    16 $shopAds -shop -denari 2000
    shot 7-rules   13 -noAds -rules
done

terminate_quietly
echo "$out"

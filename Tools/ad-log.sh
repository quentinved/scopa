#!/bin/sh
# Streams what the game says about ads: every request to AdMob and what came back.
#
#   Tools/ad-log.sh                 # the booted simulator (or the one named in $SIM)
#   Tools/ad-log.sh --device        # opens Console.app for the plugged-in iPhone
#   Tools/ad-log.sh --collect NAME  # pulls the last 10 minutes off the phone called NAME
#
# An empty banner strip looks the same whether AdMob had no fill or the units are
# misconfigured, so the log is the only way to tell them apart. `no fill` means the app is
# working and AdMob has nothing to serve yet, usually because the units are new.
#
# Google's SDK logs under com.google.ads, and that is included.
set -e
SUBSYSTEM="com.quentinvedrenne.scopa"
PREDICATE="(subsystem == \"$SUBSYSTEM\" AND category == \"ads\") OR subsystem BEGINSWITH \"com.google\""

case "${1:-}" in
  --device)
    echo "Console.app: pick the iPhone in the sidebar, tick Action > Include Debug Messages,"
    echo "and put this in the search field:   subsystem:$SUBSYSTEM category:ads"
    open -a Console
    ;;
  --collect)
    NAME="${2:?device name, as shown in Finder}"
    OUT="${3:-$HOME/Desktop/scopa-ads-$(date +%H%M).logarchive}"
    echo "Collecting the last 10 minutes from '$NAME' into $OUT (asks for your password)"
    sudo log collect --device-name "$NAME" --last 10m --output "$OUT"
    log show "$OUT" --predicate "$PREDICATE" --info --debug --style compact
    ;;
  *)
    SIM="${SIM:-booted}"
    echo "Streaming from simulator '$SIM'. Ctrl-C to stop."
    xcrun simctl spawn "$SIM" log stream --level debug --style compact --predicate "$PREDICATE"
    ;;
esac

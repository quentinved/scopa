#!/bin/sh
# Streams what the game says about connecting, from a simulator or from a phone.
#
#   Tools/peer-log.sh                 # the booted simulator (or the one named in $SIM)
#   Tools/peer-log.sh --device        # opens Console.app for the plugged-in iPhone
#   Tools/peer-log.sh --collect NAME  # pulls the last 10 minutes off the phone called NAME
#
# The app logs under the subsystem below, categories `multipeer` and `table`. The
# framework's own chatter is included under com.apple.MultipeerConnectivity.
set -e
SUBSYSTEM="com.quentinvedrenne.scopa"
PREDICATE="subsystem == \"$SUBSYSTEM\" OR subsystem == \"com.apple.MultipeerConnectivity\""

case "${1:-}" in
  --device)
    echo "Console.app: pick the iPhone in the sidebar, tick Action > Include Debug Messages,"
    echo "and put this in the search field:   subsystem:$SUBSYSTEM"
    open -a Console
    ;;
  --collect)
    NAME="${2:?device name, as shown in Finder}"
    OUT="${3:-$HOME/Desktop/scopa-$(date +%H%M).logarchive}"
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

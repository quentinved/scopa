#!/bin/bash
# Single entry point for building and driving Scopa from the command line.
#
# Many sessions share one Mac, one simulator and one build cache. Calling
# xcodebuild or simctl directly means N cold builds at once and N sessions
# fighting over the same foreground app. Everything here goes through two
# queues instead: one for the build, one for the simulator.
#
#   ./Tools/dev.sh build                      compile only
#   ./Tools/dev.sh run [app args...]          build, install, launch
#   ./Tools/dev.sh shot <out.png> [delay] [app args...]
#   ./Tools/dev.sh screenshots [languages]    reshoot the App Store sets
#                                             (SCOPA_ONLY="1-table" retakes just those)
#   ./Tools/dev.sh status                     who holds the queues
#   ./Tools/dev.sh boot / shutdown            the pinned simulator
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME=Scopa
BUNDLE_ID=com.quentinvedrenne.scopa
# The pinned phone. SCOPA_DEVICE overrides it to check a layout on another screen —
# an iPad, say. Only one simulator ever runs: boot_device shuts the others down first.
DEVICE=${SCOPA_DEVICE:-E64B2C54-7810-48FC-A20B-2ECF4E0C2EA7}   # iPhone 16 Pro, iOS 18.2
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Scopa-shared-cli"
LOCK_DIR=/tmp/scopa-locks
BUILD_LOCK="$LOCK_DIR/build"
SIM_LOCK="$LOCK_DIR/sim"
LOCK_TIMEOUT=${SCOPA_LOCK_TIMEOUT:-900}

log() { printf '[dev] %s\n' "$*" >&2; }

# Atomic mkdir lock. A holder that died without cleaning up is reaped by its pid.
acquire() {
  local lock="$1" label="$2" waited=0 owner note
  mkdir -p "$LOCK_DIR"
  while ! mkdir "$lock" 2>/dev/null; do
    owner=$(cat "$lock/pid" 2>/dev/null || true)
    if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then
      log "reaping stale $label lock (pid ${owner:-?} gone)"
      rm -rf "$lock"
      continue
    fi
    if [ "$waited" -ge "$LOCK_TIMEOUT" ]; then
      note=$(cat "$lock/what" 2>/dev/null || echo "?")
      log "gave up after ${LOCK_TIMEOUT}s; $label held by pid $owner ($note)"
      exit 75
    fi
    if [ "$((waited % 30))" -eq 0 ]; then
      note=$(cat "$lock/what" 2>/dev/null || echo "?")
      log "waiting for $label lock, held by pid $owner ($note)${waited:+ ${waited}s}"
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo $$ > "$lock/pid"
  printf '%s' "${3:-$label}" > "$lock/what"
  HELD="${HELD:-} $lock"
  trap release_all EXIT INT TERM
}

release_all() {
  local lock
  for lock in ${HELD:-}; do rm -rf "$lock"; done
  HELD=
}

do_build() {
  acquire "$BUILD_LOCK" build "${SCOPA_TASK:-build} @ $(date +%H:%M)"
  log "building into $DERIVED"
  cd "$PROJECT_DIR"
  xcodebuild build \
    -project "$SCHEME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    "$@"
  rm -rf "$BUILD_LOCK"
  HELD=$(printf '%s' "${HELD:-}" | sed "s#$BUILD_LOCK##")
}

app_path() {
  local app="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
  [ -d "$app" ] || { log "no app at $app - run build first"; exit 1; }
  printf '%s' "$app"
}

boot_device() {
  local state other
  # Two simulators on this Mac swap hard, so whatever else is up goes down first. Safe
  # under the sim lock: no other session is driving a simulator while we hold it.
  for other in $(xcrun simctl list devices booted | sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p'); do
    if [ "$other" != "$DEVICE" ]; then
      log "shutting down $other to keep one simulator up"
      xcrun simctl shutdown "$other" 2>/dev/null || true
    fi
  done
  state=$(xcrun simctl list devices | awk -v d="$DEVICE" '$0 ~ d {print}' | sed -n 's/.*(\([A-Za-z]*\)) *$/\1/p')
  if [ "$state" != "Booted" ]; then
    log "booting $DEVICE"
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || sleep 15
  fi
}

do_run() {
  do_build
  acquire "$SIM_LOCK" sim "${SCOPA_TASK:-run} @ $(date +%H:%M)"
  boot_device
  log "installing"
  xcrun simctl install "$DEVICE" "$(app_path)"
  log "launching ${*:-(no args)}"
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" "$@" >/dev/null
}

do_shot() {
  local out="$1"; shift
  local delay="${1:-12}"
  case "$delay" in ''|*[!0-9]*) delay=12 ;; *) shift ;; esac
  do_run "$@"
  log "waiting ${delay}s for the app to settle"
  sleep "$delay"
  xcrun simctl io "$DEVICE" screenshot --type=png "$out" >/dev/null
  sips -Z 1500 "$out" >/dev/null 2>&1 || true
  log "wrote $out"
}

# The App Store sets, shot on iOS 26 because that is what players run: a 6.9" iPhone and
# a 13" iPad, the two sizes the listing requires. Shot into a fresh directory and swapped
# in only when both finish, so a failure halfway leaves the old set whole.
SHOT_PHONE=${SCOPA_SHOT_PHONE:-789020F3-3FA3-43FB-8E97-ACA0B2D6777C}   # iPhone 17 Pro Max, iOS 26.5
SHOT_IPAD=${SCOPA_SHOT_IPAD:-2FF35104-7610-4B05-AEB1-ED863948920A}     # iPad Pro 13-inch (M5), iOS 26.5

do_screenshots() {
  local shots="$PROJECT_DIR/Artwork/Screenshots" fresh pinned="$DEVICE" pair
  fresh="$shots.new"
  do_build
  acquire "$SIM_LOCK" sim "${SCOPA_TASK:-screenshots} @ $(date +%H:%M)"
  rm -rf "$fresh"
  for pair in "iphone-6.9 $SHOT_PHONE" "ipad-13 $SHOT_IPAD"; do
    set -- $pair
    DEVICE=$2
    log "shooting $1 on $DEVICE"
    boot_device
    "$PROJECT_DIR/Tools/shoot-screenshots.sh" "$(app_path)" "$DEVICE" "$fresh/$1" ${LANGUAGES:-}
    xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
  done
  if [ -n "${SCOPA_ONLY:-}" ] && [ -d "$shots" ]; then
    # A retake of a few frames is laid over the set rather than replacing it.
    ditto "$fresh" "$shots"
    rm -rf "$fresh"
  else
    if [ -d "$shots" ]; then
      mv "$shots" "$shots-old-$(date +%Y-%m-%d-%H%M)"
    fi
    mv "$fresh" "$shots"
  fi
  DEVICE=$pinned
  boot_device
  log "wrote $shots"
}

show_status() {
  local lock owner note
  for lock in "$BUILD_LOCK" "$SIM_LOCK"; do
    if [ -d "$lock" ]; then
      owner=$(cat "$lock/pid" 2>/dev/null || echo '?')
      note=$(cat "$lock/what" 2>/dev/null || echo '?')
      if kill -0 "$owner" 2>/dev/null; then
        echo "$(basename "$lock"): HELD by pid $owner ($note)"
      else
        echo "$(basename "$lock"): stale (pid $owner gone), next caller reaps it"
      fi
    else
      echo "$(basename "$lock"): free"
    fi
  done
  echo
  echo "stray builds outside the queue:"
  pgrep -fl 'xcodebuild.*Scopa' | grep -v "$DERIVED" || echo "  none"
  echo
  xcrun simctl list devices booted
}

case "${1:-}" in
  build)    shift; do_build "$@" ;;
  run)      shift; do_run "$@" ;;
  shot)     shift; [ $# -ge 1 ] || { log "usage: dev.sh shot <out.png> [delay] [app args]"; exit 2; }; do_shot "$@" ;;
  screenshots) shift; LANGUAGES="$*" do_screenshots ;;
  status)   show_status ;;
  boot)     acquire "$SIM_LOCK" sim boot; boot_device ;;
  shutdown) xcrun simctl shutdown "$DEVICE" 2>/dev/null || true ;;
  device)   printf '%s\n' "$DEVICE" ;;
  derived)  printf '%s\n' "$DERIVED" ;;
  *) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

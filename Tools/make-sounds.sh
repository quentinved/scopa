#!/bin/sh
# Rebuilds Scopa/Audio/Sounds/ from Tools/SoundForge. Needs python3 with numpy.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
exec python3 "$root/Tools/SoundForge/forge.py" "$@"

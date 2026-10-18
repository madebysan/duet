#!/bin/bash
# Cuts Duet's personal ambient loops from san's downloaded reference recordings.
# Output goes to MixLayer/PersonalSounds/ (git-ignored; copied into the app at build time).
# These recordings are for san's own device only; they are not licensed for App Store distribution.
#
# Usage: scripts/cut-personal-loops.sh [source-folder]   (default ~/Downloads/ambient-references)
# Needs: afconvert (macOS), python3. Takes about a minute.
set -euo pipefail
SRC="${1:-$HOME/Downloads/ambient-references}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/MixLayer/PersonalSounds"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# file-number  id  window-start-seconds  length-seconds   (windows chosen as the calmest stretch; seams snap to quiet moments)
LOOPS="01 steady-rain 360 90
02 porch-rain 470 90
03 rain-on-leaves 380 90
04 gentle-rain 425 90
05 woodland 500 90
06 blackbird 120 120
07 forest-wind 275 90
08 soft-surf 455 120
09 breakers 120 120
10 beach 120 120"

echo "$LOOPS" | while read -r num id start length; do
  src=$(ls "$SRC"/"$num"\ -*.mp3 | head -1)
  afconvert -f WAVE -d LEI16@44100 -c 2 "$src" "$WORK/full.wav"
  python3 -I "$REPO/scripts/cut-loop.py" "$WORK/full.wav" "$WORK/$id.wav" "$start" "$length"
  afconvert -f m4af -d aac -b 160000 "$WORK/$id.wav" "$OUT/$id.m4a"
done

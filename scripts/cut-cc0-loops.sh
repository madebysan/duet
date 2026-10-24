#!/bin/bash
# Cuts Duet's recorded loops from CC0 Freesound recordings (the noise discs are generated, Box breathing is san's own) (sources in MixLayer/Resources/Sounds/CREDITS.md).
# Each loop is up to 10 minutes: the whole recording when shorter, minus a few seconds at each end for the seam.
# Output: MixLayer/Resources/Sounds/<disc>.m4a, 128 kbps AAC, level-matched across discs (-21 dBFS RMS).
#
# Usage: scripts/cut-cc0-loops.sh <source-folder>
#   The folder holds one <freesound-id>.mp3 per disc, at any depth (Freesound's HQ preview or the original).
# Needs: afconvert, afinfo (macOS), python3. Takes several minutes.
set -euo pipefail
SRC="${1:?source folder with the downloaded recordings}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/MixLayer/Resources/Sounds"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MAX=600

# disc  freesound-id
LOOPS="steady-rain 547892
blackbird 188371
forest-wind 715696
soft-surf 417797
creek 637960
coffee-shop 512253"

echo "$LOOPS" | while read -r disc id; do
  src=$(find "$SRC" -name "$id.*" -type f | head -1)
  [ -n "$src" ] || { echo "missing $id ($disc)"; exit 1; }
  afconvert -f WAVE -d LEI16@44100 -c 2 "$src" "$WORK/full.wav"
  dur=$(afinfo "$WORK/full.wav" | awk '/estimated duration/ {print $3}')
  # Skip 4 s at the start; leave room after the end for the 3 s crossfade and seam search.
  length=$(python3 -I -c "import sys; print(min($MAX, float(sys.argv[1]) - 12))" "$dur")
  python3 -I "$REPO/scripts/cut-loop.py" "$WORK/full.wav" "$WORK/$disc.wav" 4 "$length"
  afconvert -f m4af -d aac -b 128000 "$WORK/$disc.wav" "$OUT/$disc.m4a"
done
ls -la "$OUT"/*.m4a

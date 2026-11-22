#!/usr/bin/env bash
# Builds the gbtest runner and SameBoy's open-source boot ROM, then tests Kernel Drop.
# Needs: RGBDS (rgbasm/rgblink) and a SameBoy source checkout (MIT, test-only, never bundled).
#   SAMEBOY=/path/to/SameBoy RGBDS=/path/to/rgbds/ tools/gbtest/run.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
: "${SAMEBOY:?set SAMEBOY to a SameBoy checkout}"
RGBDS="${RGBDS:-}"
out="$root/build/test"
mkdir -p "$out"

# SameBoy's own open-source DMG boot ROM (no Nintendo code).
(cd "$SAMEBOY/BootROMs" && "${RGBDS}rgbasm" -o "$out/dmg_boot.o" dmg_boot.asm \
  && "${RGBDS}rgblink" -x -o "$out/dmg_boot.bin" "$out/dmg_boot.o")

# Test runner linked against SameBoy's core.
gcc -std=gnu11 -O2 -w -DGB_INTERNAL -DGB_DISABLE_DEBUGGER -DGB_DISABLE_CHEATS \
  -DGB_DISABLE_CHEAT_SEARCH -DGB_DISABLE_REWIND -DGB_VERSION='"test"' -D_GNU_SOURCE \
  -I"$SAMEBOY/Core" "$here/gbtest.c" \
  $(ls "$SAMEBOY"/Core/*.c | grep -v -E '/(debugger|sm83_disassembler|symbol_hash|cheats|cheat_search|rewind)\.c$') \
  -lm -o "$out/gbtest"

rom="$root/pocket/kernel-drop/kernel-drop.gb"
# wBootMarker=$C000, wHopTimer=$C004 (see pocket/kernel-drop/src/main.asm)
"$out/gbtest" "$out/dmg_boot.bin" "$rom" 240 \
  "expect:200:C000:42" \
  "expect:200:C004:00" \
  "shot:200:$out/kernel-drop-title.ppm" \
  "press:210:A:3" \
  "expectnot:213:C004:00" \
  "shot:213:$out/kernel-drop-hop.ppm"

python3 "$here/ppm2png.py" "$out/kernel-drop-title.ppm" "$out/kernel-drop-title.png" 3
python3 "$here/ppm2png.py" "$out/kernel-drop-hop.ppm" "$out/kernel-drop-hop.png" 3
echo "Screenshots: $out/*.png"

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
# Memory map: see the "Game state" section in pocket/kernel-drop/src/main.asm
#   C000 boot marker, C004 hop timer, C005 state, C006 cloud X, C007 cloud Y,
#   C008 paused, C009 moisture view, C00C tired timer, C00D drops in the air
"$out/gbtest" "$out/dmg_boot.bin" "$rom" 480 \
  "expect:200:C000:42"  "expect:200:C005:00" \
  "shot:200:$out/kernel-drop-title.ppm" \
  "press:210:A:3"       "expectnot:213:C004:00" \
  "press:240:T:1"       "expect:245:C005:01" \
  "press:250:R:30"      "expectnot:285:C006:48" \
  "press:300:A:2"       "expectnot:303:C00D:00" \
  "shot:306:$out/kernel-drop-rain.ppm" \
  "press:310:U:20"      "expectnot:335:C007:20" \
  "press:340:B:60"      "expectnot:395:C00C:00" \
  "shot:380:$out/kernel-drop-pour.ppm" \
  "press:420:S:1"       "expect:425:C009:01" \
  "press:440:T:1"       "expect:445:C008:01" \
  "shot:450:$out/kernel-drop-pause.ppm" \
  "press:460:T:1"       "expect:465:C008:00"

for name in title rain pour pause; do
  python3 "$here/ppm2png.py" "$out/kernel-drop-$name.ppm" "$out/kernel-drop-$name.png" 3
done
echo "Screenshots: $out/*.png"

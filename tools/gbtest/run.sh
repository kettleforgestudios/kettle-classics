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
  "press:240:T:2"       "expect:245:C005:01" \
  "press:250:R:30"      "expectnot:285:C006:48" \
  "press:300:A:2"       "expectnot:303:C00D:00" \
  "shot:306:$out/kernel-drop-rain.ppm" \
  "press:310:U:20"      "expectnot:335:C007:20" \
  "press:340:B:60"      "expectnot:395:C00C:00" \
  "shot:380:$out/kernel-drop-pour.ppm" \
  "press:420:S:2"       "expect:425:C009:01" \
  "press:440:T:2"       "expect:445:C008:01" \
  "shot:450:$out/kernel-drop-pause.ppm" \
  "press:460:T:2"       "expect:465:C008:00"

# --- Seeds (step 3) ---
#   C020 + 8*n = seed n (state, water, grow, dry, soggy). Seed 3 is under the cloud's start.
#   C038 seed 3 state (0 growing, 1 sprouted, 2 wilted, 3 flooded), C039 seed 3 water
#   C050 round over, C051 seeds sprouted
# Run 2: water seed 3 just right until it sprouts; the others dry out and wilt.
water_presses=""
for f in 250 260 270 280 290 350 410 470 530 590; do water_presses="$water_presses press:$f:A:2"; done
"$out/gbtest" "$out/dmg_boot.bin" "$rom" 900 \
  "press:200:T:2" $water_presses \
  "expectnot:248:C039:10" \
  "press:400:S:2" "shot:500:$out/kernel-drop-seeds.ppm" \
  "expect:300:C06E:00" "expectnot:300:FF26:70" \
  "wav:$out/kernel-drop-sound.wav" \
  "expect:700:C038:01" \
  "expect:820:C050:01" "expect:820:C051:01" "expect:820:C020:02" \
  "shot:820:$out/kernel-drop-result.ppm" \
  "press:840:T:2" "expect:845:C050:00" "expect:845:C038:00"

# Run 3: pour too much on seed 3 until it floods.
"$out/gbtest" "$out/dmg_boot.bin" "$rom" 700 \
  "press:200:T:2" \
  "press:220:D:30" \
  "press:260:B:40" "press:320:B:40" "press:380:B:40" "press:440:B:40" \
  "expect:600:C038:03" "shot:600:$out/kernel-drop-flooded.ppm" \
  "wav:$out/kernel-drop-flood.wav"

for name in title rain pour pause seeds result flooded; do
  python3 "$here/ppm2png.py" "$out/kernel-drop-$name.ppm" "$out/kernel-drop-$name.png" 3
done
echo "Screenshots: $out/*.png"

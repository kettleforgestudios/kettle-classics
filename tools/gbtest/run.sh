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
rm -f "$out"/*.ppm "$out"/*.png

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
sym="$root/pocket/kernel-drop/kernel-drop.sym"

# addr NAME [OFFSET]: a variable's address (hex), looked up in the symbol file
# the linker writes, so the tests keep working when variables move around.
addr() {
  local a
  a=$(awk -v n="$1" '$2 == n { split($1, p, ":"); print p[2] }' "$sym")
  [ -n "$a" ] || { echo "unknown symbol $1" >&2; exit 1; }
  printf '%04X' $(( 16#$a + ${2:-0} ))
}
seed() { addr wSeeds $(( 8 * $1 + ${2:-0} )); }   # seed N, byte OFFSET (0 state, 1 water)
run() { "$out/gbtest" "$out/dmg_boot.bin" "$rom" "$@"; }

# Every run boots to the title; the title is ready by frame 200.
# A Story stage shows its name for 2 seconds; pressing Start skips that.

echo "== Run 1: title, menu, stage intro, cloud and rain controls"
run 600 \
  "expect:200:$(addr wBootMarker):42" "expect:200:$(addr wGameState):00" \
  "shot:200:$out/kernel-drop-title.ppm" \
  "press:210:A:3"   "expectnot:213:$(addr wHopTimer):00" \
  "press:220:D:2"   "expect:225:$(addr wMenu):01" \
  "press:230:U:2"   "expect:235:$(addr wMenu):00" \
  "press:240:T:2"   "expect:245:$(addr wGameState):01" "expectnot:245:$(addr wIntroTimer):00" "expect:245:$(addr wSeedCount):05" \
  "shot:250:$out/kernel-drop-intro.ppm" \
  "expect:365:$(addr wIntroTimer):00" "expectnot:380:$(addr wMusicTimer):00" \
  "press:370:R:30"  "expectnot:405:$(addr wCloudX):48" \
  "press:410:A:2"   "expectnot:413:$(addr wActiveDrops):00" \
  "shot:416:$out/kernel-drop-rain.ppm" \
  "press:420:U:20"  "expectnot:445:$(addr wCloudY):20" \
  "press:450:B:60"  "expectnot:505:$(addr wTiredTimer):00" \
  "shot:490:$out/kernel-drop-pour.ppm" \
  "press:530:S:2"   "expect:535:$(addr wMoistureView):01" \
  "press:550:T:2"   "expect:555:$(addr wPaused):01" \
  "shot:560:$out/kernel-drop-pause.ppm" \
  "press:570:T:2"   "expect:575:$(addr wPaused):00"

echo "== Run 2: water center seed just right until it sprouts; the others wilt"
water_presses=""
for f in 261 271 281 291 301 361 421 481 541 601; do water_presses="$water_presses press:$f:A:2"; done
run 900 \
  "press:200:T:2" "press:210:T:2" $water_presses \
  "expectnot:259:$(seed 2 1):10" \
  "press:411:S:2" "shot:511:$out/kernel-drop-seeds.ppm" \
  "expect:311:$(addr wSfxQueue):00" "expectnot:311:FF26:70" \
  "wav:$out/kernel-drop-sound.wav" \
  "expect:711:$(seed 2):01" \
  "expect:831:$(addr wGameOver):01" "expect:831:$(addr wSprouted):01" \
  "expect:831:$(seed 0):02" "expect:831:$(addr wResult):00" \
  "shot:831:$out/kernel-drop-result.ppm" \
  "press:851:T:2" "expect:856:$(addr wGameOver):00" "expect:856:$(seed 2):00"

echo "== Run 3: pour too much on the center seed until it floods"
run 700 \
  "press:200:T:2" "press:210:T:2" \
  "press:231:D:30" \
  "press:271:B:40" "press:331:B:40" "press:391:B:40" "press:451:B:40" \
  "expect:611:$(seed 2):03" "shot:611:$out/kernel-drop-flooded.ppm" \
  "wav:$out/kernel-drop-flood.wav"

# Jumping ahead: poke "round over, cleared" into memory, then press Start.
skip_to() { # skip_to FRAME STAGE_BEFORE: at FRAME, pretend stage STAGE_BEFORE was cleared
  echo "poke:$1:$(addr wStage):$2 poke:$1:$(addr wResult):01 poke:$1:$(addr wGameOver):01 press:$(( $1 + 5 )):T:2"
}

echo "== Run 4: Story stages with the sun, wind and crows; Kip's stage; the ending"
run 1100 \
  "press:200:T:2" "press:210:T:2" \
  $(skip_to 220 00) \
  "expect:230:$(addr wStage):01" "expect:230:$(addr wSeedCount):06" "expect:230:$(addr wStageFlags):01" \
  "press:240:T:2" "expect:560:$(addr wSunOut):01" "shot:560:$out/kernel-drop-sunny.ppm" \
  $(skip_to 570 01) \
  "expect:580:$(addr wStageFlags):02" "shot:582:$out/kernel-drop-windy-intro.ppm" \
  "press:590:T:2" "expectnot:600:$(addr wWind):00" \
  "press:600:A:2" "shot:612:$out/kernel-drop-windy.ppm" \
  $(skip_to 620 02) \
  "expect:630:$(addr wStageFlags):04" \
  "press:640:T:2" "expect:870:$(addr wCrowState):00" "expectnot:900:$(addr wCrowState):00" \
  "shot:960:$out/kernel-drop-crow.ppm" \
  $(skip_to 1010 04) \
  "expect:1020:$(addr wKipSeed):03" "shot:1022:$out/kernel-drop-kip-stage.ppm" \
  "press:1030:T:2" "shot:1034:$out/kernel-drop-kip-seed.ppm" \
  $(skip_to 1036 05) \
  "expect:1045:$(addr wGameState):02" "shot:1060:$out/kernel-drop-ending.ppm" \
  "press:1070:T:2" "expect:1075:$(addr wGameState):00"

echo "== Run 5: puddles: a soaked seed spills onto its neighbours"
run 420 \
  "press:200:T:2" "press:210:T:2" \
  $(skip_to 220 03) \
  "expect:230:$(addr wStageFlags):09" \
  "press:240:T:2" "press:245:D:30" \
  "press:280:B:40" "press:340:B:40" \
  "expect:410:$(seed 0 1):08" "expectnot:410:$(seed 4 1):08" \
  "shot:410:$out/kernel-drop-puddles.ppm"

echo "== Run 6: Endless mode; game over keeps the high score"
run 320 \
  "press:210:D:2" "press:220:T:2" \
  "expect:225:$(addr wMode):01" "expect:225:$(addr wSeedCount):06" "expect:225:$(addr wStage):00" \
  "press:235:T:2" \
  "poke:245:$(addr wGameOver):01" "poke:245:$(addr wResult):01" "press:250:T:2" \
  "expect:255:$(addr wStage):01" "shot:260:$out/kernel-drop-endless.ppm" \
  "press:265:T:2" \
  "poke:275:$(addr wGameOver):01" "poke:275:$(addr wResult):00" "poke:275:$(addr wScore):12" \
  "press:280:T:2" \
  "expect:285:$(addr wGameState):00" "expect:285:$(addr wHiScore):12" \
  "shot:300:$out/kernel-drop-hiscore.ppm"

echo "== Run 7: Lab mode (hold Select, press Start), every page"
run 450 \
  "press:200:S:40" "press:210:T:2" "expect:215:$(addr wGameState):03" \
  "press:220:AB:20" "shot:230:$out/kernel-drop-lab-buttons.ppm" \
  "press:250:ST:2" "expect:255:$(addr wLabPage):01" \
  "press:260:R:2" "expect:265:$(addr wLabSel):01" \
  "press:270:A:2" "expectnot:275:$(addr wTuneTimer):00" \
  "shot:275:$out/kernel-drop-lab-sound.ppm" \
  "press:290:ST:2" "expect:295:$(addr wLabPage):02" \
  "press:300:A:2" "expect:305:$(addr wLabWindow):01" \
  "press:310:D:20" "shot:335:$out/kernel-drop-lab-sprites.ppm" \
  "press:350:ST:2" "expect:355:$(addr wLabPage):03" \
  "shot:420:$out/kernel-drop-lab-timer.ppm" "expectnot:420:$(addr wLabFrames):00" \
  "press:430:ST:2" "expect:435:$(addr wGameState):00"

echo "== Run 8: three sprouts clear First Rain"
run 225 \
  "press:200:T:2" "press:210:T:2" \
  "poke:220:$(seed 0):01" "poke:220:$(seed 1):01" "poke:220:$(seed 2):01" \
  "poke:220:$(seed 3):02" "poke:220:$(seed 4):02" \
  "poke:220:$(addr wSprouted):03" \
  "expect:225:$(addr wGameOver):01" "expect:225:$(addr wResult):01"

for ppm in "$out"/*.ppm; do
  python3 "$here/ppm2png.py" "$ppm" "${ppm%.ppm}.png" 3
done
echo "Screenshots: $out/*.png"

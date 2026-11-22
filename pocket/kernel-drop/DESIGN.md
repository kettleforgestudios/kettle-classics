# Kernel Drop: design doc (draft)

Original Kettle Forge Studios game for the **Pocket** (Game Boy) system. Chapter 1 of the
kernel's journey (seed → field → harvest → silo → kettle → POP). Working titles and names
are placeholders.

Status: build steps 1-4 done, Nov 22 2026. Playable round: six seeds with thirst gauges,
soil drying, sprout / wilt / flood, moisture numbers (Select), result message, Start to
replay. Tuning (first pass): water 0-63, start 16, drop +4, dries 1 per 20 frames, zone
24-47 for 4 s sprouts, 3 s at zero wilts, 2.5 s above zone floods, 4 of 6 clears.
Next: step 5, sound.
Home: `kettleforgestudios/kettle-classics`, folder `pocket/kernel-drop/`. The built game
is copied into Kernelcade as a bundled original game (allowed by Kernelcade's ROM rule).

## Pitch

A row of seeds sits in the soil at the bottom of the screen. You steer a **rain cloud**
across the top and drop water on them. Every seed needs **just the right amount** of
water: too little and it wilts, too much and it floods and rots. Sprout every seed in the
row to clear the stage. The last stage ends with *your* kernel (Kip) sprouting, which
leads into Chapter 2.

Genre: arcade timing / juggling game. Session: a polished 5-10 minute micro-game first.

## Core loop

1. Seeds appear in the soil row (about 6-8 plots).
2. Each seed shows a **thirst meter** with a target zone.
3. The soil slowly dries, so meters drain over time.
4. You move the cloud and drop water to keep each seed inside its target zone.
5. A seed that stays in its zone long enough **sprouts** (locked in, scores points).
6. Too dry for too long: the seed **wilts** (lost). Overfilled: it **floods/rots** (lost).
7. Sprout every remaining seed to clear the stage. Losing too many seeds ends the run.

## Seeds

| Seed | Needs | Notes |
|---|---|---|
| Kernel (normal) | medium water | the basic seed |
| Thirsty seed | lots of water | drains fast |
| Delicate seed | a little water | floods easily |
| Kip (story seed) | exact amount | final stage of Story mode |

## Stage twists (added gradually)

- **Sun:** soil dries faster while it's out.
- **Wind:** drops drift sideways, so aim ahead.
- **Crows:** swoop down to steal seeds; splash them to scare them off.
- **Puddles:** overflow spreads to the neighbouring plots.

## Controls (uses every button, which doubles as a test)

| Button | Action |
|---|---|
| D-pad left / right | move the cloud |
| D-pad up / down | raise / lower the cloud (higher = wider spread, lower = precise) |
| A | single drop |
| B | hold to pour a big splash (unlimited water, short cooldown after a big pour) |
| Select | toggle "moisture view" (exact numbers on each plot) |
| Start | pause menu |

## Modes

- **Story:** a few short stages introducing each twist, ending with Kip sprouting.
  The ending shows an unlock code for Chapter 2 (Kernelcade-only bonus).
- **Endless:** stages keep coming, score attack.
- **Lab mode (hidden, for testing):** button test (all 8 inputs), sound test (each of the
  4 sound channels), sprite/background/window test screens, timing/frame counter.

## Presentation

- 4-shade palette (original Game Boy look); also runs on Game Boy Color (compatible mode,
  optional small colour touches later).
- Original pixel art only: Kip the kernel, cloud, drops, seeds, sprouts, crows, sun.
- Original chiptune music and sound effects (drip, splash, sprout, wilt).
- Screens: title, stage intro, play, pause, stage clear, game over, ending, Lab mode.

## Technical plan

- **Tools (decided Nov 22 2026): RGBDS assembly** (MIT; already used for Kernelcade's boot
  ROMs). Written with plain-English comments so the owner can learn from it.
- **Cartridge:** plain 32 KB ROM, no mapper (MBC) unless we run out of space. High scores
  in battery-backed RAM can come later (would need an MBC with RAM).
- **Goal (owner, Nov 22 2026): a hardware-accurate ROM, but it does NOT need to run on a
  real Game Boy.** Follow the real hardware's rules so it behaves like a genuine cartridge
  (and is a fair test of Kernelcade's emulation):
  - Only write to VRAM during VBlank/HBlank; turn the LCD off only during VBlank.
  - Use OAM DMA (routine in HRAM) for sprites every frame.
  - No more than 10 sprites per scanline (design the cloud/drops/crows around this).
  - Valid header (title, cartridge type, sizes, header checksum).
- **One build only:** no Nintendo logo in the header (Kernelcade's open-source boot ROM
  doesn't need it), so there's no logo/trademark gray area. A real Game Boy would refuse to
  boot it, and that's fine.
- **Testing:** CI assembles the ROM, then runs it in Kernelcade's SameBoy core headlessly,
  feeds scripted button presses, and saves screenshots. SameBoy is very accurate, so it
  catches code that breaks real-hardware rules.

## Build steps

1. ~~Shared repo + toolchain + "hello" ROM that boots in SameBoy (CI builds it).~~ Done.
2. ~~Title screen and Kip sprite.~~ Done.
3. ~~Cloud movement (D-pad, height) and water drops (A / B).~~ Done.
4. ~~Seeds with thirst meters, drying, sprout / wilt / flood rules.~~ Done.
5. Sound effects and music.
6. Stages and twists (sun, wind, crows, puddles), Story and Endless modes.
7. Lab mode.
8. Polish, then bundle into Kernelcade as the built-in Pocket game.

## Open questions

- ~~Assembly or C?~~ Assembly (RGBDS).
- ~~Cloud water?~~ Unlimited with a short cooldown (keep the first game relaxing).
- Final names: game title, mascot ("Kip" is a placeholder).
- Shared-repo name.

## Shared across all the original games (owner, Nov 22 2026)

- One shared repo, one folder per game (pocket/, pocket-color/, 8-bit/, 16-bit-gen/,
  16-bit/), plus `shared/` for assets and tools.
- Kip stays recognisable on every console: a shared character sheet/style guide, and a
  signature **"voice"**: a short sound motif and a "pop" jingle, re-arranged for each
  console's sound chip (Game Boy pulse/wave/noise, NES, Genesis FM, SNES samples).

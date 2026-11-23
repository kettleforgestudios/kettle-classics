# Kettle Classics

Original games by **Kettle Forge Studios**, one for each system Kernelcade supports.
They follow Kip, a popcorn kernel, from seed to POP. The games tell one loose, connected story in the order below. Each chapter has its own genre and should work on its own. Kip's growth, recurring characters or places, and the consequences of earlier chapters carry the story across systems. The series moves toward more complex consoles, giving later chapters room for broader mechanics and presentation.

| System (Kernelcade label) | Game | Genre | Status |
|---|---|---|---|
| Pocket | *Kernel Drop*: water the seeds just right | arcade / timing | **done** (Story, Endless, Lab; gentler First Rain stage) |
| Pocket Color | [*Seed Room*](pocket-color/seed-room/DESIGN.md) (working title) | one-screen planting puzzle | Alpha 1 |
| 8-Bit | [*Fields of Silk*](8-bit/fields-of-silk/DESIGN.md) | field restoration / territory capture | NES Alpha 1 |
| 16-Bit GEN | *Hull Breach* | shoot-'em-up | planned |
| 16-Bit | *Kettle Pop* (finale) | Mode 7 flyer / 2.5D showcase | planned |
| Pocket 32 (bonus) | caramel-corn sequel | TBD | idea |

Every game is original (code, art, music), uses every button on its system, and has a
hidden Lab mode for testing. The built games are bundled in Kernelcade as built-in games.

## Layout

```
pocket/kernel-drop/   Kernel Drop (Game Boy, RGBDS assembly; art/make_gfx.py turns ASCII art into tiles)
8-bit/fields-of-silk/ Fields of Silk (NES, cc65 + Python-generated tile data)
shared/               Kip's style guide, art and sound shared across games
tools/gbtest/         headless test runner (uses SameBoy, MIT, test-only)
shared/sound/         Kip's motif (his "voice"), reused by every game
```

## Building Kernel Drop

Needs [RGBDS](https://rgbds.gbdev.io) v1.0.4 (MIT).

```
cd pocket/kernel-drop
make RGBDS=/path/to/rgbds/     # -> kernel-drop.gb
```

Test (needs a SameBoy source checkout, used only for testing):

```
SAMEBOY=/path/to/SameBoy RGBDS=/path/to/rgbds/ tools/gbtest/run.sh
```

The ROMs are hardware-accurate (they follow real Game Boy timing rules) but contain **no
Nintendo logo** in the header, so they don't boot on real hardware or with a Nintendo boot
ROM. They run in Kernelcade and in emulators that skip the boot ROM (the default in most).

## License

© 2026 Kettle Forge Studios. All rights reserved for now (license to be decided by the owner).
Build and test tools are not part of this repo: RGBDS (MIT) and SameBoy (MIT) are
downloaded at build/test time.

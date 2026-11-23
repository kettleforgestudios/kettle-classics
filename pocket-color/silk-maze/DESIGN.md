# Fields of Silk

Status: Alpha 2 playable prototype for Pocket Color. Fields of Silk follows Kernel Drop in Kip's seed-to-pop story.

## First field

Kip restores a whole cornfield. Start on healthy corn at the field edge. Anchor silk, cross dry soil, then reconnect to healthy ground. The silk closes and the captured dry patch grows into healthy corn. The new rows are safe ground for the next loop. Keep the whole field, Kip, and the active strand visible at once.

One weevil roams the dry soil. Telegraph its approach with a visible turn toward the strand and a ticking sound. If it cuts exposed silk, return Kip to the anchor, remove the unfinished strand, and lose one of three chances. Earlier growth stays. At zero chances the player can retry the field. At 100% restored, clear the field. Start without a timer.

Prototype decisions to test: for a loop that divides an open patch, keep the side occupied by the weevil dry and restore the other side. If neither side has a weevil, restore the smaller patch. When Kip closes off the last dry space, the weevil retreats and the field can reach 100%. Make the chosen patch clear in play and revisit this rule if the final few tiles are frustrating.

## Power-ups

The first field uses movement, silk capture, reeling back, and the weevil on their own. Revisit optional power-ups after playtesting. A decoy that briefly draws the weevil away from the strand is one idea for later fields.

## Controls

| Button | Purpose |
|---|---|
| D-pad | Move Kip on healthy rows and across dry soil. |
| A | Anchor the silk on healthy ground. Reconnecting closes the loop. |
| B | Reel Kip back along exposed silk and abandon the patch. |
| Select | Toggle a high-contrast view of dry soil, healthy rows, and exposed silk. |
| Start | Pause and show the current field progress. |

## Graphics and sound

Use a 160 × 144 gameplay view. Give restored corn, dry soil, and silk distinct colors and tile shapes. Give the weevil a long snout and distinct roaming, targeting, and biting poses. Animate growth across the captured patch while Kip and the weevil remain responsive. Show percent restored and three chance icons in the HUD. Keep the weevil's approach readable with sound off.

## Alpha playtest

The ROM boots directly to the field. Press A on green ground to start a strand. Hold B to backtrack and Start to toggle pause, or press Start to retry after a loss or clear. The field grows in a row-by-row pass after capture. Alpha 2 adds separate soil, corn, silk, and HUD palettes, a connected silk strand, and a 16 × 8 weevil sprite. The game still uses simple warning tones. Directional animation, stereo sound, Lab mode, and independent hardware verification remain planned.

Build with RGBDS 1.0.4: `make -C pocket-color/silk-maze`.

## Hidden Lab mode

Follow Kernel Drop's title shortcut of holding Select and pressing Start. Use original assets and repeatable inputs.

| Test | Expected result |
|---|---|
| Growth wave | Close a large patch while actors move, the HUD changes, and sound continues. Compare selected reference frames for tile, attribute, palette, and priority errors. Add a dedicated HBlank DMA case and run its transfer at both CPU speeds. |
| Sprite limit | Place eleven eligible sprites on one scanline, with known OAM order. Check which ten appear and confirm normal rendering resumes as the sprites separate. |
| Sound and controls | Display each input, including combinations. Pan a weevil tick left and right and play a growth effect while music continues. |
| Save and rewind | In Kernelcade, save with silk exposed, then cut it with the weevil. Load or rewind and verify the field, strand, actor positions, and chances are restored. Replay the same inputs and compare the outcome. |

Validate the numbered ROM in Kernelcade and an emulator with an independent core. Compare on compatible hardware when there is a way to boot the logo-free cartridge. Keep the first playable milestone to one field and one weevil. Defer any animated harvest sequence until the field plays well and the core tests are repeatable.

# Fields of Silk

The 8-Bit (NES) Alpha 1 remakes the earlier Pocket Color prototype as an original NROM cartridge. The prototype remains in repository history.

Kip restores one open 28 × 24 tile cornfield. Move with the D-pad, press A on green ground to anchor silk, and reconnect to green ground to grow an enclosed patch. Hold B to backtrack along the silk. Select changes the soil contrast. Start pauses or retries after the field is cleared or all three chances are lost.

The weevil patrols for about 2½ seconds after silk is exposed. Its color and warning tone signal the start of pursuit. It then moves toward the first exposed tile at half its patrol pace. If it cuts the silk, Kip returns to the anchor, loses one chance, and keeps finished patches. Restore 100% to clear the field.

Build with cc65 and Python 3: `make -C 8-bit/fields-of-silk`. The output is `fields-of-silk.nes`. It uses a 16 KiB PRG and 8 KiB CHR mapper-0 layout.

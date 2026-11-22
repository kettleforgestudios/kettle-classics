; Game Boy hardware register addresses used by Kernel Drop.
; Written from public documentation (Pan Docs). Only what we need, with plain names.

DEF rP1    EQU $FF00 ; joypad: pick the D-pad or the buttons, then read them
DEF rDIV   EQU $FF04 ; divider: counts up 16384 times a second (Lab timer page shows it)
DEF rIF    EQU $FF0F ; which interrupts are waiting
DEF rNR52  EQU $FF26 ; sound on/off
; Sound channel 1 (square wave with pitch sweep)
DEF rNR10  EQU $FF10 ; sweep: speed, up/down, amount
DEF rNR11  EQU $FF11 ; duty (wave shape) and length
DEF rNR12  EQU $FF12 ; volume envelope: start volume, fade up/down, fade speed
DEF rNR13  EQU $FF13 ; pitch, low 8 bits
DEF rNR14  EQU $FF14 ; pitch, high 3 bits + bit 7 = start the note
; Sound channel 2 (square wave, no sweep)
DEF rNR21  EQU $FF16
DEF rNR22  EQU $FF17
DEF rNR23  EQU $FF18
DEF rNR24  EQU $FF19
; Sound channel 3 (wave: plays the 32 4-bit samples stored in wave memory)
DEF rNR30  EQU $FF1A ; bit 7 = channel's DAC on (off = silent, wave memory can be written)
DEF rNR31  EQU $FF1B ; length
DEF rNR32  EQU $FF1C ; volume: %00 mute, %01 full, %10 half, %11 quarter (bits 6-5)
DEF rNR33  EQU $FF1D ; pitch, low 8 bits
DEF rNR34  EQU $FF1E ; pitch, high 3 bits + bit 7 = start the note
DEF WAVE_RAM EQU $FF30 ; 16 bytes = 32 samples of 4 bits
; Sound channel 4 (noise)
DEF rNR41  EQU $FF20 ; length
DEF rNR42  EQU $FF21 ; volume envelope
DEF rNR43  EQU $FF22 ; noise "pitch" and texture
DEF rNR44  EQU $FF23 ; bit 7 = start
DEF rNR50  EQU $FF24 ; master volume (left/right)
DEF rNR51  EQU $FF25 ; which channels go to the left/right speakers
DEF rLCDC  EQU $FF40 ; screen control (on/off, which layers are shown)
DEF rSTAT  EQU $FF41 ; screen status
DEF rSCY   EQU $FF42 ; background scroll Y
DEF rSCX   EQU $FF43 ; background scroll X
DEF rLY    EQU $FF44 ; which screen line is being drawn right now (0-153)
DEF rDMA   EQU $FF46 ; starts a fast copy of sprite data into the sprite table
DEF rBGP   EQU $FF47 ; background palette (4 shades)
DEF rOBP0  EQU $FF48 ; sprite palette 0
DEF rOBP1  EQU $FF49 ; sprite palette 1
DEF rWY    EQU $FF4A ; window layer: top edge (pixels)
DEF rWX    EQU $FF4B ; window layer: left edge + 7
DEF rIE    EQU $FFFF ; which interrupts are allowed

DEF IEF_VBLANK EQU %00000001 ; the "screen finished drawing" interrupt

; Screen control bits we use
DEF LCDCF_ON     EQU %10000000 ; screen on
DEF LCDCF_WIN9C00 EQU %01000000 ; window layer reads its map from $9C00
DEF LCDCF_WINON  EQU %00100000 ; window layer on
DEF LCDCF_BLK01  EQU %00010000 ; tiles live at $8000 (shared by background and sprites)
DEF LCDCF_OBJON  EQU %00000010 ; sprites on
DEF LCDCF_BGON   EQU %00000001 ; background on

; Sprite flag bits (4th byte of each sprite)
DEF OAMF_PAL1    EQU %00010000 ; use sprite palette 1 instead of 0
DEF OAMF_XFLIP   EQU %00100000 ; mirror the sprite left-right

DEF VRAM_TILES   EQU $8000 ; where tile pictures go
DEF SCRN0        EQU $9800 ; background map: 32x32 tiles, each byte = which tile to show
DEF SCRN1        EQU $9C00 ; second background map (we use it for the window layer)
DEF SCRN_VY      EQU 32    ; the background map is 32 tiles wide

; Joypad bits after ReadJoypad (1 = pressed)
DEF PADB_A      EQU 0
DEF PADB_B      EQU 1
DEF PADB_SELECT EQU 2
DEF PADB_START  EQU 3
DEF PADB_RIGHT  EQU 4
DEF PADB_LEFT   EQU 5
DEF PADB_UP     EQU 6
DEF PADB_DOWN   EQU 7
DEF PADF_A      EQU 1 << PADB_A
DEF PADF_B      EQU 1 << PADB_B
DEF PADF_SELECT EQU 1 << PADB_SELECT
DEF PADF_START  EQU 1 << PADB_START
DEF PADF_RIGHT  EQU 1 << PADB_RIGHT
DEF PADF_LEFT   EQU 1 << PADB_LEFT
DEF PADF_UP     EQU 1 << PADB_UP
DEF PADF_DOWN   EQU 1 << PADB_DOWN

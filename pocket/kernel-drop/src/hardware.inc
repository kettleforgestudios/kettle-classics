; Game Boy hardware register addresses used by Kernel Drop.
; Written from public documentation (Pan Docs). Only what we need, with plain names.

DEF rP1    EQU $FF00 ; joypad: pick the D-pad or the buttons, then read them
DEF rIF    EQU $FF0F ; which interrupts are waiting
DEF rNR52  EQU $FF26 ; sound on/off
DEF rLCDC  EQU $FF40 ; screen control (on/off, which layers are shown)
DEF rSTAT  EQU $FF41 ; screen status
DEF rSCY   EQU $FF42 ; background scroll Y
DEF rSCX   EQU $FF43 ; background scroll X
DEF rLY    EQU $FF44 ; which screen line is being drawn right now (0-153)
DEF rDMA   EQU $FF46 ; starts a fast copy of sprite data into the sprite table
DEF rBGP   EQU $FF47 ; background palette (4 shades)
DEF rOBP0  EQU $FF48 ; sprite palette 0
DEF rOBP1  EQU $FF49 ; sprite palette 1
DEF rIE    EQU $FFFF ; which interrupts are allowed

DEF IEF_VBLANK EQU %00000001 ; the "screen finished drawing" interrupt

; Screen control bits we use
DEF LCDCF_ON     EQU %10000000 ; screen on
DEF LCDCF_BLK01  EQU %00010000 ; tiles live at $8000 (shared by background and sprites)
DEF LCDCF_OBJON  EQU %00000010 ; sprites on
DEF LCDCF_BGON   EQU %00000001 ; background on

; Sprite flag bits (4th byte of each sprite)
DEF OAMF_PAL1    EQU %00010000 ; use sprite palette 1 instead of 0

DEF VRAM_TILES   EQU $8000 ; where tile pictures go
DEF SCRN0        EQU $9800 ; background map: 32x32 tiles, each byte = which tile to show
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

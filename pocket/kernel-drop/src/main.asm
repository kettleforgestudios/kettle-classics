; =============================================================================
; Kernel Drop - Chapter 1 of Kettle Classics (Pocket / Game Boy)
; (c) 2026 Kettle Forge Studios. Original code, art and sound.
;
; Step 1: "hello" title screen.
;   - Shows the title text and Kip (our popcorn-kernel hero).
;   - Kip bobs gently; press A to make Kip hop.
;   - Follows real Game Boy rules: only touches video memory while the screen
;     is off or between frames, and moves sprites with OAM DMA.
; =============================================================================

INCLUDE "hardware.inc"
INCLUDE "charmap.inc"

; --- Where Kip stands on screen (in pixels) -----------------------------------
DEF KIP_X EQU 72          ; left edge (screen is 160 pixels wide)
DEF KIP_Y EQU 88          ; top edge  (screen is 144 pixels tall)
DEF HOP_HEIGHT EQU 12     ; how many pixels a hop lifts Kip

; =============================================================================
; Memory we use (work RAM). Fixed addresses so automatic tests can read them.
; =============================================================================
SECTION "Game state", WRAM0[$C000]
wBootMarker::  db  ; set to $42 once start-up finishes (tests check this)
wJoyHeld::     db  ; buttons held right now (bit layout: see hardware.inc)
wJoyPressed::  db  ; buttons that went down THIS frame
wFrameCount::  db  ; counts up every frame (60 per second)
wHopTimer::    db  ; > 0 while Kip is in the air

; A copy of the sprite table. We edit this copy any time, and the VBlank
; interrupt copies it into the real sprite table with OAM DMA.
; It must start on a 256-byte boundary for DMA, hence ALIGN[8].
SECTION "Shadow OAM", WRAM0, ALIGN[8]
ShadowOAM::    ds 4 * 40  ; 40 sprites x 4 bytes (Y, X, tile, flags)

; High RAM: the only memory the CPU can use while OAM DMA runs.
SECTION "OAM DMA code", HRAM
hOAMDMA::      ds 10        ; size of OAMDMARoutine (checked below)

; =============================================================================
; Cartridge header. The real values (title, checksums) are filled in by
; rgbfix when we build. We do NOT put the Nintendo logo here: Kernelcade
; doesn't need it, so this game stays free of anyone else's trademarks.
; =============================================================================
SECTION "Header", ROM0[$100]
    nop
    jp Start
    ds $150 - @, 0

; The VBlank interrupt: runs once per frame, right after the screen is drawn.
SECTION "VBlank interrupt", ROM0[$40]
    jp VBlankHandler

; =============================================================================
; Start-up
; =============================================================================
SECTION "Main", ROM0

Start:
    di                      ; no interrupts while we set things up
    ld sp, $E000            ; stack at the top of work RAM

    xor a
    ldh [rNR52], a          ; sound off for now (music comes in a later step)

    ; Video memory can only be changed safely while the screen is off, and the
    ; screen may only be turned off during VBlank (lines 144-153).
.waitVBlank
    ldh a, [rLY]
    cp 144
    jr c, .waitVBlank
    xor a
    ldh [rLCDC], a          ; screen off

    ; Copy all our tile pictures (font + Kip) into video memory.
    ld hl, VRAM_TILES
    ld de, Tiles
    ld bc, TilesEnd - Tiles
    call MemCopy

    ; Clear the background map (fill with tile 0 = blank).
    ld hl, SCRN0
    ld bc, SCRN_VY * 32
    xor a
    call MemFill

    ; Write the text. Each line: where on the map, then the words.
    ld hl, SCRN0 + SCRN_VY * 4 + 4
    ld de, TextTitle
    call PrintText
    ld hl, SCRN0 + SCRN_VY * 6 + 2
    ld de, TextSeries
    call PrintText
    ld hl, SCRN0 + SCRN_VY * 15 + 4
    ld de, TextPressStart
    call PrintText

    ; Clear our sprite table copy, then copy the DMA routine into high RAM.
    ld hl, ShadowOAM
    ld bc, 4 * 40
    xor a
    call MemFill
    ld hl, hOAMDMA
    ld de, OAMDMARoutine
    ld bc, OAMDMARoutineEnd - OAMDMARoutine
    call MemCopy

    ; Starting values.
    xor a
    ld [wJoyHeld], a
    ld [wJoyPressed], a
    ld [wFrameCount], a
    ld [wHopTimer], a
    ldh [rSCX], a
    ldh [rSCY], a
    call DrawKip

    ; Shades: colour 0 = lightest ... colour 3 = darkest.
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a

    ; Turn on the VBlank interrupt and the screen.
    ld a, IEF_VBLANK
    ldh [rIE], a
    xor a
    ldh [rIF], a
    ld a, LCDCF_ON | LCDCF_BLK01 | LCDCF_OBJON | LCDCF_BGON
    ldh [rLCDC], a

    ld a, $42
    ld [wBootMarker], a     ; start-up finished (for automatic tests)
    ei

; =============================================================================
; Main loop: once per frame, read the buttons and update Kip.
; =============================================================================
MainLoop:
    halt                    ; sleep until the next VBlank interrupt
    call ReadJoypad

    ; Press A: start a hop (if Kip isn't already in the air).
    ld a, [wJoyPressed]
    bit PADB_A, a
    jr z, .noHop
    ld a, [wHopTimer]
    and a
    jr nz, .noHop
    ld a, HOP_HEIGHT
    ld [wHopTimer], a
.noHop
    ; Kip floats back down one pixel per frame.
    ld a, [wHopTimer]
    and a
    jr z, .grounded
    dec a
    ld [wHopTimer], a
.grounded
    call DrawKip
    jr MainLoop

; -----------------------------------------------------------------------------
; DrawKip: write Kip's 4 sprites (2x2 tiles of 8x8) into the sprite table copy.
; Height = hop height + a gentle 1-pixel bob every half second.
; Sprite positions are stored with an offset: Y + 16, X + 8.
; -----------------------------------------------------------------------------
DrawKip:
    ; b = how many pixels Kip is lifted
    ld a, [wFrameCount]
    swap a                  ; bit 4 of the frame counter -> bit 0
    and 1                   ; 0 or 1: the bob
    ld b, a
    ld a, [wHopTimer]
    add a, b
    ld b, a

    ld a, KIP_Y + 16
    sub b
    ld c, a                 ; c = top row Y (with the +16 offset)

    ld hl, ShadowOAM
    ; top-left
    ld a, c
    ld [hli], a
    ld a, KIP_X + 8
    ld [hli], a
    ld a, KIP_FIRST_TILE
    ld [hli], a
    xor a
    ld [hli], a
    ; top-right
    ld a, c
    ld [hli], a
    ld a, KIP_X + 8 + 8
    ld [hli], a
    ld a, KIP_FIRST_TILE + 1
    ld [hli], a
    xor a
    ld [hli], a
    ; bottom-left
    ld a, c
    add a, 8
    ld [hli], a
    ld a, KIP_X + 8
    ld [hli], a
    ld a, KIP_FIRST_TILE + 2
    ld [hli], a
    xor a
    ld [hli], a
    ; bottom-right
    ld a, c
    add a, 8
    ld [hli], a
    ld a, KIP_X + 8 + 8
    ld [hli], a
    ld a, KIP_FIRST_TILE + 3
    ld [hli], a
    xor a
    ld [hli], a
    ret

; -----------------------------------------------------------------------------
; ReadJoypad: read all 8 buttons into wJoyHeld, and which are new into
; wJoyPressed. The joypad is read in two halves: D-pad, then buttons.
; A "0" bit from the hardware means pressed, so we flip the bits (cpl).
; -----------------------------------------------------------------------------
ReadJoypad:
    ld a, %00100000         ; select the D-pad half
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]            ; read twice: the lines need a moment to settle
    cpl
    and $0F
    swap a                  ; D-pad goes in the high 4 bits
    ld b, a

    ld a, %00010000         ; select the buttons half (A, B, Select, Start)
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]            ; this half needs a little longer to settle
    cpl
    and $0F
    or b
    ld b, a                 ; b = everything held right now

    ld a, %00110000         ; deselect both halves
    ldh [rP1], a

    ld a, [wJoyHeld]        ; new presses = held now AND not held last frame
    cpl
    and b
    ld [wJoyPressed], a
    ld a, b
    ld [wJoyHeld], a
    ret

; -----------------------------------------------------------------------------
; VBlankHandler: runs every frame. Copies the sprite table (OAM DMA) and
; counts frames.
; -----------------------------------------------------------------------------
VBlankHandler:
    push af
    push bc
    push de
    push hl
    call hOAMDMA
    ld hl, wFrameCount
    inc [hl]
    pop hl
    pop de
    pop bc
    pop af
    reti

; The OAM DMA routine. It gets copied to high RAM at start-up, because during
; the copy the CPU can only run code from high RAM.
OAMDMARoutine:
    ld a, HIGH(ShadowOAM)
    ldh [rDMA], a           ; start the copy (160 bytes)
    ld a, 40                ; wait ~160 cycles for it to finish
.wait
    dec a
    jr nz, .wait
    ret
OAMDMARoutineEnd:
    ASSERT OAMDMARoutineEnd - OAMDMARoutine == 10, "update hOAMDMA size"

; -----------------------------------------------------------------------------
; Small helpers
; -----------------------------------------------------------------------------

; MemCopy: copy bc bytes from de to hl.
MemCopy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, MemCopy
    ret

; MemFill: fill bc bytes at hl with the value in a.
MemFill:
    ld d, a
.loop
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

; PrintText: copy text from de to the background map at hl, until $FF.
PrintText:
    ld a, [de]
    cp $FF
    ret z
    ld [hli], a
    inc de
    jr PrintText

; -----------------------------------------------------------------------------
; Text (letters become tile numbers through charmap.inc)
; -----------------------------------------------------------------------------
TextTitle:      db "KERNEL DROP", $FF
TextSeries:     db "KETTLE CLASSICS", $FF
TextPressStart: db "PRESS START", $FF

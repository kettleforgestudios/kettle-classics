; =============================================================================
; Lab mode (pulled into main.asm with INCLUDE)
;
; Hidden test pages, so Kernel Drop doubles as a test for Kernelcade.
; Open it from the title: hold Select and press Start.
; Select + Start together goes to the next page; after the last, the title.
;   Page 0  BUTTONS  every button lights a block while held
;   Page 1  SOUND    Left/Right picks a channel, A plays it, B = Kip's motif
;   Page 2  SPRITES  D-pad moves Kip, B + D-pad scrolls the background,
;                    A turns the window layer on/off. Eleven drops share one
;                    line: the hardware shows only 10 (the 11th must vanish).
;   Page 3  TIMER    frames and seconds since the Lab opened, and the DIV
;                    register (a hardware counter that never stops)
; Each page can fill two 20-tile rows (wLabLines) that are copied to rows 7
; and 11 at VBlank; everything else on the page is drawn once.
; =============================================================================

DEF LAB_PAGES  EQU 4
DEF LAB_ROW1   EQU 7
DEF LAB_ROW2   EQU 11
DEF LAB_DROPS_Y EQU 72     ; sprite test: the line with 11 drops
DEF LAB_DROPS  EQU 11

EnterLab:
    xor a
    ld [wLabPage], a
    ld [wLabFrames], a
    ld [wLabFrames + 1], a
    ld [wLabSeconds], a
    ld [wLabSeconds + 1], a
    ld [wLabTick], a
    ld [wTuneTimer], a
    call StopMusic
    ld a, STATE_LAB
    ld [wGameState], a
    ; fall through to DrawLabPage

; DrawLabPage: draw page wLabPage from scratch (with the screen off).
DrawLabPage:
    call ScreenOff          ; (also switches the window layer off)
    call ClearSprites
    call ClearMap
    xor a
    ld [wLabSel], a
    ld [wLabWindow], a
    ldh [rSCX], a
    ldh [rSCY], a
    ld a, KIP_X
    ld [wLabKipX], a
    ld a, 40
    ld [wLabKipY], a
    ld b, 1
    ld c, 6
    ld de, TextLab
    call PrintAt
    ld b, 17
    ld c, 2
    ld de, TextLabNext
    call PrintAt
    ; This page's own texts: row, column, text ... $FF (LabPageTexts).
    ld a, [wLabPage]
    add a, a
    ld hl, LabPageTexts
    ADD_A_TO_HL
    ld a, [hli]
    ld h, [hl]
    ld l, a
.text
    ld a, [hli]
    cp $FF
    jr z, .texts
    ld b, a
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    push hl
    call PrintAt
    pop hl
    jr .text
.texts
    call DrawWindowMap
    call UpdateLabPage      ; fill the two rows once...
    call DrawLabLines       ; ...and draw them now (the screen is off)
    jp ScreenOn

UpdateLab:
    ; Select + Start together (one of them just pressed): next page.
    ld a, [wJoyHeld]
    and PADF_SELECT | PADF_START
    cp PADF_SELECT | PADF_START
    jr nz, .stay
    ld a, [wJoyPressed]
    and PADF_SELECT | PADF_START
    jr z, .stay
    ld a, [wLabPage]
    inc a
    cp LAB_PAGES
    jp nc, EnterTitle       ; after the last page: back to the title
    ld [wLabPage], a
    jp DrawLabPage
.stay
    ; Count time for the timer page: frames, and seconds every 60 frames.
    ld hl, wLabFrames
    inc [hl]
    jr nz, .counted
    inc hl
    inc [hl]
.counted
    ld hl, wLabTick
    inc [hl]
    ld a, [hl]
    cp 60
    jr c, UpdateLabPage
    ld [hl], 0
    ld hl, wLabSeconds
    ld a, [hl]
    add a, 1
    daa                     ; keep it in decimal digits
    ld [hli], a
    ld a, [hl]
    adc a, 0
    daa
    ld [hl], a
    ; fall through to UpdateLabPage

; UpdateLabPage: run the current page (LabPageCode).
UpdateLabPage:
    ld a, [wLabPage]
    add a, a
    ld hl, LabPageCode
    ADD_A_TO_HL
    ld a, [hli]
    ld h, [hl]
    ld l, a
    jp hl

LabPageCode:
    dw LabButtons, LabSound, LabSprites, LabTimer
LabPageTexts:
    dw LabTexts0, LabTexts1, LabTexts2, LabTexts3

; ClearLabLines: blank both rows, and mark them for drawing.
ClearLabLines:
    ld hl, wLabLines
    ld bc, 40
    xor a
    call MemFill
    ld a, 1
    ld [wLabDirty], a
    ret

; DrawLabLines: copy the two rows to the screen (VBlank or screen off only).
DrawLabLines:
    xor a
    ld [wLabDirty], a
    ld de, wLabLines
    ld hl, SCRN0 + SCRN_VY * LAB_ROW1
    call .row
    ld hl, SCRN0 + SCRN_VY * LAB_ROW2
.row
    ld b, 20
.copy
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .copy
    ret

; DrawWindowMap: the window layer's text, in the second map (screen off only).
DrawWindowMap:
    ld hl, SCRN1
    ld bc, SCRN_VY * 2
    xor a
    call MemFill
    ld hl, SCRN1 + 2
    ld de, TextWindowOn
    jp PrintText

; --- Page 0: buttons ------------------------------------------------------------
LabButtons:
    call ClearLabLines
    ld hl, ButtonMarks
    ld c, 8
.mark
    ld a, [hli]
    ld b, a                 ; the button's bit
    ld a, [hli]
    ld e, a                 ; where its block goes in wLabLines
    ld a, [hli]
    ld d, a                 ; how wide
    ld a, [wJoyHeld]
    and b
    jr z, .next             ; not held
    push hl
    ld hl, wLabLines
    ld a, e
    ADD_A_TO_HL
    ld a, TILE_BLOCK
.block
    ld [hli], a
    dec d
    jr nz, .block
    pop hl
.next
    dec c
    jr nz, .mark
    ret

; Button bit, position in the two rows (row 7 = 0-19, row 11 = 20-39), width.
; These line up under the labels in LabTexts0.
ButtonMarks:
    db PADF_A,      2, 1
    db PADF_B,      5, 1
    db PADF_SELECT, 8, 3
    db PADF_START, 13, 3
    db PADF_UP,    20 + 2, 2
    db PADF_DOWN,  20 + 6, 2
    db PADF_LEFT,  20 + 10, 2
    db PADF_RIGHT, 20 + 14, 2

; --- Page 1: sound --------------------------------------------------------------
LabSound:
    ld a, [wJoyPressed]
    ld b, a
    ld hl, wLabSel
    bit PADB_RIGHT, b
    jr z, .notRight
    inc [hl]
.notRight
    bit PADB_LEFT, b
    jr z, .notLeft
    dec [hl]
.notLeft
    ld a, [hl]
    and 3                   ; wrap around: 0-3
    ld [hl], a
    bit PADB_B, b
    jr z, .notB
    QUEUE_SFX2 SFX2B_KIP
.notB
    bit PADB_A, b
    call nz, LabPlayChannel
    ; A block under the chosen channel (labels at columns 1, 5, 9, 13).
    call ClearLabLines
    ld a, [wLabSel]
    add a, a
    add a, a                ; * 4
    inc a
    ld hl, wLabLines
    ADD_A_TO_HL
    ld a, TILE_BLOCK
    ld [hli], a
    ld [hli], a
    ld [hl], a
    ret

; LabPlayChannel: play a test sound on channel wLabSel + 1.
LabPlayChannel:
    ld a, [wLabSel]
    and a
    ld hl, SfxStart
    jp z, PlaySquare        ; channel 1
    dec a
    ld hl, TuneSprout
    jp z, StartTune         ; channel 2
    dec a
    ld hl, SongTest
    jp z, StartMusic        ; channel 3
    ld hl, SfxFlood
    jp PlayNoise            ; channel 4

; --- Page 2: sprites and layers ---------------------------------------------------
LabSprites:
    ; A: window layer on / off (changing LCDC bits is allowed at any time).
    ld a, [wJoyPressed]
    bit PADB_A, a
    jr z, .noWindow
    ld a, [wLabWindow]
    xor 1
    ld [wLabWindow], a
    ldh a, [rLCDC]
    xor LCDCF_WINON
    ldh [rLCDC], a
.noWindow
    ld a, [wJoyHeld]
    ld b, a
    bit PADB_B, b
    jr z, .moveKip
    ; B held: the D-pad scrolls the whole background.
    bit PADB_LEFT, b
    jr z, .sl
    ldh a, [rSCX]
    dec a
    ldh [rSCX], a
.sl
    bit PADB_RIGHT, b
    jr z, .sr
    ldh a, [rSCX]
    inc a
    ldh [rSCX], a
.sr
    bit PADB_UP, b
    jr z, .su
    ldh a, [rSCY]
    dec a
    ldh [rSCY], a
.su
    bit PADB_DOWN, b
    jr z, .draw
    ldh a, [rSCY]
    inc a
    ldh [rSCY], a
    jr .draw
.moveKip
    ld hl, wLabKipX
    bit PADB_LEFT, b
    jr z, .kl
    ld a, [hl]
    and a
    jr z, .kl
    dec [hl]
.kl
    bit PADB_RIGHT, b
    jr z, .kr
    ld a, [hl]
    cp 144
    jr nc, .kr
    inc [hl]
.kr
    ld hl, wLabKipY
    bit PADB_UP, b
    jr z, .ku
    ld a, [hl]
    cp 17
    jr c, .ku
    dec [hl]
.ku
    bit PADB_DOWN, b
    jr z, .draw
    ld a, [hl]
    cp 128
    jr nc, .draw
    inc [hl]
.draw
    ; Kip (slots 0-3, so Kip wins over the drops if they share a line),
    ; the cloud and the crow for show.
    ld a, [wLabKipY]
    ld b, a
    ld a, [wLabKipX]
    ld c, a
    ld d, TILE_KIP
    ld e, 0
    ld hl, ShadowOAM
    call Draw16x16
    ld bc, (40 << 8) | 16   ; b = top 40, c = left 16
    ld d, TILE_CLOUD
    ld e, 0
    call Draw16x16
    ld bc, (40 << 8) | 128
    ld d, TILE_CROW
    ld e, 0
    call Draw16x16
    ; Eleven drops on one line, 14 pixels apart.
    ld b, LAB_DROPS
    ld c, 4 + 8             ; first drop's x (+ 8 for the sprite table)
.drop
    ld a, LAB_DROPS_Y + 16
    ld [hli], a
    ld a, c
    ld [hli], a
    add a, 14
    ld c, a
    ld a, TILE_DROP
    ld [hli], a
    xor a
    ld [hli], a
    dec b
    jr nz, .drop
    jp ClearLabLines

; --- Page 3: timer ----------------------------------------------------------------
LabTimer:
    call ClearLabLines
    ; Row 7: frames (hex) under FRAMES, seconds under SECONDS.
    ld hl, wLabLines + 1
    ld a, [wLabFrames + 1]
    call PrintHex
    ld a, [wLabFrames]
    call PrintHex
    ld hl, wLabLines + 10
    ld a, [wLabSeconds + 1]
    call PrintBCD
    ld a, [wLabSeconds]
    call PrintBCD
    ; Row 11: the DIV register.
    ld hl, wLabLines + 20 + 1
    ldh a, [rDIV]
    jp PrintHex

; --- Texts ------------------------------------------------------------------------
TextLab:      db "LAB MODE", $FF
TextLabNext:  db "SELECT+START", $FF
TextWindowOn: db "WINDOW LAYER ON", $FF
; Each page: row, column, text ... $FF
LabTexts0:
    db 3, 4
    dw .t1
    db 6, 2
    dw .t2
    db 10, 2
    dw .t3
    db 14, 2
    dw .t4
    db $FF
.t1: db "BUTTON TEST", $FF
.t2: db "A  B  SEL  STA", $FF
.t3: db "UP  DN  LT  RT", $FF
.t4: db "HOLD EACH BUTTON", $FF
LabTexts1:
    db 3, 5
    dw .t1
    db 6, 1
    dw .t2
    db 13, 2
    dw .t3
    db 14, 2
    dw .t4
    db 15, 2
    dw .t5
    db $FF
.t1: db "SOUND TEST", $FF
.t2: db "CH1 CH2 CH3 CH4", $FF
.t3: db "<> PICK", $FF
.t4: db "A  PLAY CHANNEL", $FF
.t5: db "B  KIP MOTIF", $FF
LabTexts2:
    db 3, 3
    dw .t1
    db 8, 4
    dw .t2
    db 13, 2
    dw .t3
    db 14, 2
    dw .t4
    db 15, 2
    dw .t5
    db $FF
.t1: db "SPRITES LAYERS", $FF
.t2: db "10 PER LINE", $FF
.t3: db "PAD   MOVE KIP", $FF
.t4: db "B+PAD SCROLL", $FF
.t5: db "A     WINDOW", $FF
LabTexts3:
    db 3, 7
    dw .t1
    db 6, 1
    dw .t2
    db 10, 1
    dw .t3
    db $FF
.t1: db "TIMER", $FF
.t2: db "FRAMES   SECONDS", $FF
.t3: db "DIV", $FF

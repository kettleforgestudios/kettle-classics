; =============================================================================
; Title screen and ending (pulled into main.asm with INCLUDE)
;
; Title: Kip bobs (A = hop). Up/Down picks STORY or ENDLESS, Start plays.
;        Hidden: hold Select and press Start to open the Lab mode.
; Ending: Kip sprouts! Shows the Chapter 2 code and the score. Start = title.
; =============================================================================

; EnterTitle: draw the title screen and play its music.
EnterTitle:
    call ScreenOff
    call ClearSprites
    call DrawTitleScreen
    xor a
    ld [wGameState], a      ; STATE_TITLE
    ld [wHopTimer], a
    ld [wPaused], a
    ld [wTuneTimer], a
    ldh [rSCX], a
    ldh [rSCY], a
    ld hl, SongTitle
    call StartMusic
    jp ScreenOn

DrawTitleScreen:
    call ClearMap
    ld b, 3
    ld c, 4
    ld de, TextTitle
    call PrintAt
    ld b, 5
    ld c, 2
    ld de, TextSeries
    call PrintAt
    ld b, MENU_ROW
    ld c, MENU_COL + 2
    ld de, TextStory
    call PrintAt
    ld b, MENU_ROW + 1
    ld c, MENU_COL + 2
    ld de, TextEndlessMenu
    call PrintAt
    ld b, 14
    ld c, 4
    ld de, TextPressStart
    call PrintAt
    ; "HI 00000": best score since the game was switched on
    ld b, 16
    ld c, 6
    ld de, TextHi
    call PrintAt            ; leaves hl just after "HI "
    ld de, wHiScore
    call PrintScore
    ; fall through to DrawMenuArrow

; DrawMenuArrow: the ">" next to the chosen mode (VBlank or screen off only).
DrawMenuArrow:
    xor a
    ld [wMenuDirty], a
    ld a, [wMenu]
    and a
    ld b, TILE_ARROW_R      ; STORY chosen: arrow on the first row...
    ld c, 0
    jr z, .draw
    ld b, 0                 ; ...ENDLESS chosen: on the second
    ld c, TILE_ARROW_R
.draw
    ld hl, SCRN0 + SCRN_VY * MENU_ROW + MENU_COL
    ld [hl], b
    ld hl, SCRN0 + SCRN_VY * (MENU_ROW + 1) + MENU_COL
    ld [hl], c
    ret

UpdateTitle:
    ; Start: play (or, with Select held, open the Lab).
    ld a, [wJoyPressed]
    bit PADB_START, a
    jr z, .noStart
    ld a, [wJoyHeld]
    bit PADB_SELECT, a
    jp nz, EnterLab
    jp StartGame
.noStart
    ; Up / Down: switch between STORY and ENDLESS.
    and PADF_UP | PADF_DOWN
    jr z, .noMove
    ld a, [wMenu]
    xor 1
    ld [wMenu], a
    ld a, 1
    ld [wMenuDirty], a
    QUEUE_SFX2 SFX2B_MENU
.noMove
    call HopKip
    jp DrawKip

; HopKip: A makes Kip hop (if Kip isn't already in the air); Kip floats back
; down one pixel per frame.
HopKip:
    ld a, [wJoyPressed]
    bit PADB_A, a
    jr z, .noHop
    ld a, [wHopTimer]
    and a
    jr nz, .noHop
    ld a, HOP_HEIGHT
    ld [wHopTimer], a
.noHop
    ld a, [wHopTimer]
    and a
    ret z
    dec a
    ld [wHopTimer], a
    ret

; DrawKip: Kip's 4 sprites (2x2 tiles). Height = hop + a gentle 1-pixel bob.
; Returns b = Kip's top (the ending puts a sprout on Kip's head).
DrawKip:
    ld a, [wFrameCount]
    swap a                  ; bit 4 of the frame counter -> bit 0
    and 1                   ; 0 or 1: the bob
    ld b, a
    ld a, [wHopTimer]
    add a, b
    ld b, a
    ld a, KIP_Y
    sub b
    ld b, a                 ; b = Kip's top (pixels)
    push bc
    ld c, KIP_X             ; c = Kip's left
    ld d, TILE_KIP          ; d = first of Kip's 4 tiles
    ld e, 0                 ; e = sprite flags (normal palette)
    ld hl, ShadowOAM + SLOT_MAIN * 4
    call Draw16x16
    pop bc
    ret

; StartGame: begin the chosen mode at its first stage, score 0.
StartGame:
    ld a, [wMenu]
    ld [wMode], a
    xor a
    ld [wStage], a
    ld [wScore], a
    ld [wScore + 1], a
    jp StartStage

; UpdateHiScore: if this score beats the best one, keep it.
UpdateHiScore:
    ld a, [wHiScore + 1]
    ld b, a
    ld a, [wScore + 1]
    cp b                    ; compare the high bytes first...
    jr c, .no
    jr nz, .yes
    ld a, [wHiScore]
    ld b, a
    ld a, [wScore]
    cp b                    ; ...then the low bytes
    jr c, .no
.yes
    ld a, [wScore]
    ld [wHiScore], a
    ld a, [wScore + 1]
    ld [wHiScore + 1], a
.no
    ret

; =============================================================================
; Ending (after the last Story stage)
; =============================================================================
EnterEnding:
    call UpdateHiScore
    call ScreenOff
    call ClearSprites
    call ClearMap
    ld hl, EndingTexts
.text
    ld a, [hli]             ; row ($FF = no more texts)
    cp $FF
    jr z, .texts
    ld b, a
    ld a, [hli]             ; column
    ld c, a
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a                 ; de = text
    push hl
    call PrintAt
    pop hl
    jr .text
.texts
    ld b, 16
    ld c, 4
    ld de, TextScore
    call PrintAt
    ld de, wScore
    call PrintScore
    ld a, STATE_ENDING
    ld [wGameState], a
    xor a
    ld [wHopTimer], a
    ld [wTuneTimer], a
    QUEUE_SFX2 SFX2B_POP
    ld hl, SongEnding
    call StartMusic
    jp ScreenOn

UpdateEnding:
    ld a, [wJoyPressed]
    bit PADB_START, a
    jp nz, EnterTitle
    call HopKip
    call DrawKip            ; b = Kip's top
    ; A little sprout on Kip's head (sprite slot 4).
    ld hl, ShadowOAM + SLOT_DROPS * 4
    ld a, b
    add a, 16 - 7           ; sprite Y + 16, sitting 7 pixels above Kip's top
    ld [hli], a
    ld a, KIP_X + 4 + 8     ; centred on Kip (sprite X + 8)
    ld [hli], a
    ld a, TILE_SPROUT
    ld [hli], a
    xor a
    ld [hl], a
    ret

; Ending texts: row, column, text.
EndingTexts:
    db 1, 2
    dw TextChapterClear
    db 3, 3
    dw TextKipDone
    db 11, 2
    dw TextNext
    db 13, 3
    dw TextCodeLabel
    db 14, 5
    dw TextCode
    db 17, 1
    dw TextThanks
    db $FF
TextChapterClear: db "CHAPTER 1 CLEAR", $FF
TextKipDone:      db "KIP SPROUTED!", $FF
TextNext:         db "NEXT: THE FIELD", $FF
TextCodeLabel:    db "CHAPTER 2 CODE", $FF
TextCode:         db "SILK-KIP-2", $FF      ; placeholder unlock code
TextThanks:       db "THANKS FOR PLAYING", $FF

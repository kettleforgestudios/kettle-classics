; Seed Room: one original Pocket Color puzzle.
SECTION "Header", ROM0[$100]
    nop
    jp Boot
    ds $150 - @, 0

SECTION "State", WRAM0
wX: db
wY: db
wPixelX: db
wPixelY: db
wStep: db
wDeltaX: db
wDeltaY: db
wHeld: db
wPressed: db
wBridge: db
wSeed: db
wHints: db
wBridgeDirty: db
wHintDirty: db

SECTION "Code", ROM0
Boot:
    di
    ld sp, $DFFF
    ldh a, [$FF40]
    bit 7, a
    jr z, .off
    call WaitBlank
.off
    xor a
    ldh [$FF40], a
    ldh [$FF42], a
    ldh [$FF43], a
    ldh [$FF4F], a
    ld de, Tiles
    ld hl, $8000
    ld bc, TilesEnd - Tiles
    call Copy
    ld de, RoomTiles
    call TileMap
    ld a, 1
    ldh [$FF4F], a
    ld de, RoomAttrs
    call TileMap
    xor a
    ldh [$FF4F], a
    ld hl, $FE00
    ld b, 160
.oam
    ld [hli], a
    dec b
    jr nz, .oam
    ld a, $80
    ldh [$FF68], a
    ldh [$FF6A], a
    ld hl, Palettes
    ld b, 32
.background
    ld a, [hli]
    ldh [$FF69], a
    dec b
    jr nz, .background
    ld b, 16
.sprites
    ld a, [hli]
    ldh [$FF6B], a
    dec b
    jr nz, .sprites
    ld a, $80
    ldh [$FF26], a
    ld a, $77
    ldh [$FF24], a
    ld a, $11
    ldh [$FF25], a
    xor a
    ld [wHeld], a
    call ResetRoom
    call Draw
    ld a, $93
    ldh [$FF40], a

Frame:
    call ReadPad
    ld a, [wPressed]
    bit 7, a
    call nz, ResetRoom
    ld a, [wPressed]
    bit 6, a
    jr z, .move
    ld hl, wHints
    ld a, [hl]
    xor 1
    ld [hl], a
    ld a, 1
    ld [wHintDirty], a
.move
    call UpdateKip
    call NextBlank
    call Draw
    jr Frame

ResetRoom:
    ld a, 4
    ld [wX], a
    ld a, 8
    ld [wY], a
    ld a, 40
    ld [wPixelX], a
    ld a, 80
    ld [wPixelY], a
    xor a
    ld [wStep], a
    ld [wBridge], a
    ld [wSeed], a
    inc a
    ld [wHints], a
    ld [wBridgeDirty], a
    ld [wHintDirty], a
    ret

UpdateKip:
    ld hl, wStep
    ld a, [hl]
    and a
    jr z, .center
    dec [hl]
    jp Slide
.center
    ld a, [wPressed]
    bit 4, a
    call nz, UseSeed
    ld a, [wPressed]
    bit 5, a
    call nz, Tug
    ld a, [wHeld]
    and 15
    ret z
    ld c, a
    ld a, [wX]
    ld b, a
    ld a, [wY]
    ld e, a
    ld d, 0
    ld h, 0
    bit 0, c
    jr z, .left
    inc b
    inc d
    jr .check
.left
    bit 1, c
    jr z, .up
    dec b
    dec d
    jr .check
.up
    bit 2, c
    jr z, .down
    dec e
    dec h
    jr .check
.down
    inc e
    inc h
.check
    ld a, b
    cp 2
    ret c
    cp 18
    ret nc
    ld a, e
    cp 3
    ret c
    cp 15
    ret nc
    ld a, b
    cp 10
    jr c, .go
    cp 12
    jr nc, .go
    ld a, e
    cp 8
    ret nz
    ld a, [wBridge]
    and a
    ret z
.go
    ld a, b
    ld [wX], a
    ld a, e
    ld [wY], a
    ld a, d
    ld [wDeltaX], a
    ld a, h
    ld [wDeltaY], a
    ld a, 7
    ld [wStep], a
Slide:
    ld a, [wDeltaX]
    ld hl, wPixelX
    add [hl]
    ld [hl], a
    ld a, [wDeltaY]
    ld hl, wPixelY
    add [hl]
    ld [hl], a
    ret

UseSeed:
    ld a, [wY]
    cp 6
    ret nz
    ld a, [wSeed]
    cp 2
    ret z
    and a
    ld a, [wX]
    jr nz, .plant
    cp 5
    ret nz
    ld a, 1
    ld [wSeed], a
    ld a, $62
    jr .tone
.plant
    cp 15
    ret nz
    ld a, 2
    ld [wSeed], a
    ld a, $C0
.tone
    ld b, a
    ld a, 1
    ld [wHintDirty], a
    ld a, b
    jp Tone

Tug:
    ld a, [wY]
    cp 8
    ret nz
    ld a, [wX]
    cp 9
    jr z, .flip
    cp 12
    ret nz
.flip
    ld hl, wBridge
    ld a, [hl]
    xor 1
    ld [hl], a
    ld a, 1
    ld [wBridgeDirty], a
    ld [wHintDirty], a
    ld a, $42
Tone:
    ldh [$FF13], a
    ld a, $80
    ldh [$FF11], a
    ld a, $93
    ldh [$FF12], a
    ld a, $87
    ldh [$FF14], a
    ret

Draw:
    ld hl, $FE00
    ld a, [wPixelY]
    ld [hli], a
    ld a, [wPixelX]
    ld [hli], a
    ld a, 8
    ld [hli], a
    xor a
    ld [hli], a
    ld a, [wSeed]
    and a
    jr z, .seed
    cp 1
    jr z, .carried
    ld b, 64
    ld c, 128
    ld d, 10
    jr .drawSeed
.seed
    ld b, 64
    ld c, 48
    ld d, 9
    jr .drawSeed
.carried
    ld a, [wPixelY]
    sub 7
    ld b, a
    ld a, [wPixelX]
    add 4
    ld c, a
    ld d, 9
.drawSeed
    ld [hl], b
    inc hl
    ld [hl], c
    inc hl
    ld [hl], d
    inc hl
    ld [hl], 1
    ld hl, wBridgeDirty
    ld a, [hl]
    and a
    call nz, DrawBridge
    ld hl, wHintDirty
    ld a, [hl]
    and a
    ret z
    ld [hl], 0
    ld hl, $9A00
    ld de, HintBlank
    ld a, [wHints]
    and a
    jr z, .hint
    ld a, [wSeed]
    cp 2
    ld de, HintBloom
    jr z, .hint
    and a
    ld de, HintPick
    jr z, .hint
    ld a, [wBridge]
    and a
    ld de, HintPull
    jr z, .hint
    ld de, HintPlant
.hint
    ld bc, 20
    jp Copy

DrawBridge:
    ld [hl], 0
    ld a, [wBridge]
    and a
    ld b, 3
    ld c, 2
    jr z, .paint
    ld b, 4
    ld c, 1
.paint
    ld a, b
    ld [$990A], a
    ld [$990B], a
    ld a, 1
    ldh [$FF4F], a
    ld a, c
    ld [$990A], a
    ld [$990B], a
    xor a
    ldh [$FF4F], a
    ret

ReadPad:
    ld a, $20
    ldh [$FF00], a
    ldh a, [$FF00]
    ldh a, [$FF00]
    cpl
    and $0F
    ld b, a
    ld a, $10
    ldh [$FF00], a
    ldh a, [$FF00]
    ldh a, [$FF00]
    cpl
    and $0F
    swap a
    or b
    ld hl, wHeld
    ld b, a
    xor [hl]
    and b
    ld [wPressed], a
    ld [hl], b
    ret

NextBlank:
    ldh a, [$FF44]
    cp 144
    jr nc, NextBlank
WaitBlank:
    ldh a, [$FF44]
    cp 144
    jr c, WaitBlank
    ret

TileMap:
    ld hl, $9800
    ld a, 18
.row
    push af
    ld bc, 20
    call Copy
    ld bc, 12
    add hl, bc
    pop af
    dec a
    jr nz, .row
    ret
Copy:
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, Copy
    ret

Palettes:
    dw $0D64, $1EAD, $2F52, $73BF
    dw $0D64, $19CA, $32D6, $533E
    dw $28C3, $5191, $6B19, $7BDE
    dw $10C7, $1E4E, $3F3A, $73BF
    dw $0000, $16FF, $09B6, $08A8
    dw $0000, $2D97, $167F, $0D05
INCLUDE "room.inc"

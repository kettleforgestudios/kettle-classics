; Fields of Silk — Kettle Classics, Pocket Color alpha.
; The 16x16 board is indexed by Y in the high nibble and X in the low nibble.
DEF SOIL EQU 0
DEF CORN EQU 1
DEF SILK EQU 2
DEF VISITED EQU 3

SECTION "Header", ROM0[$100]
    nop
    jp Start
    ds $150 - @, 0

SECTION "Board", WRAM0, ALIGN[8]
wField: ds 256
SECTION "Trail", WRAM0, ALIGN[8]
wTrail: ds 256
SECTION "Search queue", WRAM0, ALIGN[8]
wQueue: ds 256
SECTION "State", WRAM0
wPos: db
wAnchor: db
wBug: db
wLength: db
wArmed: db
wInput: db
wPressed: db
wPhase: db
wDX: db
wDY: db
wRow: db
wChance: db
wPause: db
wContrast: db
wClock: db
wHead: db
wTail: db
wScreen: db
wProgress: db
wRenderStart: db
wRenderTiles: ds 32
wRenderAttrs: ds 32

SECTION "Game", ROM0
Start:
    di
    ld sp, $DFFF
    call ScreenOff
    xor a
    ldh [$FF4F], a
    ld hl, $8000
    ld de, Tiles
    ld bc, TilesEnd - Tiles
.copy
    ld a, [de]
    inc de
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .copy
    ld hl, $FE00
    ld b, 160
.clearOAM
    xor a
    ld [hli], a
    dec b
    jr nz, .clearOAM
    ld a, $80
    ldh [$FF68], a
    ld hl, Colors
    ld b, 32
.bg
    ld a, [hli]
    ldh [$FF69], a
    dec b
    jr nz, .bg
    ld a, $80
    ldh [$FF6A], a
    ld b, 24
.obj
    ld a, [hli]
    ldh [$FF6B], a
    dec b
    jr nz, .obj
    ld a, $80
    ldh [$FF26], a
    ld a, $77
    ldh [$FF24], a
    ld a, $FF
    ldh [$FF25], a
    xor a
    ldh [$FF42], a
    ldh [$FF43], a
    ld [wInput], a
    call NewField
    ld a, $93
    ldh [$FF40], a

Frame:
    call ReadPad
    ld a, [wPressed]
    bit 7, a
    jr z, .check
    ld a, [wChance]
    and a
    jr z, .restart
    ld a, [wScreen]
    and a
    jr nz, .restart
    ld hl, wPause
    ld a, [hl]
    xor 1
    ld [hl], a
    jr .check
.restart
    call ScreenOff
    call NewField
    ld a, $93
    ldh [$FF40], a
.check
    ld a, [wPressed]
    bit 6, a
    jr z, .paused
    ld hl, wContrast
    ld a, [hl]
    xor 1
    ld [hl], a
.paused
    ld a, [wPause]
    ld hl, wScreen
    or [hl]
    ld hl, wChance
    jr nz, .draw
    ld a, [hl]
    and a
    jr z, .draw
    call Player
    call Weevil
.draw
    call PrepareRows
    call NextBlank
    call DrawActors
    ld a, [wPressed]
    bit 6, a
    jr z, .copyRows
    call DrawPalette
    jr .hud
.copyRows
    call DrawRows
.hud
    call DrawHUD
    jr Frame

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
    ld hl, wInput
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
ScreenOff:
    ldh a, [$FF40]
    bit 7, a
    ret z
    call WaitBlank
    xor a
    ldh [$FF40], a
    ret

NewField:
    ld a, 3
    call FillMap
    ld a, 1
    ldh [$FF4F], a
    ld a, 3
    call FillMap
    xor a
    ldh [$FF4F], a
    ld hl, wField
.field
    ld a, l
    cp $10
    jr c, .edge
    cp $F0
    jr nc, .edge
    and 15
    jr z, .edge
    cp 15
    ld a, SOIL
    jr nz, .store
.edge
    ld a, CORN
.store
    ld [hli], a
    ld a, l
    and a
    jr nz, .field
    ld a, $80
    ld [wPos], a
    ld [wAnchor], a
    ld a, $8A
    ld [wBug], a
    ld a, 3
    ld [wChance], a
    xor a
    ld [wLength], a
    ld [wArmed], a
    ld [wPause], a
    ld [wPhase], a
    ld [wRow], a
    ld [wScreen], a
    ld [wProgress], a
    ld [wContrast], a
    ld [wClock], a
    call DrawPalette
    ld hl, $9A22
    ld de, AlphaLabel
    ld b, 7
.label
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .label
    ld hl, $9801
    ld de, FieldLabel
    ld b, 5
.fieldLabel
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .fieldLabel
    ld c, 8
.rows
    push bc
    call PrepareRows
    call DrawRows
    pop bc
    dec c
    jr nz, .rows
    ret

FillMap:
    ld hl, $9800
    ld bc, 1024
    ld d, a
.clear
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .clear
    ret

; Keep motion at two pixels per frame. Grid decisions happen at tile centers.
Player:
    ld hl, wPhase
    ld a, [hl]
    and a
    jr z, .center
    dec [hl]
    ret
.center
    ld a, [wInput]
    bit 5, a
    jr z, .anchor
    ld a, [wLength]
    and a
    jp nz, Reel
.anchor
    ld a, [wPressed]
    bit 4, a
    jr z, .move
    ld a, [wLength]
    and a
    jr nz, .move
    ld a, [wPos]
    ld [wAnchor], a
    ld a, 1
    ld [wArmed], a
.move
    ld a, [wInput]
    and 15
    ret z
    ld b, a
    ld a, [wPos]
    ld c, a
    bit 0, b
    jr z, .left
    and 15
    cp 15
    ret z
    ld a, c
    inc a
    jr .candidate
.left
    bit 1, b
    jr z, .up
    and 15
    ret z
    ld a, c
    dec a
    jr .candidate
.up
    bit 2, b
    jr z, .down
    cp 16
    ret c
    sub 16
    jr .candidate
.down
    cp 240
    ret nc
    add 16
.candidate
    ld e, a
    ld h, HIGH(wField)
    ld l, a
    ld a, [hl]
    cp CORN
    jr z, .safe
    and a
    ret nz
    ld a, [wArmed]
    and a
    ret z
    ld [hl], SILK
    ld hl, wLength
    ld l, [hl]
    ld h, HIGH(wTrail)
    ld [hl], e
    ld hl, wLength
    inc [hl]
    jr SetPosition
.safe
    ld a, [wLength]
    and a
    jr nz, .capture
    ld a, e
    ld [wAnchor], a
    jr SetPosition
.capture
    push de
    call Capture
    pop de
    ld a, e
    ld [wAnchor], a
SetPosition:
    ld a, [wPos]
    ld c, a
    ld a, e
    ld [wPos], a
    sub c
    ld b, a
    xor a
    ld [wDX], a
    ld [wDY], a
    ld a, b
    cp 1
    jr z, .right
    cp $FF
    jr z, .left
    cp 16
    ld a, 2
    jr z, .vertical
    ld a, -2
.vertical
    ld [wDY], a
    jr .phase
.right
    ld a, 2
    jr .horizontal
.left
    ld a, -2
.horizontal
    ld [wDX], a
.phase
    ld a, 3
    ld [wPhase], a
    ret

Reel:
    ld hl, wLength
    dec [hl]
    ld a, [wPos]
    ld h, HIGH(wField)
    ld l, a
    ld [hl], SOIL
    ld a, [wLength]
    and a
    ld hl, wAnchor
    jr z, .back
    dec a
    ld l, a
    ld h, HIGH(wTrail)
.back
    ld e, [hl]
    jr SetPosition

; Flood-fill dry ground reachable from the weevil. Silk and corn stop the search.
Capture:
    xor a
    ld [wLength], a
    ld [wArmed], a
    ld [wHead], a
    ld [wTail], a
    ld a, [wBug]
    call Enqueue
.next
    ld a, [wHead]
    ld c, a
    ld a, [wTail]
    cp c
    jr z, .grow
    ld h, HIGH(wQueue)
    ld l, c
    ld c, [hl]
    ld hl, wHead
    inc [hl]
    ld a, c
    inc a
    call Enqueue
    ld a, c
    dec a
    call Enqueue
    ld a, c
    add 16
    call Enqueue
    ld a, c
    sub 16
    call Enqueue
    jr .next
.grow
    ld hl, wField
    ld b, 0
.row
    ld a, [hl]
    cp VISITED
    jr nz, .corn
    inc b
    xor a
    jr .write
.corn
    ld a, CORN
.write
    ld [hli], a
    ld a, l
    and a
    jr nz, .row
    ; The weevil flees when too little dry ground remains to hide.
    ld a, b
    cp 5
    jr nc, .progress
    ld hl, wField
.all
    ld [hl], CORN
    inc l
    jr nz, .all
    ld a, 1
    ld [wScreen], a
    ld a, 100
    jr .saveProgress
.progress
    ; Compute the percentage of the original 196 dry plots that grew.
    ld a, 196
    sub b
    ld hl, 0
    ld de, 100
.multiply
    add hl, de
    dec a
    jr nz, .multiply
    ld de, -196
    ld a, 0
.divide
    add hl, de
    jr nc, .saveProgress
    inc a
    jr .divide
.saveProgress
    ld [wProgress], a
.sound
    ld a, $C2
    jp Tone

Enqueue:
    ld h, HIGH(wField)
    ld l, a
    ld a, [hl]
    and a
    ret nz
    ld [hl], VISITED
    ld e, l
    ld hl, wTail
    ld a, [hl]
    inc [hl]
    ld h, HIGH(wQueue)
    ld l, a
    ld [hl], e
    ret

Weevil:
    ld a, [wScreen]
    and a
    ret nz
    ld hl, wClock
    inc [hl]
    ld a, [hl]
    and 15
    ret nz
    ld a, [wBug]
    ld c, a
    ld a, [wLength]
    and a
    jr z, .wander
    ld a, [wPos]
    xor c
    and 15
    jr z, .vertical
    ld a, [wPos]
    and 15
    ld b, a
    ld a, c
    and 15
    cp b
    ld a, c
    jr nc, .left
    jr .right
.vertical
    ld a, [wPos]
    cp c
    ld a, c
    jr nc, .down
    jr .up
.wander
    ld a, [wClock]
    swap a
    and 3
    jr z, .wanderUp
    dec a
    jr z, .wanderDown
    dec a
    ld a, c
    jr z, .left
.right
    inc a
    jr .test
.left
    dec a
    jr .test
.wanderUp
    ld a, c
.up
    sub 16
    jr .test
.wanderDown
    ld a, c
.down
    add 16
.test
    ld h, HIGH(wField)
    ld l, a
    ld a, [hl]
    cp SILK
    jr z, .cut
    and a
    ret nz
    ld a, l
    ld [wBug], a
    ld a, $18
    jp Tone
.cut
    ld hl, wField
.clear
    ld a, [hl]
    cp SILK
    jr nz, .skip
    ld [hl], SOIL
.skip
    inc l
    jr nz, .clear
    xor a
    ld [wLength], a
    ld [wArmed], a
    ld [wPhase], a
    ld a, [wAnchor]
    ld [wPos], a
    ld hl, wChance
    dec [hl]
    ld a, $60
Tone:
    ldh [$FF13], a
    ld a, $81
    ldh [$FF11], a
    ld a, $92
    ldh [$FF12], a
    ld a, $87
    ldh [$FF14], a
    ret

; Prepare two field rows before VBlank. Only the short VRAM copy runs in VBlank.
PrepareRows:
    ld a, [wRow]
    ld [wRenderStart], a
    swap a
    ld h, HIGH(wField)
    ld l, a
    ld de, wRenderTiles
    ld b, 32
.next
    ld a, [hl]
    ld c, a
    and a
    jr z, .soil
    cp SILK
    jr nz, .store
    push bc
    push hl
    call StrandTile
    pop hl
    pop bc
    jr .store
.soil
    ; Most tiles are plain earth, with occasional cracks and small clods.
    ld a, l
    swap a
    xor l
    rrca
    xor l
    and 15
    cp 2
    ld a, SOIL
    jr nc, .store
    ld a, l
    and 1
    add 45
.store
    ld [de], a
    push hl
    ld hl, wRenderAttrs - wRenderTiles
    add hl, de
    ld [hl], c
    pop hl
    inc de
    inc l
    dec b
    jr nz, .next
    ld hl, wRow
    ld a, [hl]
    add 2
    and 15
    ld [hl], a
    ret

; Select a line tile with arms toward the anchor or neighboring silk.
StrandTile:
    ld b, l
    ld c, 0
    ld a, b
    sub 16
    call StrandNeighbor
    ld a, b
    inc a
    call StrandNeighbor
    ld a, b
    add 16
    call StrandNeighbor
    ld a, b
    dec a
    call StrandNeighbor
    ld a, c
    add 25
    ret

StrandNeighbor:
    sla c
    ld l, a
    ld a, [hl]
    cp SILK
    jr z, .join
    ld a, [wAnchor]
    cp l
    ret nz
.join
    inc c
    ret

DrawRows:
    ld a, [wRenderStart]
    inc a
    ld e, a
    ld d, 0
    REPT 5
        sla e
        rl d
    ENDR
    ld a, d
    add $98
    ld d, a
    inc e
    inc e
    push de
    ld hl, wRenderTiles
    call CopyRows
    pop de
    ld a, 1
    ldh [$FF4F], a
    ld hl, wRenderAttrs
    call CopyRows
    xor a
    ldh [$FF4F], a
    ret

CopyRows:
    ld b, 16
.first
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .first
    ld a, e
    add 16
    ld e, a
    jr nc, .secondRow
    inc d
.secondRow
    ld b, 16
.second
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .second
    ret

DrawActors:
    ld a, [wPos]
    ld c, a
    and $F0
    srl a
    add 24
    ld b, a
    ld a, [wPhase]
    ld e, a
    ld a, [wDY]
    call Offset
    ld [$FE00], a
    ld a, c
    and 15
    add a
    add a
    add a
    add 24
    ld b, a
    ld a, [wDX]
    call Offset
    ld [$FE01], a
    ld a, 4
    ld [$FE02], a
    ld a, [wBug]
    ld c, a
    and $F0
    srl a
    add 24
    ld b, a
    ld a, [wScreen]
    and a
    ld a, b
    jr z, .bug
    xor a
.bug
    ld [$FE04], a
    ld [$FE08], a
    ld a, c
    and 15
    add a
    add a
    add a
    add 20
    ld [$FE05], a
    add 8
    ld [$FE09], a
    ld a, 5
    ld [$FE06], a
    ld a, 24
    ld [$FE0A], a
    ld a, [wLength]
    and a
    ld a, 1
    jr z, .bugPalette
    inc a
.bugPalette
    ld [$FE07], a
    ld [$FE0B], a
    ret
Offset:
    ld d, a
    ld a, e
    and a
    ld a, b
    ret z
.subtract
    sub d
    dec e
    jr nz, .subtract
    ld a, [wPhase]
    ld e, a
    ret

DrawPalette:
    ld a, [wContrast]
    and a
    ld a, $80
    ldh [$FF68], a
    ld hl, Colors
    jr z, .palette
    ld hl, Contrast
.palette
    ld b, 32
.pal
    ld a, [hli]
    ldh [$FF69], a
    dec b
    jr nz, .pal
    ret

DrawHUD:
    ld a, [wChance]
    ld b, a
    ld hl, $9810
    ld c, 3
.hearts
    ld a, b
    and a
    jr nz, .filled
    ld a, 3
    jr .heart
.filled
    dec b
    ld a, 6
.heart
    ld [hli], a
    dec c
    jr nz, .hearts
    ld a, [wScreen]
    and a
    ld a, 0
    jr z, .pause
    ld a, 7
    jr .status
.pause
    ld a, [wChance]
    and a
    ld a, 23
    jr z, .status
    ld a, [wPause]
    and a
    ld a, 22
    jr nz, .status
    ld a, 3
.status
    ld [$980D], a
    ld a, [wProgress]
    ld hl, $9807
    ld b, 8
    cp 100
    jr c, .tens
    sub 100
    inc b
.tens
    ld [hl], b
    inc hl
    ld b, 8
.more
    cp 10
    jr c, .digits
    sub 10
    inc b
    jr .more
.digits
    ld [hl], b
    inc hl
    add 8
    ld [hli], a
    ld [hl], 18
    ret

Colors:
    dw $2639, $1D94, $1551, $10ED
    dw $0D04, $11A8, $1E91, $233E
    dw $2639, $1D94, $373D, $67DF
    dw $0CC5, $21CD, $1EDD, $67DF
    dw $0000, $233E, $11D6, $0C87
    dw $0000, $3130, $20AA, $1065
    dw $0000, $1918, $28ED, $1046
Contrast:
    dw $08EC, $1DD7, $32DD, $0887
    dw $08A2, $0DC6, $1F10, $237F
    dw $08EC, $1DD7, $2B9F, $7FFF
    dw $0CC5, $21CD, $1EDD, $67DF
AlphaLabel:
    db 19, 20, 22, 21, 19, 3, 10
FieldLabel:
    db 41, 42, 43, 20, 44

Tiles:
    DW `00000000,`00000000,`00000000,`00000000,`00000000,`00000000,`00000000,`00000000
    DW `00010000,`00333000,`00232000,`20221020,`12221210,`01212200,`00121000,`00010000
    DW `30303030,`03030303,`30303030,`03030303,`30303030,`03030303,`30303030,`03030303
    DW `00000000,`00000000,`00000000,`00000000,`00000000,`00000000,`00000000,`00000000
    DW `00333300,`03111130,`31211113,`31131313,`31131313,`32111123,`03222230,`00333300
    DW `00000000,`00000030,`00000313,`00033123,`03330133,`33000333,`30000303,`00003003
    DW `00000000,`00023300,`00233200,`02333200,`02332200,`00222000,`00000000,`00000000
    DW `00000000,`00000003,`00000033,`30000330,`33003300,`03333000,`00330000,`00000000
    DW `00000000,`00333000,`00303000,`00303000,`00303000,`00333000,`00000000,`00000000
    DW `00000000,`00030000,`00330000,`00030000,`00030000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00003000,`00333000,`00300000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00003000,`00333000,`00003000,`00333000,`00000000,`00000000
    DW `00000000,`00303000,`00303000,`00333000,`00003000,`00003000,`00000000,`00000000
    DW `00000000,`00333000,`00300000,`00333000,`00003000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00300000,`00333000,`00303000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00003000,`00030000,`00030000,`00030000,`00000000,`00000000
    DW `00000000,`00333000,`00303000,`00333000,`00303000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00303000,`00333000,`00003000,`00333000,`00000000,`00000000
    DW `00000000,`03300300,`03303000,`00030000,`00303300,`03003300,`00000000,`00000000
    DW `00000000,`00030000,`00303000,`00333000,`00303000,`00303000,`00000000,`00000000
    DW `00000000,`00300000,`00300000,`00300000,`00300000,`00333000,`00000000,`00000000
    DW `00000000,`00303000,`00303000,`00333000,`00303000,`00303000,`00000000,`00000000
    DW `00000000,`00330000,`00303000,`00330000,`00300000,`00300000,`00000000,`00000000
    DW `00000000,`00303000,`00303000,`00030000,`00303000,`00303000,`00000000,`00000000
    DW `00333300,`03111130,`31222213,`31111113,`31222213,`03333330,`03030300,`00003030
    DW `00000000,`00000000,`00000000,`00023000,`00033000,`00000000,`00000000,`00000000
    DW `00000000,`00000000,`00000000,`23323000,`33233000,`00000000,`00000000,`00000000
    DW `00000000,`00000000,`00000000,`00023000,`00033000,`00032000,`00023000,`00033000
    DW `00000000,`00000000,`00000000,`23323000,`33233000,`00032000,`00023000,`00033000
    DW `00000000,`00000000,`00000000,`00023323,`00033233,`00000000,`00000000,`00000000
    DW `00000000,`00000000,`00000000,`23323323,`33233233,`00000000,`00000000,`00000000
    DW `00000000,`00000000,`00000000,`00023323,`00033233,`00032000,`00023000,`00033000
    DW `00000000,`00000000,`00000000,`23323323,`33233233,`00032000,`00023000,`00033000
    DW `00023000,`00033000,`00032000,`00023000,`00033000,`00000000,`00000000,`00000000
    DW `00023000,`00033000,`00032000,`23323000,`33233000,`00000000,`00000000,`00000000
    DW `00023000,`00033000,`00032000,`00023000,`00033000,`00032000,`00023000,`00033000
    DW `00023000,`00033000,`00032000,`23323000,`33233000,`00032000,`00023000,`00033000
    DW `00023000,`00033000,`00032000,`00023323,`00033233,`00000000,`00000000,`00000000
    DW `00023000,`00033000,`00032000,`23323323,`33233233,`00000000,`00000000,`00000000
    DW `00023000,`00033000,`00032000,`00023323,`00033233,`00032000,`00023000,`00033000
    DW `00023000,`00033000,`00032000,`23323323,`33233233,`00032000,`00023000,`00033000
    DW `00000000,`00333000,`00300000,`00330000,`00300000,`00300000,`00000000,`00000000
    DW `00000000,`00333000,`00030000,`00030000,`00030000,`00333000,`00000000,`00000000
    DW `00000000,`00333000,`00300000,`00330000,`00300000,`00333000,`00000000,`00000000
    DW `00000000,`00330000,`00303000,`00303000,`00303000,`00330000,`00000000,`00000000
    DW `00000000,`00010000,`00021000,`00120000,`01011000,`00002100,`00000000,`00000000
    DW `00000000,`00000000,`00100000,`00000000,`00000100,`00001100,`00000000,`00000000
TilesEnd:

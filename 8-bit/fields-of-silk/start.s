.export _render, _flood, _waitFrame, _copyRow, _frame, __STARTUP__: absolute = 1
.import _main, _renderRow, _floodSeed, _hud, _rowAddress, _soilColor
.importzp sp

.segment "HEADER"
.byte "NES", $1A, 1, 1, 0, 0
.res 8, 0

.segment "ZEROPAGE"
_frame: .res 1
candidate: .res 2
current: .res 2
head: .res 1
tail: .res 1
overflow: .res 1

.segment "BSS"
queueLo: .res 64
queueHi: .res 64

.segment "STARTUP"
reset:
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$ff
    txs
    inx
    stx $2000
    stx $2001
    stx $4010
    bit $2002
:
    bit $2002
    bpl :-
    txa
:
    sta $00,x
    sta $100,x
    sta $200,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x
    inx
    bne :-
:
    bit $2002
    bpl :-
    lda #$00
    sta sp
    lda #$08
    sta sp+1
    jmp _main

nmi:
    inc _frame
irq:
    rti

_waitFrame:
    lda _frame
:
    cmp _frame
    beq :-
    rts

; Uses the address already set by C. Copy one row within the vblank budget.
_copyRow:
    ldx #0
:
    lda _renderRow,x
    sta $2007
    inx
    cpx #28
    bne :-
    rts

; All active-screen PPU and OAM writes fit in a single vblank.
_render:
    jsr _waitFrame
    lda #0
    sta $2003
    lda #2
    sta $4014
    bit $2002
    lda _rowAddress+1
    sta $2006
    lda _rowAddress
    sta $2006
    jsr _copyRow
    lda #$20
    sta $2006
    lda #$28
    sta $2006
    ldx #0
:
    lda _hud,x
    sta $2007
    inx
    cpx #19
    bne :-
    lda #$3f
    sta $2006
    lda #1
    sta $2006
    lda _soilColor
    sta $2007
    bit $2002
    lda #0
    sta $2005
    sta $2005
    rts

 ; Mark dry tiles reachable from the weevil. The corn border bounds the search.
_flood:
    lda #0
    sta head
    sta tail
    sta overflow
    lda _floodSeed
    sta candidate
    lda _floodSeed+1
    sta candidate+1
    jsr enqueue
loop:
    ldx head
    cpx tail
    beq done
    lda queueLo,x
    sta current
    lda queueHi,x
    sta current+1
    inx
    txa
    and #63
    sta head
    .repeat 4, I
        .if I = 0
            OFFSET .set 1
        .elseif I = 1
            OFFSET .set -1
        .elseif I = 2
            OFFSET .set 32
        .else
            OFFSET .set -32
        .endif
        clc
        lda current
        adc #<OFFSET
        sta candidate
        lda current+1
        adc #>OFFSET
        sta candidate+1
        jsr enqueue
    .endrepeat
    jmp loop
done:
    lda overflow
    ldx #0
    rts

enqueue:
    ldy #0
    lda (candidate),y
    bne seen
    lda #2
    sta (candidate),y
    ldx tail
    inx
    txa
    and #63
    cmp head
    beq full
    ldx tail
    sta tail
    lda candidate
    sta queueLo,x
    lda candidate+1
    sta queueHi,x
seen:
    rts
full:
    lda #1
    sta overflow
    rts

.segment "VECTORS"
.word nmi, reset, irq

.segment "CHARS"
.incbin "tiles.chr"

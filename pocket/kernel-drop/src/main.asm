; =============================================================================
; Kernel Drop - Chapter 1 of Kettle Classics (Pocket / Game Boy)
; (c) 2026 Kettle Forge Studios. Original code, art and sound.
;
; Step 3: seeds.
;   Six seeds sit on the soil, each with a thirst gauge above it. The soil
;   slowly dries them out. Keep a seed's water in its "just right" zone (the
;   ticks on its gauge) long enough and it SPROUTS. Too dry for too long and it
;   WILTS; too wet for too long and it FLOODS. When every seed is done, you get
;   a result; press Start to play again.
; Step 2: the rain cloud.
;   Title screen: Kip bobs, A = hop, Start = play.
;   Play screen:  D-pad left/right moves the cloud, up/down raises/lowers it
;                 (higher = drops scatter more). A = one drop. Hold B = pour.
;                 After a long pour the cloud is tired for a moment (turns pale).
;                 Start = pause. Select = moisture view (exact water numbers).
;
; Real Game Boy rules we follow:
;   - Video memory is only changed while the screen is off, or right after the
;     VBlank interrupt (the short break between frames).
;   - Sprites are moved with OAM DMA from a copy in work RAM.
; =============================================================================

INCLUDE "hardware.inc"
INCLUDE "charmap.inc"

; --- Title screen -------------------------------------------------------------
DEF KIP_X       EQU 72     ; Kip's position on the title screen (pixels)
DEF KIP_Y       EQU 88
DEF HOP_HEIGHT  EQU 12     ; how many pixels a hop lifts Kip

; --- Play screen --------------------------------------------------------------
DEF CLOUD_MIN_X EQU 0      ; cloud can move from the left edge...
DEF CLOUD_MAX_X EQU 144    ; ...to the right edge (screen 160 - cloud 16)
DEF CLOUD_TOP   EQU 16     ; highest the cloud can go (smallest Y)
DEF CLOUD_LOW   EQU 56     ; lowest the cloud can go
DEF CLOUD_START_X EQU 72
DEF CLOUD_START_Y EQU 32
DEF SOIL_ROW    EQU 16     ; soil starts at background row 16 (= pixel 128)
DEF SOIL_Y      EQU SOIL_ROW * 8
DEF MAX_DROPS   EQU 8      ; up to 8 drops in the air at once
DEF DROP_SPEED  EQU 2      ; pixels per frame
DEF A_DELAY     EQU 8      ; frames between single drops (A)
DEF POUR_EVERY  EQU 4      ; while pouring (B), one drop every 4 frames
DEF POUR_LIMIT  EQU 48     ; pour this many frames in a row...
DEF TIRED_TIME  EQU 90     ; ...and the cloud rests this long (1.5 seconds)

; --- Seeds --------------------------------------------------------------------
DEF NUM_SEEDS   EQU 6
DEF SEED_SIZE   EQU 8      ; bytes per seed in wSeeds (see below)
DEF SEED_COL0   EQU 1      ; first seed at background column 1 (x = 8)...
DEF SEED_COL_STEP EQU 3    ; ...then every 3 columns (24 pixels)
DEF PLOT_WIDTH  EQU 16     ; a drop landing within 16 pixels of a seed counts
DEF SEED_ROW    EQU SOIL_ROW - 1   ; seeds sit just above the soil
DEF GAUGE_ROW   EQU SOIL_ROW - 2   ; thirst gauges above the seeds
DEF NUMBER_ROW  EQU SOIL_ROW - 3   ; moisture numbers above the gauges
DEF WATER_MAX   EQU 63     ; water level 0-63 (the gauge shows water / 8)
DEF WATER_START EQU 16     ; seeds start a little dry
DEF DROP_WATER  EQU 4      ; each drop adds this much
DEF DRY_EVERY   EQU 20     ; soil loses 1 water every 20 frames (3 per second)
DEF ZONE_LOW    EQU 24     ; "just right" zone for a normal kernel...
DEF ZONE_HIGH   EQU 47     ; ...(gauge levels 3-5, the ticks)
DEF GROW_TIME   EQU 240    ; frames in the zone to sprout (4 seconds)
DEF WILT_TIME   EQU 180    ; frames at zero water before wilting (3 seconds)
DEF FLOOD_TIME  EQU 150    ; frames above the zone before flooding (2.5 s)
DEF GOOD_RESULT EQU 4      ; sprout at least 4 of 6 to clear the stage

; Seed states
DEF SEED_GROWING  EQU 0
DEF SEED_SPROUTED EQU 1
DEF SEED_WILTED   EQU 2
DEF SEED_FLOODED  EQU 3

; Offsets inside one seed's 8 bytes
DEF S_STATE  EQU 0
DEF S_WATER  EQU 1
DEF S_GROW   EQU 2         ; frames spent in the zone
DEF S_DRY    EQU 3         ; frames spent at zero water
DEF S_SOGGY  EQU 4         ; frames spent above the zone

; Game states
DEF STATE_TITLE EQU 0
DEF STATE_PLAY  EQU 1

; Sprite slots in the sprite table (each slot is 4 bytes)
DEF SLOT_MAIN   EQU 0      ; slots 0-3: Kip (title) or the cloud (play)
DEF SLOT_DROPS  EQU 4      ; slots 4-11: water drops

; =============================================================================
; Memory we use (work RAM). Fixed addresses so automatic tests can read them.
; =============================================================================
SECTION "Game state", WRAM0[$C000]
wBootMarker::  db  ; $C000: $42 once start-up finished (tests check this)
wJoyHeld::     db  ; $C001: buttons held right now (bits: see hardware.inc)
wJoyPressed::  db  ; $C002: buttons that went down THIS frame
wFrameCount::  db  ; $C003: counts up every frame (60 per second)
wHopTimer::    db  ; $C004: > 0 while Kip is in the air (title screen)
wGameState::   db  ; $C005: STATE_TITLE or STATE_PLAY
wCloudX::      db  ; $C006: cloud left edge (pixels)
wCloudY::      db  ; $C007: cloud top edge (pixels)
wPaused::      db  ; $C008: 1 = paused
wMoistureView::db  ; $C009: 1 = show exact moisture numbers (step 3)
wDropDelay::   db  ; $C00A: frames until A can drop again
wPourTimer::   db  ; $C00B: how long B has been held (while pouring)
wTiredTimer::  db  ; $C00C: > 0 while the cloud rests after a long pour
wActiveDrops:: db  ; $C00D: how many drops are in the air (tests read this)
wRandom::      db  ; $C00E: random number seed
wMsgDirty::    db  ; $C00F: 1 = the message line needs redrawing next VBlank
wDrops::       ds MAX_DROPS * 2  ; $C010: each drop = Y, X (Y = 0 means unused)
wSeeds::       ds NUM_SEEDS * SEED_SIZE ; $C020: 6 seeds x 8 bytes
wGameOver::    db  ; $C050: 1 = every seed is done (result showing)
wSprouted::    db  ; $C051: how many seeds sprouted
wDryTick::     db  ; $C052: counts frames until the soil dries a little more
wMsgPtr::      dw  ; $C053: which text the message line shows
wBgDirty::     db  ; $C055: 1 = seed tiles need copying next VBlank
; Tiles waiting to be copied to the screen at the next VBlank, per seed:
wSeedTiles::   ds NUM_SEEDS * 4 ; $C056: tens digit, ones digit, gauge, seed
wStateEnd::

; A copy of the sprite table. We edit it any time; the VBlank interrupt copies
; it into the real sprite table with OAM DMA. DMA needs a 256-byte boundary.
SECTION "Shadow OAM", WRAM0, ALIGN[8]
ShadowOAM::    ds 4 * 40  ; 40 sprites x 4 bytes (Y, X, tile, flags)

; High RAM: the only memory the CPU can use while OAM DMA runs.
SECTION "OAM DMA code", HRAM
hOAMDMA::      ds 10      ; size of OAMDMARoutine (checked below)

; =============================================================================
; Cartridge header. rgbfix fills in the title and checksums when we build.
; No Nintendo logo on purpose: Kernelcade doesn't need it.
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
    ldh [rNR52], a          ; sound off for now (sound comes in a later step)

    call ScreenOff

    ; Copy all our tile pictures into video memory.
    ld hl, VRAM_TILES
    ld de, Tiles
    ld bc, TilesEnd - Tiles
    call MemCopy

    ; Clear all game variables.
    ld hl, wBootMarker
    ld bc, wStateEnd - wBootMarker
    xor a
    call MemFill
    ld a, $5A
    ld [wRandom], a         ; any starting seed

    ; Clear our sprite table copy, then copy the DMA routine into high RAM.
    call ClearSprites
    ld hl, hOAMDMA
    ld de, OAMDMARoutine
    ld bc, OAMDMARoutineEnd - OAMDMARoutine
    call MemCopy

    call DrawTitleScreen

    ; Shades: colour 0 = lightest ... colour 3 = darkest.
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a
    ld a, %01010000         ; pale palette for the tired cloud
    ldh [rOBP1], a
    xor a
    ldh [rSCX], a
    ldh [rSCY], a

    ; Turn on the VBlank interrupt and the screen.
    ld a, IEF_VBLANK
    ldh [rIE], a
    xor a
    ldh [rIF], a
    call ScreenOn

    ld a, $42
    ld [wBootMarker], a     ; start-up finished (for automatic tests)
    ei

; =============================================================================
; Main loop. Runs once per frame.
; First: quick video memory jobs (we just woke up in VBlank, so it's safe).
; Then:  read buttons and update the current screen.
; =============================================================================
MainLoop:
    halt                    ; sleep until the next VBlank interrupt

    ; --- VBlank jobs (must be quick) ---
    ld a, [wBgDirty]
    and a
    call nz, CopySeedTiles
    ld a, [wMsgDirty]
    and a
    call nz, DrawMessage

    ; --- Game logic ---
    call ReadJoypad
    call NextRandom
    ld a, [wGameState]
    cp STATE_PLAY
    jr z, .play
    call UpdateTitle
    jr MainLoop
.play
    call UpdatePlay
    jr MainLoop

; =============================================================================
; Title screen
; =============================================================================
UpdateTitle:
    ; Start: begin the game.
    ld a, [wJoyPressed]
    bit PADB_START, a
    jp nz, StartGame

    ; A: hop (if Kip isn't already in the air).
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
    jr z, DrawKip
    dec a
    ld [wHopTimer], a
    ; fall through to DrawKip

; DrawKip: Kip's 4 sprites (2x2 tiles). Height = hop + a gentle 1-pixel bob.
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
    ld c, KIP_X             ; c = Kip's left
    ld d, TILE_KIP          ; d = first of Kip's 4 tiles
    ld e, 0                 ; e = sprite flags (normal palette)
    ld hl, ShadowOAM + SLOT_MAIN * 4
    jp Draw16x16

; StartGame: switch to the play screen.
StartGame:
    call ScreenOff
    call DrawPlayScreen
    call ClearSprites
    ld a, STATE_PLAY
    ld [wGameState], a
    ld a, CLOUD_START_X
    ld [wCloudX], a
    ld a, CLOUD_START_Y
    ld [wCloudY], a
    xor a
    ld [wPaused], a
    ld [wPourTimer], a
    ld [wTiredTimer], a
    ld [wDropDelay], a
    ld [wActiveDrops], a
    ld [wGameOver], a
    ld [wSprouted], a
    ld [wDryTick], a
    ld hl, wDrops
    ld bc, MAX_DROPS * 2
    call MemFill
    call ResetSeeds
    ld de, TextBlank12
    call SetMessage
    call DrawMessage        ; screen is off, so we can draw right away
    call BuildSeedTiles
    call CopySeedTiles
    jp ScreenOn

; ResetSeeds: every seed starts growing, a little dry.
ResetSeeds:
    ld hl, wSeeds
    ld b, NUM_SEEDS
.seed
    ld a, SEED_GROWING
    ld [hli], a             ; S_STATE
    ld a, WATER_START
    ld [hli], a             ; S_WATER
    xor a
    ld c, SEED_SIZE - 2
.zero
    ld [hli], a             ; timers
    dec c
    jr nz, .zero
    dec b
    jr nz, .seed
    ret

; =============================================================================
; Play screen
; =============================================================================
UpdatePlay:
    ; Round over: Start plays again.
    ld a, [wGameOver]
    and a
    jr z, .playing
    ld a, [wJoyPressed]
    bit PADB_START, a
    jp nz, StartGame
    ret
.playing
    ; Start: pause / unpause (the text is drawn at the next VBlank).
    ld a, [wJoyPressed]
    bit PADB_START, a
    jr z, .noPause
    ld a, [wPaused]
    xor 1
    ld [wPaused], a
    ld de, TextPause
    jr nz, .showPause
    ld de, TextBlank12
.showPause
    call SetMessage
.noPause
    ld a, [wPaused]
    and a
    ret nz                  ; paused: nothing moves

    ; Select: moisture view on / off (shown from step 3).
    ld a, [wJoyPressed]
    bit PADB_SELECT, a
    jr z, .noSelect
    ld a, [wMoistureView]
    xor 1
    ld [wMoistureView], a
.noSelect
    call MoveCloud
    call MakeRain
    call MoveDrops
    call UpdateSeeds
    call BuildSeedTiles
    jp DrawPlaySprites

; MoveCloud: D-pad moves the cloud one pixel per frame, inside the limits.
MoveCloud:
    ld a, [wJoyHeld]
    ld b, a
    ld hl, wCloudX
    bit PADB_LEFT, b
    jr z, .notLeft
    ld a, [hl]
    cp CLOUD_MIN_X + 1
    jr c, .notLeft
    dec [hl]
.notLeft
    bit PADB_RIGHT, b
    jr z, .notRight
    ld a, [hl]
    cp CLOUD_MAX_X
    jr nc, .notRight
    inc [hl]
.notRight
    ld hl, wCloudY
    bit PADB_UP, b
    jr z, .notUp
    ld a, [hl]
    cp CLOUD_TOP + 1
    jr c, .notUp
    dec [hl]
.notUp
    bit PADB_DOWN, b
    ret z
    ld a, [hl]
    cp CLOUD_LOW
    ret nc
    inc [hl]
    ret

; MakeRain: A = one drop (with a short delay), hold B = pour.
MakeRain:
    ; Count down the delays.
    ld hl, wDropDelay
    ld a, [hl]
    and a
    jr z, .delayDone
    dec [hl]
.delayDone
    ld hl, wTiredTimer
    ld a, [hl]
    and a
    jr z, .rested
    dec [hl]
.rested
    ; A: single drop.
    ld a, [wJoyPressed]
    bit PADB_A, a
    jr z, .noA
    ld a, [wDropDelay]
    and a
    jr nz, .noA
    ld a, A_DELAY
    ld [wDropDelay], a
    call SpawnDrop
.noA
    ; B held: pour, unless the cloud is tired.
    ld a, [wJoyHeld]
    bit PADB_B, a
    jr nz, .pouring
    xor a
    ld [wPourTimer], a      ; B let go: the pour counter resets
    ret
.pouring
    ld a, [wTiredTimer]
    and a
    ret nz                  ; tired: no rain
    ld hl, wPourTimer
    inc [hl]
    ld a, [hl]
    cp POUR_LIMIT
    jr c, .keepPouring
    xor a                   ; poured too long: rest
    ld [hl], a
    ld a, TIRED_TIME
    ld [wTiredTimer], a
    ret
.keepPouring
    and POUR_EVERY - 1      ; one drop every POUR_EVERY frames
    ret nz
    ; fall through to SpawnDrop

; SpawnDrop: put a new drop under the cloud, if there's a free slot.
; Higher cloud = drops scatter further left/right.
SpawnDrop:
    ld hl, wDrops
    ld b, MAX_DROPS
.find
    ld a, [hl]
    and a                   ; Y = 0 means this slot is free
    jr z, .found
    inc hl
    inc hl
    dec b
    jr nz, .find
    ret                     ; all 8 drops are in the air
.found
    ; Y: just under the cloud.
    ld a, [wCloudY]
    add a, 12
    ld [hli], a
    ; How far drops can scatter, from the cloud's height:
    ;   low (Y >= 44): 0, middle (Y >= 28): 0-3, high: 0-7 pixels.
    ld a, [wCloudY]
    ld c, 0
    cp 44
    jr nc, .gotSpread
    ld c, 3
    cp 28
    jr nc, .gotSpread
    ld c, 7
.gotSpread
    ; X = cloud middle - 4 + random(0..c) - c/2
    ld a, [wRandom]
    and c
    ld b, a
    ld a, c
    srl a
    ld e, a                 ; e = c / 2
    ld a, [wCloudX]
    add a, 4                ; cloud is 16 wide, drop is 8: centre it
    add a, b
    sub e
    ld [hl], a
    ret

; MoveDrops: every drop falls; drops that reach the soil disappear.
MoveDrops:
    ld hl, wDrops
    ld b, MAX_DROPS
    ld c, 0                 ; count of drops still falling
.loop
    ld a, [hl]
    and a
    jr z, .next             ; unused slot
    add a, DROP_SPEED
    cp SOIL_Y - 4
    jr c, .stillFalling
    xor a                   ; hit the soil: the drop is gone...
    ld [hl], a
    push hl
    push bc
    inc hl
    ld a, [hl]              ; ...and whatever seed is under it drinks
    call WaterAt
    pop bc
    pop hl
    jr .next
.stillFalling
    ld [hl], a
    inc c
.next
    inc hl
    inc hl
    dec b
    jr nz, .loop
    ld a, c
    ld [wActiveDrops], a
    ret

; DrawPlaySprites: the cloud (slots 0-3) and the drops (slots 4-11).
DrawPlaySprites:
    ; Tired cloud uses the pale palette (sprite palette 1).
    ld e, 0
    ld a, [wTiredTimer]
    and a
    jr z, .normal
    ld e, OAMF_PAL1
.normal
    ld a, [wCloudY]
    ld b, a
    ld a, [wCloudX]
    ld c, a
    ld d, TILE_CLOUD
    ld hl, ShadowOAM + SLOT_MAIN * 4
    call Draw16x16

    ; Drops: hl now points at slot 4.
    ld de, wDrops
    ld b, MAX_DROPS
.drop
    ld a, [de]              ; Y (0 = unused)
    and a
    jr z, .hidden
    add a, 16               ; sprite table stores Y + 16
    ld [hli], a
    inc de
    ld a, [de]              ; X
    add a, 8                ; ...and X + 8
    ld [hli], a
    inc de
    ld a, TILE_DROP
    ld [hli], a
    xor a
    ld [hli], a
    jr .nextDrop
.hidden
    xor a                   ; Y = 0 puts the sprite off-screen
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    inc de
    inc de
.nextDrop
    dec b
    jr nz, .drop
    ret

; SetMessage: show text de on the message line (drawn at the next VBlank).
SetMessage:
    ld a, e
    ld [wMsgPtr], a
    ld a, d
    ld [wMsgPtr + 1], a
    ld a, 1
    ld [wMsgDirty], a
    ret

; DrawMessage: write the message line (12 letters) in the middle of the screen.
; Only called when video memory is safe: right after VBlank or screen off.
DEF MSG_POS EQU SCRN0 + SCRN_VY * 7 + 4
DrawMessage:
    xor a
    ld [wMsgDirty], a
    ld a, [wMsgPtr]
    ld e, a
    ld a, [wMsgPtr + 1]
    ld d, a
    ld hl, MSG_POS
    jp PrintText

; =============================================================================
; Seeds
; =============================================================================

; WaterAt: a drop landed with its left edge at x = a. If it's over a seed
; that is still growing, that seed gets DROP_WATER more water.
;   Seed i sits at x = 8 + 24*i; its plot is the 16 pixels from x-4 to x+12.
WaterAt:
    add a, 4                ; drop centre is 4 pixels right of its left edge
    sub 4                   ; ...measure from the first plot's left edge (x = 4)
    ret c                   ; left of the first plot
    ld c, 0                 ; c = which seed
.divide                     ; a / 24, counting in c, remainder in a
    cp 24
    jr c, .gotPlot
    sub 24
    inc c
    jr .divide
.gotPlot
    cp PLOT_WIDTH
    ret nc                  ; landed between plots
    ld a, c
    cp NUM_SEEDS
    ret nc                  ; right of the last plot
    call SeedAddress        ; hl = this seed
    ld a, [hl]
    cp SEED_GROWING
    ret nz                  ; already sprouted/wilted/flooded: no effect
    inc hl                  ; S_WATER
    ld a, [hl]
    add a, DROP_WATER
    cp WATER_MAX + 1
    jr c, .store
    ld a, WATER_MAX
.store
    ld [hl], a
    ret

; SeedAddress: hl = wSeeds + c * 8.
SeedAddress:
    ld a, c
    add a, a
    add a, a
    add a, a                ; c * 8
    ld hl, wSeeds
    add a, l
    ld l, a
    ret nc
    inc h
    ret

; UpdateSeeds: drying, growing, wilting and flooding, once per frame.
UpdateSeeds:
    ; Is it time for the soil to dry a little?
    ld hl, wDryTick
    inc [hl]
    ld a, [hl]
    cp DRY_EVERY
    ld e, 0                 ; e = 1 if seeds lose water this frame
    jr c, .noDry
    xor a
    ld [hl], a
    ld e, 1
.noDry
    ld hl, wSeeds
    ld b, NUM_SEEDS
    ld d, 0                 ; d = how many seeds are done (not growing)
.seed
    push hl
    ld a, [hl]              ; S_STATE
    cp SEED_GROWING
    jr z, .growing
    inc d
    jr .next
.growing
    inc hl                  ; S_WATER
    ld a, e
    and a
    jr z, .wet
    ld a, [hl]
    and a
    jr z, .wet
    dec [hl]                ; soil dried a little
.wet
    ld a, [hl]              ; a = water
    ld c, a
    inc hl                  ; S_GROW
    ; --- Too dry? (water = 0) ---
    and a
    jr nz, .notDry
    inc hl                  ; S_DRY
    inc [hl]
    ld a, [hl]
    cp WILT_TIME
    jr c, .next
    ld a, SEED_WILTED
    jr .setState
.notDry
    inc hl                  ; S_DRY
    ld [hl], 0              ; any water resets the dry timer
    dec hl                  ; back to S_GROW
    ; --- Too wet? (above the zone) ---
    ld a, c
    cp ZONE_HIGH + 1
    jr c, .notSoggy
    inc hl
    inc hl                  ; S_SOGGY
    inc [hl]
    ld a, [hl]
    cp FLOOD_TIME
    jr c, .next
    ld a, SEED_FLOODED
    jr .setState
.notSoggy
    push hl
    inc hl
    inc hl                  ; S_SOGGY
    ld [hl], 0
    pop hl                  ; back to S_GROW
    ; --- Just right? (inside the zone) ---
    ld a, c
    cp ZONE_LOW
    jr c, .next             ; a bit dry, but not dying: nothing happens
    inc [hl]                ; S_GROW
    ld a, [hl]
    cp GROW_TIME
    jr c, .next
    ld a, [wSprouted]
    inc a
    ld [wSprouted], a
    ld a, SEED_SPROUTED
.setState
    pop hl
    ld [hl], a              ; S_STATE
    push hl
    inc d
.next
    pop hl
    ld a, l
    add a, SEED_SIZE
    ld l, a
    jr nc, .noCarry
    inc h
.noCarry
    dec b
    jr nz, .seed

    ; Every seed done? Show the result.
    ld a, d
    cp NUM_SEEDS
    ret nz
    ld a, 1
    ld [wGameOver], a
    ld a, [wSprouted]
    cp NUM_SEEDS
    ld de, TextAllSprouted
    jr z, .result
    cp GOOD_RESULT
    ld de, TextStageClear
    jr nc, .result
    ld de, TextTryAgain
.result
    jp SetMessage

; BuildSeedTiles: work out which tiles each seed needs (number, gauge, seed
; picture) and mark them for copying at the next VBlank.
BuildSeedTiles:
    ld hl, wSeeds
    ld de, wSeedTiles
    ld b, NUM_SEEDS
.seed
    ld a, [hli]             ; S_STATE
    ld c, a
    ld a, [hl]              ; S_WATER
    push hl
    push bc
    ld h, a                 ; h = water (kept for the gauge)
    ; Moisture numbers (only in moisture view, and only while growing).
    ld a, [wMoistureView]
    and a
    jr z, .noNumber
    ld a, c
    cp SEED_GROWING
    jr nz, .noNumber
    ld a, h
    ld l, 0                 ; l = tens
.tens
    cp 10
    jr c, .gotTens
    sub 10
    inc l
    jr .tens
.gotTens
    ld b, a                 ; b = ones
    ld a, l
    add a, TILE_DIGIT0
    ld [de], a
    inc de
    ld a, b
    add a, TILE_DIGIT0
    ld [de], a
    inc de
    jr .gauge
.noNumber
    xor a
    ld [de], a
    inc de
    ld [de], a
    inc de
.gauge
    ; Gauge: water / 8 = level 0-7 (blank once the seed is done).
    ld a, c
    cp SEED_GROWING
    ld a, 0
    jr nz, .storeGauge
    ld a, h
    srl a
    srl a
    srl a
    add a, TILE_GAUGE
.storeGauge
    ld [de], a
    inc de
    ; Seed picture: one tile per state (seed, sprout, wilted, flooded).
    ld a, c
    add a, TILE_SEED
    ld [de], a
    inc de
    pop bc
    pop hl
    ld a, l
    add a, SEED_SIZE - 1    ; hl was already one past S_STATE
    ld l, a
    jr nc, .noCarry
    inc h
.noCarry
    dec b
    jr nz, .seed
    ld a, 1
    ld [wBgDirty], a
    ret

; CopySeedTiles: copy wSeedTiles onto the screen (rows NUMBER, GAUGE, SEED).
; Only called when video memory is safe: right after VBlank or screen off.
CopySeedTiles:
    xor a
    ld [wBgDirty], a
    ld de, wSeedTiles
    ld hl, SCRN0 + SCRN_VY * NUMBER_ROW + SEED_COL0
    ld b, NUM_SEEDS
.seed
    push hl
    ld a, [de]              ; tens digit
    inc de
    ld [hli], a
    ld a, [de]              ; ones digit
    inc de
    ld [hl], a
    ld a, l
    add a, SCRN_VY - 1      ; down one row, back one column
    ld l, a
    jr nc, .c1
    inc h
.c1
    ld a, [de]              ; gauge
    inc de
    ld [hl], a
    ld a, l
    add a, SCRN_VY          ; down one row
    ld l, a
    jr nc, .c2
    inc h
.c2
    ld a, [de]              ; seed picture
    inc de
    ld [hl], a
    pop hl
    ld a, l
    add a, SEED_COL_STEP    ; next seed's column
    ld l, a
    jr nc, .c3
    inc h
.c3
    dec b
    jr nz, .seed
    ret

; =============================================================================
; Screens (drawn while the screen is off)
; =============================================================================
DrawTitleScreen:
    call ClearMap
    ld hl, SCRN0 + SCRN_VY * 4 + 4
    ld de, TextTitle
    call PrintText
    ld hl, SCRN0 + SCRN_VY * 6 + 2
    ld de, TextSeries
    call PrintText
    ld hl, SCRN0 + SCRN_VY * 15 + 4
    ld de, TextPressStart
    jp PrintText

DrawPlayScreen:
    call ClearMap
    ; Soil: one row of surface, then one row of dirt, across the screen.
    ld hl, SCRN0 + SCRN_VY * SOIL_ROW
    ld bc, 20
    ld a, TILE_SOIL_TOP
    call MemFill
    ld hl, SCRN0 + SCRN_VY * (SOIL_ROW + 1)
    ld bc, 20
    ld a, TILE_SOIL
    jp MemFill

ClearMap:
    ld hl, SCRN0
    ld bc, SCRN_VY * 32
    xor a
    jp MemFill

; =============================================================================
; Helpers
; =============================================================================

; ScreenOff: wait for VBlank, then turn the screen off (the only safe moment).
ScreenOff:
    ldh a, [rLCDC]
    bit 7, a
    ret z                   ; already off
.wait
    ldh a, [rLY]
    cp 144
    jr c, .wait
    xor a
    ldh [rLCDC], a
    ret

ScreenOn:
    ld a, LCDCF_ON | LCDCF_BLK01 | LCDCF_OBJON | LCDCF_BGON
    ldh [rLCDC], a
    ret

; ClearSprites: hide all 40 sprites in our copy of the sprite table.
ClearSprites:
    ld hl, ShadowOAM
    ld bc, 4 * 40
    xor a
    jp MemFill

; Draw16x16: write a 16x16 picture (4 sprites) into the sprite table copy.
;   b = top, c = left (screen pixels), d = first tile, e = flags,
;   hl = first of 4 sprite slots. Leaves hl just after the 4th slot.
;   The sprite table stores Y + 16 and X + 8.
Draw16x16:
    ld a, b
    add a, 16
    ld b, a                 ; b = Y + 16
    ld a, c
    add a, 8
    ld c, a                 ; c = X + 8
    call .one               ; top-left
    ld a, c
    add a, 8
    ld c, a
    call .one               ; top-right
    ld a, b
    add a, 8
    ld b, a
    ld a, c
    sub 8
    ld c, a
    call .one               ; bottom-left
    ld a, c
    add a, 8
    ld c, a
    ; bottom-right falls into .one
.one
    ld a, b
    ld [hli], a
    ld a, c
    ld [hli], a
    ld a, d
    ld [hli], a
    inc d                   ; next tile for the next part
    ld a, e
    ld [hli], a
    ret

; NextRandom: a simple pseudo-random number that changes every frame.
; seed = seed * 5 + 1 (wraps around at 256).
NextRandom:
    ld a, [wRandom]
    ld b, a
    add a, a
    add a, a
    add a, b                ; a = seed * 5
    inc a
    ld [wRandom], a
    ret

; ReadJoypad: read all 8 buttons into wJoyHeld, and which are new into
; wJoyPressed. The joypad is read in two halves: D-pad, then buttons.
; A "0" bit from the hardware means pressed, so we flip the bits (cpl).
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

; VBlankHandler: runs every frame. Copies the sprite table (OAM DMA) and
; counts frames.
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

; =============================================================================
; Text (letters become tile numbers through charmap.inc)
; =============================================================================
TextTitle:      db "KERNEL DROP", $FF
TextSeries:     db "KETTLE CLASSICS", $FF
TextPressStart: db "PRESS START", $FF
; Message line texts are 12 characters so they fully replace each other.
TextPause:       db "   PAUSE    ", $FF
TextBlank12:     db "            ", $FF
TextAllSprouted: db "ALL SPROUTED", $FF
TextStageClear:  db "STAGE CLEAR ", $FF
TextTryAgain:    db " TRY AGAIN  ", $FF

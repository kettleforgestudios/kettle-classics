; =============================================================================
; The game (pulled into main.asm with INCLUDE)
;
; Play screen:  D-pad left/right moves the cloud, up/down raises/lowers it
;               (higher = drops scatter more). A = one drop. Hold B = pour.
;               After a long pour the cloud is tired for a moment (turns pale).
;               Start = pause. Select = moisture view (exact water numbers).
; Six seeds sit on the soil, each with a thirst gauge above it. The soil slowly
; dries them out. Keep a seed's water in its "just right" zone (the ticks on its
; gauge) long enough and it SPROUTS. Too dry for too long and it WILTS; too wet
; for too long and it FLOODS. Sprout 4 of 6 to clear the stage.
; =============================================================================

; -----------------------------------------------------------------------------
; Stage data
; -----------------------------------------------------------------------------
; Seed types: zone low, zone high, water lost per drying, flood time (frames).
; The gauge pictures' ticks (art/make_gfx.py, ZONES) show the same zones.
SeedTypes:
    db 24, 47, 1, 150       ; TYPE_NORMAL
    db 32, 55, 2, 180       ; TYPE_THIRSTY: wants more, drinks twice as fast
    db 16, 31, 1,  90       ; TYPE_DELICATE: wants little, floods quickly
    db 24, 39, 1, 150       ; TYPE_KIP: a narrow zone

DEF S_N EQU TYPE_NORMAL     ; short names for the table below
DEF S_T EQU TYPE_THIRSTY
DEF S_D EQU TYPE_DELICATE
DEF S_K EQU TYPE_KIP
DEF TW_SUN EQU 1 << TWISTB_SUN
DEF TW_WIND EQU 1 << TWISTB_WIND
DEF TW_CROWS EQU 1 << TWISTB_CROWS
DEF TW_PUDDLES EQU 1 << TWISTB_PUDDLES

; Story stages (STAGE_SIZE = 13 bytes each):
;   name text, hint text, twists, frames between dryings, 6 seed types, Kip's seed
StoryStages:
    dw TextStage1, TextHint1
    db 0, 20
    db S_N, S_N, S_N, S_N, S_N, S_N, $FF
    dw TextStage2, TextHint2
    db TW_SUN, 20
    db S_N, S_T, S_N, S_N, S_T, S_N, $FF
    dw TextStage3, TextHint3
    db TW_WIND, 20
    db S_D, S_N, S_D, S_N, S_D, S_N, $FF
    dw TextStage4, TextHint4
    db TW_CROWS, 20
    db S_N, S_T, S_D, S_N, S_T, S_D, $FF
    dw TextStage5, TextHint5
    db TW_PUDDLES | TW_SUN, 20
    db S_D, S_N, S_D, S_D, S_N, S_D, $FF
    dw TextStage6, TextHint6
    db TW_SUN | TW_WIND | TW_CROWS, 20
    db S_N, S_T, S_D, S_K, S_T, S_N, 3      ; seed 3 (under the cloud's start) is Kip's
StoryStagesEnd:
    ASSERT StoryStagesEnd - StoryStages == STAGE_SIZE * STORY_STAGES

PURGE S_N, S_T, S_D, S_K, TW_SUN, TW_WIND, TW_CROWS, TW_PUDDLES

; Endless: which twists may appear, for stage 1, 2, 3, 4 and 5+.
EndlessTwists:
    db 0, %0001, %0011, %0111, %1111

TextStage1: db " FIRST RAIN ", $FF
TextHint1:  db "WATER 3 OF 5", $FF
TextStage2: db " SUNNY DAY  ", $FF
TextHint2:  db "SUN DRIES UP", $FF
TextStage3: db "   WINDY    ", $FF
TextHint3:  db "AIM UPWIND  ", $FF
TextStage4: db "   CROWS    ", $FF
TextHint4:  db "SPLASH THEM ", $FF
TextStage5: db "  PUDDLES   ", $FF
TextHint5:  db "WET SPREADS ", $FF
TextStage6: db "  KIP SEED  ", $FF
TextHint6:  db "SPROUT KIP! ", $FF

; -----------------------------------------------------------------------------
; Starting a stage
; -----------------------------------------------------------------------------

; StartStage: set up stage wStage of mode wMode and show its name. Used for
; the first stage, the next one, and trying a stage again.
StartStage:
    call ScreenOff
    call ClearSprites
    call DrawPlayScreen
    ld a, STATE_PLAY
    ld [wGameState], a
    ; Clear every round variable (wRoundStart ... wRoundEnd in main.asm).
    ld hl, wRoundStart
    ld bc, wRoundEnd - wRoundStart
    xor a
    call MemFill
    ld [wTuneTimer], a      ; stop any tune still playing
    ld a, CLOUD_START_X
    ld [wCloudX], a
    ld a, CLOUD_START_Y
    ld [wCloudY], a
    ld a, INTRO_TIME
    ld [wIntroTimer], a
    ld a, SUN_TIME
    ld [wSunTimer], a
    ld a, 1
    ld [wWindTimer], a      ; a windy stage picks its first wind right away
    ld a, CROW_WAIT
    ld [wCrowTimer], a
    call StopMusic
    call LoadStage
    ; The screen is off, so everything can be drawn right now.
    call DrawMessage
    call DrawMessage2
    call BuildSeedTiles
    call CopySeedTiles
    call BuildHud
    call DrawHud
    call DrawPlaySprites
    QUEUE_SFX SFXB_START
    jp ScreenOn

; LoadStage: seed types, twists, drying speed and the stage's texts.
LoadStage:
    ld a, NUM_SEEDS
    ld [wSeedCount], a
    ld a, [wMode]
    and a
    jr nz, .endless
    ; Story: hl = StoryStages + stage * STAGE_SIZE
    ld hl, StoryStages
    ld a, [wStage]
    and a
    jr nz, .laterStory
    ld a, 5                 ; First Rain gives the player more room to aim.
    ld [wSeedCount], a
    jr .found
.laterStory
    ld b, a
    ld de, STAGE_SIZE
.mul
    add hl, de
    dec b
    jr nz, .mul
.found
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    push hl
    call SetMessage         ; stage name
    pop hl
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    push hl
    call SetMessage2        ; hint
    pop hl
    ld a, [hli]
    ld [wStageFlags], a
    ld a, [hli]
    ld [wStageDry], a
    ld de, wSeeds + S_TYPE
    ld b, NUM_SEEDS
.types
    ld a, [hli]
    ld [de], a
    ld a, e
    add a, SEED_SIZE
    ld e, a
    dec b
    jr nz, .types
    ld a, [hl]
    ld [wKipSeed], a
    jr .fillWater

.endless
    ; Twists: none on stage 1, then a random mix that grows (EndlessTwists).
    ld a, [wStage]
    cp 4
    jr c, .few
    ld a, 4
.few
    ld hl, EndlessTwists
    ADD_A_TO_HL
    ld b, [hl]
    call NextRandom
    and b
    ld [wStageFlags], a
    ; Drying: every 22 frames on stage 1, one frame faster each stage, never
    ; faster than every 12 frames.
    ld a, [wStage]
    ld b, a
    ld a, 22
    sub b
    jr c, .fastest
    cp 12
    jr nc, .dry
.fastest
    ld a, 12
.dry
    ld [wStageDry], a
    ; Random seed types: normal, thirsty or delicate.
    ld hl, wSeeds + S_TYPE
    ld b, NUM_SEEDS
.randomType
    call NextRandom
    and 3
    cp 3
    jr nz, .storeType
    xor a                   ; 3 -> normal (so normal comes up more often)
.storeType
    ld [hl], a
    ld a, l
    add a, SEED_SIZE
    ld l, a
    dec b
    jr nz, .randomType
    ld a, $FF
    ld [wKipSeed], a
    ; "  STAGE nn  " built in RAM, then "  ENDLESS   ".
    ld hl, wMsgBuf
    ld de, TextStageNum
    ld bc, 13
    call MemCopy
    ld a, [wStage]
    inc a
    call TwoDigits
    ld hl, wMsgBuf + 8
    ld [hl], b
    inc hl
    ld [hl], a
    ld de, wMsgBuf
    call SetMessage
    ld de, TextEndless
    call SetMessage2

.fillWater
    ; Every seed starts growing and a little dry (the rest was cleared).
    ld hl, wSeeds + S_WATER
    ld b, NUM_SEEDS
.water
    ld [hl], WATER_START
    ld a, l
    add a, SEED_SIZE
    ld l, a
    dec b
    jr nz, .water
    ret

; DrawPlayScreen: soil across the bottom (screen off only).
DrawPlayScreen:
    call ClearMap
    ld hl, SCRN0 + SCRN_VY * SOIL_ROW
    ld bc, 20
    ld a, TILE_SOIL_TOP
    call MemFill
    ld hl, SCRN0 + SCRN_VY * (SOIL_ROW + 1)
    ld bc, 20
    ld a, TILE_SOIL
    jp MemFill

; -----------------------------------------------------------------------------
; The score bar (row 0) and the wind and sun pictures (rows 1-2)
; -----------------------------------------------------------------------------

; BuildHud: prepare "STAGE nn SCORE sssss" in wHudBuf; drawn at the next VBlank.
BuildHud:
    ld hl, wHudBuf
    ld de, TextHud
    ld bc, 20
    call MemCopy
    ld a, [wStage]
    inc a                   ; players count stages from 1
    call TwoDigits
    ld hl, wHudBuf + 6
    ld [hl], b
    inc hl
    ld [hl], a
    ld hl, wHudBuf + 15
    ld de, wScore
    call PrintScore
    ld a, 1
    ld [wHudDirty], a
    ret

; DrawHud: copy the score bar, the wind arrows and the sun onto the screen.
; Only called when video memory is safe (VBlank or screen off).
DrawHud:
    xor a
    ld [wHudDirty], a
    ld hl, SCRN0
    ld de, wHudBuf
    ld b, 20
.copy
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .copy
    ; Wind: two arrows at the start of row 1 (blank when calm).
    ld hl, SCRN0 + SCRN_VY
    ld a, [wHudWind]
    ld [hli], a
    ld [hl], a
    ; Sun: 2x2 tiles in the top-right corner (rows 1-2), or blank.
    ld hl, SCRN0 + SCRN_VY + 18
    ld a, [wSunOut]
    and a
    jr z, .noSun
    ld a, TILE_SUN
    ld [hli], a
    inc a
    ld [hl], a
    inc a
    ld hl, SCRN0 + SCRN_VY * 2 + 18
    ld [hli], a
    inc a
    ld [hl], a
    ret
.noSun
    ld [hli], a
    ld [hl], a
    ld hl, SCRN0 + SCRN_VY * 2 + 18
    ld [hli], a
    ld [hl], a
    ret

; AddScore: add a (BCD, in tens of points) to the score, and redraw the bar.
AddScore:
    ld hl, wScore
    ld b, a
    ld a, [hl]
    add a, b
    daa                     ; fix the result back into two decimal digits
    ld [hli], a
    ld a, [hl]
    adc a, 0                ; carry into the high byte
    daa
    ld [hl], a
    jr nc, .ok
    ld a, $99               ; went past 9999: stay at the maximum
    ld [hld], a
    ld [hl], a
.ok
    jp BuildHud

; -----------------------------------------------------------------------------
; Every frame on the play screen
; -----------------------------------------------------------------------------
UpdatePlay:
    ; --- Stage intro: the name shows and nothing moves. Start skips it. ---
    ld a, [wIntroTimer]
    and a
    jr z, .noIntro
    dec a
    ld b, a
    ld a, [wJoyPressed]
    bit PADB_START, a
    jr z, .wait
    ld b, 0
.wait
    ld a, b
    ld [wIntroTimer], a
    and a
    jp nz, DrawPlaySprites
    ; Intro over: clear the texts and start the music.
    ld de, TextBlank12
    call SetMessage
    ld de, TextBlank12
    call SetMessage2
    ld hl, SongPlay
    jp StartMusic

.noIntro
    ; --- Round over: Start goes on (next stage, retry, ending or title). ---
    ld a, [wGameOver]
    and a
    jr z, .playing
    ld a, [wJoyPressed]
    bit PADB_START, a
    jp nz, NextAfterResult
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
    QUEUE_SFX SFXB_PAUSE
    call SetMessage
    xor a
    ldh [rNR30], a          ; hush the music (it carries on with the next note)
.noPause
    ld a, [wPaused]
    and a
    ret nz                  ; paused: nothing moves

    ; Select: moisture view on / off.
    ld a, [wJoyPressed]
    bit PADB_SELECT, a
    jr z, .noSelect
    ld a, [wMoistureView]
    xor 1
    ld [wMoistureView], a
.noSelect
    call MoveCloud
    call MakeRain
    call UpdateWind
    call MoveDrops
    call UpdateSun
    call UpdateCrow
    call UpdateSeeds
    call BuildSeedTiles
    jp DrawPlaySprites

; NextAfterResult: Start was pressed on the result.
NextAfterResult:
    ld a, [wMode]
    and a
    jr nz, .endless
    ld a, [wResult]
    and a
    jp z, StartStage        ; Story, not cleared: try the same stage again
    ld a, [wStage]
    cp STORY_STAGES - 1
    jp nc, EnterEnding      ; that was the last stage
    inc a
    ld [wStage], a
    jp StartStage
.endless
    ld a, [wResult]
    and a
    jr z, .over
    ld a, [wStage]
    cp 98                   ; the bar shows two digits: stay on stage 99
    jr nc, .same
    inc a
    ld [wStage], a
.same
    jp StartStage
.over
    call UpdateHiScore
    jp EnterTitle

; -----------------------------------------------------------------------------
; Cloud and rain
; -----------------------------------------------------------------------------

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
    QUEUE_SFX SFXB_TIRED
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
    call NextRandom
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

; MoveDrops: every drop falls (and drifts in the wind). A drop that hits the
; crow scares it away; a drop that reaches the soil waters the seed below.
MoveDrops:
    ld hl, wDrops
    ld b, MAX_DROPS
    ld c, 0                 ; count of drops still falling
.loop
    ld a, [hl]
    and a
    jr z, .next             ; unused slot
    add a, DROP_SPEED
    ld [hl], a
    call DropWind
    call DropHitsCrow
    jr c, .gone
    ld a, [hl]
    cp SOIL_Y - 4
    jr c, .stillFalling
    push hl                 ; hit the soil: whatever seed is under it drinks
    push bc
    inc hl
    ld a, [hl]
    call WaterAt
    pop bc
    pop hl
.gone
    ld [hl], 0              ; Y = 0: the drop is gone
    jr .next
.stillFalling
    inc c
.next
    inc hl
    inc hl
    dec b
    jr nz, .loop
    ld a, c
    ld [wActiveDrops], a
    ret

; DropWind: hl = a drop. Every 4th frame the wind pushes it 1 pixel sideways,
; but never off the screen. Keeps every register except a.
DropWind:
    ld a, [wWind]
    and a
    ret z                   ; calm
    ld a, [wFrameCount]
    and 3
    ret nz
    push hl
    inc hl                  ; X
    ld a, [wWind]           ; +1 or -1 ($FF)
    add a, [hl]
    cp 153                  ; 153-255 = went past an edge (or wrapped below 0)
    jr nc, .edge
    ld [hl], a
.edge
    pop hl
    ret

; DropHitsCrow: hl = a drop. Returns carry set if it hit the crow (which then
; flies away). Keeps hl, b and c.
DropHitsCrow:
    ld a, [wCrowState]
    and a
    ret z                   ; no crow (and a clears carry)
    cp CROW_LEAVE
    jr nc, .miss            ; already leaving
    ; Hit if the drop's middle (its corner + 4) is inside the crow's 16x16 box.
    ld a, [wCrowY]
    ld d, a
    ld a, [hl]
    add a, 4
    sub d
    cp 16
    jr nc, .miss
    ld a, [wCrowX]
    ld d, a
    inc hl
    ld a, [hl]
    dec hl
    add a, 4
    sub d
    cp 16
    jr nc, .miss
    ld a, CROW_LEAVE
    ld [wCrowState], a
    QUEUE_SFX2 SFX2B_SCARE
    scf
    ret
.miss
    and a                   ; carry clear
    ret

; DrawPlaySprites: the cloud (slots 0-3), the drops (4-11), the crow (12-15).
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

    ; Crow: hl now points at slot 12.
    ld a, [wCrowState]
    and a
    jr nz, .crow
    ld b, 4
    jp HideSprites
.crow
    ld a, [wCrowY]
    ld b, a
    ld a, [wCrowX]
    ld c, a
    ld a, [wFrameCount]
    and %00001000           ; flap: switch pictures every 8 frames
    ld d, TILE_CROW
    jr z, .wings
    ld d, TILE_CROW + 4
.wings
    ld a, [wCrowDir]
    and a
    ld e, 0
    jp z, Draw16x16         ; facing right (as drawn)
    ld e, OAMF_XFLIP
    jp Draw16x16Flip        ; facing left: mirrored

; -----------------------------------------------------------------------------
; Twists: sun, wind, crows (puddles are in WaterAt)
; -----------------------------------------------------------------------------

; UpdateSun: the sun comes out and goes away every 5 seconds.
UpdateSun:
    ld a, [wStageFlags]
    bit TWISTB_SUN, a
    ret z
    ld a, [wFrameCount]
    rra
    ret c                   ; only every other frame
    ld hl, wSunTimer
    dec [hl]
    ret nz
    ld [hl], SUN_TIME
    ld a, [wSunOut]
    xor 1
    ld [wSunOut], a
    ld a, 1
    ld [wHudDirty], a       ; the sun is drawn with the score bar
    ret

; UpdateWind: every 4 seconds the wind picks a direction: left or right.
UpdateWind:
    ld a, [wStageFlags]
    bit TWISTB_WIND, a
    ret z
    ld a, [wFrameCount]
    rra
    ret c                   ; only every other frame
    ld hl, wWindTimer
    dec [hl]
    ret nz
    ld [hl], WIND_TIME
    call NextRandom
    and 1
    ld a, 1                 ; 0: blowing right
    ld b, TILE_ARROW_R
    jr z, .set
    ld a, $FF               ; 1: blowing left (-1)
    ld b, TILE_ARROW_L
.set
    ld [wWind], a
    ld a, b
    ld [wHudWind], a
    ld a, 1
    ld [wHudDirty], a
    ret

; UpdateCrow: a crow picks a growing seed, flies over, lands and pecks. If it
; pecks long enough the seed is stolen. Splashing it with a drop scares it off.
; Crows never go for Kip's seed. Everything moves every other frame.
UpdateCrow:
    ld a, [wStageFlags]
    bit TWISTB_CROWS, a
    ret z
    ld a, [wFrameCount]
    rra
    ret c
    ld a, [wCrowState]
    and a
    jp z, .away
    cp CROW_FLY
    jp z, .fly
    cp CROW_LAND
    jp z, .land
    cp CROW_PECK
    jp z, .peck

    ; --- Leaving: rise to flying height, then fly off the nearest edge. ---
    ld a, [wCrowY]
    cp CROW_FLY_Y + 1
    jr c, .leaveSide
    dec a
    ld [wCrowY], a
    ret
.leaveSide
    ld a, [wCrowX]
    cp CROW_RIGHT_X / 2
    jr c, .leaveLeft
    inc a
    ld [wCrowX], a
    ld b, 0                 ; facing right
    cp CROW_RIGHT_X
    jr c, .face
    jr .gone
.leaveLeft
    and a
    jr z, .gone
    dec a
    ld [wCrowX], a
    ld b, 1                 ; facing left
.face
    ld a, b
    ld [wCrowDir], a
    ret
.gone
    xor a
    ld [wCrowState], a      ; CROW_AWAY
    call NextRandom
    and 63
    add a, CROW_WAIT        ; wait 4 to 6 seconds for the next crow
    ld [wCrowTimer], a
    ret

    ; --- Away: wait, then pick a seed to go for. ---
.away
    ld hl, wCrowTimer
    dec [hl]
    ret nz
    ; Start at a random seed and take the first growing one (not Kip's).
    call NextRandom
    and 7
    cp NUM_SEEDS
    jr c, .start
    sub NUM_SEEDS           ; 6 -> 0, 7 -> 1
.start
    ld e, a                 ; e = seed to look at
    ld d, NUM_SEEDS         ; d = seeds left to look at
.try
    ld a, [wKipSeed]
    cp e
    jr z, .skip
    ld c, e
    call SeedAddress
    ld a, [hl]
    and a                   ; SEED_GROWING?
    jr z, .picked
.skip
    inc e
    ld a, e
    cp NUM_SEEDS
    jr c, .wrapped
    ld e, 0
.wrapped
    dec d
    jr nz, .try
    ld a, 30                ; nothing to steal: look again in a second
    ld [wCrowTimer], a
    ret
.picked
    ld a, e
    ld [wCrowTarget], a
    ; Fly in from a random side.
    call NextRandom
    and 1
    ld a, 0                 ; from the left, facing right
    ld b, 0
    jr z, .side
    ld a, CROW_RIGHT_X      ; from the right, facing left
    ld b, 1
.side
    ld [wCrowX], a
    ld a, b
    ld [wCrowDir], a
    ld a, CROW_FLY_Y
    ld [wCrowY], a
    ld a, CROW_FLY
    ld [wCrowState], a
    QUEUE_SFX2 SFX2B_CAW
    ret

    ; --- Flying across to the target seed. ---
.fly
    call CrowCheckTarget
    ret c
    call CrowTargetX
    ld b, a
    ld a, [wCrowX]
    cp b
    jr z, .arrived
    jr c, .flyRight
    dec a
    ld [wCrowX], a
    ld a, 1
    ld [wCrowDir], a
    ret
.flyRight
    inc a
    ld [wCrowX], a
    xor a
    ld [wCrowDir], a
    ret
.arrived
    ld a, CROW_LAND
    ld [wCrowState], a
    ret

    ; --- Dropping down onto the seed. ---
.land
    call CrowCheckTarget
    ret c
    ld a, [wCrowY]
    inc a
    ld [wCrowY], a
    cp CROW_GROUND_Y
    ret c
    ld a, CROW_PECK
    ld [wCrowState], a
    ld a, CROW_PECK_TIME
    ld [wCrowTimer], a
    ret

    ; --- Pecking: when the time runs out, the seed is gone. ---
.peck
    call CrowCheckTarget
    ret c
    ld hl, wCrowTimer
    dec [hl]
    ret nz
    ld a, [wCrowTarget]
    ld c, a
    call SeedAddress
    ld [hl], SEED_STOLEN
    QUEUE_SFX2 SFX2B_CAW
    ld a, CROW_LEAVE
    ld [wCrowState], a
    ret

; CrowCheckTarget: if the target seed isn't growing any more (it sprouted or
; was lost), the crow gives up and leaves. Returns carry set if it left.
CrowCheckTarget:
    ld a, [wCrowTarget]
    ld c, a
    call SeedAddress
    ld a, [hl]
    and a                   ; still growing? (and a clears carry)
    ret z
    ld a, CROW_LEAVE
    ld [wCrowState], a
    scf
    ret

; CrowTargetX: a = the crow's x when it stands centred on its target seed.
; Seed i is at x = 8 + 24 * i; the crow is 16 wide, so 4 + 24 * i.
CrowTargetX:
    ld a, [wCrowTarget]
    ld b, a
    ld a, 4
    inc b
.mul
    dec b
    ret z
    add a, 24
    jr .mul

; -----------------------------------------------------------------------------
; Seeds
; -----------------------------------------------------------------------------

; WaterAt: a drop landed with its left edge at x = a. If it's over a seed
; that is still growing, that seed drinks.
;   Seed i sits at x = 8 + 24*i; its plot is the 16 pixels from x-4 to x+12.
;   (Drop centre = a + 4, minus the first plot's left edge (4) = a.)
WaterAt:
    ld b, a
    ld a, [wSeedCount]
    cp NUM_SEEDS
    ld a, b
    jr z, .standard
    ; First Rain spaces plots 32 pixels apart and accepts 24 pixels per plot.
    ; Shift by 4 so the wider hit area stays centered on the same tile.
    add a, 4
    ld c, 0
.firstRainPlot
    cp 32
    jr c, .firstRainWidth
    sub 32
    inc c
    jr .firstRainPlot
.firstRainWidth
    cp 24
    jr .checkPlot
.standard
    ld c, 0                 ; c = which seed
.divide                     ; a / 24, counting in c, remainder in a
    cp 24
    jr c, .gotPlot
    sub 24
    inc c
    jr .divide
.gotPlot
    cp PLOT_WIDTH
.checkPlot
    ret nc                  ; landed between plots
    ld a, [wSeedCount]
    cp c
    ret c                   ; right of the last plot
    ret z
    call SeedAddress        ; hl = this seed
    ld a, [hl]
    cp SEED_GROWING
    ret nz                  ; already sprouted/wilted/flooded: no effect
    QUEUE_SFX SFXB_SPLASH
    ; Puddles: if this seed is already too wet, the water spills over and
    ; both neighbours get some too.
    ld a, [wStageFlags]
    bit TWISTB_PUDDLES, a
    jr z, .drink
    call LoadSeedType
    inc l                   ; S_WATER
    ld a, [wTmpHigh]
    cp [hl]                 ; carry if water > zone high
    jr nc, .drink
    push bc
    dec c                   ; left neighbour ($FF if none: AddWater ignores it)
    ld b, SPILL_WATER
    call AddWater
    pop bc
    push bc
    inc c                   ; right neighbour
    ld b, SPILL_WATER
    call AddWater
    pop bc
.drink
    ld b, DROP_WATER
    ; fall through to AddWater

; AddWater: seed c drinks b water (only if it exists and is still growing).
AddWater:
    ld a, c
    cp NUM_SEEDS
    ret nc
    call SeedAddress
    ld a, [hl]
    and a                   ; SEED_GROWING?
    ret nz
    inc l                   ; S_WATER
    ld a, [hl]
    add a, b
    cp WATER_MAX + 1
    jr c, .store
    ld a, WATER_MAX
.store
    ld [hl], a
    ret

; SeedAddress: hl = wSeeds + c * 8. (Keeps b, c, d, e.)
SeedAddress:
    ld a, c
    add a, a
    add a, a
    add a, a                ; c * 8
    add a, LOW(wSeeds)
    ld l, a
    ld h, HIGH(wSeeds)      ; all seeds are in one page (checked in main.asm)
    ret

; LoadSeedType: hl = a seed. Copies its type's limits into wTmpLow, wTmpHigh,
; wTmpDryAmt, wTmpFlood. Keeps hl, b and c.
LoadSeedType:
    push hl
    ld a, l
    add a, S_TYPE
    ld l, a
    ld a, [hl]
    add a, a
    add a, a                ; 4 bytes per type
    ld hl, SeedTypes
    ADD_A_TO_HL
    ld a, [hli]
    ld [wTmpLow], a
    ld a, [hli]
    ld [wTmpHigh], a
    ld a, [hli]
    ld [wTmpDryAmt], a
    ld a, [hl]
    ld [wTmpFlood], a
    pop hl
    ret

; UpdateSeeds: drying, growing, wilting and flooding, once per frame.
UpdateSeeds:
    ; Is it time for the soil to dry a little? (Twice as often in the sun.)
    ld a, [wStageDry]
    ld b, a
    ld a, [wSunOut]
    and a
    jr z, .noSun
    srl b
.noSun
    ld hl, wDryTick
    inc [hl]
    ld a, [hl]
    cp b
    ld a, 0
    jr c, .noDry
    ld [hl], a              ; restart the count...
    inc a                   ; ...and dry this frame
.noDry
    ld [wDryNow], a

    xor a
    ld [wSeedIndex], a
.seed
    ld c, a
    call SeedAddress
    ld a, [hl]
    and a
    jr nz, .next            ; only growing seeds change
    call LoadSeedType
    call UpdateOneSeed
.next
    ld a, [wSeedIndex]
    inc a
    ld [wSeedIndex], a
    ld b, a
    ld a, [wSeedCount]
    cp b
    ld a, b
    jr nz, .seed

    ; Every seed done? Then the round is over.
    ld hl, wSeeds
    ld a, [wSeedCount]
    ld b, a
.count
    ld a, [hl]
    and a
    ret z                   ; one is still growing
    ld a, l
    add a, SEED_SIZE
    ld l, a
    dec b
    jr nz, .count
    jp FinishRound

; UpdateOneSeed: hl = a growing seed; its type's limits are in wTmp...
UpdateOneSeed:
    inc l                   ; S_WATER
    ld a, [wDryNow]
    and a
    jr z, .wet
    ld a, [wTmpDryAmt]      ; the soil dries a little
    ld b, a
    ld a, [hl]
    sub b
    jr nc, .dried
    xor a
.dried
    ld [hl], a
.wet
    ld c, [hl]              ; c = water
    inc l                   ; S_GROW
    inc l                   ; S_DRY
    ; --- Too dry? (water = 0) ---
    ld a, c
    and a
    jr nz, .notDry
    inc [hl]
    ld a, [hl]
    cp WILT_TIME
    ret c
    QUEUE_SFX SFXB_WILT
    ld b, SEED_WILTED
    jr .setState
.notDry
    ld [hl], 0              ; any water resets the dry timer
    inc l                   ; S_SOGGY
    ; --- Too wet? (above the zone) ---
    ld a, [wTmpHigh]
    cp c                    ; carry if water > zone high
    jr nc, .notSoggy
    inc [hl]
    ld a, [wTmpFlood]
    ld b, a
    ld a, [hl]
    cp b
    ret c
    QUEUE_SFX SFXB_FLOOD
    ld b, SEED_FLOODED
    jr .setState
.notSoggy
    ld [hl], 0
    dec l
    dec l                   ; S_GROW
    ; --- Just right? (inside the zone) ---
    ld a, [wTmpLow]
    ld b, a
    ld a, c
    cp b
    ret c                   ; a bit dry, but not dying: nothing happens
    inc [hl]
    ld a, [hl]
    cp GROW_TIME
    ret c
    ; Sprouted! Kip's seed gets Kip's own little tune.
    ld hl, wSprouted
    inc [hl]
    ld a, 1                 ; 10 points
    call AddScore
    ld a, [wKipSeed]
    ld b, a
    ld a, [wSeedIndex]
    cp b
    jr z, .kip
    QUEUE_SFX SFXB_SPROUT
    jr .sprouted
.kip
    QUEUE_SFX2 SFX2B_KIP
.sprouted
    ld b, SEED_SPROUTED
.setState
    ld a, [wSeedIndex]
    ld c, a
    call SeedAddress
    ld [hl], b              ; S_STATE
    ret

; FinishRound: every seed is done. Work out the result and show it.
FinishRound:
    ld a, 1
    ld [wGameOver], a
    call StopMusic
    xor a
    ld [wCrowState], a      ; the crow goes home
    ld [wResult], a
    ; First Rain needs three sprouts. Later stages still need four.
    ld a, [wSeedCount]
    cp NUM_SEEDS
    ld b, GOOD_RESULT
    jr z, .compare
    dec b
.compare
    ld a, [wSprouted]
    cp b
    jr c, .failed
    ld a, [wKipSeed]
    cp $FF
    jr z, .cleared
    ld c, a
    call SeedAddress
    ld a, [hl]
    cp SEED_SPROUTED
    jr nz, .failed
    ld a, 1
    ld [wResult], a
    ld de, TextKipSprouted
    jr .show
.cleared
    ld a, 1
    ld [wResult], a
    ld a, [wSprouted]
    ld b, a
    ld a, [wSeedCount]
    cp b
    ld de, TextStageClear
    jr nz, .show
    ld a, 5                 ; all active plots: 50 bonus points
    call AddScore
    ld de, TextAllSprouted
    jr .show
.failed
    ld a, [wMode]
    and a
    ld de, TextTryAgain     ; Story: try the stage again
    jr z, .show
    ld de, TextGameOver     ; Endless: the run is over
.show
    call SetMessage
    ld de, TextPressStart12
    call SetMessage2
    QUEUE_SFX SFXB_RESULT
    ret

; BuildSeedTiles: work out which tiles each seed needs (number, gauge, seed
; picture) and mark them for copying at the next VBlank.
BuildSeedTiles:
    ld hl, wSeeds
    ld de, wSeedTiles
    ld a, [wSeedCount]
    ld b, a
.seed
    push bc
    ld c, [hl]              ; c = state
    ; Moisture numbers (only in moisture view, and only while growing).
    ld a, [wMoistureView]
    and a
    jr z, .noNumber
    ld a, c
    and a
    jr nz, .noNumber
    inc l
    ld a, [hl]              ; water
    dec l
    call TwoDigits          ; b = tens tile, a = ones tile
    push af
    ld a, b
    ld [de], a
    inc de
    pop af
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
    ; Gauge: TILE_GAUGE + type * 8 + water / 8 (blank once the seed is done).
    ld a, c
    and a
    ld a, 0
    jr nz, .storeGauge
    push hl
    ld a, l
    add a, S_TYPE
    ld l, a
    ld a, [hl]              ; type
    add a, a
    add a, a
    add a, a                ; type * 8
    ld b, a
    pop hl
    inc l
    ld a, [hl]              ; water
    dec l
    srl a
    srl a
    srl a                   ; water / 8 = level 0-7
    add a, b
    add a, TILE_GAUGE
.storeGauge
    ld [de], a
    inc de
    ; Picture: a growing seed shows its type, a finished one its state.
    ld a, c
    and a
    jr nz, .finished
    push hl
    ld a, l
    add a, S_TYPE
    ld l, a
    ld a, [hl]
    pop hl
    add a, TILE_SEED_TYPES
    jr .storePicture
.finished
    add a, TILE_SPROUT - 1
.storePicture
    ld [de], a
    inc de
    ld a, l
    add a, SEED_SIZE
    ld l, a
    pop bc
    dec b
    jr nz, .seed
    ld a, 1
    ld [wBgDirty], a
    ret

; CopySeedTiles: copy wSeedTiles onto the screen (rows NUMBER, GAUGE, SEED).
; Only called when video memory is safe: during VBlank or with the screen off.
CopySeedTiles:
    xor a
    ld [wBgDirty], a
    ld de, wSeedTiles
    ld hl, SCRN0 + SCRN_VY * NUMBER_ROW + SEED_COL0
    ld a, [wSeedCount]
    ld b, a
    ld c, SEED_COL_STEP
    cp NUM_SEEDS
    jr z, .seed
    inc c                   ; First Rain uses every fourth tile column.
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
    add a, c                ; next seed's column
    ld l, a
    jr nc, .c3
    inc h
.c3
    dec b
    jr nz, .seed
    ret

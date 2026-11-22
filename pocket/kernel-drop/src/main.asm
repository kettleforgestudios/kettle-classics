; =============================================================================
; Kernel Drop - Chapter 1 of Kettle Classics (Pocket / Game Boy)
; (c) 2026 Kettle Forge Studios. Original code, art and sound.
;
; Steer a rain cloud and water a row of seeds just right: too dry and they
; wilt, too wet and they flood. Story mode has six stages that add the sun,
; wind, crows and puddles, and ends with Kip (our kernel) sprouting. Endless
; mode keeps going for a high score. A hidden Lab mode tests the hardware.
;
; The game is split into files that are all pulled into this one with INCLUDE
; (so they share every name and constant):
;   main.asm   start-up, memory map, main loop, screen jobs, helpers, texts
;   title.asm  title screen with the mode menu, and the ending
;   play.asm   the game itself: stages, cloud, rain, seeds and the twists
;   sound.asm  sound effects, short tunes and the background music player
;   lab.asm    the hidden Lab mode (button, sound, sprite/layer, timer tests)
;
; Real Game Boy rules we follow:
;   - Video memory is only changed while the screen is off, or during VBlank
;     (the short break between frames). Each VBlank job first checks that
;     enough of the break is left; if not, it simply waits for the next frame.
;   - Sprites are moved with OAM DMA from a copy in work RAM.
;   - No more than 10 sprites on one screen line: the crow flies below the
;     cloud, so cloud + crow never share a line (drops 8 + crow 2 = 10).
;   - The wave channel is switched off before its wave memory is written or a
;     new note is started (the original handheld can scramble it otherwise).
; =============================================================================

INCLUDE "hardware.inc"
INCLUDE "charmap.inc"
INCLUDE "notes.inc"

; --- Title screen -------------------------------------------------------------
DEF KIP_X       EQU 72     ; Kip's position on the title screen (pixels)
DEF KIP_Y       EQU 64
DEF HOP_HEIGHT  EQU 12     ; how many pixels a hop lifts Kip
DEF MENU_ROW    EQU 11     ; "STORY" is on this row, "ENDLESS" on the next
DEF MENU_COL    EQU 6      ; column of the menu arrow

; --- Play screen --------------------------------------------------------------
DEF CLOUD_MIN_X EQU 0      ; cloud can move from the left edge...
DEF CLOUD_MAX_X EQU 144    ; ...to the right edge (screen 160 - cloud 16)
DEF CLOUD_TOP   EQU 16     ; highest the cloud can go (rows 0-1 are the score bar)
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
DEF INTRO_TIME  EQU 120    ; the stage name shows for 2 seconds before play

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
DEF SPILL_WATER EQU 2      ; puddles: water that spills onto each neighbour
DEF GROW_TIME   EQU 240    ; frames in the zone to sprout (4 seconds)
DEF WILT_TIME   EQU 180    ; frames at zero water before wilting (3 seconds)
DEF GOOD_RESULT EQU 4      ; sprout at least 4 of 6 to clear the stage
; Each seed type's "just right" zone and flood time is in SeedTypes (play.asm).

; Seed types
DEF TYPE_NORMAL   EQU 0
DEF TYPE_THIRSTY  EQU 1    ; needs more water and drinks it twice as fast
DEF TYPE_DELICATE EQU 2    ; needs only a little, floods quickly
DEF TYPE_KIP      EQU 3    ; Kip's own seed: a narrow zone (final stage)

; Seed states (the picture for states 1-4 is TILE_SPROUT - 1 + state)
DEF SEED_GROWING  EQU 0
DEF SEED_SPROUTED EQU 1
DEF SEED_WILTED   EQU 2
DEF SEED_FLOODED  EQU 3
DEF SEED_STOLEN   EQU 4    ; a crow took it

; Offsets inside one seed's 8 bytes
DEF S_STATE  EQU 0
DEF S_WATER  EQU 1
DEF S_GROW   EQU 2         ; frames spent in the zone
DEF S_DRY    EQU 3         ; frames spent at zero water
DEF S_SOGGY  EQU 4         ; frames spent above the zone
DEF S_TYPE   EQU 5         ; TYPE_xxx

; --- Twists (one bit each in wStageFlags) ---------------------------------------
DEF TWISTB_SUN     EQU 0   ; the sun comes and goes; soil dries twice as fast
DEF TWISTB_WIND    EQU 1   ; drops drift sideways
DEF TWISTB_CROWS   EQU 2   ; crows try to steal seeds; splash them away
DEF TWISTB_PUDDLES EQU 3   ; watering a soaked seed spills onto its neighbours
DEF SUN_TIME    EQU 150    ; sun changes every 150 steps (every other frame: 5 s)
DEF WIND_TIME   EQU 120    ; wind may turn every 120 steps (4 s)

; Crow (it moves every other frame, so "steps" = 2 frames)
DEF CROW_AWAY   EQU 0      ; not on screen, waiting
DEF CROW_FLY    EQU 1      ; flying across to its target seed
DEF CROW_LAND   EQU 2      ; dropping down onto the seed
DEF CROW_PECK   EQU 3      ; pecking: steals the seed when the timer runs out
DEF CROW_LEAVE  EQU 4      ; flying away (scared, or carrying the seed)
DEF CROW_FLY_Y  EQU 80     ; flying height: below the cloud (sprite line limit)
DEF CROW_GROUND_Y EQU 112  ; standing on a seed
DEF CROW_PECK_TIME EQU 75  ; steps of pecking before the seed is gone (2.5 s)
DEF CROW_WAIT   EQU 120    ; steps between crows (4 s)
DEF CROW_RIGHT_X EQU 152   ; crows come in / leave at x = 0 or this

; --- Modes and stages -------------------------------------------------------------
DEF MODE_STORY   EQU 0
DEF MODE_ENDLESS EQU 1
DEF STORY_STAGES EQU 6
DEF STAGE_SIZE   EQU 13    ; bytes per stage in StoryStages (play.asm)

; --- Sound effects --------------------------------------------------------------
; Each event sets one bit in wSfxQueue or wSfxQueue2. Several can happen in one
; frame; they are all played at the end of the frame (see UpdateSound).
DEF SFXB_START  EQU 0      ; stage starts      (channel 1: rising chirp)
DEF SFXB_PAUSE  EQU 1      ; pause / unpause   (channel 1: blip)
DEF SFXB_TIRED  EQU 2      ; cloud gets tired  (channel 1: falling "phew")
DEF SFXB_WILT   EQU 3      ; a seed wilts      (channel 1: low droop)
DEF SFXB_SPLASH EQU 4      ; drop waters a seed (channel 4: soft noise)
DEF SFXB_FLOOD  EQU 5      ; a seed floods     (channel 4: long splash)
DEF SFXB_SPROUT EQU 6      ; a seed sprouts    (channel 2: 3-note tune)
DEF SFXB_RESULT EQU 7      ; round over        (channel 2: happy or sad tune)
DEF SFX2B_CAW   EQU 0      ; a crow arrives    (channel 1: harsh caw)
DEF SFX2B_SCARE EQU 1      ; crow splashed     (channel 4: flutter)
DEF SFX2B_KIP   EQU 2      ; Kip's motif       (channel 2: Kip's "voice")
DEF SFX2B_POP   EQU 3      ; the POP jingle    (channel 4 pop + channel 2)
DEF SFX2B_MENU  EQU 4      ; menu move         (channel 1: tick)

; QUEUE_SFX SFXB_xxx / QUEUE_SFX2 SFX2B_xxx: ask for a sound. Keeps every
; register (even a and flags) so it can be dropped into the middle of any routine.
MACRO QUEUE_SFX
    push af
    ld a, [wSfxQueue]
    set \1, a
    ld [wSfxQueue], a
    pop af
ENDM
MACRO QUEUE_SFX2
    push af
    ld a, [wSfxQueue2]
    set \1, a
    ld [wSfxQueue2], a
    pop af
ENDM

; ADD_A_TO_HL: hl = hl + a (a is changed).
MACRO ADD_A_TO_HL
    add a, l
    ld l, a
    adc a, h               ; a = h + l + carry...
    sub l                  ; ...minus l = h + carry
    ld h, a
ENDM

; Game states (which screen we're on)
DEF STATE_TITLE  EQU 0
DEF STATE_PLAY   EQU 1
DEF STATE_ENDING EQU 2
DEF STATE_LAB    EQU 3

; Sprite slots in the sprite table (each slot is 4 bytes)
DEF SLOT_MAIN   EQU 0      ; slots 0-3: Kip (title/ending/Lab) or the cloud (play)
DEF SLOT_DROPS  EQU 4      ; slots 4-11: water drops
DEF SLOT_CROW   EQU 12     ; slots 12-15: the crow

; =============================================================================
; Memory we use (work RAM). Fixed addresses so automatic tests can find them
; (the test script looks the names up in kernel-drop.sym).
; =============================================================================
SECTION "Game state", WRAM0[$C000]
wBootMarker::  db  ; $42 once start-up finished (tests check this)
wJoyHeld::     db  ; buttons held right now (bits: see hardware.inc)
wJoyPressed::  db  ; buttons that went down THIS frame
wFrameCount::  db  ; counts up every frame (60 per second)
wHopTimer::    db  ; > 0 while Kip is in the air (title, ending)
wGameState::   db  ; STATE_xxx
wRandom::      dw  ; random number generator state (never 0)

; --- Round variables: all cleared when a stage starts -------------------------
wRoundStart::
wCloudX::      db  ; cloud left edge (pixels)
wCloudY::      db  ; cloud top edge (pixels)
wPaused::      db  ; 1 = paused
wMoistureView::db  ; 1 = show exact moisture numbers
wDropDelay::   db  ; frames until A can drop again
wPourTimer::   db  ; how long B has been held (while pouring)
wTiredTimer::  db  ; > 0 while the cloud rests after a long pour
wActiveDrops:: db  ; how many drops are in the air (tests read this)
wDrops::       ds MAX_DROPS * 2  ; each drop = Y, X (Y = 0 means unused)
wSeeds::       ds NUM_SEEDS * SEED_SIZE ; 6 seeds x 8 bytes
wGameOver::    db  ; 1 = every seed is done (result showing)
wSprouted::    db  ; how many seeds sprouted
wDryTick::     db  ; counts frames until the soil dries a little more
wDryNow::      db  ; 1 = seeds lose water this frame
wResult::      db  ; 1 = stage cleared, 0 = not (valid once wGameOver = 1)
wIntroTimer::  db  ; > 0 while the stage name is showing
wSunOut::      db  ; 1 = the sun is out (soil dries twice as fast)
wSunTimer::    db  ; steps until the sun comes out / goes away
wWind::        db  ; 0 = calm, 1 = blowing right, $FF (-1) = blowing left
wWindTimer::   db  ; steps until the wind may turn
wHudWind::     db  ; tile shown for the wind in the score bar (0 = none)
wCrowState::   db  ; CROW_xxx
wCrowX::       db  ; crow left edge (pixels)
wCrowY::       db  ; crow top edge (pixels)
wCrowTarget::  db  ; which seed the crow wants
wCrowTimer::   db  ; steps until the next crow / until the seed is stolen
wCrowDir::     db  ; 0 = facing right, 1 = facing left
wSeedIndex::   db  ; loop counter used while updating seeds
wRoundEnd::
; ------------------------------------------------------------------------------

wSeedTiles::   ds NUM_SEEDS * 4 ; per seed: tens digit, ones digit, gauge, seed
wBgDirty::     db  ; 1 = seed tiles need copying next VBlank
wMsgPtr::      dw  ; text shown on the message line (row 7)
wMsgDirty::    db
wMsg2Ptr::     dw  ; text shown on the second message line (row 9)
wMsg2Dirty::   db
wMsgBuf::      ds 13 ; room to build a message in RAM (12 letters + end mark)
wHudBuf::      ds 20 ; the score bar (row 0), ready to copy
wHudDirty::    db
wMenu::        db  ; title menu: MODE_STORY or MODE_ENDLESS
wMenuDirty::   db
wMode::        db  ; mode being played
wStage::       db  ; stage number, counting from 0
wStageFlags::  db  ; twists in this stage (TWISTB_xxx bits)
wStageDry::    db  ; frames between dryings in this stage
wKipSeed::     db  ; which seed is Kip's ($FF = none)
wScore::       dw  ; score / 10, as 4 decimal digits (BCD: low byte first)
wHiScore::     dw  ; best score since power-on (same format)
wTmpLow::      db  ; the seed type being worked on: zone low,
wTmpHigh::     db  ;   zone high,
wTmpDryAmt::   db  ;   water lost per drying,
wTmpFlood::    db  ;   frames above the zone before it floods
wSfxQueue::    db  ; sounds asked for this frame (one bit each)
wSfxQueue2::   db
wTunePtr::     dw  ; next note of the tune playing on channel 2
wTuneTimer::   db  ; frames left on the current note (0 = no tune)
wMusicPtr::    dw  ; next note of the music on channel 3
wMusicLoop::   dw  ; where the music starts again when it reaches the end
wMusicTimer::  db  ; frames left on the current music note (0 = no music)
wLabPage::     db  ; Lab mode page (0-3)
wLabSel::      db  ; sound test: chosen channel (0-3)
wLabWindow::   db  ; layer test: 1 = window layer on
wLabKipX::     db  ; sprite test: Kip's position
wLabKipY::     db
wLabFrames::   dw  ; timer test: frames since the Lab opened
wLabSeconds::  dw  ; ...and seconds (BCD)
wLabTick::     db  ; frames toward the next second
wLabLines::    ds 40 ; two 20-tile rows the Lab pages draw into
wLabDirty::    db
wStateEnd::

    ; Seeds must sit inside one 256-byte page: the seed code steps through a
    ; seed's bytes with "inc l", which never carries into h.
    ASSERT HIGH(wSeeds) == HIGH(wSeeds + NUM_SEEDS * SEED_SIZE - 1)

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

    ; Sound on: master volume full, every channel to both speakers.
    ld a, $80
    ldh [rNR52], a          ; bit 7 = sound hardware on (must be first)
    ld a, $77
    ldh [rNR50], a          ; left and right volume 7 (the max)
    ld a, $FF
    ldh [rNR51], a
    call LoadWave           ; the wave channel's sound shape (sound.asm)

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
    ld a, $5A               ; any starting value except 0
    ld [wRandom], a
    ld a, $C3
    ld [wRandom + 1], a

    ; Clear our sprite table copy, then copy the DMA routine into high RAM.
    call ClearSprites
    ld hl, hOAMDMA
    ld de, OAMDMARoutine
    ld bc, OAMDMARoutineEnd - OAMDMARoutine
    call MemCopy

    ; Shades: colour 0 = lightest ... colour 3 = darkest.
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a
    ld a, %01010000         ; pale palette for the tired cloud
    ldh [rOBP1], a
    xor a
    ldh [rSCX], a
    ldh [rSCY], a
    ld a, 7                 ; window layer (only used in the Lab): left edge,
    ldh [rWX], a
    ld a, 128               ; near the bottom of the screen
    ldh [rWY], a

    ld a, IEF_VBLANK
    ldh [rIE], a
    xor a
    ldh [rIF], a
    call EnterTitle         ; draws the title and turns the screen on

    ld a, $42
    ld [wBootMarker], a     ; start-up finished (for automatic tests)
    ei

; =============================================================================
; Main loop. Runs once per frame.
; First: quick video memory jobs (we just woke up in VBlank, so it's safe).
; Then:  read buttons, update the current screen, play sounds.
; =============================================================================
MainLoop:
    halt                    ; sleep until the next VBlank interrupt
    call VBlankJobs
    call ReadJoypad
    call NextRandom         ; stir the random numbers every frame

    ; Jump to the update routine for the current screen (StateTable below).
    ld a, [wGameState]
    add a, a                ; 2 bytes per table entry
    ld hl, StateTable
    ADD_A_TO_HL
    ld a, [hli]
    ld h, [hl]
    ld l, a
    call CallHL

    call UpdateSound
    jr MainLoop

StateTable:
    dw UpdateTitle          ; STATE_TITLE
    dw UpdatePlay           ; STATE_PLAY
    dw UpdateEnding         ; STATE_ENDING
    dw UpdateLab            ; STATE_LAB

CallHL:
    jp hl

; =============================================================================
; VBlank jobs: copy whatever changed onto the screen.
; The break between frames is only 10 screen lines long (lines 144-153). A job
; only starts if we're still in the first 5 of them, so it can't run past the
; end; otherwise its "dirty" flag stays set and it runs next frame. The seed
; tiles change every frame, so they go last and the rare jobs go first.
; =============================================================================
VBlankJobs:
    ld a, [wMsgDirty]
    and a
    jr z, .msg2
    call RoomInVBlank
    ret c
    call DrawMessage
.msg2
    ld a, [wMsg2Dirty]
    and a
    jr z, .hud
    call RoomInVBlank
    ret c
    call DrawMessage2
.hud
    ld a, [wHudDirty]
    and a
    jr z, .menu
    call RoomInVBlank
    ret c
    call DrawHud
.menu
    ld a, [wMenuDirty]
    and a
    jr z, .lab
    call RoomInVBlank
    ret c
    call DrawMenuArrow
.lab
    ld a, [wLabDirty]
    and a
    jr z, .seeds
    call RoomInVBlank
    ret c
    call DrawLabLines
.seeds
    ld a, [wBgDirty]
    and a
    ret z
    call RoomInVBlank
    ret c
    jp CopySeedTiles

; RoomInVBlank: carry clear = still early in VBlank (lines 144-148): safe to
; start a job. Carry set = too late, wait for the next frame.
RoomInVBlank:
    ldh a, [rLY]
    sub 144                 ; lines into VBlank (wraps to a big number if < 144)
    cp 5                    ; carry set if 0-4...
    ccf                     ; ...flip it: carry clear means "go ahead"
    ret

; SetMessage / SetMessage2: show text de (12 letters) on message line 1 / 2.
; It's drawn at the next VBlank.
SetMessage:
    ld a, e
    ld [wMsgPtr], a
    ld a, d
    ld [wMsgPtr + 1], a
    ld a, 1
    ld [wMsgDirty], a
    ret
SetMessage2:
    ld a, e
    ld [wMsg2Ptr], a
    ld a, d
    ld [wMsg2Ptr + 1], a
    ld a, 1
    ld [wMsg2Dirty], a
    ret

; DrawMessage / DrawMessage2: write the message lines in the middle of the
; screen. Only called when video memory is safe (VBlank or screen off).
DEF MSG_POS  EQU SCRN0 + SCRN_VY * 7 + 4
DEF MSG2_POS EQU SCRN0 + SCRN_VY * 9 + 4
DrawMessage:
    xor a
    ld [wMsgDirty], a
    ld a, [wMsgPtr]
    ld e, a
    ld a, [wMsgPtr + 1]
    ld d, a
    ld hl, MSG_POS
    jp PrintText
DrawMessage2:
    xor a
    ld [wMsg2Dirty], a
    ld a, [wMsg2Ptr]
    ld e, a
    ld a, [wMsg2Ptr + 1]
    ld d, a
    ld hl, MSG2_POS
    jp PrintText

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

; ScreenOn: background + sprites on; the window layer stays off (the Lab
; turns it on). Tiles at $8000, window map at $9C00.
ScreenOn:
    ld a, LCDCF_ON | LCDCF_WIN9C00 | LCDCF_BLK01 | LCDCF_OBJON | LCDCF_BGON
    ldh [rLCDC], a
    ret

; ClearSprites: hide all 40 sprites in our copy of the sprite table.
ClearSprites:
    ld hl, ShadowOAM
    ld bc, 4 * 40
    xor a
    jp MemFill

; ClearMap: blank the whole background map (screen off only).
ClearMap:
    ld hl, SCRN0
    ld bc, SCRN_VY * 32
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

; Draw16x16Flip: the same, mirrored left-right (e should include OAMF_XFLIP).
; Each 8x8 part is mirrored by the hardware, but we also have to swap the left
; and right parts: the left sprite shows the top-RIGHT tile, and so on.
Draw16x16Flip:
    ld a, b
    add a, 16
    ld b, a
    ld a, c
    add a, 8
    ld c, a
    inc d                   ; top-right tile...
    call .one               ; ...on the left
    dec d                   ; top-left tile...
    ld a, c
    add a, 8
    ld c, a
    call .one               ; ...on the right
    ld a, b
    add a, 8
    ld b, a
    ld a, c
    sub 8
    ld c, a
    inc d
    inc d
    inc d                   ; bottom-right tile on the left
    call .one
    dec d                   ; bottom-left tile on the right
    ld a, c
    add a, 8
    ld c, a
.one
    ld a, b
    ld [hli], a
    ld a, c
    ld [hli], a
    ld a, d
    ld [hli], a
    ld a, e
    ld [hli], a
    ret

; HideSprites: hl = first slot, b = how many sprites to hide.
HideSprites:
    xor a
.loop
    ld [hli], a             ; Y = 0 puts the sprite off-screen
    ld [hli], a
    ld [hli], a
    ld [hli], a
    dec b
    jr nz, .loop
    ret

; NextRandom: returns a new random number in a (other registers are kept).
; A 16-bit "xorshift" generator: x ^= x << 7, x ^= x >> 9, x ^= x << 8.
; Shifting and mixing the bits like this visits all 65535 non-zero values.
NextRandom:
    push bc
    push de
    ld a, [wRandom]
    ld c, a                 ; c = low byte
    ld a, [wRandom + 1]
    ld b, a                 ; b = high byte
    ; x ^= x << 7: the high byte gets (b << 7) | (c >> 1), the low byte c << 7.
    ld a, b
    rrca
    and $80                 ; a = b << 7 (only bit 0 of b survives)
    ld e, a
    ld a, c
    srl a                   ; c >> 1
    or e
    xor b
    ld b, a
    ld a, c
    rrca
    and $80                 ; c << 7
    xor c
    ld c, a
    ; x ^= x >> 9: the low byte gets high >> 1.
    ld a, b
    srl a
    xor c
    ld c, a
    ; x ^= x << 8: the high byte gets the low byte.
    xor b
    ld b, a
    ld [wRandom + 1], a
    ld a, c
    ld [wRandom], a
    pop de
    pop bc
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

; PrintAt: like PrintText, but the screen position comes as row b, column c.
PrintAt:
    ld h, 0
    ld l, b
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl              ; hl = row * 32
    ld a, c
    ADD_A_TO_HL
    ld a, h
    add a, HIGH(SCRN0)
    ld h, a                 ; + $9800
    jr PrintText

; TwoDigits: a = 0-99. Returns b = tens digit tile, a = ones digit tile.
TwoDigits:
    ld b, TILE_DIGIT0
.tens
    cp 10
    jr c, .ones
    sub 10
    inc b
    jr .tens
.ones
    add a, TILE_DIGIT0
    ret

; PrintBCD: a = two decimal digits (BCD, e.g. $42). Writes 2 digit tiles at hl.
PrintBCD:
    push af
    swap a                  ; first digit is in the high 4 bits
    and $0F
    add a, TILE_DIGIT0
    ld [hli], a
    pop af
    and $0F
    add a, TILE_DIGIT0
    ld [hli], a
    ret

; PrintScore: write a score (de = its 2 BCD bytes, low byte first) as 5 digit
; tiles at hl. Scores are stored divided by 10, so the 5th digit is always 0.
PrintScore:
    inc de
    ld a, [de]              ; high byte: thousands and hundreds of (score / 10)
    call PrintBCD
    dec de
    ld a, [de]
    call PrintBCD
    ld a, TILE_DIGIT0
    ld [hli], a
    ret

; PrintHex: a = a byte. Writes it as 2 hex digit tiles (0-9, A-F) at hl.
PrintHex:
    push af
    swap a
    call .digit
    pop af
.digit
    and $0F
    push hl
    ld hl, HexDigits
    ADD_A_TO_HL
    ld a, [hl]
    pop hl
    ld [hli], a
    ret
HexDigits: db "0123456789ABCDEF"

; =============================================================================
; Text (letters become tile numbers through charmap.inc)
; =============================================================================
TextTitle:      db "KERNEL DROP", $FF
TextSeries:     db "KETTLE CLASSICS", $FF
TextPressStart: db "PRESS START", $FF
TextStory:      db "STORY", $FF
TextEndlessMenu:db "ENDLESS", $FF
TextHi:         db "HI ", $FF
TextScore:      db "SCORE ", $FF
; Score bar: stage number goes at column 6, score at column 15.
TextHud:        db "STAGE 00 SCORE 00000"
; Message line texts are 12 characters so they fully replace each other.
TextPause:       db "   PAUSE    ", $FF
TextBlank12:     db "            ", $FF
TextAllSprouted: db "ALL SPROUTED", $FF
TextStageClear:  db "STAGE CLEAR ", $FF
TextTryAgain:    db " TRY AGAIN  ", $FF
TextGameOver:    db " GAME OVER  ", $FF
TextKipSprouted: db "KIP SPROUTED", $FF
TextPressStart12:db "PRESS START ", $FF
TextStageNum:    db "  STAGE 00  ", $FF   ; Endless: digits filled in at 8-9
TextEndless:     db "  ENDLESS   ", $FF

INCLUDE "title.asm"
INCLUDE "play.asm"
INCLUDE "sound.asm"
INCLUDE "lab.asm"

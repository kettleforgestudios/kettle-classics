; =============================================================================
; Sound (pulled into main.asm with INCLUDE)
;
; The Pocket's sound chip plays on its own once a note is started: we just
; write a few registers (pitch, volume, how it fades) and it does the rest.
; Who uses which channel:
;   channel 1 (square + sweep)  sound effects (chirps, blips, caws)
;   channel 2 (square)          short tunes (sprout, win/lose, Kip's motif)
;   channel 3 (wave)            background music
;   channel 4 (noise)           splashes, flutters, the POP
; Pitch numbers come from notes.inc (art/make_notes.py works them out).
; =============================================================================

; UpdateSound: once per frame. Play queued effects, then step the tune on
; channel 2 and the music on channel 3.
UpdateSound:
    call PlayQueue1
    call PlayQueue2
    call UpdateMusic
    jp UpdateTune

; PlayQueue1: sounds from wSfxQueue.
PlayQueue1:
    ld a, [wSfxQueue]
    and a
    ret z
    ld b, a
    xor a
    ld [wSfxQueue], a
    ; Noise channel (later lines win if two happen in the same frame).
    bit SFXB_SPLASH, b
    ld hl, SfxSplash
    call nz, PlayNoise
    bit SFXB_FLOOD, b
    ld hl, SfxFlood
    call nz, PlayNoise
    ; Channel 1 effects, least to most important.
    bit SFXB_PAUSE, b
    ld hl, SfxPause
    call nz, PlaySquare
    bit SFXB_START, b
    ld hl, SfxStart
    call nz, PlaySquare
    bit SFXB_TIRED, b
    ld hl, SfxTired
    call nz, PlaySquare
    bit SFXB_WILT, b
    ld hl, SfxWilt
    call nz, PlaySquare
    ; Channel 2 tunes: the round result beats a sprout.
    bit SFXB_SPROUT, b
    ld hl, TuneSprout
    call nz, StartTune
    bit SFXB_RESULT, b
    ret z
    ld a, [wResult]
    and a
    ld hl, TuneLose
    jr z, StartTune
    ld hl, TuneWin
    jr StartTune

; PlayQueue2: sounds from wSfxQueue2.
PlayQueue2:
    ld a, [wSfxQueue2]
    and a
    ret z
    ld b, a
    xor a
    ld [wSfxQueue2], a
    bit SFX2B_SCARE, b
    ld hl, SfxScare
    call nz, PlayNoise
    bit SFX2B_POP, b
    ld hl, SfxPop
    call nz, PlayNoise
    bit SFX2B_MENU, b
    ld hl, SfxMenu
    call nz, PlaySquare
    bit SFX2B_CAW, b
    ld hl, SfxCaw
    call nz, PlaySquare
    bit SFX2B_KIP, b
    ld hl, TuneKip
    call nz, StartTune
    bit SFX2B_POP, b
    ld hl, TunePop
    call nz, StartTune
    ret

; UpdateTune: step the tune on channel 2: count down this note, then start the
; next one.
UpdateTune:
    ld a, [wTuneTimer]
    and a
    ret z                   ; no tune playing
    dec a
    ld [wTuneTimer], a
    ret nz                  ; current note still going
    ld a, [wTunePtr]
    ld l, a
    ld a, [wTunePtr + 1]
    ld h, a
    ; fall through to PlayNote

; PlayNote: hl = a note (pitch low, pitch high, frames). Frames 0 = tune over.
PlayNote:
    ld a, [hli]
    ld c, a                 ; pitch low
    ld a, [hli]
    ld d, a                 ; pitch high
    ld a, [hli]             ; how many frames
    and a
    ret z                   ; end of tune (wTuneTimer stays 0)
    ld [wTuneTimer], a
    ld a, l
    ld [wTunePtr], a
    ld a, h
    ld [wTunePtr + 1], a
    ld a, $80
    ldh [rNR21], a          ; 50% square wave: a clean "beep" tone
    ld a, $D3
    ldh [rNR22], a          ; volume 13, fading out gently
    ld a, c
    ldh [rNR23], a
    ld a, d
    or $80                  ; bit 7 = start the note
    ldh [rNR24], a
    ret

; StartTune: hl = first note. Keeps register b (the queues need it).
StartTune:
    jr PlayNote

; PlaySquare: hl = 5 bytes for channel 1 (sweep, duty, envelope, pitch lo, hi).
PlaySquare:
    ld c, LOW(rNR10)
    ld e, 5
    jr CopyToSound

; PlayNoise: hl = 4 bytes for channel 4 (length, envelope, texture, start).
PlayNoise:
    ld c, LOW(rNR41)
    ld e, 4
CopyToSound:
    ld a, [hli]
    ldh [c], a              ; write to $FF00 + c
    inc c
    dec e
    jr nz, CopyToSound
    ret

; -----------------------------------------------------------------------------
; Music player (channel 3)
; A song is a list of notes: pitch low, pitch high, frames. Pitch 0 = rest.
; Frames 0 ends the song: pitch high $FF = stop, anything else = start again.
; -----------------------------------------------------------------------------

; LoadWave: put the sound shape into wave memory (channel 3 must be off).
LoadWave:
    xor a
    ldh [rNR30], a          ; channel 3 off while we write its memory
    ld hl, WAVE_RAM
    ld de, WaveShape
    ld b, 16
.copy
    ld a, [de]
    inc de
    ld [hli], a
    dec b
    jr nz, .copy
    ret

; A soft triangle wave: 32 steps of 4 bits, rising then falling.
WaveShape:
    db $01, $23, $45, $67, $89, $AB, $CD, $EF
    db $FE, $DC, $BA, $98, $76, $54, $32, $10

; StartMusic: hl = a song. Plays it on channel 3, looping.
StartMusic:
    ld a, l
    ld [wMusicPtr], a
    ld [wMusicLoop], a
    ld a, h
    ld [wMusicPtr + 1], a
    ld [wMusicLoop + 1], a
    ld a, 1
    ld [wMusicTimer], a     ; play the first note at the next update
    ret

; StopMusic: silence channel 3.
StopMusic:
    xor a
    ld [wMusicTimer], a
    ldh [rNR30], a          ; turning the channel off silences it at once
    ret

; UpdateMusic: once per frame. Starts the next note when the current one ends.
UpdateMusic:
    ld a, [wPaused]
    and a
    ret nz                  ; paused: the music waits
    ld a, [wMusicTimer]
    and a
    ret z                   ; no music
    dec a
    ld [wMusicTimer], a
    ret nz                  ; current note still going
    ld a, [wMusicPtr]
    ld l, a
    ld a, [wMusicPtr + 1]
    ld h, a
.read
    ld a, [hli]
    ld c, a                 ; pitch low
    ld a, [hli]
    ld d, a                 ; pitch high
    ld a, [hli]             ; frames
    and a
    jr nz, .note
    ld a, d                 ; end of the song:
    inc a                   ; pitch high $FF -> 0 = stop
    jr z, StopMusic
    ld a, [wMusicLoop]      ; otherwise go back to the start
    ld l, a
    ld a, [wMusicLoop + 1]
    ld h, a
    jr .read
.note
    ld [wMusicTimer], a
    ld a, l
    ld [wMusicPtr], a
    ld a, h
    ld [wMusicPtr + 1], a
    ; Turn the channel off before every new note. On the original handheld,
    ; restarting channel 3 while it plays can scramble the wave memory.
    xor a
    ldh [rNR30], a
    ld a, c
    or d
    ret z                   ; pitch 0 = rest: stay silent
    ld a, $80
    ldh [rNR30], a          ; channel on again
    ld a, %01000000         ; half volume (the music stays in the background)
    ldh [rNR32], a
    ld a, c
    ldh [rNR33], a
    ld a, d
    or $80                  ; bit 7 = start the note
    ldh [rNR34], a
    ret

; -----------------------------------------------------------------------------
; Effect data
; -----------------------------------------------------------------------------
;                sweep duty  envel pitch lo/hi (bit 7 of hi = start)
SfxStart:   db $15, $80, $F2, $00, $86   ; pitch rises quickly
SfxPause:   db $00, $80, $A1, $83, $87   ; short high blip
SfxTired:   db $1D, $80, $A3, $00, $87   ; pitch falls: "phew"
SfxWilt:    db $2F, $40, $C4, $40, $86   ; slow low droop
SfxCaw:     db $2B, $00, $C2, $00, $85   ; thin, harsh, falling: "caw"
SfxMenu:    db $00, $80, $81, $C0, $87   ; tiny tick
;                len   envel texture start
SfxSplash:  db $00, $41, $24, $80        ; quiet short hiss
SfxFlood:   db $00, $F5, $46, $80        ; loud long splash
SfxScare:   db $00, $A2, $35, $80        ; wings flapping away
SfxPop:     db $00, $F1, $20, $80        ; POP!

; -----------------------------------------------------------------------------
; Tunes for channel 2: each note = pitch low, pitch high, frames; 0,0,0 ends.
; -----------------------------------------------------------------------------
MACRO NOTE
    db LOW(\1), HIGH(\1), \2
ENDM
TuneSprout:
    NOTE SQ_E5, 4
    NOTE SQ_G5, 4
    NOTE SQ_C6, 10
    db 0, 0, 0
TuneWin:
    NOTE SQ_C5, 7
    NOTE SQ_E5, 7
    NOTE SQ_G5, 7
    NOTE SQ_C6, 20
    db 0, 0, 0
TuneLose:
    NOTE SQ_G4, 10
    NOTE SQ_E4, 10
    NOTE SQ_C4, 24
    db 0, 0, 0
; Kip's motif: Kip's signature "voice" in every Kettle Classics game
; (see shared/sound/KIP_MOTIF.md). Up a chord, a step down, then a high leap.
TuneKip:
    NOTE SQ_G5, 5
    NOTE SQ_C6, 5
    NOTE SQ_E6, 5
    NOTE SQ_D6, 5
    NOTE SQ_G6, 14
    db 0, 0, 0
; The POP jingle (with the noise "pop" from SfxPop).
TunePop:
    NOTE SQ_C6, 4
    NOTE SQ_E6, 4
    NOTE SQ_G6, 4
    NOTE SQ_C7, 18
    db 0, 0, 0

; -----------------------------------------------------------------------------
; Songs for channel 3 (original Kettle Forge Studios music)
; -----------------------------------------------------------------------------
MACRO MNOTE                 ; MNOTE C5, 10 = play C5 for 10 frames
    db LOW(WV_\1), HIGH(WV_\1), \2
ENDM
MACRO MREST                 ; MREST 10 = silence for 10 frames
    db 0, 0, \1
ENDM
MACRO MLOOP                 ; back to the start of the song
    db 0, 0, 0
ENDM
MACRO MEND                  ; stop
    db 0, $FF, 0
ENDM

; "Morning Field": the title tune.
SongTitle:
    MNOTE C5, 10
    MNOTE E5, 10
    MNOTE G5, 10
    MNOTE A5, 20
    MNOTE G5, 10
    MNOTE E5, 20
    MNOTE D5, 10
    MNOTE E5, 10
    MNOTE G5, 10
    MNOTE E5, 10
    MNOTE D5, 10
    MNOTE C5, 30
    MREST 10
    MNOTE E5, 10
    MNOTE G5, 10
    MNOTE A5, 10
    MNOTE C6, 20
    MNOTE A5, 10
    MNOTE G5, 20
    MNOTE A5, 10
    MNOTE G5, 10
    MNOTE E5, 10
    MNOTE D5, 10
    MNOTE E5, 10
    MNOTE C5, 30
    MREST 20
    MLOOP

; "Light Rain": plays during a stage. Calm, so it doesn't rush the player.
SongPlay:
    MNOTE A4, 12
    MNOTE C5, 12
    MNOTE D5, 12
    MNOTE E5, 24
    MNOTE D5, 12
    MNOTE C5, 12
    MNOTE A4, 12
    MNOTE G4, 24
    MREST 12
    MNOTE A4, 12
    MNOTE C5, 12
    MNOTE D5, 12
    MNOTE E5, 12
    MNOTE G5, 24
    MNOTE E5, 12
    MNOTE D5, 36
    MREST 12
    MNOTE C5, 12
    MNOTE D5, 12
    MNOTE E5, 24
    MNOTE C5, 12
    MNOTE A4, 12
    MNOTE G4, 12
    MNOTE A4, 36
    MREST 24
    MLOOP

; "Sprouted": the ending.
SongEnding:
    MNOTE G5, 8
    MNOTE C6, 8
    MNOTE E6, 8
    MNOTE D6, 16
    MNOTE C6, 8
    MNOTE A5, 8
    MNOTE G5, 16
    MNOTE E5, 8
    MNOTE G5, 8
    MNOTE C6, 24
    MREST 8
    MNOTE A5, 8
    MNOTE G5, 8
    MNOTE E5, 8
    MNOTE D5, 16
    MNOTE E5, 8
    MNOTE G5, 8
    MNOTE C6, 32
    MREST 16
    MLOOP

; Lab sound test for channel 3: three notes, then stop.
SongTest:
    MNOTE C5, 20
    MNOTE E5, 20
    MNOTE G5, 30
    MEND

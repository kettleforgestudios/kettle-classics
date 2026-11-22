// gbtest: headless test runner for our Pocket (Game Boy) games.
// Runs a ROM in the SameBoy core (MIT, fetched at test time, never bundled),
// presses buttons on given frames, saves screenshots, and checks memory.
//
// Usage:
//   gbtest <boot.bin> <game.gb> <frames> [actions...]
// Actions:
//   press:<frame>:<buttons>:<count>   hold buttons from <frame> for <count> frames
//                                     buttons: any of A B S(elect) T(start) U D L R
//   shot:<frame>:<file.ppm>           save the screen after <frame>
//   expect:<frame>:<addr hex>:<byte hex>  fail unless memory[addr] == byte
//   expectnot:<frame>:<addr hex>:<byte hex>
//   poke:<frame>:<addr hex>:<byte hex>    write a byte into memory after <frame>
//                                     (lets a test jump ahead, e.g. to a later stage)
//   wav:<file.wav>                    record the game's sound to a WAV file
// Exit code 0 = all expectations passed.
#include "gb.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t pixels[256 * 224];

// --- Sound recording (optional) -----------------------------------------------
// SameBoy hands us one stereo sample at a time; we collect them and write a
// plain 16-bit WAV file at the end.
#define SAMPLE_RATE 44100
static int16_t *audio;
static size_t audioCount, audioCap;
static void onSample(GB_gameboy_t *gb, GB_sample_t *s) {
    (void)gb;
    if (audioCount + 2 > audioCap) {
        audioCap = audioCap ? audioCap * 2 : 1 << 20;
        audio = realloc(audio, audioCap * sizeof *audio);
    }
    audio[audioCount++] = s->left;
    audio[audioCount++] = s->right;
}
static void put32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }
static void put16(FILE *f, uint16_t v) { fwrite(&v, 2, 1, f); }
static void saveWav(const char *path) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return; }
    uint32_t bytes = (uint32_t)(audioCount * 2);
    fwrite("RIFF", 1, 4, f); put32(f, 36 + bytes); fwrite("WAVEfmt ", 1, 8, f);
    put32(f, 16); put16(f, 1); put16(f, 2); put32(f, SAMPLE_RATE);
    put32(f, SAMPLE_RATE * 4); put16(f, 4); put16(f, 16);
    fwrite("data", 1, 4, f); put32(f, bytes);
    fwrite(audio, 2, audioCount, f);
    fclose(f);
}
static uint32_t rgb(GB_gameboy_t *gb, uint8_t r, uint8_t g, uint8_t b) {
    (void)gb;
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

static uint8_t *readFile(const char *path, size_t *size) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(2); }
    fseek(f, 0, SEEK_END);
    *size = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *data = malloc(*size);
    if (fread(data, 1, *size, f) != *size) { perror(path); exit(2); }
    fclose(f);
    return data;
}

static void savePpm(const char *path, unsigned w, unsigned h) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); exit(2); }
    fprintf(f, "P6\n%u %u\n255\n", w, h);
    for (unsigned i = 0; i < w * h; i++) {
        uint8_t px[3] = { pixels[i] >> 16, pixels[i] >> 8, pixels[i] };
        fwrite(px, 1, 3, f);
    }
    fclose(f);
}

static void setButtons(GB_gameboy_t *gb, const char *spec, bool down) {
    for (const char *c = spec; *c; c++) {
        GB_key_t key;
        switch (*c) {
            case 'A': key = GB_KEY_A; break;
            case 'B': key = GB_KEY_B; break;
            case 'S': key = GB_KEY_SELECT; break;
            case 'T': key = GB_KEY_START; break;
            case 'U': key = GB_KEY_UP; break;
            case 'D': key = GB_KEY_DOWN; break;
            case 'L': key = GB_KEY_LEFT; break;
            case 'R': key = GB_KEY_RIGHT; break;
            default: continue;
        }
        GB_set_key_state(gb, key, down);
    }
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: gbtest <boot.bin> <game.gb> <frames> [actions...]\n");
        return 2;
    }
    size_t bootSize, romSize;
    uint8_t *boot = readFile(argv[1], &bootSize);
    uint8_t *rom = readFile(argv[2], &romSize);
    int frames = atoi(argv[3]);

    GB_gameboy_t *gb = GB_init(GB_alloc(), GB_MODEL_DMG_B);
    GB_set_rgb_encode_callback(gb, rgb);
    GB_set_pixels_output(gb, pixels);
    GB_load_boot_rom_from_buffer(gb, boot, bootSize);
    GB_load_rom_from_buffer(gb, rom, romSize);
    GB_reset(gb);

    const char *wavPath = NULL;
    for (int i = 4; i < argc; i++) {
        if (strncmp(argv[i], "wav:", 4) == 0) wavPath = argv[i] + 4;
    }
    if (wavPath) {
        GB_set_sample_rate(gb, SAMPLE_RATE);
        GB_apu_set_sample_callback(gb, onSample);
    }

    int failures = 0;
    for (int frame = 1; frame <= frames; frame++) {
        // Apply button presses that are active on this frame.
        for (int i = 4; i < argc; i++) {
            int start, count;
            char buttons[16];
            if (sscanf(argv[i], "press:%d:%15[^:]:%d", &start, buttons, &count) == 3) {
                if (frame == start) setButtons(gb, buttons, true);
                if (frame == start + count) setButtons(gb, buttons, false);
            }
        }
        GB_run_frame(gb);
        for (int i = 4; i < argc; i++) {
            int at, addr, value;
            char path[256];
            if (sscanf(argv[i], "shot:%d:%255s", &at, path) == 2 && at == frame) {
                savePpm(path, GB_get_screen_width(gb), GB_get_screen_height(gb));
                printf("frame %d: saved %s\n", frame, path);
            } else if (sscanf(argv[i], "expect:%d:%x:%x", &at, &addr, &value) == 3 && at == frame) {
                uint8_t got = GB_safe_read_memory(gb, (uint16_t)addr);
                bool ok = got == value;
                printf("frame %d: [%04X] = %02X, expected %02X: %s\n", frame, addr, got, value, ok ? "PASS" : "FAIL");
                failures += !ok;
            } else if (sscanf(argv[i], "poke:%d:%x:%x", &at, &addr, &value) == 3 && at == frame) {
                GB_write_memory(gb, (uint16_t)addr, (uint8_t)value);
                printf("frame %d: poke [%04X] = %02X\n", frame, addr, value);
            } else if (sscanf(argv[i], "expectnot:%d:%x:%x", &at, &addr, &value) == 3 && at == frame) {
                uint8_t got = GB_safe_read_memory(gb, (uint16_t)addr);
                bool ok = got != value;
                printf("frame %d: [%04X] = %02X, expected not %02X: %s\n", frame, addr, got, value, ok ? "PASS" : "FAIL");
                failures += !ok;
            }
        }
    }
    if (wavPath) {
        saveWav(wavPath);
        printf("saved %s\n", wavPath);
    }
    GB_free(gb);
    free(gb);
    free(boot);
    free(rom);
    printf("%s (%d failure%s)\n", failures ? "FAILED" : "ALL PASSED", failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}

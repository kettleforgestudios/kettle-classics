# Builds kernel-drop.gb with RGBDS (https://rgbds.gbdev.io, MIT license).
# Usage: make            (needs rgbasm, rgblink, rgbfix on PATH, or set RGBDS=path/)
RGBDS ?=
ASM   := $(RGBDS)rgbasm
LINK  := $(RGBDS)rgblink
FIX   := $(RGBDS)rgbfix

OBJS := build/main.o build/gfx.o

kernel-drop.gb: $(OBJS)
	$(LINK) -n kernel-drop.sym -m kernel-drop.map -o $@ $(OBJS)
	# Header: title + checksums only ("-f hg"). No Nintendo logo on purpose.
	$(FIX) -f hg -t "KERNEL DROP" -p 0xFF $@

build/%.o: src/%.asm src/hardware.inc src/charmap.inc
	@mkdir -p build
	$(ASM) -Weverything -I src/ -o $@ $<

clean:
	rm -rf build kernel-drop.gb kernel-drop.sym kernel-drop.map

.PHONY: clean

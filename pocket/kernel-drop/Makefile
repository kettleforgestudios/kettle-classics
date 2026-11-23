# Builds kernel-drop.gb with RGBDS (https://rgbds.gbdev.io, MIT license).
# Usage: make            (needs rgbasm, rgblink, rgbfix on PATH, or set RGBDS=path/)
RGBDS ?=
ASM   := $(RGBDS)rgbasm
LINK  := $(RGBDS)rgblink
FIX   := $(RGBDS)rgbfix

KERNEL_DROP_BUILD ?=

OBJS := build/main.o build/gfx.o

kernel-drop.gb: $(OBJS)
	$(LINK) -n kernel-drop.sym -m kernel-drop.map -o $@ $(OBJS)
	# Header: title + checksums only ("-f hg"). No Nintendo logo on purpose.
	$(FIX) -f hg -t "KERNEL DROP" -p 0xFF $@

# main.asm pulls in the other .asm files with INCLUDE, so any change rebuilds it.
build/main.o: ASM_FLAGS = $(if $(KERNEL_DROP_BUILD),-D KERNEL_DROP_BUILD=$(KERNEL_DROP_BUILD))
build/main.o: src/main.asm src/title.asm src/play.asm src/sound.asm src/lab.asm \
              src/hardware.inc src/charmap.inc src/notes.inc build/build-number

build/%.o: src/%.asm src/hardware.inc src/charmap.inc
	@mkdir -p build
	$(ASM) $(ASM_FLAGS) -Weverything -I src/ -o $@ $<

# Reassemble the title when the build number changes, even in an existing output folder.
build/build-number: FORCE
	@mkdir -p build
	@printf '%s\n' '$(KERNEL_DROP_BUILD)' > $@.tmp
	@if cmp -s $@.tmp $@; then rm $@.tmp; else mv $@.tmp $@; fi

clean:
	rm -rf build kernel-drop.gb kernel-drop.sym kernel-drop.map

.PHONY: clean FORCE

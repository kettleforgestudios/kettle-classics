RGBDS ?=
PYTHON ?= python3

seed-room.gbc: main.asm room.inc
	$(RGBDS)rgbasm -Wall -o seed-room.o main.asm
	$(RGBDS)rgblink -n seed-room.sym -o $@ seed-room.o
	$(RGBDS)rgbfix -f hg -C -t "SEED ROOM" -p 0 $@

room.inc: art.py
	$(PYTHON) art.py

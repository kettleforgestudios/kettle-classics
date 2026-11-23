CL65 ?= cl65
PYTHON ?= python3

fields-of-silk.nes: game.c start.s nes.cfg tiles.chr
	$(CL65) -t nes -C nes.cfg -Ors -m fields-of-silk.map -Ln fields-of-silk.lbl -o $@ start.s game.c
tiles.chr: tiles.py
	$(PYTHON) tiles.py

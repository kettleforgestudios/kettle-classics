RGBDS ?=

fields-of-silk.gbc: main.asm
	$(RGBDS)rgbasm -Wall -o fields-of-silk.o main.asm
	$(RGBDS)rgblink -n fields-of-silk.sym -o $@ fields-of-silk.o
	$(RGBDS)rgbfix -f hg -C -t "FIELDS OF SILK" -p 0 $@

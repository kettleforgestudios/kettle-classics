; Original Kettle Forge Studios pixel art (font + Kip). Drawn as ASCII art, stored as tiles.
; Each `row` is 8 pixels: 0 = lightest, 3 = darkest.

SECTION "Graphics", ROM0

Tiles::
    ; tile 0: blank
    ds 16, 0
    ; tile 1: letter A
    dw `03333000
    dw `33003300
    dw `33003300
    dw `33333300
    dw `33003300
    dw `33003300
    dw `33003300
    dw `00000000
    ; tile 2: letter C
    dw `03333000
    dw `33003300
    dw `33000000
    dw `33000000
    dw `33000000
    dw `33003300
    dw `03333000
    dw `00000000
    ; tile 3: letter D
    dw `33333000
    dw `33003300
    dw `33003300
    dw `33003300
    dw `33003300
    dw `33003300
    dw `33333000
    dw `00000000
    ; tile 4: letter E
    dw `33333300
    dw `33000000
    dw `33000000
    dw `33333000
    dw `33000000
    dw `33000000
    dw `33333300
    dw `00000000
    ; tile 5: letter I
    dw `33333300
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00330000
    dw `33333300
    dw `00000000
    ; tile 6: letter K
    dw `33003300
    dw `33033000
    dw `33330000
    dw `33300000
    dw `33330000
    dw `33033000
    dw `33003300
    dw `00000000
    ; tile 7: letter L
    dw `33000000
    dw `33000000
    dw `33000000
    dw `33000000
    dw `33000000
    dw `33000000
    dw `33333300
    dw `00000000
    ; tile 8: letter N
    dw `33003300
    dw `33303300
    dw `33333300
    dw `33333300
    dw `33033300
    dw `33003300
    dw `33003300
    dw `00000000
    ; tile 9: letter O
    dw `03333000
    dw `33003300
    dw `33003300
    dw `33003300
    dw `33003300
    dw `33003300
    dw `03333000
    dw `00000000
    ; tile 10: letter P
    dw `33333000
    dw `33003300
    dw `33003300
    dw `33333000
    dw `33000000
    dw `33000000
    dw `33000000
    dw `00000000
    ; tile 11: letter R
    dw `33333000
    dw `33003300
    dw `33003300
    dw `33333000
    dw `33330000
    dw `33033000
    dw `33003300
    dw `00000000
    ; tile 12: letter S
    dw `03333000
    dw `33003300
    dw `33000000
    dw `03333000
    dw `00003300
    dw `33003300
    dw `03333000
    dw `00000000
    ; tile 13: letter T
    dw `33333300
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00330000
    dw `00000000
    ; tile 14: Kip top-left
    dw `00000033
    dw `00003322
    dw `00032111
    dw `00321111
    dw `00321331
    dw `03211331
    dw `03211111
    dw `03221131
    ; tile 15: Kip top-right
    dw `33000000
    dw `22330000
    dw `11123000
    dw `11112300
    dw `13312300
    dw `13311230
    dw `11111230
    dw `13112230
    ; tile 16: Kip bottom-left
    dw `03221113
    dw `00322111
    dw `00322211
    dw `00032222
    dw `00003222
    dw `00000332
    dw `00000003
    dw `00000000
    ; tile 17: Kip bottom-right
    dw `31112230
    dw `11112300
    dw `11222300
    dw `22223000
    dw `22230000
    dw `23300000
    dw `30000000
    dw `00000000
TilesEnd::


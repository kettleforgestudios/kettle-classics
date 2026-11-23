"""Original 8 × 8 tiles and the first Seed Room map."""
from pathlib import Path

tiles = []


def tile(rows):
    values = rows.split()
    assert len(values) == 8 and all(len(row) == 8 for row in values)
    tiles.append('    dw ' + ','.join('`' + row for row in values))


tile('00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000')
tile('11111111 11111111 11111111 11111111 11111111 11111111 11111111 11111111')
tile('11111111 11111111 11121111 11211111 11111111 11111111 11111111 11111111')
tile('00000000 01110000 00000110 00000000 00000000 11000000 00001110 00000000')
tile('22222222 21112111 22222222 22232222 22222222 21111211 22222222 11111111')
tile('11111111 11011011 10100101 10000001 10000001 10100101 11011011 11111111')
tile('11111111 11111111 11133111 11322311 11322311 11133111 11111111 11111111')
tile('11111131 11111221 11113211 11122111 11221111 12211111 12111111 21111111')
tile('00333300 03111130 31211113 31131313 31131313 32111123 03222230 00333300')
tile('00000000 00033000 00322300 03222230 03222230 00333300 00000000 00000000')
tile('00000000 00333000 00323000 00020000 02020200 00222000 00020000 00111000')

font = [
    '010 101 111 101 101','110 101 110 101 110','111 100 100 100 111',
    '110 101 101 101 110','111 100 110 100 111','111 100 110 100 100',
    '111 100 101 101 111','101 101 111 101 101','111 010 010 010 111',
    '001 001 001 101 111','101 101 110 101 101','100 100 100 100 111',
    '101 111 111 101 101','101 111 111 111 101','111 101 101 101 111',
    '110 101 110 100 100','111 101 101 111 001','110 101 110 101 101',
    '111 100 111 001 111','111 010 010 010 010','101 101 101 101 111',
    '101 101 101 101 010','101 101 111 111 101','101 101 010 101 101',
    '101 101 010 010 010','111 001 010 100 111',
]
for glyph in font:
    tile(' '.join(['00000000'] + ['00'+row.replace('1','3')+'000' for row in glyph.split()] + ['00000000']*2))
tile('00000000 00030000 00330000 00030000 00030000 00333000 00000000 00000000')


def encode(label):
    return [0 if c == ' ' else 37 if c == '1' else 11 + ord(c)-ord('A') for c in label]


def rows(data):
    return '\n'.join('    db '+', '.join(str(v) for v in data[i:i+20]) for i in range(0,len(data),20))


def pad(label):
    return (label + ' ' * 20)[:20]


layout, attrs = [], []
for y in range(18):
    for x in range(20):
        kind, pal = 0, 0
        if y == 0:
            kind = encode(pad('SEED ROOM    ALPHA 1'))[x]
        elif y == 16:
            kind = encode(pad('A PICK UP SEED'))[x]
        if 2 <= x <= 17 and 3 <= y <= 14:
            kind, pal = (2 if (x*5+y*7) % 13 < 3 else 1), 1
            if x in (10,11):
                kind, pal = 3, 2
            if (x,y) == (15,6):
                kind, pal = 5, 3
            if (x,y) == (9,8):
                kind, pal = 6, 3
            if (x,y) == (12,8):
                kind, pal = 7, 1
        layout.append(kind)
        attrs.append(pal)

segments = ['Tiles:',*tiles,'TilesEnd:','RoomTiles:',rows(layout),'RoomAttrs:',rows(attrs)]
for name, label in [('Pick','A PICK UP SEED'),('Pull','B PULL LEAF BRIDGE'),('Plant','A PLANT THE SEED'),('Bloom','BLOOM   START RESET'),('Blank','')]:
    segments.extend([f'Hint{name}:',rows(encode(pad(label)))])
Path('room.inc').write_text('\n'.join(segments)+'\n')

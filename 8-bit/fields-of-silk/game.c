/* Fields of Silk, original 8-bit cartridge. Each tile occupies eight pixels. */
typedef unsigned char u8;
typedef unsigned int u16;
#define REG(address) (*(volatile u8 *)(address))
#define W 28
#define H 24
#define STRIDE 32
#define CELL(x,y) (((u16)(y) << 5) + (x))
#define OAM ((u8 *)0x0200)
#define DRY 0
#define CORN 1
#define REACH 2
#define SILK 4
#define A 1
#define B 2
#define SELECT 4
#define START 8
#define UP 16
#define DOWN 32
#define LEFT 64
#define RIGHT 128
#define GRACE 150

void waitFrame(void);
void copyRow(void);
u8 renderRow[W];
u8 board[STRIDE * H];
u8 *floodSeed;
u8 flood(void);
static u8 x, y, bx, by, lives, paused, won, contrast, tick, age, row;
static u8 anchorX, anchorY, armed, lengthLo, lengthHi, buttons, pressed;
static u8 phase, fromX, fromY;
static u16 remaining;
u8 hud[19];
u16 rowAddress;
u8 soilColor;
void render(void);
static const signed char dx[] = {1, -1, 0, 0};
static const signed char dy[] = {0, 0, 1, -1};
static const u8 palette[] = {
    0x09,0x27,0x19,0x30, 0x09,0x17,0x2a,0x30,
    0x09,0x07,0x29,0x30, 0x09,0x27,0x2a,0x30,
    0x09,0x07,0x28,0x38, 0x09,0x04,0x14,0x16,
    0x09,0x04,0x14,0x26, 0x09,0x07,0x28,0x38
};

static void addr(u16 p) {
    (void)REG(0x2002);
    REG(0x2006) = p >> 8;
    REG(0x2006) = p;
}
static void tone(u8 pitch) {
    REG(0x4000) = 0x93;
    REG(0x4001) = 0;
    REG(0x4002) = pitch;
    REG(0x4003) = 0x08;
}
static void readPad(void) {
    u8 i, next = 0;
    REG(0x4016) = 1;
    REG(0x4016) = 0;
    for (i = 0; i < 8; ++i) {
        next >>= 1;
        if (REG(0x4016) & 1) next |= 0x80;
    }
    pressed = next & ~buttons;
    buttons = next;
}
static void text(const char *s) {
    while (*s) REG(0x2007) = *s++;
}
static u16 trailLength(void) { return ((u16)lengthHi << 8) + lengthLo; }

static void clearTrail(void) {
    u16 cell;
    for (cell = 0; cell < sizeof(board); ++cell)
        if (board[cell] >= SILK) board[cell] = DRY;
    lengthLo = lengthHi = age = armed = phase = 0;
}
static void resetField(void) {
    u8 i, j;
    for (j = 0; j < H; ++j)
        for (i = 0; i < W; ++i)
            board[CELL(i,j)] = (!i || !j || i == W-1 || j == H-1) ? CORN : DRY;
    x = 0; y = H/2;
    bx = 20; by = 11;
    lives = 3;
    paused = won = contrast = row = tick = 0;
    remaining = (W-2)*(H-2);
    clearTrail();
}
static void capture(void) {
    u16 cell;
    u8 i, j, change;
    u8 *p;
    remaining = 0;
    floodSeed = board + CELL(bx,by);
    /* If the bounded queue fills, finish marking with a board sweep. */
    if (flood()) do {
        change = 0;
        for (j = 1; j < H-1; ++j) {
            p = board + CELL(1,j);
            for (i = 1; i < W-1; ++i, ++p) {
                if (*p == DRY &&
                    (p[-1] == REACH || p[1] == REACH ||
                     p[-STRIDE] == REACH || p[STRIDE] == REACH)) {
                    *p = REACH;
                    change = 1;
                }
            }
        }
    } while (change);
    for (j = 0; j < H; ++j)
        for (i = 0; i < W; ++i) {
            cell = CELL(i,j);
            if (board[cell] == REACH) { board[cell] = DRY; ++remaining; }
            else board[cell] = CORN;
        }
    if (remaining <= 4) {
        for (cell = 0; cell < sizeof(board); ++cell) board[cell] = CORN;
        remaining = 0;
        won = 1;
    }
    lengthLo = lengthHi = age = armed = 0;
    tone(0x50);
}
static void move(u8 nx, u8 ny) {
    fromX = x; fromY = y;
    x = nx; y = ny; phase = 3;
}
static void player(void) {
    u8 dir, nx, ny, tile;
    u16 cell;
    if (phase) { --phase; return; }
    cell = CELL(x,y);
    if ((buttons & B) && trailLength()) {
        dir = board[cell] - SILK;
        board[cell] = DRY;
        if (!lengthLo) --lengthHi;
        --lengthLo;
        move(x + dx[dir], y + dy[dir]);
        if (!trailLength()) age = 0;
        return;
    }
    if ((pressed & A) && board[cell] == CORN) {
        armed = 1;
        tone(0x30);
    }
    if (buttons & RIGHT) dir = 0;
    else if (buttons & LEFT) dir = 1;
    else if (buttons & DOWN) dir = 2;
    else if (buttons & UP) dir = 3;
    else return;
    nx = x + dx[dir]; ny = y + dy[dir];
    if (nx >= W || ny >= H || (nx == bx && ny == by)) return;
    cell = CELL(nx,ny);
    tile = board[cell];
    if (tile == CORN) {
        if (trailLength()) capture();
    } else if (tile == DRY && armed) {
        if (!trailLength()) { anchorX = nx; anchorY = ny; }
        board[cell] = SILK + (dir ^ 1);
        if (!++lengthLo) ++lengthHi;
    } else return;
    move(nx,ny);
}
static u8 bugStep(u8 nx, u8 ny) {
    u8 tile;
    if (nx >= W || ny >= H) return 0;
    tile = board[CELL(nx,ny)];
    if (tile >= SILK && age == GRACE) {
        /* Follow the strand backward to return Kip to stable ground. */
        while (board[CELL(x,y)] >= SILK) {
            u8 dir = board[CELL(x,y)] - SILK;
            x += dx[dir]; y += dy[dir];
        }
        clearTrail();
        --lives;
        tone(0xbc);
        return 1;
    }
    if (tile != DRY || (nx == x && ny == y)) return 0;
    bx = nx; by = ny;
    return 1;
}
static void weevil(void) {
    u8 dir;
    ++tick;
    if (!trailLength()) age = 0;
    else if (age < GRACE && ++age == GRACE) { tone(0x96); return; }
    if (age == GRACE) {
        if (tick & 31) return;
        /* Go after the strand's start, with a warning and room to react. */
        if (bx != anchorX && bugStep(bx + (bx < anchorX ? 1 : -1), by)) return;
        if (by != anchorY) bugStep(bx, by + (by < anchorY ? 1 : -1));
    } else if (!(tick & 15)) {
        dir = (tick >> 4) & 3;
        bugStep(bx + dx[dir], by + dy[dir]);
    }
}
static void sprite(u8 slot, u8 px, u8 py, u8 tile, u8 attr) {
    OAM[slot] = py - 1;
    OAM[slot+1] = tile;
    OAM[slot+2] = attr;
    OAM[slot+3] = px;
}
static void prepareRow(void) {
    u8 i, tile, mask;
    u8 *p = board + CELL(0,row);
    for (i = 0; i < W; ++i, ++p) {
        tile = *p;
        if (tile >= SILK) {
            mask = 0;
            if (p[-STRIDE]) mask |= 8;
            if (p[1]) mask |= 4;
            if (p[STRIDE]) mask |= 2;
            if (p[-1]) mask |= 1;
            tile = 8 + mask;
        }
        if (tile == DRY && ((i*5 + row*7 + (row >> 2)) & 15) == 3) tile = 3;
        renderRow[i] = tile;
    }
}
static void drawRow(void) {
    addr(0x2002 + CELL(0,row+3));
    copyRow();
    if (++row == H) row = 0;
}
static void preparePercent(u8 progress) {
    hud[0] = '0' + progress / 100;
    hud[1] = '0' + (progress / 10) % 10;
    hud[2] = '0' + progress % 10;
    hud[3] = '%';
}
static void prepareHud(void) {
    u8 i;
    const char *status;
    for (i = 4; i < sizeof(hud); ++i) hud[i] = ' ';
    for (i = 0; i < lives; ++i) hud[8+i] = '*';
    if (won) status = "GROWN";
    else if (!lives) status = "RETRY";
    else if (paused) status = "PAUSE";
    else return;
    for (i = 0; i < 5; ++i) hud[14+i] = status[i];
}
int main(void) {
    u8 i, progress, px, py;
    u16 n, lastRemaining = 0xffff;
    addr(0x2000);
    for (n = 0; n < 1024; ++n) REG(0x2007) = ' ';
    addr(0x23c0);
    for (i = 0; i < 64; ++i) REG(0x2007) = 0;
    addr(0x3f00);
    for (i = 0; i < sizeof(palette); ++i) REG(0x2007) = palette[i];
    addr(0x2022); text("FIELD");
    addr(0x2362); text("ALPHA 2");
    resetField();
    for (i = 0; i < 64; ++i) OAM[i*4] = 0xff;
    for (i = 0; i < H; ++i) { prepareRow(); drawRow(); }
    REG(0x4015) = 1;
    REG(0x2005) = 0;
    REG(0x2005) = 0;
    REG(0x2000) = 0x80;
    REG(0x2001) = 0x1e;
    progress = 0;
    for (;;) {
        readPad();
        if (pressed & START) {
            if (won || !lives) resetField();
            else paused ^= 1;
        }
        if (pressed & SELECT) contrast ^= 1;
        if (!paused && lives && !won) { player(); weevil(); }
        if (remaining != lastRemaining) {
            lastRemaining = remaining;
            progress = (u16)(((W-2)*(H-2) - remaining)*100u) / ((W-2)*(H-2));
            preparePercent(progress);
        }
        px = (x+2)*8; py = (y+3)*8;
        if (phase) { px += (fromX-x)*phase*2; py += (fromY-y)*phase*2; }
        sprite(0,px,py,4,0);
        sprite(4,(bx+2)*8-4,won ? 0 : (by+3)*8,5,age == GRACE ? 2 : 1);
        sprite(8,(bx+2)*8+4,won ? 0 : (by+3)*8,6,age == GRACE ? 2 : 1);
        prepareRow();
        prepareHud();
        rowAddress = 0x2002 + CELL(0,row+3);
        soilColor = contrast ? 0x17 : 0x27;
        render();
        if (++row == H) row = 0;
    }
    return 0;
}

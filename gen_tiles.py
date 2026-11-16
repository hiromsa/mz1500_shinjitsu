#!/usr/bin/env python3
# SHINJITSU NO TOU - PCG tiles. Each tile: 8 strings of 8 chars -> 24 bytes (B,R,G planes)
PAL = {'.':0,'B':1,'R':2,'M':3,'G':4,'C':5,'Y':6,'W':7,'k':0}
def T(rows):
    assert len(rows)==8 and all(len(r)==8 for r in rows), rows
    out=[]
    for plane in (1,2,4):
        for r in rows:
            b=0
            for i,ch in enumerate(r):
                if PAL[ch]&plane: b |= (0x80>>i)
            out.append(b)
    return out
def T2(rows16, idx):
    # rows16: 16 strings of 16 -> tile idx (0..3) of 2x2 block
    ox = (idx%2)*8; oy = (idx//2)*8
    return T([r[ox:ox+8] for r in rows16[oy:oy+8]])
def T4(rows32, idx):
    ox = (idx%4)*8; oy = (idx//4)*8
    return T([r[ox:ox+8] for r in rows32[oy:oy+8]])

def brick(fg, n):
    # line-less wall face: solid fg with a few black dots (same dot
    # positions as floor()); more dots = dimmer = reads farther away.
    # No mortar grid, so faces at different depths do not share the
    # same "grid of squares" scale cue (user feedback 2026-11-16).
    rows=[[fg]*8 for _ in range(8)]
    pts=[(1,1),(5,3),(3,6),(6,7),(2,4),(7,1)]
    for (x,y) in pts[:n]:
        rows[y][x]="."
    return T(["".join(r) for r in rows])
def side(fg):
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            r += "." if (x - y//2) % 5 == 4 else fg
        rows.append(r)
    return T(rows)
def side_dither():
    # side mask of tiles 5/6, filled pixels alternate cyan/blue (checker)
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            if (x - y//2) % 5 == 4: r += "."
            else: r += 'C' if (x+y)%2==0 else 'B'
        rows.append(r)
    return T(rows)
def floor(fg, n):
    rows=["........"]*8
    pts=[(1,1),(5,3),(3,6),(6,7),(2,4),(7,1)]
    rows=[list(r) for r in rows]
    for i,(x,y) in enumerate(pts[:n]):
        rows[y][x]=fg
    return T(["".join(r) for r in rows])

tiles = []
tiles.append(T(["........"]*8))            # 0 blank
tiles.append(brick('W',2))                  # 1 face near (line-less)
tiles.append(brick('C',4))                  # 2 face mid (line-less)
tiles.append(brick('B',6))                  # 3 face far (line-less)
tiles.append(side_dither())                 # 4 side z=2 dither (cyan/blue)
tiles.append(side('C'))                     # 5 side mid
tiles.append(side('B'))                     # 6 side far
tiles.append(floor('W',6))                  # 7 floor near
tiles.append(floor('C',4))                  # 8 floor mid
tiles.append(floor('B',2))                  # 9 floor far / ceil
tiles.append(T([                            # 10 door
 "WWWWWWWW",
 "WRRRRRRW",
 "WR.RR.RW",
 "WR.RR.RW",
 "WR.RY.RW",
 "WR.RR.RW",
 "WR.RR.RW",
 "WWWWWWWW"]))
CHEST=[
"................",
"................",
"...YYYYYYYYYY...",
"..YWWWWWWWWWWY..",
"..YWWYYYYYYWWY..",
"..YWWYYYYYYWWY..",
"..YWWWWWWWWWWY..",
"...YYYYYYYYYY...",
"...YRRRRRRRRY...",
"...YRYYYYYYRY...",
"...YRRRRRRRRY...",
"....YYYYYYYY....",
"................",
"................",
"................",
"................"]
SPIRIT=[
"......WW........",
".....WWWW.......",
"....WWWWWW......",
"....WYYYYW......",
"....WWWWWW......",
"...CCCCCCCC.....",
"..CCCCCCCCCC....",
"..CC.CCCC.CC....",
"..CC.CCCC.CC....",
".....CCCC.......",
".....C..C.......",
".....C..C.......",
"....CC..CC......",
"................",
"................",
"................"]
STAIRS=[
"................",
"................",
"..........WWWWWW",
"..........W.....",
"......WWWW......",
"......W.........",
"..WWWW..........",
"..W.............",
"WW..............",
"................",
"................",
"................",
"................",
"................",
"................",
"................"]
PLAYER_A=[
"................",
".....WWWW.......",
"....WWWWWW......",
"....WYYYYW......",
"....WWWWWW......",
".....BBBB.......",
"....BBBBBB......",
"...BBBBBBBB.....",
"...BBBBBB...WW..",
"....BBBB....WW..",
"....BBBB........",
"....BB.BB.......",
"....BB.BB.......",
"...BBB.BBB......",
"................",
"................"]
PLAYER_B=[
"................",
".....WWWW.......",
"....WWWWWW......",
"....WYYYYW......",
"....WWWWWW......",
".....BBBB.......",
"....BBBBBB......",
"...BBBBBBBBWWWWW",
"...BBBBBB...WW..",
"....BBBB........",
"....BBBB........",
"....BB.BB.......",
"...BBB...BB.....",
"................",
"................",
"................"]
MONSTER_A=[
"................",
"....GG....GG....",
"....GG....GG....",
"....GGGGGGGG....",
"...GGGGGGGGGG...",
"...GYGGGGGGYG...",
"...GGGGGGGGGG...",
"....GWWWWWG.....",
"....GGGGGG......",
".....GGGG.......",
"....GG..GG......",
"....G....G......",
"...GG....GG.....",
"................",
"................",
"................"]
MONSTER_B=[
"................",
"....GG....GG....",
"....GG....GG....",
"....GGGGGGGG....",
"...GGGGGGGGGG...",
"...GYGGGGGGYG...",
"...GGGGGGGGGG...",
"....GRRRRG......",
"....GWRRWG......",
".....GGGG.......",
"....GG..GG......",
"....G....G......",
"...GG....GG.....",
"................",
"................",
"................"]
for blk in (CHEST,SPIRIT,STAIRS,PLAYER_A,PLAYER_B,MONSTER_A,MONSTER_B):
    for i in range(4): tiles.append(T2(blk,i))
# big lizard portrait 4x4 (tiles 39..54)
BIG=[
"................................",
"....YY......................YY..",
"....YY......................YY..",
"....YYY....................YYY..",
".....GGGGGGGGGGGGGGGGGGGGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGGGG....",
"...GGGGGGGGGGGGGGGGGGGGGGGGGG...",
"...GGGGGGGGGGGGGGGGGGGGGGGGGG...",
"...GGGRRRGGGGGGGGGGGGRRRGGG.....",
"..GGGGRRRRGGGGGGGGGGRRRRGGGG....",
"..GGGGRRRRGGGGGGGGGGRRRRGGGG....",
"...GGGGGGGGGGGGGGGGGGGGGGGG.....",
"...GGGGGGGGG.GG.G.GGGGGGGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGG......",
"....GGGGGGGGGGGGGGGGGGGGGG......",
".....GGGGGGGGGGGGGGGGGGGG.......",
"......GGGGGGGGGGGGGGGGGG........",
".......WWWWWWWWWWWWWWWW.........",
".......GWGWGWGWGWGWGWG..........",
".......GGGGGGGGGGGGGGGG.........",
"........GGGGRRRRRRGGGG..........",
".........GGGGGGGGGG...........",
"..........GGGGGGGG............",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
# fix row lengths to 32
BIG=[r.ljust(32,'.')[:32] for r in BIG]
for i in range(16): tiles.append(T4(BIG,i))
tiles.append(T([                            # 55 potion
"....GG..",
"...GGGG.",
"....WW..",
"...WRRW.",
"..WRRRRW",
"..WRRRRW",
"...WWWW.",
"........"]))
tiles.append(T([                            # 56 sword
".......W",
"......WW",
".....WW.",
".Y..WW..",
"..YWW...",
"..WW....",
".WW.....",
"WW......"]))
tiles.append(T([                            # 57 heart
".RR.RR..",
"RRRRRRR.",
"RRRRRRR.",
".RRRRR..",
"..RRR...",
"...R....",
"........",
"........"]))

# ---- enemy portraits 4x4 (tiles 58..249, enemy id order) ----
PIC_SLIME=[
"................................",
"................................",
"................................",
"................................",
"................................",
"..........CCCCCCCCCC............",
".......CCCCCCCCCCCCCCCC.........",
".....CCCCCCCCCCCCCCCCCCCC.......",
"....CCCWWCCCCCCCCCCCCCCCCCC.....",
"...CCCWWWWCCCCCCCCCCCCCCCCC....",
"...CCCCCCCCCCCCCCCCCCCCCCCC....",
"..CCCCCCCCCCCCCCCCCCCCCCCCCC...",
"..CCCCCCCCCCCCCCCCCCCCCCCCCC...",
"..CCCWWWWCCCCCCCCCCWWWWCCCC....",
"..CCWWWWWWCCCCCCCCWWWWWWCCC....",
"..CCWWkkWWCCCCCCCCWWkkWWCCC....",
"..CCWWkkWWCCCCCCCCWWkkWWCCC....",
"..CCCWWWWCCCCCCCCCCWWWWCCCC....",
"..CCCCCCCCCCCCCCCCCCCCCCCCC....",
"..CCCCCCCCCC......CCCCCCCCC....",
"...CCCCCCCC........CCCCCCC.....",
"...CCCCCCCCC......CCCCCCCC.....",
"....CCCCCCCCCCCCCCCCCCCCCC.....",
"....CCCCCCCCCCCCCCCCCCCCCC.....",
"...CCCCCCCCCCCCCCCCCCCCCCCC....",
"...CCCCCCCCCCCCCCCCCCCCCCCC....",
"..CCCCCCCCCCCCCCCCCCCCCCCCCC...",
"..CCCCCCCCCCCCCCCCCCCCCCCCCC...",
".CCCCCCCCCCCCCCCCCCCCCCCCCCCC..",
".CCCCCCCCCCCCCCCCCCCCCCCCCCCC..",
"................................",
"................................"]
PIC_BAT=[
"................................",
"................................",
"................................",
"................................",
"...........MM....MM.............",
"...........MMM..MMM.............",
"............MMMMMM..............",
"............MMMMMM..............",
".....MM.....MMMMMM.....MM.......",
"...MMMMM...MMMMMMMM...MMMMM.....",
"..MMMMMMM..MMMMMMMM..MMMMMMM....",
".MMMMMMMMM.MMMMMMMMM.MMMMMMMMM..",
".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM..",
"..MMMMMMMMMMYMMMMYMMMMMMMMMMM...",
"...MMMMMMMMMMMMMMMMMMMMMMMMM....",
"....MMMMMMMMMMMMMMMMMMMMMMM.....",
".....MMMMMMMWMMMMWMMMMMMMM......",
"......MMMMMMMMMMMMMMMMMM........",
".......MMMMMMMMMMMMMMMM.........",
"........MMMM.MMMMM.MMMM.........",
".........MMM..MMMM..MM..........",
"..........M...M..M...M..........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_SNAKE=[
"................................",
"................................",
"................................",
"...........GGGGGGGG.............",
".........GGGGGGGGGGGG...........",
"........GGGGGGGGGGGGGG..........",
"........GGYYGGGGGGYYGG..........",
"........GYkYGGGGGGYkYG..........",
"........GGYYGGGGGGYYGG..........",
".........GGGGGGGGGGGG...........",
"..........GGGGGGGGGG............",
"...........GGGGGGGG.............",
"............GGGGGG..............",
".............RRRR...............",
".............R..R...............",
".............R..R...............",
"................................",
"......GGGGGGGGGGGGGGGG..........",
"....GGGGGGGGGGGGGGGGGGGG........",
"...GGGGGGGGGGGGGGGGGGGGGG.......",
"..GGGGGGGGGGGGGGGGGGGGGGGG......",
"..GG....................GG......",
"...GGGGGGGGGGGGGGGGGGGGGG.......",
"....GGGGGGGGGGGGGGGGGGGG........",
".....GGGGGGGGGGGGGGGGGG.........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_WOLF=[
"................................",
"................................",
"................................",
".....WW..................WW.....",
"....WWWW................WWWW....",
"....WWWWW..............WWWWW....",
".....WWWWW............WWWWW.....",
"......WWWWWWWWWWWWWWWWWWWW......",
".....WWWWWWWWWWWWWWWWWWWWWW.....",
"....WWWWWWWWWWWWWWWWWWWWWWWW....",
"....WWWWWWWWWWWWWWWWWWWWWWWW....",
"....WWWYYWWWWWWWWWWWWYYWWWWW....",
"....WWYYYYWWWWWWWWWWYYYYWWWW....",
"....WWWWWWWWWWWWWWWWWWWWWWWW....",
".....WWWWWWWWWWWWWWWWWWWWW......",
".....WWWWWWWWWWWWWWWWWWWWW......",
"......WWWWWWW....WWWWWWWW.......",
"......WWWWWW......WWWWWWW.......",
"......WWWWWW..kk..WWWWWWW.......",
".......WWWWWW....WWWWWW.........",
".......WWWWWWWWWWWWWWWW.........",
"........WWWWWWWWWWWWWW..........",
"........WW.WWWWWWWW.WW..........",
"........WWWWWWWWWWWWWW..........",
".........WWWWWWWWWWWW...........",
"..........WWWWWWWWWW............",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_ZOMBIE=[
"................................",
"................................",
"................................",
".....kkk....kkk....kkk..........",
"....kkkkk..kkkkk..kkkkk.........",
"....GGGGGGGGGGGGGGGGGGGGG.......",
"...GGGGGGGGGGGGGGGGGGGGGGG......",
"...GGGGGGGGGGGGGGGGGGGGGGG......",
"...GGG.GGG.GGG.GGG.GGGGGGG......",
"...GGGGGGGGGGGGGGGGGGGGGGG......",
"...GGGGGGGGGGGGGGGGGGGGGGG......",
"...GGWWWWWGGGGGGGGGWWWWGGG......",
"...GWWkkkWWGGGGGGGWWkkWWGG......",
"...GWWkkkWWGGGGGGGGWWWWGGG......",
"...GGWWWWWGGGGGGGGGGGGGGGG......",
"...GGGGGGGGGGGGGGGGGGGGGGG......",
"...GGGGGGGGGG..GGGGGGGGGGG......",
"...GGGGGGGGG....GGGGGGGGGG......",
"....GGGGGGGGGGGGGGGGGGGGG.......",
"....GGGGGWWWWWWWWWWWGGGGG.......",
"....GGGGGWWkWWkWWkWWGGGGG.......",
"....GGGGGGWWWWWWWWWWGGGG........",
".....GGGGGGGGGGGGGGGGGGG........",
".....GGGGG.GGGGGG.GGGGG.........",
"......GGGGGGGGGGGGGGGG..........",
".......GGGGGGGGGGGGGG...........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_GOBLIN=[
"................................",
"................................",
"................................",
"................................",
"................................",
"..........GGGGGGGGGG............",
".........GGGGGGGGGGGG...........",
"..G......GGGGGGGGGGGG......G....",
"..GGG....GGGGGGGGGGGG....GGG....",
"...GGGG..GGGGGGGGGGGG..GGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGG......",
".....GGGGGGGGGGGGGGGGGGGG.......",
".....GGYYYGGGGGGGGGGYYYGG.......",
".....GYYkYGGGGGGGGGGYkYGG.......",
".....GGYYYGGGGGGGGGGYYYGG.......",
"......GGGGGGGGGGGGGGGGGG........",
"......GGGGGGGYYYYGGGGGGG........",
"......GGGGGGGGGGGGGGGGGG........",
".......GGGGGGGGGGGGGGGG.........",
".......GWWWWWWWWWWWWWWG.........",
".......GWkWWkWWkWWkWWkG.........",
".......GWWWWWWWWWWWWWWG.........",
"........GGGGGGGGGGGGGG..........",
".........GGGGGGGGGGGG...........",
"..........GGGGGGGGGG............",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_THIEF=[
"................................",
"................................",
"................................",
"..........BBBBBBBBBB............",
".......BBBBBBBBBBBBBBBB.........",
".....BBBBBBBBBBBBBBBBBBBB.......",
"....BBBBBBBBBBBBBBBBBBBBBB......",
"....BBBBBBBBBBBBBBBBBBBBBB......",
"...BBBBBBBBBBBBBBBBBBBBBBBB.....",
"...BBBBBBBYYYYYYYYYYBBBBBBB.....",
"...BBBBBBYYYYYYYYYYYYBBBBBB.....",
"...BBBBBYY..........YYBBBBB.....",
"...BBBBBYY.WW....WW.YYBBBBB.....",
"...BBBBBYY.WW....WW.YYBBBBB.....",
"...BBBBBYY..........YYBBBBB.....",
"...BBBBBBYYYYYYYYYYYYBBBBBB.....",
"....BBBBBYYYYYYYYYYYYBBBBB......",
"....BBBBBBYYYY.YYYYYBBBBBB......",
".....BBBBBBYY.....YBBBBBB.......",
".....BBBBBBBYYYYYYBBBBBB........",
"......BBBBBBBBBBBBBBBBB.........",
"......BBBBBBBBBBBBBBBBB.........",
".....BBBBBBBBBBBBBBBBBBB........",
"....BBBBBBBBBBBBBBBBBBBBB.......",
"...BBBBBBBBBBBBBBBBBBBBBBB......",
"..BBBBBBBBBBBBBBBBBBBBBBBBB.....",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_DEMON=[
"................................",
"................................",
"...YY........................YY.",
"...YYY......................YYY.",
"....YYY....................YYY..",
".....YYYY................YYYY...",
"......YYYYRRRRRRRRRRRRYYYY......",
".......RRRRRRRRRRRRRRRRRR.......",
"......RRRRRRRRRRRRRRRRRRRR......",
".....RRRRRRRRRRRRRRRRRRRRRR.....",
".....RRRRRRRRRRRRRRRRRRRRRR.....",
".....RRRYYYRRRRRRRRRYYYRRRR.....",
".....RRYYkYRRRRRRRRYYkYRRRR.....",
".....RRRYYYRRRRRRRRRYYYRRRR.....",
"......RRRRRRRRRRRRRRRRRRRR......",
"......RRRRRRRR....RRRRRRRR......",
".......RRRRRRR....RRRRRRR.......",
".......RRRRRRRRRRRRRRRRRR.......",
"........RWWWWWWWWWWWWWWWR.......",
"........RWWkWWkWWkWWkWWR........",
".........RWWWWWWWWWWWWR.........",
"..........RRRRRRRRRRRR..........",
"...........RRRRRRRRRR...........",
"............RRRRRRRR............",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_KINGBAT=[
"..........Y..YY..Y..............",
"..........YY.Y..Y.YY............",
"..........YYYYYYYYYY............",
"...........YYYYYYYY.............",
"...........MM....MM.............",
"...........MMM..MMM.............",
"............MMMMMM..............",
".....MM.....MMMMMM.....MM.......",
"...MMMMM...MMMMMMMM...MMMMM.....",
"..MMMMMMM..MMMMMMMM..MMMMMMM....",
".MMMMMMMMM.MMMMMMMMM.MMMMMMMMM..",
".MMMMMMMMMMMMMMMMMMMMMMMMMMMMM..",
"..MMMMMMMMMMRRMMRRMMMMMMMMMMM...",
"...MMMMMMMMMMMMMMMMMMMMMMMMM....",
"....MMMMMMMMMMMMMMMMMMMMMMM.....",
".....MMMMMMMWMMMMWMMMMMMMM......",
"......MMMMMMMMMMMMMMMMMM........",
".......MMMMMMMMMMMMMMMM.........",
"........MMMM.MMMMM.MMMM.........",
".........MMM..MMMM..MM..........",
"..........M...M..M...M..........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_DRAGON=[
"................................",
"................................",
"...YY......................YY...",
"....YY....................YY....",
".....YY..GGGGGGGGGGGG....YY.....",
"......GGGGGGGGGGGGGGGGGGGG......",
".....GGGGGGGGGGGGGGGGGGGGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGGGG....",
"....GGGGGGGGGGGGGGGGGGGGGGGG....",
"....GGRRRGGGGGGGGGGGGGRRGGG....",
"....GRRkRGGGGGGGGGGGGGRRkRG.....",
"....GGRRRGGGGGGGGGGGGGRRRGG.....",
".....GGGGGGGGGGGGGGGGGGGGG......",
".....GGGGGGGGGGGGGGGGGGGGG......",
"....GGGGGGGGGGGGGGGGGGGGGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGGG.....",
"...GGGGGGGGGGGGGGGGGGGGGGGGG....",
"...GGGGGGGGGGGGGGGGGGGGGGGGG....",
"...GGGGG..GGGGGGGGGG..GGGGG.....",
"...GGGG....GGGGGGGG....GGGG.....",
"....GGGGGGGGGGGGGGGGGGGGGG......",
"....GWWWWWWWWWWWWWWWWWWWG......",
"....GWkWWkWWkWWkWWkWWkWWG......",
".....GWWWWWWWWWWWWWWWWWG.......",
"......GGGGGGGGGGGGGGGGG.........",
".......GGGGGGGGGGGGGGG..........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................"]
PIC_VAMPIRE=[
"................................",
"................................",
"................................",
".........kkkkkkkkkkkk...........",
".......kkkkkkkkkkkkkkkk.........",
"......kkkkkkkkkkkkkkkkkk........",
"......kkkkkWWWWWWWWkkkkk........",
".....kkkkWWWWWWWWWWWWkkkk.......",
".....kkkWWWWWWWWWWWWWWkkk.......",
".....kkWWWWWWWWWWWWWWWWkk.......",
".....kkWWWWWWWWWWWWWWWWkk.......",
".....kkWWRRRWWWWWWRRRWWkk.......",
".....kkWWRkRWWWWWWWRkRWWk.......",
".....kkWWRRRWWWWWWRRRWWkk.......",
"......kWWWWWWWWWWWWWWWWk........",
"......kWWWWWWWWWWWWWWWWk........",
".......WWWWWW....WWWWWW.........",
".......WWWWWWW..WWWWWWW.........",
"........WWWWWWWWWWWWWW..........",
"........WWWWWWWWWWWWWW..........",
".........WWWWWWWWWWWW...........",
"..........WWWWWWWWWW............",
"......RRRRWWWWWWWWWWRRRR........",
"....RRRRRRRWWWWWWWWRRRRRRR......",
"...RRRRRRRRR......RRRRRRRRR.....",
"..RRRRRRRR..........RRRRRRRR....",
"..RRRRRRR............RRRRRRR....",
"...RRRRR..............RRRRR.....",
"................................",
"................................",
"................................",
"................................"]
PIC_DARKKNIGHT=[
"................................",
"..................MMMM..........",
".................MMMMMM.........",
"................MMMMMM..........",
"...............MMMMM............",
"..............MMMM..............",
"..........BBBBBBBBBB............",
".......BBBBBBBBBBBBBBBB.........",
".....BBBBBBBBBBBBBBBBBBBB.......",
"....BBBBBBBBBBBBBBBBBBBBBB......",
"....BBBWBBBBBBBBBBBBBBWBBB......",
"....BBBBBBBBBBBBBBBBBBBBBB......",
"....BBBBBBBBBBBBBBBBBBBBBB......",
"....BBBBB..........BBBBBBB......",
"....BBBBB.YY....YY.BBBBBBB......",
"....BBBBB..........BBBBBBB......",
".....BBBBBBBBBBBBBBBBBBBB.......",
".....BBBB.BB.BB.BB.BBBBB........",
".....BBBB.BB.BB.BB.BBBBB........",
".....BBBB.BB.BB.BB.BBBBB........",
".....BBBBBBBBBBBBBBBBBBB........",
"......BBBBBBBBBBBBBBBBB.........",
"......BBBBBBBBBBBBBBBBB.........",
".....BBBBBBBBBBBBBBBBBBB........",
"....BBBBBBBBBBBBBBBBBBBBB.......",
"...BBBBBBBBBBBBBBBBBBBBBBB......",
"..BBBBBBBBBBBBBBBBBBBBBBBB.....",
"................................",
"................................",
"................................",
"................................",
"................................"]
for _p in (PIC_SLIME,PIC_BAT,PIC_SNAKE,PIC_WOLF,PIC_ZOMBIE,PIC_GOBLIN,PIC_THIEF,PIC_DEMON,PIC_KINGBAT,PIC_DRAGON,PIC_VAMPIRE,PIC_DARKKNIGHT):
    _p=[r.ljust(32,'.')[:32] for r in _p]
    for i in range(16): tiles.append(T4(_p,i))
# ---- perspective diagonal tiles 250..255 (wall below the diagonal, black above)
def diag(fg, mode):
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            filled = (y > x) if mode=='A' else (y > 7-x)
            r += fg if filled else "."
        rows.append(r)
    return T(rows)
def side_dither_dark():
    # side wall at the farthest depth: same stripe mask as tiles 5/6,
    # filled pixels alternate blue/black (darker than the z=2 dither).
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            if (x - y//2) % 5 == 4: r += "."
            else: r += 'B' if (x+y)%2==0 else '.'
        rows.append(r)
    return T(rows)
tiles.append(side_dither_dark())   # 250 far side wall (blue/black dither)
tiles.append(diag('W','C'))   # 251 right-top slope, near
tiles.append(diag('C','A'))   # 252 left-top slope, mid (cyan)
tiles.append(diag('C','C'))   # 253 right-top slope, mid
tiles.append(diag('B','A'))   # 254 left-top slope, far (blue)
tiles.append(diag('B','C'))   # 255 right-top slope, far

# ---- bank-1 slope tiles: 1:1 diagonals (16 tiles -> tiles1.inc) ----
# geometry per tile: boundary line in pixel coords (x:0..7 left->right,
# y:0..7 top->bottom), wall on the stated side. Patterns are data-swappable.
def slope(fg, kind):
    # 1:1 (45-degree) diagonal tiles for the square 25x25 view:
    # one tile per step composes the whole slope. kind '_' = unused slot.
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            if   kind=='TL': f = y >= x          # fill below line (0,0)->(8,8)
            elif kind=='TR': f = x + y >= 7      # fill below line (0,8)->(8,0)
            elif kind=='BL': f = x + y <= 7      # fill above line (0,8)->(8,0)
            elif kind=='BR': f = y <= x          # fill above line (0,0)->(8,8)
            else: f = False
            r += fg if f else "."
        rows.append(r)
    return T(rows)

def slope_dither(kind):
    # 1:1 diagonal, same fill conditions as slope(), but filled pixels
    # alternate cyan/blue in a checkerboard (z=2 intermediate tone).
    # Lives in the cyan set's odd slots: base 1 (+0 TL, +2 TR, +4 BL, +6 BR).
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            if   kind=='TL': f = y >= x          # fill below line (0,0)->(8,8)
            elif kind=='TR': f = x + y >= 7      # fill below line (0,8)->(8,0)
            elif kind=='BL': f = x + y <= 7      # fill above line (0,8)->(8,0)
            elif kind=='BR': f = y <= x          # fill above line (0,0)->(8,8)
            else: f = False
            r += ('C' if (x+y)%2==0 else 'B') if f else "."
        rows.append(r)
    return T(rows)

def arrow():
    # player marker for the panel mini-map (bank-1 index 9, the blue
    # set's first odd slot). Always points up: the map rotates instead.
    return T([
        "...Y....",
        "..YYY...",
        ".YYYYY..",
        "YYYYYYY.",
        "...Y....",
        "...Y....",
        "...Y....",
        "...Y....",
    ])

def slope_dither_dark(kind):
    # 1:1 diagonal with blue/black checkerboard fill (z=3 far set).
    # Lives at base 16 (+0 TL, +2 TR, +4 BL, +6 BR); odd slots blank.
    rows=[]
    for y in range(8):
        r=""
        for x in range(8):
            if   kind=='TL': f = y >= x
            elif kind=='TR': f = x + y >= 7
            elif kind=='BL': f = x + y <= 7
            elif kind=='BR': f = y <= x
            else: f = False
            r += ('B' if (x+y)%2==0 else '.') if f else "."
        rows.append(r)
    return T(rows)

slope_kinds = ['TL','_','TR','_','BL','_','BR','_']
dither_kinds = ['TL','TR','BL','BR']   # for odd slots 1,3,5,7 of the cyan set
tiles1 = []
for fg in ('C','B'):
    for i,k in enumerate(slope_kinds):
        if fg=='C' and k=='_':
            tiles1.append(slope_dither(dither_kinds[(i-1)//2]))
        elif fg=='B' and i==1:
            tiles1.append(arrow())
        else:
            tiles1.append(slope(fg, k))
for i,k in enumerate(slope_kinds):
    if k=='_':
        tiles1.append(slope('B','_'))
    else:
        tiles1.append(slope_dither_dark(k))
out1=["; generated by gen_tiles.py (PCG bank 1: 1:1 diagonal tiles)","tiles1_data:"]
for i,t in enumerate(tiles1):
    out1.append(f"; tile B1-{i}")
    out1.append("    DB "+", ".join(f"${b:02X}" for b in t))
with open("tiles1.inc","w") as fh: fh.write("\n".join(out1)+"\n")
print("tiles1.inc:", len(tiles1), "tiles")

out=["; generated by gen_tiles.py","tiles_data:"]
for i,t in enumerate(tiles):
    out.append(f"; tile {i}")
    out.append("    DB "+", ".join(f"${b:02X}" for b in t))
with open("tiles.inc","w") as fh: fh.write("\n".join(out)+"\n")
print("tiles.inc:", len(tiles), "tiles")

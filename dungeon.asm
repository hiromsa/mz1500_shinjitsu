; ============================================================
; dungeon: 3D view renderer + movement + events
; view: cols 2..37 (36 wide), rows 1..18 (18 tall), rel origin (0,0)
; ============================================================
VIEW_BASE equ $D400     ; 25x25 view at screen (0,0), panel at cols 25-39
RX0 equ VARS+50
RY0 equ VARS+51
RX1 equ VARS+52
RY1 equ VARS+53
RTILE equ VARS+54
CURZ  equ VARS+55
CURDX equ VARS+56
CELLX equ VARS+57
CELLY equ VARS+58
CELLV equ VARS+59
SD_TILE equ VARS+63
SD_PREV equ VARS+64
SD_TOP  equ VARS+65
SD_BOT  equ VARS+66
SD_MODE equ VARS+67
SD_X    equ VARS+68
FC_END  equ VARS+69
SD_PBOT equ VARS+93     ; previous column bottom (for slope pairs)
SD_BASE equ VARS+94     ; bank-1 slope pair base for current z
SD_LST  equ VARS+95     ; 1 if previous column had a top step
SD_LSB  equ VARS+96     ; 1 if previous column had a bottom step
MAP_SX  equ VARS+97     ; mini-map screen offset x (-7..7)
MAP_SY  equ VARS+98     ; mini-map screen offset y (-6..6)
MAP_X   equ VARS+99     ; mini-map current map x
MAP_Y   equ VARS+100    ; mini-map current map y
MAP_RX  equ VARS+101    ; rgt_dx[PDIR] cached for draw_map
MAP_RY  equ VARS+102    ; rgt_dy[PDIR]
MAP_FX  equ VARS+103    ; fwd_dx[PDIR]
MAP_FY  equ VARS+104    ; fwd_dy[PDIR]
MAP_SVX equ VARS+105    ; saved CELLX (chest checks clobber it)
MAP_SVY equ VARS+106    ; saved CELLY
MAP_T1  equ VARS+107    ; scratch
MAP_CELL equ VARS+108   ; current cell value
MAP_ATTR equ VARS+109   ; current cell attr
SF_XL equ VARS+110      ; side_fill: current column (left-space)
SF_OFF equ VARS+111     ; side_fill: diagonal offset (0 left, 2 right)
SF_CHN_L equ VARS+112   ; side_fill: left slope chain (farther band drawn)
SF_CHN_R equ VARS+113   ; side_fill: right slope chain

fwd_dx: db 0,1,0,-1
fwd_dy: db -1,0,1,0
rgt_dx: db 1,0,-1,0
rgt_dy: db 0,1,0,-1

; cell_at: E=x, D=y, A=floor -> A=cell. Clobbers HL.
cell_at:
    ld l,d
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl           ; y*16
    ld d,0
    add hl,de           ; +x  (E=x, D cleared)
    ex de,hl            ; DE=offset in floor
    ld h,a
    ld l,0              ; floor*256
    add hl,de
    ld de,maps_data
    add hl,de
    ld a,(hl)
    ret

; view cell: CURDX=dx(-1..1), CURZ=z -> CELLV, CELLX, CELLY
view_cell:
    ; wx = PX + fwd_dx[dir]*z + rgt_dx[dir]*dx
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,fwd_dx
    add hl,de
    ld a,(hl)           ; fwd dx (signed)
    ld c,a
    ld a,(CURZ)
    call mul_dir         ; A = c*z signed
    ld b,a
    ld a,(PX)
    add a,b
    ld (CELLX),a
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,rgt_dx
    add hl,de
    ld a,(hl)
    ld c,a
    ld a,(CURDX)
    call mul_dir
    ld b,a
    ld a,(CELLX)
    add a,b
    ld (CELLX),a
    ; wy similarly
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,fwd_dy
    add hl,de
    ld a,(hl)
    ld c,a
    ld a,(CURZ)
    call mul_dir
    ld b,a
    ld a,(PY)
    add a,b
    ld (CELLY),a
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,rgt_dy
    add hl,de
    ld a,(hl)
    ld c,a
    ld a,(CURDX)
    call mul_dir
    ld b,a
    ld a,(CELLY)
    add a,b
    ld (CELLY),a
    ; bounds: x or y >= 16 (unsigned, catches negatives) -> wall
    ld a,(CELLX)
    cp 16
    jr nc,vc_wall
    ld a,(CELLY)
    cp 16
    jr nc,vc_wall
    ld a,(FL)
    ld d,a
    ld a,(CELLY)
    ld d,a
    ld a,(CELLX)
    ld e,a
    ld a,(FL)
    call cell_at
    ld (CELLV),a
    ret
vc_wall:
    ld a,CT_WALL
    ld (CELLV),a
    ret

; mul_s8: A = C * A where C is -1,0,1 (dir components) -> trivial
mul_s8:
    ld a,c
    or a
    jr z,ms_zero
    jp p,ms_pos
    ; c = -1: negate multiplicand (in A? we lost it) - restructure:
    ret
ms_zero:
    xor a
    ret
ms_pos:
    ret
; NOTE: mul_s8 as called is broken by design; use mul_dir instead:
; mul_dir: input: C=component(-1/0/1), A=multiplier(0..3 or -1..1)
; output A = C*A
mul_dir:
    ld b,a              ; save multiplier
    ld a,c
    or a
    jr z,md_zero
    jp m,md_neg
    ld a,b
    ret
md_zero:
    xor a
    ret
md_neg:
    ld a,b
    neg
    ret

; --- clipped rect in view rel coords ---
; RX0,RY0,RX1,RY1 signed ok; RTILE=code
draw_rect:
    ; clip x to 0..24, y to 0..24
    ld a,(RX0)
    bit 7,a
    jr z,dr_x0ok
    xor a
    ld (RX0),a
dr_x0ok:
    ld a,(RX1)
    cp 25
    jr c,dr_x1ok
    ld a,24
    ld (RX1),a
dr_x1ok:
    ld a,(RY0)
    bit 7,a
    jr z,dr_y0ok
    xor a
    ld (RY0),a
dr_y0ok:
    ld a,(RY1)
    cp 25
    jr c,dr_y1ok
    ld a,24
    ld (RY1),a
dr_y1ok:
    ld a,(RX1)
    ld c,a
    ld a,(RX0)
    cp c
    jr z,dr_one_w
    jr nc,dr_ret
dr_one_w:
    ld a,(RY1)
    ld c,a
    ld a,(RY0)
    cp c
    jr z,dr_one_h
    jr nc,dr_ret
dr_one_h:
    ; HL = VIEW_BASE + RY0*40 + RX0
    ld a,(RY0)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *40           ; *40
    ld a,(RX0)
    ld e,a
    ld d,0
    add hl,de
    ld de,VIEW_BASE
    add hl,de
    ; B = width = RX1-RX0+1, C = height
    ld a,(RX1)
    ld c,a
    ld a,(RX0)
    ld b,a
    ld a,c
    sub b
    inc a
    ld b,a
    ld a,(RY1)
    ld c,a
    ld a,(RY0)
    ld d,a
    ld a,c
    sub d
    inc a
    ld c,a
    ld a,(RTILE)
    call fill_pcg_rect
dr_ret:
    ret

; set single PCG cell rel: A=code, D=x, E=y
set_cell_rel:
    push de
    push af
    ld l,e
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *40
    pop af
    pop de
    push de
    ld e,d
    ld d,0
    add hl,de
    ld de,VIEW_BASE
    add hl,de
    pop de
    ld (hl),a
    push de
    ld de,$800
    add hl,de
    ld a,8              ; exact write: bank bits must not stick from a
    ld (hl),a           ; previous bank-1 tile in the same cell
    pop de
    ret

; set single PCG cell rel, bank 1: A=code (0..15), D=x, E=y
set_cell_b1:
    push de
    push af
    ld l,e
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *40
    pop af
    pop de
    push de
    ld e,d
    ld d,0
    add hl,de
    ld de,VIEW_BASE
    add hl,de
    pop de
    ld (hl),a
    push de
    ld de,$800
    add hl,de
    ld a,$48            ; PCG on + bank 1 (attr bit 6), exact write
    ld (hl),a
    pop de
    ret

; place a bank-1 diagonal tile, clipped to the view: A=code, D=x, E=y (signed ok)
place_b1:
    push af
    ld a,d
    bit 7,a
    jr nz,pb_no
    cp 25
    jr nc,pb_no
    ld a,e
    bit 7,a
    jr nz,pb_no
    cp 25
    jr nc,pb_no
    pop af
    jp set_cell_b1
pb_no:
    pop af
    ret

; draw 2x2 sprite: A=first code, D=x, E=y (rel)
draw_sprite2:
    ld (TMP),a
    call set_cell_rel
    inc d
    ld a,(TMP)
    inc a
    call set_cell_rel
    inc e
    ld a,(TMP)
    add a,3
    call set_cell_rel
    dec d
    ld a,(TMP)
    add a,2
    call set_cell_rel
    ret

; corridor frames by depth (index 0 = screen edge, 1..4 = steps ahead)
; band widths 3,3,2,2 and every column steps exactly +/-1, so the
; ceiling/floor slope lines run at an unbroken 45 degrees from the
; screen corners to the far frame (10,14,9,15): 5 wide, 7 tall.
plane_x0: db 0,3,6,8,10
plane_x1: db 24,21,18,16,14
plane_y0: db 0,2,5,7,9
plane_y1: db 24,22,19,17,15
brick_tile: db 0,1,2,3,3,3
side_tile: db 0,5,4,250,250   ; z=1 cyan, z=2 C/B dither, z=3/4 B/K dither

; get plane value: HL=table, A=z -> A=(table+z)
plane_get:
    ld l,a
    ld h,0
    add hl,de
    ld a,(hl)
    ret

; ---------------- draw_view ----------------
draw_view:
    ; (PCG attrs are written exactly by set_cell_rel/fill_pcg_rect,
    ; so bank bits never stick between overlapping draws)
    xor a
    ld (SF_CHN_L),a     ; slope chains start broken
    ld (SF_CHN_R),a
    ; background: ceiling rows 0..11 tile 9, floor rows 12..24 gradient
    ld a,9
    ld (RTILE),a
    xor a
    ld (RX0),a
    ld (RY0),a
    ld a,24
    ld (RX1),a
    ld a,11
    ld (RY1),a
    call draw_rect
    ld a,9
    ld (RTILE),a
    xor a
    ld (RX0),a
    ld a,12
    ld (RY0),a
    ld a,24
    ld (RX1),a
    ld a,15
    ld (RY1),a
    call draw_rect
    ld a,8
    ld (RTILE),a
    ld a,16
    ld (RY0),a
    ld a,20
    ld (RY1),a
    call draw_rect
    ld a,7
    ld (RTILE),a
    ld a,21
    ld (RY0),a
    ld a,24
    ld (RY1),a
    call draw_rect
    ; depths far -> near (painter)
    ld a,5
    ld (CURZ),a
    call draw_depth
    ld a,4
    ld (CURZ),a
    call draw_depth
    ld a,3
    ld (CURZ),a
    call draw_depth
    ld a,2
    ld (CURZ),a
    call draw_depth
    ld a,1
    ld (CURZ),a
    call draw_depth
    ret

; ---------------- perspective side profiles ----------------
; per depth z: db count, then (top,bot) per column, outer -> inner.
; tops/bots interpolate frame(z-1) -> frame(z): trapezoid side walls.
prof_ptr: dw prof_1, prof_2, prof_3, prof_4
prof_1: db 3, 0,24, 1,23, 2,22
prof_2: db 3, 3,21, 4,20, 5,19
prof_3: db 2, 6,18, 7,17
prof_4: db 2, 8,16, 9,15
; bank-1 diagonal base index by z (offsets: +0 TL, +2 TR, +4 BL, +6 BR)
; z=1 cyan set (0), z=2 C/B dither set (1), z=3 B/K dither set (16)
slope_base: db 0, 0, 1, 16, 16

; fill one view column: A=tile, SD_X (signed), SD_TOP, SD_BOT (signed)
; clips x to 0..24 and y to 0..24. Preserves BC.
fill_column:
    ld (SD_TILE),a
    ld a,(SD_X)
    bit 7,a
    ret nz
    cp 25
    ret nc
    ld a,(SD_TOP)
    bit 7,a
    jr z,fc_t1
    xor a
    ld (SD_TOP),a
fc_t1:
    ld a,(SD_BOT)
    cp 25
    jr c,fc_b1
    ld a,24
fc_b1:
    ld (FC_END),a
    ld a,(SD_TOP)
    ld e,a
fc_loop:
    ld a,(FC_END)
    cp e
    ret c
    ld a,(SD_X)
    ld d,a
    ld a,(SD_TILE)
    call set_cell_rel
    inc e
    jr fc_loop

; black edge column at SD_X, SD_TOP..SD_BOT
black_column:
    xor a
    jr fill_column

; ---- side trapezoid: ONE routine for both sides (mirror method) ----
; The band is computed in left-side coordinates: columns
; plane_x0[CURZ-1] .. plane_x0[CURZ]-1, profile (top,bot) pairs
; outer -> inner. For the right side each column is plotted at
; (24 - x) with mirrored diagonal tiles (TL<->TR, BL<->BR), so
; the two sides are symmetric by construction; there is no
; right-side coordinate math to get wrong.
; In: SD_TILE = fill tile; CURZ, CURDX set.
side_fill:
    ld a,(CURZ)
    dec a
    add a,a
    ld l,a
    ld h,0
    ld de,prof_ptr
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    push de
    pop ix              ; IX = profile table
    ld a,(CURZ)
    dec a
    ld de,plane_x0
    call plane_get
    ld (SF_XL),a        ; current column (left-space)
    ld a,$7F
    ld (SD_PREV),a
    ld (SD_PBOT),a
    ld a,(CURZ)
    ld de,slope_base
    call plane_get
    ld (SD_BASE),a
    xor a
    ld (SF_OFF),a       ; left: diagonal offsets +0 (TL) / +4 (BL)
    ld a,(CURDX)
    or a
    jp m,sf_setup
    ld a,2
    ld (SF_OFF),a       ; right: +2 (TR) / +6 (BR)
sf_setup:
    ld b,(ix+0)         ; remaining columns
    ld c,0              ; column index
sf_loop:
    ld a,c
    add a,a
    ld l,a
    ld h,0
    push ix
    pop de
    add hl,de
    inc hl
    ld a,(hl)
    ld (SD_TOP),a
    inc hl
    ld a,(hl)
    ld (SD_BOT),a
    call sf_scrx        ; screen X of this column
    ld (SD_X),a
    ; --- top step: SD_TOP == SD_PREV+1 ---
    ld a,(SD_PREV)
    cp $7F
    jr z,sf_botstep
    ld e,a              ; E = prev top
    ld a,(SD_TOP)
    dec a
    cp e
    jr nz,sf_botstep
    ; stepped: one 1:1 diagonal on the previous column's top cell
    call sf_prevx
    ld d,a
    ld a,(SD_PREV)
    ld e,a
    ld a,(SD_BASE)
    ld hl,SF_OFF
    add a,(hl)
    call place_b1
sf_botstep:
    ; --- bottom step: SD_BOT == SD_PBOT-1 ---
    ld a,(SD_PBOT)
    cp $7F
    jr z,sf_fill
    ld e,a              ; E = prev bot
    ld a,(SD_BOT)
    inc a
    cp e
    jr nz,sf_fill
    ; stepped: one 1:1 diagonal on the previous column's bottom cell
    call sf_prevx
    ld d,a
    ld a,(SD_PBOT)
    ld e,a
    ld a,(SD_BASE)
    ld hl,SF_OFF
    add a,(hl)
    add a,4
    call place_b1
sf_fill:
    ld a,(SD_TILE)
    push bc
    call fill_column
    pop bc
    ld a,(SD_TOP)
    ld (SD_PREV),a
    ld a,(SD_BOT)
    ld (SD_PBOT),a
    ld hl,SF_XL
    inc (hl)
    inc c
    dec b
    jp nz,sf_loop
    ; ---- seam diagonals to the farther band ----
    ; If the side wall continues one depth farther, that band was
    ; drawn just before this one; the slope step between this
    ; band's innermost column and the farther band's outermost
    ; column gets its diagonal here (on this column, in the
    ; farther band's slope set), so the 45-degree line runs
    ; unbroken from the screen edge to the far face's corner.
    ld a,(CURDX)
    or a
    jp m,sf_end_l
    ld a,(SF_CHN_R)
    or a
    jr z,sf_mark_r
    call sf_seam
sf_mark_r:
    ld a,1
    ld (SF_CHN_R),a     ; this band is drawn for the next depth
    ret
sf_end_l:
    ld a,(SF_CHN_L)
    or a
    jr z,sf_mark_l
    call sf_seam
sf_mark_l:
    ld a,1
    ld (SF_CHN_L),a
    ret

; seam diagonals on this band's innermost column (SD_PREV/SD_PBOT
; still hold its profile), using slope_base[CURZ+1].
sf_seam:
    ld a,(CURZ)
    inc a
    ld de,slope_base
    call plane_get
    ld hl,SF_OFF
    add a,(hl)
    ld (TMP),a          ; top tile: TL (left) / TR (right)
    call sf_prevx       ; innermost column's screen X
    ld d,a
    ld a,(SD_PREV)
    ld e,a
    ld a,(TMP)
    call place_b1
    ld a,(TMP)
    add a,4             ; bottom tile: BL / BR
    ld (TMP),a
    call sf_prevx
    ld d,a
    ld a,(SD_PBOT)
    ld e,a
    ld a,(TMP)
    jp place_b1

; screen X of the current column (SF_XL in left-space)
sf_scrx:
    ld a,(CURDX)
    or a
    jp m,sfx_left
    ld a,24
    ld hl,SF_XL
    sub (hl)
    ret
sfx_left:
    ld a,(SF_XL)
    ret

; screen X of the previous column (SF_XL-1 in left-space)
sf_prevx:
    ld a,(CURDX)
    or a
    jp m,sfp_left
    ld a,25
    ld hl,SF_XL
    sub (hl)
    ret
sfp_left:
    ld a,(SF_XL)
    dec a
    ret
; depth-0 side check (depth 1 only): if the cell beside the player
; (same side, depth 0) is open, the depth-1 wall's flat front face
; shows at the screen edge as a clean rectangle of frame-1 height
; (rows 2..22, horizontal top and bottom, no slope tiles on it):
; paint the outermost column with the white face tile, restore
; the ceiling/floor background above and below it, and draw one
; black edge column between the panel and the cyan trapezoid.
; CURZ/CURDX are the caller's (z=1, side).
dd_z1_edge:
    ld a,(CURZ)
    cp 1
    ret nz
    xor a
    ld (CURZ),a
    call view_cell
    ld a,1
    ld (CURZ),a
    ld a,(CELLV)
    cp CT_WALL
    ret z               ; depth-0 side is a wall: nothing to do
    cp CT_D
    ret z
    ld a,(CURDX)
    or a
    jp m,dz1_left
    ld a,24             ; panel column (right edge)
    ld (SD_X),a
    ld a,23             ; edge column
    ld (TMP),a
    jr dz1_draw
dz1_left:
    xor a               ; panel column 0
    ld (SD_X),a
    ld a,1              ; edge column
    ld (TMP),a
dz1_draw:
    ; background above the panel (ceiling tile 9, rows 0..1)
    xor a
    ld (SD_TOP),a
    ld a,1
    ld (SD_BOT),a
    ld a,9
    call fill_column
    ; background below the panel (floor tile 7, rows 23..24)
    ld a,23
    ld (SD_TOP),a
    ld a,24
    ld (SD_BOT),a
    ld a,7
    call fill_column
    ; the white panel itself: frame-1 height (rows 2..22)
    ld a,2
    ld (SD_TOP),a
    ld a,22
    ld (SD_BOT),a
    ld a,1              ; brick_tile[1]: near front face
    call fill_column
    ; one black edge column between panel and trapezoid
    ld a,(TMP)
    ld (SD_X),a
    jp black_column

; opening at (CURZ, CURDX): the side corridor's far wall shows as
; a flat front face in this band: fill band(CURZ) x frame(CURZ)
; with the face tile of the next depth (brick_tile[CURZ+1]).
; Flat rectangle only; no slope tiles, no see-through dots.
dd_panel:
    ; an opening breaks this side's slope chain
    ld a,(CURDX)
    or a
    jp m,dp_cl
    xor a
    ld (SF_CHN_R),a
    jr dp_body
dp_cl:
    xor a
    ld (SF_CHN_L),a
dp_body:
    ld a,(CURZ)
    inc a
    ld l,a
    ld h,0
    ld de,brick_tile
    add hl,de
    ld a,(hl)
    ld (RTILE),a
    ; rows = frame(CURZ)
    ld a,(CURZ)
    ld de,plane_y0
    call plane_get
    ld (RY0),a
    ld a,(CURZ)
    ld de,plane_y1
    call plane_get
    ld (RY1),a
    ; columns = band(CURZ) on this side
    ld a,(CURDX)
    or a
    jp m,dp_left
    ; right band: cols plane_x1[CURZ]+1 .. plane_x1[CURZ-1]
    ld a,(CURZ)
    ld de,plane_x1
    call plane_get
    inc a
    ld (RX0),a
    ld a,(CURZ)
    dec a
    ld de,plane_x1
    call plane_get
    ld (RX1),a
    jp draw_rect
dp_left:
    ; left band: cols plane_x0[CURZ-1] .. plane_x0[CURZ]-1
    ld a,(CURZ)
    dec a
    ld de,plane_x0
    call plane_get
    ld (RX0),a
    ld a,(CURZ)
    ld de,plane_x0
    call plane_get
    dec a
    ld (RX1),a
    jp draw_rect

; front face rect for center cell + black side edges. A = face tile.
; The face of the wall CURZ steps ahead lies on frame CURZ-1 (the
; plane on the near side of that cell), so a wall 2 steps ahead
; fills frame 1's rectangle... i.e. depth d -> frame d-1.
dd_front:
    ld (RTILE),a
    ld a,(CURZ)
    dec a
    ld de,plane_x0
    call plane_get
    ld (RX0),a
    ld a,(CURZ)
    dec a
    ld de,plane_x1
    call plane_get
    ld (RX1),a
    ld a,(CURZ)
    dec a
    ld de,plane_y0
    call plane_get
    ld (RY0),a
    ld a,(CURZ)
    dec a
    ld de,plane_y1
    call plane_get
    ld (RY1),a
    call draw_rect
    ; black edge columns at the sides of the face -- but an edge
    ; is skipped on a side where a flat side panel at depth
    ; CURZ-1 continues this very face (same plane, same facing):
    ; coplanar faces merge into one continuous wall with no seam.
    ; The edge stays where a nearer trapezoid meets the face.
    ld a,(RY0)
    ld (SD_TOP),a
    ld a,(RY1)
    ld (SD_BOT),a
    ld a,-1
    ld (CURDX),a
    call df_skip
    or a
    jr nz,df_redge
    ld a,(RX0)
    ld (SD_X),a
    call black_column
df_redge:
    ld a,1
    ld (CURDX),a
    call df_skip
    or a
    jr nz,df_done
    ld a,(RX1)
    ld (SD_X),a
    call black_column
df_done:
    xor a
    ld (CURDX),a
    ret

; df_skip: A=1 if the face edge on side CURDX should be skipped
; because the side cell at depth CURZ-1 is open (a flat panel
; there continues this face). Depth 1 faces always keep edges.
df_skip:
    ld a,(CURZ)
    cp 2
    jr c,dfs_no
    dec a
    ld (CURZ),a
    call view_cell
    ld a,(CURZ)
    inc a
    ld (CURZ),a
    ld a,(CELLV)
    cp CT_WALL
    jr z,dfs_no
    cp CT_D
    jr z,dfs_no
    ld a,1
    ret
dfs_no:
    xor a
    ret

draw_depth:
    ld a,(CURZ)
    cp 5
    jr z,dd_center      ; depth 5: no side bands, centre only
    ; ---- left cell ----
    ld a,-1
    ld (CURDX),a
    call view_cell
    ld a,(CELLV)
    cp CT_WALL
    jr z,dd_l_wall
    cp CT_D
    jr z,dd_l_wall      ; a side door draws as a wall
    call dd_panel       ; opening: flat far-wall panel in this band
    jr dd_right
dd_l_wall:
    ld a,(CURZ)
    ld l,a
    ld h,0
    ld de,side_tile
    add hl,de
    ld a,(hl)
    ld (SD_TILE),a
    call side_fill
    call dd_z1_edge
dd_right:
    ; ---- right cell ----
    ld a,1
    ld (CURDX),a
    call view_cell
    ld a,(CELLV)
    cp CT_WALL
    jr z,dd_r_wall
    cp CT_D
    jr z,dd_r_wall      ; a side door draws as a wall
    call dd_panel       ; opening: flat far-wall panel in this band
    jr dd_center
dd_r_wall:
    ld a,(CURZ)
    ld l,a
    ld h,0
    ld de,side_tile
    add hl,de
    ld a,(hl)
    ld (SD_TILE),a
    call side_fill
    call dd_z1_edge
dd_center:
    ; ---- center cell ----
    xor a
    ld (CURDX),a
    call view_cell
    ld a,(CELLV)
    cp CT_WALL
    jr z,ddc_wall
    cp CT_D
    jr z,ddc_door
    cp CT_C
    jp z,dd_feat_chest
    cp CT_P
    jp z,dd_feat_spirit
    cp CT_U
    jp z,dd_feat_stairs
    cp CT_B
    jp z,dd_feat_boss
    ret
ddc_wall:
    ld a,(CURZ)
    ld l,a
    ld h,0
    ld de,brick_tile
    add hl,de
    ld a,(hl)
    call dd_front
    ret
ddc_door:
    ld a,10
    call dd_front
    ret
dd_feat_chest:
    ; if this chest already taken -> nothing
    call chest_taken_here
    or a
    ret nz
    ld a,11
    jr dd_feat_draw
dd_feat_spirit:
    ld a,15
    jr dd_feat_draw
dd_feat_stairs:
    ld a,19
    jr dd_feat_draw
dd_feat_draw:
    ; only z 1..2 drawn; position: x=11 (view center), y=plane_y1(z)-1
    ld c,a
    ld a,(CURZ)
    cp 3
    ret nc
    ld a,(CURZ)
    ld de,plane_y1
    call plane_get
    dec a
    ld e,a
    ld d,11
    ld a,c
    call draw_sprite2
    ret
dd_feat_boss:
    ld a,(CURZ)
    cp 1
    ret nz
    ; big portrait 4x4 at (10,10)
    ld a,39
    ld (TMP),a
    ld e,10
    ld b,4
dboss_row:
    ld d,10
    ld c,4
dboss_col:
    ld a,(TMP)
    push bc
    push de
    call set_cell_rel
    pop de
    pop bc
    inc d
    ld a,(TMP)
    inc a
    ld (TMP),a
    dec c
    jr nz,dboss_col
    inc e
    djnz dboss_row
    ret

; chest index of cell (CELLX,CELLY) on floor FL: count C cells in scan
; order up to and including it -> A=index (0-based). If not chest, A=$FF.
chest_index:
    ld c,0              ; count
    ld b,0              ; y
ci_y:
    ld d,0              ; x in d? use e for x
    ld e,0
ci_x:
    push bc
    push de
    ld a,(FL)
    call cell_at        ; E=x, D=y... cell_at wants D=y,E=x
    pop de
    pop bc
    cp CT_C
    jr nz,ci_next
    ; is this the target?
    ld a,e
    ld hl,CELLX
    cp (hl)
    jr nz,ci_not_target
    ld a,d
    ld hl,CELLY
    cp (hl)
    jr nz,ci_not_target
    ld a,c
    ret
ci_not_target:
    inc c
ci_next:
    inc e
    ld a,e
    cp 16
    jr nz,ci_x
    inc d
    ld a,d
    cp 16
    jr nz,ci_y
    ld a,$FF
    ret
; NOTE: chest_index loop vars: D used as y but cell_at clobbers D!
; chest_taken_here: uses CELLX/CELLY (set by view_cell). Returns A=1 if taken.
chest_taken_here:
    call chest_index_safe
    cp $FF
    jr z,cth_no
    ; check mask bit A
    ld c,a
    ld hl,(CHEST_MASK)
    ld a,c
    or a
    jr z,cth_bit
cth_shift:
    srl h
    rr l
    dec a
    jr nz,cth_shift
cth_bit:
    ld a,l
    and 1
    ret
cth_no:
    xor a
    ret
; chest_index_safe: same as chest_index but preserves loop via memory vars
CI_X equ VARS+60
CI_Y equ VARS+61
CI_N equ VARS+62
chest_index_safe:
    xor a
    ld (CI_N),a
    ld (CI_Y),a
cis_y:
    xor a
    ld (CI_X),a
cis_x:
    ld a,(CI_Y)
    ld d,a
    ld a,(CI_X)
    ld e,a
    ld a,(FL)
    call cell_at
    cp CT_C
    jr nz,cis_next
    ld a,(CI_X)
    ld hl,CELLX
    cp (hl)
    jr nz,cis_not
    ld a,(CI_Y)
    ld hl,CELLY
    cp (hl)
    jr nz,cis_not
    ld a,(CI_N)
    ret
cis_not:
    ld hl,CI_N
    inc (hl)
cis_next:
    ld hl,CI_X
    inc (hl)
    ld a,(CI_X)
    cp 16
    jr nz,cis_x
    ld hl,CI_Y
    inc (hl)
    ld a,(CI_Y)
    cp 16
    jr nz,cis_y
    ld a,$FF
    ret
; mark chest at (CELLX,CELLY) taken
chest_mark_here:
    call chest_index_safe
    cp $FF
    ret z
    ld c,a
    ld hl,1
    ld a,c
    or a
    jr z,cmh_set
cmh_shift:
    add hl,hl
    dec a
    jr nz,cmh_shift
cmh_set:
    ld de,(CHEST_MASK)
    ld a,l
    or e
    ld l,a
    ld a,h
    or d
    ld h,a
    ld (CHEST_MASK),hl
    ret

; find S cell on floor A -> PX,PY
find_start:
    ld (TMP),a
    ld c,0
fs_y:
    ld b,0
fs_x:
    push bc
    ld d,c
    ld e,b
    ld a,(TMP)
    call cell_at
    pop bc
    cp CT_S
    jr z,fs_found
    inc b
    ld a,b
    cp 16
    jr nz,fs_x
    inc c
    ld a,c
    cp 16
    jr nz,fs_y
    ret
fs_found:
    ld a,b
    ld (PX),a
    ld a,c
    ld (PY),a
    ret

; ---------------- dungeon main ----------------
dungeon_enter:
    xor a
    ld (FL),a
    ld (CHEST_MASK),a
    ld (CHEST_MASK_H),a
    call find_start
    xor a
    ld (PDIR),a         ; north
    jp dungeon_main
dungeon_screen:
    call clear_screen
    ld a,3
    out ($F0),a         ; PCG front
    ld a,2
    call music_start
    call draw_view
    call draw_hud_dungeon
    ret

dungeon_main:
    call dungeon_screen
dm_loop:
    call wait_key
    cp 'U'
    jr z,dm_fwd
    cp 'D'
    jr z,dm_back
    cp 'L'
    jr z,dm_left
    cp 'R'
    jr z,dm_right
    cp 'S'
    jp z,dm_item
    jr dm_loop
dm_left:
    ld a,(PDIR)
    add a,3
    and 3
    ld (PDIR),a
    call snd_step
    call draw_view
    call draw_hud_dungeon
    jr dm_loop
dm_right:
    ld a,(PDIR)
    inc a
    and 3
    ld (PDIR),a
    call snd_step
    call draw_view
    call draw_hud_dungeon
    jr dm_loop
dm_fwd:
    xor a
    ld (CURDX),a
    ld a,1
    ld (CURZ),a
    call view_cell
    ld a,(CELLV)
    cp CT_WALL
    jr z,dm_bump
    ; move
    ld a,(CELLX)
    ld (PX),a
    ld a,(CELLY)
    ld (PY),a
    call snd_step
    call draw_view
    call draw_hud_dungeon
    call after_step
    jr dm_loop
dm_back:
    ; cell behind: dir^2
    ld a,(PDIR)
    xor 2
    ld (TMP),a
    ld a,(PDIR)
    push af
    ld a,(TMP)
    ld (PDIR),a
    xor a
    ld (CURDX),a
    ld a,1
    ld (CURZ),a
    call view_cell
    pop af
    ld (PDIR),a
    ld a,(CELLV)
    cp CT_WALL
    jp z,dm_loop
    ld a,(CELLX)
    ld (PX),a
    ld a,(CELLY)
    ld (PY),a
    call snd_step
    call draw_view
    call draw_hud_dungeon
    call after_step
    jp dm_loop
dm_bump:
    call snd_bump
    jp dm_loop
dm_item:
    ld hl,str_item_menu
    call dmsg_box
    call wait_key
    cp 'Z'
    jr z,dm_use_potion
    cp 'X'
    jr z,dm_use_feather
    call draw_view
    call draw_hud_dungeon
    jp dm_loop
dm_use_potion:
    ld a,(PL_POT)
    or a
    jr z,dmp_none
    ld hl,(PL_HP)
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr z,dmp_full
    ld hl,PL_POT
    dec (hl)
    ld hl,(PL_HP)
    ld de,12
    add hl,de
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr c,dmp_set
    jr z,dmp_setz
    ld hl,(PL_LIM)
    jr dmp_set2
dmp_set:
    add hl,de
dmp_set2:
    ld (PL_HP),hl
    jr dmp_done
dmp_setz:
    ld hl,(PL_LIM)
    ld (PL_HP),hl
dmp_done:
    ld hl,str_potion_use
    call dmsg_wait
    call draw_view
    call draw_hud_dungeon
    jp dm_loop
dmp_none:
    ld hl,str_no_potion
    call dmsg_wait
    call draw_view
    call draw_hud_dungeon
    jp dm_loop
dmp_full:
    ld hl,str_inn_full
    call dmsg_wait
    call draw_view
    call draw_hud_dungeon
    jp dm_loop
dm_use_feather:
    ld a,(PL_FEA)
    or a
    jr z,dmf_none
    dec a
    ld (PL_FEA),a
    ld hl,str_feather_use
    call dmsg_wait
    jp town_main
dmf_none:
    ld hl,str_no_feather
    call dmsg_wait
    call draw_view
    call draw_hud_dungeon
    jp dm_loop

; after a successful step: cell events + encounters
after_step:
    ld hl,(STEP_CNT)
    inc hl
    ld (STEP_CNT),hl
    ; current cell
    ld a,(PY)
    ld d,a
    ld a,(PX)
    ld e,a
    ld a,(FL)
    call cell_at
    ld (CELL_T),a
    cp CT_U
    jr z,as_up
    cp CT_S
    jr z,as_start
    cp CT_C
    jr z,as_chest
    cp CT_P
    jp z,as_spirit
    cp CT_B
    jp z,as_boss
    jp as_enc
as_up:
    ld a,(FL)
    cp 4
    jp z,as_enc
    inc a
    ld (FL),a
    xor a
    ld (CHEST_MASK),a
    ld (CHEST_MASK_H),a
    ld a,(FL)
    call find_start
    call draw_view
    call draw_hud_dungeon
    ret
as_start:
    ld a,(FL)
    or a
    ret nz
    ; floor1 S = exit to town
    jp town_main
as_chest:
    ld a,(PX)
    ld (CELLX),a
    ld a,(PY)
    ld (CELLY),a
    call chest_taken_here
    or a
    jp nz,as_enc
    call chest_mark_here
    call snd_chest
    ld hl,str_chest
    call dmsg_box
    ld b,40
    call wait_frames
    call rand
    and 3
    or a
    jr z,as_ch_gold
    cp 1
    jr z,as_ch_potion
    cp 2
    jr z,as_ch_feather
    ; LIM drink
    ld hl,(PL_LIM)
    inc hl
    inc hl
    ld (PL_LIM),hl
    ld hl,str_chest_lim
    call dmsg_wait
    jr as_done
as_ch_gold:
    call rand
    and 31
    add a,20
    ld c,a
    ld a,(FL)
    inc a
    ld b,a
    ld a,c
as_ch_gold_mul:
    dec b
    jr z,as_ch_gold_add
    add a,c
    jr as_ch_gold_mul
as_ch_gold_add:
    ld l,a
    ld h,0
    ld de,(PL_GOLD)
    add hl,de
    ld (PL_GOLD),hl
    ld hl,str_chest_gold
    call dmsg_wait
    jr as_done
as_ch_potion:
    ld hl,PL_POT
    inc (hl)
    ld hl,str_chest_potion
    call dmsg_wait
    jr as_done
as_ch_feather:
    ld hl,PL_FEA
    inc (hl)
    ld hl,str_chest_feather
    call dmsg_wait
as_done:
    call draw_view
    call draw_hud_dungeon
    ret
as_spirit:
    ld a,(FL)
    dec a               ; spirit index = floor-1 (floors 2..4)
    ld c,a
    ; mask = 1<<c in B
    ld b,1
    ld a,c
    or a
    jr z,as_sp_mask_ok
as_sp_mask:
    sla b
    dec a
    jr nz,as_sp_mask
as_sp_mask_ok:
    ld a,(SPIRIT_GOT)
    and b
    jr nz,as_sp_done_already
    ; dialogue
    ld hl,str_spirit1
    call dmsg_wait
    ld hl,str_spirit2
    call dmsg_box
    ld hl,str_spirit3
    ld de,VRAM+20*40+2
    ld b,$70
    call print_str
    call wait_key
    cp 'Z'
    jr nz,as_sp_no
    ; accept: EXP halved, sword++
    ld hl,(PL_EXP)
    srl h
    rr l
    ld (PL_EXP),hl
    ld hl,PL_SWD
    inc (hl)
    ; mark got
    ld a,(FL)
    dec a
    ld c,a
    ld b,1
    ld a,c
    or a
    jr z,as_sp_set
as_sp_shift:
    sla b
    dec a
    jr nz,as_sp_shift
as_sp_set:
    ld a,(SPIRIT_GOT)
    or b
    ld (SPIRIT_GOT),a
    call snd_levelup
    ld hl,str_got_sword
    call dmsg_wait
    jr as_done
as_sp_no:
    ld hl,str_spirit_no
    call dmsg_wait
    jr as_done
as_sp_done_already:
    ld hl,str_spirit_done
    call dmsg_wait
    jr as_done
as_boss:
    jp battle_boss
as_enc:
    call rand
    cp 30
    ret nc
    jp battle_start

; dungeon HUD: status + floor/compass on row 21
; ---- status panel: cols 25-39 (text from col 26), rows 0-11 ----
; The message zone (rows 12-24) is NOT touched here; see dmsg_box.
draw_hud_dungeon:
    ; clear panel rows 0..11, cols 25..39
    ld hl,VRAM+0*40+25
    ld c,12
dpan_cr:
    push hl
    ld b,15
    xor a
dpan_cc:
    ld (hl),a
    push hl
    ld de,$800
    add hl,de
    ld (hl),$70
    pop hl
    inc hl
    djnz dpan_cc
    pop hl
    ld de,40
    add hl,de
    dec c
    jr nz,dpan_cr
    ; floor + compass (row 1)
    ld hl,str_hud_floor
    ld de,VRAM+1*40+26
    ld b,$47
    call print_str
    ld a,(FL)
    inc a
    ld l,a
    ld h,0
    ld de,VRAM+1*40+28
    ld b,$47
    call print_num16_at
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,compass_tbl
    add hl,de
    ld a,(hl)
    ld (VRAM+1*40+38),a
    ld a,$47
    ld (VATTR+1*40+38),a
    ; LV (row 2)
    ld hl,str_hud_lv
    ld de,VRAM+2*40+26
    ld b,$70
    call print_str
    ld a,(PL_LV)
    ld l,a
    ld h,0
    ld de,VRAM+2*40+29
    ld b,$70
    call print_num16_at
    ; HP (row 3)
    ld hl,str_hud_hp
    ld de,VRAM+3*40+26
    ld b,$70
    call print_str
    ld hl,(PL_HP)
    ld de,VRAM+3*40+29
    ld b,$70
    call print_num16_at
    ld a,$2D            ; '/'
    ld (VRAM+3*40+32),a
    ld a,$70
    ld (VATTR+3*40+32),a
    ld hl,(PL_LIM)
    ld de,VRAM+3*40+33
    ld b,$70
    call print_num16_at
    ; ATK (row 4)
    ld hl,str_atk
    ld de,VRAM+4*40+26
    ld b,$70
    call print_str
    call atk_total
    ld l,a
    ld h,0
    ld de,VRAM+4*40+30
    ld b,$70
    call print_num16_at
    ; DEF (row 5)
    ld hl,str_def
    ld de,VRAM+5*40+26
    ld b,$70
    call print_str
    call def_total
    ld l,a
    ld h,0
    ld de,VRAM+5*40+30
    ld b,$70
    call print_num16_at
    ; EXP (row 6)
    ld hl,str_exp
    ld de,VRAM+6*40+26
    ld b,$70
    call print_str
    ld hl,(PL_EXP)
    ld de,VRAM+6*40+30
    ld b,$70
    call print_num16_at
    ; NEXT (row 7)
    ld hl,str_next
    ld de,VRAM+7*40+26
    ld b,$70
    call print_str
    call next_exp
    ld de,VRAM+7*40+31
    ld b,$70
    call print_num16_at
    ; G (row 8)
    ld hl,str_hud_g
    ld de,VRAM+8*40+26
    ld b,$70
    call print_str
    ld hl,(PL_GOLD)
    ld de,VRAM+8*40+28
    ld b,$70
    call print_num16_at
    ; holy swords (row 9)
    ld hl,str_sword
    ld de,VRAM+9*40+26
    ld b,$47
    call print_str
    ld a,(PL_SWD)
    ld l,a
    ld h,0
    ld de,VRAM+9*40+31
    ld b,$47
    call print_num16_at
    ; potions (row 10)
    ld hl,str_cmd_item
    ld de,VRAM+10*40+26
    ld b,$37
    call print_str
    ld a,(PL_POT)
    ld l,a
    ld h,0
    ld de,VRAM+10*40+31
    ld b,$37
    call print_num16_at
    call draw_map
    ret
compass_tbl: db $0E,$05,$13,$17   ; N E S W

; ---- mini-map: panel rows 12..24, cols 25..39 (15x13 window) ----
; Rotated so the player's facing is always up; the player is a PCG
; up-arrow (bank-1 tile 9) at the window centre (col 32, row 18).
; Map cells are text-plane colour blocks (code 0 + BG-colour attr).
map_attr_tbl:
    db $00,$07,$01,$04,$06,$03,$02,$05
    ;   open wall  S     U     C     P     B     D
    ;   blk  white blue  green yellow magt  red   cyan

; dm_term: B=coord (signed), C=component (-1/0/1) -> A = component*coord
dm_term:
    ld a,c
    or a
    jr z,dmt_zero
    jp p,dmt_pos
    ld a,b
    neg
    ret
dmt_pos:
    ld a,b
    ret
dmt_zero:
    xor a
    ret

draw_map:
    ld a,(CELLX)
    ld (MAP_SVX),a
    ld a,(CELLY)
    ld (MAP_SVY),a
    ; cache direction components for PDIR
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,rgt_dx
    add hl,de
    ld a,(hl)
    ld (MAP_RX),a
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,rgt_dy
    add hl,de
    ld a,(hl)
    ld (MAP_RY),a
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,fwd_dx
    add hl,de
    ld a,(hl)
    ld (MAP_FX),a
    ld a,(PDIR)
    ld l,a
    ld h,0
    ld de,fwd_dy
    add hl,de
    ld a,(hl)
    ld (MAP_FY),a
    ; row loop: sy = -6..6 -> screen rows 12..24
    ld ix,VRAM+12*40+25
    ld a,-6
    ld (MAP_SY),a
dm_row:
    ld a,-7
    ld (MAP_SX),a
dm_cell:
    ; MAP_X = PX + term(RX,SX) - term(FX,SY)
    ld a,(MAP_SX)
    ld b,a
    ld a,(MAP_RX)
    ld c,a
    call dm_term
    ld (MAP_T1),a
    ld a,(MAP_SY)
    ld b,a
    ld a,(MAP_FX)
    ld c,a
    call dm_term
    ld c,a
    ld a,(PX)
    ld hl,MAP_T1
    add a,(hl)
    sub c
    ld (MAP_X),a
    ; MAP_Y = PY + term(RY,SX) - term(FY,SY)
    ld a,(MAP_SX)
    ld b,a
    ld a,(MAP_RY)
    ld c,a
    call dm_term
    ld (MAP_T1),a
    ld a,(MAP_SY)
    ld b,a
    ld a,(MAP_FY)
    ld c,a
    call dm_term
    ld c,a
    ld a,(PY)
    ld hl,MAP_T1
    add a,(hl)
    sub c
    ld (MAP_Y),a
    ; fetch the cell (out of bounds -> void/open)
    ld a,(MAP_X)
    cp 16
    jp nc,dm_void
    ld a,(MAP_Y)
    cp 16
    jp nc,dm_void
    ld a,(MAP_Y)
    ld d,a
    ld a,(MAP_X)
    ld e,a
    ld a,(FL)
    call cell_at
    ld (MAP_CELL),a
    cp CT_C
    jp nz,dm_attr
    ; chest: already taken this visit -> show as open
    ld a,(MAP_X)
    ld (CELLX),a
    ld a,(MAP_Y)
    ld (CELLY),a
    call chest_taken_here
    or a
    jp z,dm_attr
    xor a
    ld (MAP_CELL),a
    jp dm_attr
dm_void:
    xor a
    ld (MAP_CELL),a
dm_attr:
    ld a,(MAP_CELL)
    ld l,a
    ld h,0
    ld de,map_attr_tbl
    add hl,de
    ld a,(hl)
    ld (MAP_ATTR),a
    ; HL = text pointer for this window cell
    push ix
    pop hl
    ld a,(MAP_SX)
    add a,7
    ld e,a
    ld d,0
    add hl,de
    ; player cell? (sx=0 and sy=0)
    ld a,(MAP_SX)
    or a
    jp nz,dm_write
    ld a,(MAP_SY)
    or a
    jp nz,dm_write
    ld (hl),0
    push hl
    ld de,$400
    add hl,de
    ld (hl),9           ; PCG code: bank-1 arrow tile
    pop hl
    push hl
    ld de,$C00
    add hl,de
    ld (hl),$48         ; PCG attr: bank 1 + PCG on
    pop hl
    push hl
    ld de,$800
    add hl,de
    ld (hl),$00
    pop hl
    jp dm_next
dm_write:
    ld (hl),0
    push hl
    ld de,$800
    add hl,de
    ld a,(MAP_ATTR)
    ld (hl),a
    pop hl
    push hl
    ld de,$400
    add hl,de
    ld (hl),0
    pop hl
    ld de,$C00
    add hl,de
    ld (hl),0
dm_next:
    ld hl,MAP_SX
    inc (hl)
    ld a,(MAP_SX)
    cp 8
    jp nz,dm_cell
    ld de,40
    add ix,de
    ld hl,MAP_SY
    inc (hl)
    ld a,(MAP_SY)
    cp 7
    jp nz,dm_row
    ld a,(MAP_SVX)
    ld (CELLX),a
    ld a,(MAP_SVY)
    ld (CELLY),a
    ret

; ---- dungeon message in the panel: cols 26..39, rows 12..24 ----
; HL = string (same format as msg_box). Wraps at the panel edge.
dmsg_box:
    push hl
    ld hl,VRAM+12*40+25
    ld c,13
dmsg_cr:
    push hl
    ld b,15
    xor a
dmsg_cc:
    ld (hl),a
    push hl
    ld de,$800
    add hl,de
    ld (hl),$70
    pop hl
    push hl
    ld de,$C00
    add hl,de
    ld (hl),0           ; PCG attr off (mini-map arrow must not leak)
    pop hl
    inc hl
    djnz dmsg_cc
    pop hl
    ld de,40
    add hl,de
    dec c
    jr nz,dmsg_cr
    pop hl
    ld de,VRAM+12*40+26
    ld b,$70
    ld c,26             ; current column
dmsg_loop:
    ld a,(hl)
    cp $FF
    ret z
    ld (de),a
    push hl
    push de
    ld h,d
    ld l,e
    ld de,$800
    add hl,de
    ld (hl),b
    pop de
    pop hl
    inc hl
    inc de
    inc c
    ld a,c
    cp 40
    jr nz,dmsg_loop
    ld c,26
    push hl
    ld h,d
    ld l,e
    ld de,26
    add hl,de
    ex de,hl
    pop hl
    jr dmsg_loop

dmsg_wait:
    call dmsg_box
    call wait_ok
    call draw_map       ; restore the mini-map under the message
    ret

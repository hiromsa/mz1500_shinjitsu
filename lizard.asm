; ============================================================
; SHINJITSU NO TOU - a 3D dungeon RPG for MZ-1500
; homage to 1980s Japanese 3D dungeon RPGs. Original code/music.
; org/load/exec $1200, single .mzt
; ============================================================
    org $1200
    jp START

; ---------------- constants ----------------
VRAM    equ $D000
VATTR   equ $D800
PCGATTR equ $DC00
KEYW    equ $E000
KEYR    equ $E001
VBL     equ $E002

; cell types (maps.inc)
CT_WALL equ 1
CT_S    equ 2
CT_U    equ 3
CT_C    equ 4
CT_P    equ 5
CT_B    equ 6
CT_D    equ 7

; ---------------- variables ($B000-) ----------------
VARS    equ $B000
PL_TYPE equ VARS+0      ; 0 warrior 1 thief 2 merchant
PL_LV   equ VARS+1
PL_HP   equ VARS+2      ; 16-bit
PL_HP_H equ VARS+3
PL_LIM  equ VARS+4      ; 16-bit max hp
PL_LIM_H equ VARS+5
PL_ATKB equ VARS+6      ; base atk
PL_DEFB equ VARS+7      ; base def
PL_EXP  equ VARS+8      ; 16-bit
PL_EXP_H equ VARS+9
PL_GOLD equ VARS+10     ; 16-bit
PL_GOLD_H equ VARS+11
PL_WPN  equ VARS+12     ; weapon id 0..5
PL_ARM  equ VARS+13     ; armor id 0..4
PL_POT  equ VARS+14     ; potions
PL_FEA  equ VARS+15     ; feathers
PL_SWD  equ VARS+16     ; holy swords 0..3
FL      equ VARS+17     ; floor 0..4
PX      equ VARS+18
PY      equ VARS+19
PDIR    equ VARS+20     ; 0=N 1=E 2=S 3=W
SPIRIT_GOT equ VARS+21  ; bits per floor-spirit (floor1..3 -> bits0..2)
CHEST_MASK equ VARS+22  ; 16-bit: chests taken on current floor visit
CHEST_MASK_H equ VARS+23
RNG     equ VARS+24
TMP     equ VARS+25
TMP2    equ VARS+26
TMP16   equ VARS+27     ; 2 bytes
TMP16_H equ VARS+28
MSG_PTR equ VARS+29     ; 2 bytes: current message str
MSG_PTR_H equ VARS+30
IN_BATTLE equ VARS+31
KEY_BUF equ VARS+90     ; key pressed during an action (rising-edge capture)
KEY_PREV equ VARS+91    ; last scanned key (for edge detection)
KEY_NOW equ VARS+92     ; scan scratch
BOSS_DONE equ VARS+32
FRAME   equ VARS+33     ; frame counter (vblank edges)
MUS_SONG equ VARS+34    ; current song id (0=none)
MUS_TICK equ VARS+35    ; tick counter
MUS_POS1 equ VARS+36    ; 2B ptr ch1
MUS_POS1_H equ VARS+37
MUS_POS2 equ VARS+38    ; 2B ptr ch2
MUS_POS2_H equ VARS+39
MUS_LEN1 equ VARS+40    ; remaining len ch1
MUS_LEN2 equ VARS+41
MUS_WAIT equ VARS+42    ; ticks until next step
CELL_T  equ VARS+43     ; current cell type under player
STEP_CNT equ VARS+44    ; 2B steps taken
STEP_CNT_H equ VARS+45

; ============================================================
START:
    di
    ld sp,$BFF0
    xor a
    out ($E0),a         ; low RAM (IPL leaves monitor ROM mapped)
    out ($E3),a         ; VRAM & EXT mapped
    ; clear vars
    ld hl,VARS
    ld de,VARS+1
    ld bc,127
    ld (hl),0
    ldir
    ld a,$5A
    ld (RNG),a
    call upload_tiles
    xor a
    out ($F0),a         ; text in front for text screens
    ei
    jp title_screen

; ============================================================
; PCG upload: tiles_data -> PCG RAM planes (codes 0..249)
upload_tiles:
    ; bank 0: 256 codes from tiles_data at plane offset 0
    ld ix,tiles_data
    ld hl,0
    ld a,0              ; 0 = 256 codes
    call ut_bank
    ; bank 1: 24 codes from tiles1_data at plane offset 2048
    ld ix,tiles1_data
    ld hl,2048
    ld a,24
    call ut_bank
    ret

ut_off: dw 0
ut_cnt: db 0
; ut_bank: IX=data ptr, HL=plane offset, A=code count (0 means 256)
ut_bank:
    ld (ut_off),hl
    ld (ut_cnt),a
    xor a
    ld (TMP),a          ; code index within the bank
utb_loop:
    ; for each plane 1..3: map plane, write 8 bytes at offset+code*8
    ld b,1              ; plane select value (1=B,2=R,3=G)
utb_plane:
    ld a,b
    out ($E5),a
    ; dest = $D000 + plane offset + code*8
    ld a,(TMP)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,(ut_off)
    add hl,de
    ld de,$D000
    add hl,de
    ex de,hl            ; DE=dest
    ; src = ix + (plane-1)*8
    push ix
    pop hl
    ld a,b
    dec a
    add a,a
    add a,a
    add a,a
    ld c,a
    ld a,l
    add a,c
    ld l,a
    ld a,h
    adc a,0
    ld h,a              ; HL=src
    push bc
    ld bc,8
    ldir
    pop bc
    inc b
    ld a,b
    cp 4
    jr nz,utb_plane
    out ($E6),a         ; unmap PCG (a=3 here, any value ok? use xor)
    ; next code: ix += 24
    ld de,24
    add ix,de
    ld hl,TMP
    inc (hl)
    ld a,(ut_cnt)
    dec a
    ld (ut_cnt),a
    jr nz,utb_loop
    ret

; ============================================================
; clear whole screen: text codes 0, attr $70, PCG attr off
clear_screen:
    ld hl,VRAM
    ld de,VRAM+1
    ld bc,999
    ld (hl),0
    ldir
    ld hl,VATTR
    ld de,VATTR+1
    ld bc,999
    ld (hl),$70
    ldir
    ld hl,PCGATTR
    ld de,PCGATTR+1
    ld bc,999
    ld (hl),0
    ldir
    ret

; set PCG cell: A=code, HL=PCG VRAM ptr ($D400 base), attr set separately
; fill a rect in PCG layer: HL=top-left PCG-code ptr, B=width, C=height, A=code
; (uses PCG code VRAM $D400.. and sets PCG attr bit3 for those cells)
fill_pcg_rect:
    ld (TMP2),a
    push hl
    pop ix              ; IX = row start (code vram)
fpr_row:
    push bc
    push ix
    pop hl
    ld a,(TMP2)
    ld b,0
    ; width in stack-saved B... use inner counter in A? restructure:
    pop bc
    push bc
    ld a,b              ; width
    ld (TMP),a
    push ix
    pop hl
fpr_col:
    ld a,(TMP2)
    ld (hl),a
    ; set pcg attr: ptr = hl + ($DC00-$D400) = hl + $800
    push hl
    ld de,$800
    add hl,de
    ld a,8              ; exact write (bank bits must not stick)
    ld (hl),a
    pop hl
    inc hl
    ld a,(TMP)
    dec a
    ld (TMP),a
    jr nz,fpr_col
    ; next row: ix += 40
    ld de,40
    add ix,de
    pop bc
    dec c
    jr nz,fpr_row
    ret

; print MZ string: HL=str ($FF term), DE=text VRAM ptr, B=attr
print_str:
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
    jr print_str

; print 16-bit decimal: HL=value, DE=text VRAM ptr, B=attr
; leading zeros suppressed. Preserves HL? no. Preserves DE? no (advances).
print_num16_at:
    ld (pn_dest),de
    ld a,b
    ld (pn_attr),a
    xor a
    ld (pn_started),a
    ld (TMP16),hl
    ld ix,num_buf
    ld de,10000
    call pn_digit
    ld de,1000
    call pn_digit
    ld de,100
    call pn_digit
    ld de,10
    call pn_digit
    ld hl,(TMP16)
    ld a,l
    add a,$20
    ld (ix+0),a
    ; print from first nonzero digit (num_buf has 0 for suppressed)
    ld hl,num_buf
    ld b,4
pn_skip:
    ld a,(hl)
    or a
    jr nz,pn_found
    inc hl
    djnz pn_skip
pn_found:
    ld de,(pn_dest)
    inc b               ; remaining digits = (4-skipped)+1
pn_loop:
    ld a,(hl)
    or a
    jr z,pn_next
    ld (de),a
    push hl
    ld h,d
    ld l,e
    push de
    ld de,$800
    add hl,de
    ld a,(pn_attr)
    ld (hl),a
    pop de
    pop hl
pn_next:
    inc hl
    inc de
    djnz pn_loop
    ret
; digit: DE=power; result char (or 0 if leading zero) -> (IX), IX++
pn_digit:
    ld hl,(TMP16)
    ld a,0
pn_dloop:
    or a
    sbc hl,de
    jr c,pn_ddone
    inc a
    jr pn_dloop
pn_ddone:
    add hl,de
    ld (TMP16),hl
    or a
    jr nz,pn_nonzero
    ; zero digit: print '0' only if a digit was already started
    ld a,(pn_started)
    or a
    jr z,pn_zstore0
    ld (ix+0),$20
    inc ix
    ret
pn_zstore0:
    ld (ix+0),0
    inc ix
    ret
pn_nonzero:
    ld c,a
    ld a,1
    ld (pn_started),a
    ld a,c
    add a,$20
    ld (ix+0),a
    inc ix
    ret
pn_dest: dw 0
pn_attr: db $70
pn_started: db 0
num_buf: db 0,0,0,0,0

; ============================================================
; keyboard: scan once. Returns A: 0=none, else key code:
; 'U','D','L','R' arrows, 'Z','X','S'(space),'C'(CR)
scan_key:
    ld a,7
    ld (KEYW),a
    ld a,(KEYR)
    bit 5,a
    jr z,sk_up
    bit 4,a
    jr z,sk_down
    bit 2,a
    jr z,sk_left
    bit 3,a
    jr z,sk_right
    ld a,1
    ld (KEYW),a
    ld a,(KEYR)
    bit 6,a
    jr z,sk_z
    ld a,2
    ld (KEYW),a
    ld a,(KEYR)
    bit 0,a
    jr z,sk_x
    ld a,6
    ld (KEYW),a
    ld a,(KEYR)
    bit 4,a
    jr z,sk_space
    ld a,0
    ld (KEYW),a
    ld a,(KEYR)
    bit 0,a
    jr z,sk_cr
    xor a
    ret
sk_up:    ld a,'U' & $FF
    ret
sk_down:  ld a,'D' & $FF
    ret
sk_left:  ld a,'L' & $FF
    ret
sk_right: ld a,'R' & $FF
    ret
sk_z:     ld a,'Z' & $FF
    ret
sk_x:     ld a,'X' & $FF
    ret
sk_space: ld a,'S' & $FF
    ret
sk_cr:    ld a,'C' & $FF
    ret

; wait B frames while scanning keys each frame.
; returns A=key code if pressed during the wait, else 0.
wait_frames_scan:
    ld c,0
wfs_loop:
    push bc
    call wait_vblank_edge
    call music_tick
    call scan_key
    pop bc
    or a
    jr nz,wfs_got
    djnz wfs_loop
    xor a
    ret
wfs_got:
    ld c,a
    ; drain remaining frames quickly (keep blink timing stable-ish)
    ld a,c
    ret

; wait for a fresh key press (waits release first). Returns A=key.
; music ticks while waiting.
wait_key:
    ; a key pressed during the preceding action (buffered by wait_frames'
    ; rising-edge capture) counts as the next press
    ld a,(KEY_BUF)
    or a
    jr z,wk_rel
    push af
    xor a
    ld (KEY_BUF),a
    pop af
    push af
    call snd_click
    pop af
    ret
wk_rel:
    ; wait until no key
    call music_poll
    call scan_key
    ld (KEY_PREV),a
    or a
    jr nz,wk_rel
wk_press:
    call music_poll
    call scan_key
    ld (KEY_PREV),a
    or a
    jr z,wk_press
    push af
    call snd_click
    pop af
    ret

; wait SPACE or CR or Z
wait_ok:
    call wait_key
    cp 'S'
    ret z
    cp 'C'
    ret z
    cp 'Z'
    ret z
    jr wait_ok

; wait N vblank frames (B=N), music ticks
wait_frames:
    ld a,b
    or a
    ret z
wf_loop:
    push bc
    ; capture a fresh key press (rising edge) so taps during SE/animation
    ; waits are not eaten; wait_key consumes KEY_BUF first
    call scan_key
    ld (KEY_NOW),a
    ld a,(KEY_PREV)
    or a
    jr nz,wf_kp
    ld a,(KEY_NOW)
    or a
    jr z,wf_kp
    ld a,(KEY_BUF)
    or a
    jr nz,wf_kp
    ld a,(KEY_NOW)
    ld (KEY_BUF),a
wf_kp:
    ld a,(KEY_NOW)
    ld (KEY_PREV),a
    call wait_vblank_edge
    call music_tick
    pop bc
    djnz wf_loop
    ret

; wait one vblank edge (bit7: 1->0 active low start of blank)
wait_vblank_edge:
    ld a,(VBL)
    bit 7,a
    jr z,wait_vblank_edge   ; wait until display (bit=1)
wve_2:
    ld a,(VBL)
    bit 7,a
    jr nz,wve_2             ; wait until blank (bit=0)
    ret

; random: returns A 0..255 (xorshift-ish on RNG + FRAME)
rand:
    ld a,(RNG)
    ld c,a
    add a,a
    add a,a
    add a,c
    add a,$3D
    ld c,a
    ld a,(FRAME)
    add a,c
    rrca
    ld (RNG),a
    ret

; random range: A = rand mod B
rand_mod:
    ; A = rand mod B; preserves BC and DE (callers keep base values in C)
    push bc
    push de
    ld d,b
    call rand
rm_loop:
    sub d
    jr nc,rm_loop
    add a,d
    pop de
    pop bc
    ret

    include "sound.asm"
    include "town.asm"
    include "dungeon.asm"
    include "battle.asm"

; ============================================================
; data
    include "notes.inc"
    include "tiles.inc"
    include "tiles1.inc"
    include "maps.inc"
    include "text.inc"

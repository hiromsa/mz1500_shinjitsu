; ============================================================
; title / char-make / town / shared UI
; ============================================================

; clear text rows: A=start row, B=count
clear_rows:
    push bc
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl           ; row*8
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl           ; row*32
    add hl,de           ; row*40
    ld de,VRAM
    add hl,de
    pop bc
cr_loop:
    push bc
    push hl
    ld b,40
cr_col:
    ld (hl),0
    push hl
    ld de,$800
    add hl,de
    ld (hl),$70
    pop hl
    inc hl
    djnz cr_col
    pop hl
    ld de,40
    add hl,de
    pop bc
    djnz cr_loop
    ret

; message in box rows 19-20: HL=str
msg_box:
    push hl
    ld a,19
    ld b,2
    call clear_rows
    pop hl
    ld de,VRAM+19*40+2
    ld b,$70
    call print_str
    ret
msg_wait:
    call msg_box
    call wait_ok
    ret

; menu state (used by menu_select2 below)
menu_items: db 0
menu_sel: db 0
menu_dest: dw 0
menu_tbl: dw 0

; ---- status line (rows 22-23) ----
; LV HP/LIM ATK DEF / EXP NEXT G SWD POT FEA
draw_status:
    ld a,22
    ld b,2
    call clear_rows
    ; LV
    ld hl,str_hud_lv
    ld de,VRAM+22*40+1
    ld b,$70
    call print_str
    ld a,(PL_LV)
    ld l,a
    ld h,0
    ld de,VRAM+22*40+4
    ld b,$70
    call print_num16_at
    ; HP
    ld hl,str_hud_hp
    ld de,VRAM+22*40+8
    ld b,$70
    call print_str
    ld hl,(PL_HP)
    ld de,VRAM+22*40+11
    ld b,$70
    call print_num16_at
    ld a,$2D            ; '/'
    ld (VRAM+22*40+14),a
    ld hl,(PL_LIM)
    ld de,VRAM+22*40+15
    ld b,$70
    call print_num16_at
    ; ATK
    ld hl,str_atk
    ld de,VRAM+22*40+20
    ld b,$70
    call print_str
    call atk_total
    ld l,a
    ld h,0
    ld de,VRAM+22*40+24
    ld b,$70
    call print_num16_at
    ; DEF
    ld hl,str_def
    ld de,VRAM+22*40+28
    ld b,$70
    call print_str
    call def_total
    ld l,a
    ld h,0
    ld de,VRAM+22*40+32
    ld b,$70
    call print_num16_at
    ; row 23: EXP NEXT G
    ld hl,str_exp
    ld de,VRAM+23*40+1
    ld b,$70
    call print_str
    ld hl,(PL_EXP)
    ld de,VRAM+23*40+5
    ld b,$70
    call print_num16_at
    ld hl,str_next
    ld de,VRAM+23*40+11
    ld b,$70
    call print_str
    call next_exp
    ld de,VRAM+23*40+16
    ld b,$70
    call print_num16_at
    ld hl,str_hud_g
    ld de,VRAM+23*40+22
    ld b,$70
    call print_str
    ld hl,(PL_GOLD)
    ld de,VRAM+23*40+24
    ld b,$70
    call print_num16_at
    ; swords + potions
    ld hl,str_sword
    ld de,VRAM+23*40+30
    ld b,$47
    call print_str
    ld a,(PL_SWD)
    ld l,a
    ld h,0
    ld de,VRAM+23*40+34
    ld b,$47
    call print_num16_at
    ret

; next_exp: returns HL = PL_LV*25
next_exp:
    ld a,(PL_LV)
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *5
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *25
    ret

; atk_total -> A
atk_total:
    ld a,(PL_WPN)
    ld l,a
    ld h,0
    ld de,wpn_atk_tbl
    add hl,de
    ld a,(hl)
    ld c,a
    ld a,(PL_ATKB)
    add a,c
    ld c,a
    ld a,(PL_SWD)
    add a,a
    add a,a
    ld b,a
    add a,a
    add a,b             ; swd*6 = *4 + *2... a was *2, *4=a+a? recompute:
    ; simpler: swd*6:
    ld a,(PL_SWD)
    ld b,a
    add a,a
    add a,a
    add a,b
    add a,b             ; *6
    add a,c
    ret
def_total:
    ld a,(PL_ARM)
    ld l,a
    ld h,0
    ld de,arm_def_tbl
    add hl,de
    ld a,(hl)
    ld c,a
    ld a,(PL_DEFB)
    add a,c
    ret
wpn_atk_tbl: db 0,2,4,7,11,16
arm_def_tbl: db 0,1,3,5,8
wpn_price_tbl: dw 0,60,150,400,900,2000
arm_price_tbl: dw 0,50,180,450,1000
wpn_name_tbl: dw str_wpn0,str_wpn1,str_wpn2,str_wpn3,str_wpn4,str_wpn5
arm_name_tbl: dw str_arm0,str_arm1,str_arm2,str_arm3,str_arm4

; ============================================================
title_screen:
    call clear_screen
    ld a,3
    out ($F0),a         ; PCG in front
    ld a,4
    call music_start
    ; big portrait 4x4 at cols 18..21 rows 2..5 (code vram)
    ld hl,$D400+2*40+18
    ld a,39
    ld (TMP),a
    ld c,4
tp_row:
    ld b,4
    push hl
tp_col:
    ld a,(TMP)
    ld (hl),a
    push hl
    ld de,$800
    add hl,de
    ld a,8
    ld (hl),a
    pop hl
    inc hl
    ld a,(TMP)
    inc a
    ld (TMP),a
    djnz tp_col
    pop hl
    ld de,40
    add hl,de
    dec c
    jr nz,tp_row
    ; title text (text layer shows where PCG attr off; but PCG is in
    ; front - text rows below portrait have no PCG cells, fine)
    ld hl,str_title
    ld de,VRAM+8*40+12
    ld b,$47
    call print_str
    ld hl,str_subtitle
    ld de,VRAM+10*40+7
    ld b,$70
    call print_str
    ld hl,str_howto1
    ld de,VRAM+18*40+8
    ld b,$37
    call print_str
    ld hl,str_howto2
    ld de,VRAM+19*40+8
    ld b,$37
    call print_str
title_wait:
    ; blink PUSH SPACE on row 13, scanning keys every frame
    ld hl,str_push
    ld de,VRAM+13*40+15
    ld b,$62
    call print_str
    ld b,25
    call wait_frames_scan
    or a
    jr nz,tw_check
    ld a,13
    ld b,1
    call clear_rows
    ld b,25
    call wait_frames_scan
    or a
    jr nz,tw_check
    jr title_wait
tw_check:
    cp 'S'
    jr z,title_go
    cp 'Z'
    jr z,title_go
    cp 'C'
    jr z,title_go
    jr title_wait
title_go:
    call music_stop
    xor a
    out ($F0),a
    jp char_make

; ============================================================
char_make:
    call clear_screen
    ld hl,str_make_title
    ld de,VRAM+2*40+8
    ld b,$47
    call print_str
    ld hl,str_q_type
    ld de,VRAM+4*40+8
    ld b,$70
    call print_str
    ; menu of 3 types at row 7
    ld hl,type_menu_tbl
    ld (menu_tbl),hl
    ld de,VRAM+7*40+10
    ld a,3
    call menu_select2
    ld (PL_TYPE),a
    ; stats from table: 5 bytes each (LIM, ATKB, DEFB, GOLD lo, GOLD hi)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl           ; *8? entries are 5 bytes -> *5 below overrides
    ld a,(PL_TYPE)
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *5
    ld de,type_tbl
    add hl,de
    ld a,(hl)
    ld (PL_LIM),a
    ld (PL_HP),a
    inc hl
    ld a,(hl)
    ld (PL_ATKB),a
    inc hl
    ld a,(hl)
    ld (PL_DEFB),a
    inc hl
    ld a,(hl)
    ld (PL_GOLD),a
    inc hl
    ld a,(hl)
    ld (PL_GOLD_H),a
    ld a,1
    ld (PL_LV),a
    ld a,1
    ld (PL_POT),a
    jp town_main
type_tbl:
    db 18,7,3,80,0      ; warrior
    db 14,6,3,120,0     ; thief
    db 12,5,2,44,1      ; merchant 300
type_menu_tbl:
    dw str_type1, str_type2, str_type3

; menu_select2: like menu_select but with desc line per item
; HL=table, A=count, DE=dest. desc table at menu_desc (may be 0)
menu_desc: dw 0
menu_select2:
    ld (menu_items),a
    ld (menu_dest),de
    xor a
    ld (menu_sel),a
    call menu_draw2f
ms2_loop:
    call wait_key
    cp 'U'
    jr z,ms2_up
    cp 'D'
    jr z,ms2_down
    cp 'Z'
    jr z,ms2_ok
    cp 'C'
    jr z,ms2_ok
    jr ms2_loop
ms2_ok:
    ld a,(menu_sel)
    ret
ms2_up:
    ld a,(menu_sel)
    or a
    jr z,ms2_loop
    dec a
    ld (menu_sel),a
    call menu_draw2f
    jr ms2_loop
ms2_down:
    ld a,(menu_sel)
    inc a
    ld c,a
    ld a,(menu_items)
    cp c
    jr z,ms2_loop
    ld a,c
    ld (menu_sel),a
    call menu_draw2f
    jr ms2_loop
menu_draw2f:
    ld hl,(menu_dest)
    ld (TMP16),hl
    ld a,(menu_items)
    ld b,a
    ld c,0
md2_loop:
    push bc
    ; dest for this row = TMP16
    ld hl,(TMP16)
    ld a,c
    ld de,menu_sel
    ; cursor
    ld a,(menu_sel)
    cp c
    ld a,0
    jr nz,md2_putc
    ld a,$57
md2_putc:
    ld (hl),a
    push hl
    ld de,$800
    add hl,de
    ld a,(menu_sel)
    cp c
    ld a,$70
    jr nz,md2_attr
    ld a,$47
md2_attr:
    ld (hl),a
    pop hl
    inc hl
    ex de,hl
    ; str ptr from menu_tbl + c*2
    ld hl,(menu_tbl)
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld b,$70
    call print_str
    ; next row
    ld hl,(TMP16)
    ld de,80
    add hl,de
    ld (TMP16),hl
    pop bc
    inc c
    djnz md2_loop
    ; desc line if menu_desc set
    ld hl,(menu_desc)
    ld a,h
    or l
    ret z
    ld a,(menu_sel)
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    push hl
    ld a,17
    ld b,1
    call clear_rows
    pop hl
    ld de,VRAM+17*40+4
    ld b,$37
    call print_str
    ret

; generic menu entry: HL=table A=count DE=dest (desc=0)
menu_select:
    ld (menu_tbl),hl
    ld hl,0
    ld (menu_desc),hl
    jp menu_select2
; with desc: HL=table, IX=desc table
menu_select_d:
    ld (menu_tbl),hl
    push ix
    pop hl
    ld (menu_desc),hl
    jp menu_select2

; ============================================================
town_main:
    ld a,1
    call music_start
    call clear_screen
    xor a
    out ($F0),a
    ld hl,str_town_name
    ld de,VRAM+1*40+17
    ld b,$47
    call print_str
    ld hl,str_town_wel
    ld de,VRAM+3*40+13
    ld b,$70
    call print_str
    call draw_status
    ld hl,town_menu_tbl
    ld de,VRAM+6*40+12
    ld a,5
    call menu_select
    or a
    jp z,town_hospital
    cp 1
    jp z,town_inn
    cp 2
    jp z,town_temple
    cp 3
    jp z,town_shop
    jp dungeon_enter
town_menu_tbl:
    dw str_m_hospital, str_m_inn, str_m_temple, str_m_shop, str_m_tower

; ---------------- hospital ----------------
town_hospital:
    call clear_screen
    ld hl,str_hosp_wel
    ld de,VRAM+2*40+2
    ld b,$70
    call print_str
    call draw_status
    ld hl,hosp_menu_tbl
    ld de,VRAM+6*40+10
    ld a,4
    call menu_select
    or a
    jr z,hosp_heal
    cp 1
    jr z,hosp_potion
    cp 2
    jr z,hosp_lim
    jp town_main
hosp_menu_tbl:
    dw str_hosp_heal, str_hosp_potion, str_hosp_lim, str_bye
hosp_heal:
    ld hl,(PL_HP)
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr z,hosp_full
    ld hl,100
    call try_pay
    jr nc,no_money_msg
    ld hl,(PL_LIM)
    ld (PL_HP),hl
    ld hl,str_healed
    call msg_wait
    jp town_hospital
hosp_full:
    ld hl,str_hosp_full
    call msg_wait
    jp town_hospital
hosp_potion:
    ld hl,50
    call try_pay
    jr nc,no_money_msg
    ld hl,PL_POT
    inc (hl)
    ld hl,str_got_potion
    call msg_wait
    jp town_hospital
hosp_lim:
    ld hl,300
    call try_pay
    jr nc,no_money_msg
    ld hl,(PL_LIM)
    inc hl
    inc hl
    ld (PL_LIM),hl
    ld hl,str_lim_up
    call msg_wait
    jp town_hospital
no_money_msg:
    ld hl,str_no_money
    call msg_wait
    jp town_main

; try_pay: HL=price. If gold>=price: gold-=price, CF=1. else CF=0.
try_pay:
    ld (TMP16),hl
    ld hl,(PL_GOLD)
    ld de,(TMP16)
    or a
    sbc hl,de
    jr c,tp_ng
    ld (PL_GOLD),hl
    scf
    ret
tp_ng:
    or a
    ret

; ---------------- inn ----------------
town_inn:
    call clear_screen
    ld hl,str_inn_wel
    ld de,VRAM+2*40+4
    ld b,$70
    call print_str
    call draw_status
    ld hl,inn_menu_tbl
    ld de,VRAM+6*40+10
    ld a,2
    call menu_select
    or a
    jr z,inn_do
    jp town_main
inn_menu_tbl:
    dw str_inn_do, str_bye
inn_do:
    ld hl,(PL_HP)
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr z,inn_full
    ld hl,20
    call try_pay
    jr nc,no_money_msg
    ; heal LIM/2
    ld hl,(PL_LIM)
    srl h
    rr l
    ld de,(PL_HP)
    add hl,de
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr c,inn_set
    jr z,inn_set
    ld hl,(PL_LIM)
    jr inn_set2
inn_set:
    add hl,de
inn_set2:
    ld (PL_HP),hl
    ld hl,str_rested
    call msg_wait
    jp town_inn
inn_full:
    ld hl,str_inn_full
    call msg_wait
    jp town_inn

; ---------------- temple ----------------
town_temple:
    call clear_screen
    ld hl,str_temple_wel2
    ld de,VRAM+2*40+6
    ld b,$70
    call print_str
    call draw_status
    ; check exp
    call next_exp
    ld de,(PL_EXP)
    ex de,hl
    or a
    sbc hl,de           ; exp - needed
    jr c,temp_ng
    ld hl,temp_menu_tbl
    ld de,VRAM+6*40+10
    ld a,2
    call menu_select
    or a
    jr z,temp_do
    jp town_main
temp_ng:
    ld hl,str_temp_notyet
    call msg_wait
    jp town_main
temp_menu_tbl:
    dw str_temp_do, str_bye
temp_do:
    ld hl,PL_LV
    inc (hl)
    ld hl,(PL_LIM)
    ld de,4
    add hl,de
    ld (PL_LIM),hl
    ld (PL_HP),hl
    ld hl,PL_ATKB
    inc (hl)
    inc (hl)
    ld hl,PL_DEFB
    inc (hl)
    call snd_levelup
    ld hl,str_leveled
    call msg_wait
    jp town_temple

; ---------------- shop ----------------
town_shop:
    call clear_screen
    ld hl,str_shop_wel
    ld de,VRAM+2*40+8
    ld b,$70
    call print_str
    call draw_status
    ld hl,shop_menu_tbl
    ld de,VRAM+6*40+10
    ld a,3
    call menu_select
    or a
    jr z,shop_wpn
    cp 1
    jp z,shop_arm
    jp town_main
shop_menu_tbl:
    dw str_shop_w_wpn, str_shop_w_arm, str_bye
shop_wpn:
    ; list weapons 1..5 at rows 9..13: name + price; cursor menu over ids
    call clear_screen
    ld hl,str_shop_wel
    ld de,VRAM+2*40+8
    ld b,$70
    call print_str
    call draw_status
    call shop_draw_wpn
    ld hl,shop_wpn_tbl
    ld de,VRAM+9*40+8
    ld a,5
    call menu_select
    inc a               ; id 1..5
    ld (TMP),a
    ld a,(PL_WPN)
    ld c,a
    ld a,(TMP)
    cp c
    jr z,shop_have
    jr c,shop_have
    ; price
    ld l,a
    ld h,0
    add hl,hl
    ld de,wpn_price_tbl
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    call try_pay
    jp nc,no_money_msg
    ld a,(TMP)
    ld (PL_WPN),a
    ld hl,str_equipped
    call msg_wait
    jp town_shop
shop_have:
    ld hl,str_equipped
    call msg_wait
    jp town_shop
shop_draw_wpn:
    ld c,1
sdw_loop:
    ; name at row 8+c col 10, price col 28
    ld a,c
    add a,a
    add a,7
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de
    ld de,VRAM+10
    add hl,de
    ex de,hl            ; DE=dest
    push bc
    ld hl,wpn_name_tbl
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld b,$70
    call print_str
    pop bc
    ; price
    push bc
    ld a,c
    add a,a
    add a,7
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de
    ld de,VRAM+28
    add hl,de
    ex de,hl
    ld hl,wpn_price_tbl
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld b,$70
    call print_num16_at
    pop bc
    inc c
    ld a,c
    cp 6
    jr nz,sdw_loop
    ret
shop_wpn_tbl:
    dw str_wpn1,str_wpn2,str_wpn3,str_wpn4,str_wpn5
shop_arm:
    call clear_screen
    ld hl,str_shop_wel
    ld de,VRAM+2*40+8
    ld b,$70
    call print_str
    call draw_status
    call shop_draw_arm
    ld hl,shop_arm_tbl
    ld de,VRAM+9*40+8
    ld a,4
    call menu_select
    inc a
    ld (TMP),a
    ld a,(PL_ARM)
    ld c,a
    ld a,(TMP)
    cp c
    jp z,shop_have
    jp c,shop_have
    ld l,a
    ld h,0
    add hl,hl
    ld de,arm_price_tbl
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    call try_pay
    jp nc,no_money_msg
    ld a,(TMP)
    ld (PL_ARM),a
    ld hl,str_equipped
    call msg_wait
    jp town_shop
shop_draw_arm:
    ld c,1
sda_loop:
    ld a,c
    add a,a
    add a,7
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de
    ld de,VRAM+10
    add hl,de
    ex de,hl
    push bc
    ld hl,arm_name_tbl
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld b,$70
    call print_str
    pop bc
    push bc
    ld a,c
    add a,a
    add a,7
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de
    ld de,VRAM+28
    add hl,de
    ex de,hl
    ld hl,arm_price_tbl
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    ld b,$70
    call print_num16_at
    pop bc
    inc c
    ld a,c
    cp 6
    jr nz,sda_loop
    ret
shop_arm_tbl:
    dw str_arm1,str_arm2,str_arm3,str_arm4

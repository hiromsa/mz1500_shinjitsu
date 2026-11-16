; ============================================================
; battle: command fight with animated mini chars.
; Each enemy has its own big portrait (tiles 58+id*16); the boss
; uses the lizard portrait (tile 39). Mini chars are shared.
; ============================================================
ENE_HP   equ VARS+70
ENE_MAX  equ VARS+71
ENE_ATK  equ VARS+72
ENE_DEF  equ VARS+73
ENE_EXP  equ VARS+74    ; 2B
ENE_EXP_H equ VARS+75
ENE_GOLD equ VARS+76    ; 2B
ENE_GOLD_H equ VARS+77
ENE_HUM  equ VARS+78
IS_BOSS  equ VARS+79
ENE_NAME equ VARS+80    ; 2B ptr
ENE_NAME_H equ VARS+81
WARNED   equ VARS+82
ENE_PIC  equ VARS+83

ene_tbl:
    dw str_ene0
    db 10,5,1
    dw 6
    dw 8
    db 0
    dw str_ene1
    db 8,6,0
    dw 7
    dw 5
    db 0
    dw str_ene2
    db 12,6,1
    dw 8
    dw 10
    db 0
    dw str_ene3
    db 16,8,2
    dw 12
    dw 12
    db 0
    dw str_ene4
    db 20,8,3
    dw 14
    dw 8
    db 0
    dw str_ene5
    db 15,9,2
    dw 13
    dw 20
    db 0
    dw str_ene6
    db 22,11,3
    dw 20
    dw 40
    db 1
    dw str_ene7
    db 26,12,4
    dw 24
    dw 25
    db 0
    dw str_ene8
    db 20,12,2
    dw 22
    dw 30
    db 0
    dw str_ene9
    db 34,14,5
    dw 34
    dw 50
    db 0
    dw str_ene10
    db 30,13,4
    dw 30
    dw 45
    db 0
    dw str_ene11
    db 36,15,6
    dw 38
    dw 60
    db 1
boss_entry:
    dw str_boss_name
    db 120,18,8
    dw 200
    dw 500
    db 0
floor_pool:
    db 0,1,2
    db 3,4,5
    db 6,7,8
    db 9,10,11
    db 9,10,11

; setup enemy from HL=entry ptr
setup_enemy:
    ld a,(hl)
    inc hl
    ld (ENE_NAME),a
    ld a,(hl)
    inc hl
    ld (ENE_NAME_H),a
    ld a,(hl)
    inc hl
    ld (ENE_HP),a
    ld (ENE_MAX),a
    ld a,(hl)
    inc hl
    ld (ENE_ATK),a
    ld a,(hl)
    inc hl
    ld (ENE_DEF),a
    ld a,(hl)
    inc hl
    ld (ENE_EXP),a
    ld a,(hl)
    inc hl
    ld (ENE_EXP_H),a
    ld a,(hl)
    inc hl
    ld (ENE_GOLD),a
    ld a,(hl)
    inc hl
    ld (ENE_GOLD_H),a
    ld a,(hl)
    ld (ENE_HUM),a
    ret

battle_start:
    ld a,(FL)
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,de           ; floor*3
    ld de,floor_pool
    add hl,de           ; HL=pool ptr
    push hl
    ld b,3
    call rand_mod
    pop hl
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)           ; enemy id
    ; portrait base = 58 + id*16
    push af
    add a,a
    add a,a
    add a,a
    add a,a
    add a,58
    ld (ENE_PIC),a
    pop af
    ; entry = ene_tbl + id*10
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *5
    add hl,hl           ; *10
    ld de,ene_tbl
    add hl,de
    xor a
    ld (IS_BOSS),a
    ld (WARNED),a
    call setup_enemy
    jp battle_main

battle_boss:
    ld hl,boss_entry
    ld a,1
    ld (IS_BOSS),a
    ld (WARNED),a
    ld a,39
    ld (ENE_PIC),a
    call setup_enemy
    ; fall into battle_main

battle_main:
    ld a,3
    call music_start
    call clear_screen
    ld a,3
    out ($F0),a
    ; big portrait at rel (16,0) (cols 18..21, rows 1..4)
    ld e,0
    ld d,16
    call draw_big_rel
    ; enemy name row 7 (text row = rel row 6 -> screen row 7)
    ld hl,(ENE_NAME)
    ld de,VRAM+6*40+16
    ld b,$62
    call print_str
    call draw_battle_strip
    call draw_battle_hud
    ld a,(IS_BOSS)
    or a
    jr z,bm_enc
    ld hl,str_boss_appear
    jr bm_enc2
bm_enc:
    ld hl,str_encounter
bm_enc2:
    call msg_box
    ld b,50
    call wait_frames
bm_cmd:
    call draw_battle_hud
    ld hl,battle_menu_tbl
    ld de,VRAM+8*40+4
    ld a,4
    call menu_select
    or a
    jp z,bm_fight
    cp 1
    jp z,bm_run
    cp 2
    jp z,bm_talk
    jp bm_item
battle_menu_tbl:
    dw str_cmd_fight, str_cmd_run, str_cmd_talk, str_cmd_item

; draw player mini (4,13) frame A, monster mini (28,13) frame A
draw_battle_strip:
    ld d,4
    ld e,15
    ld a,23
    call draw_sprite2
    ld d,28
    ld e,15
    ld a,31
    call draw_sprite2
    ret
erase_sprite2:
    ld a,0
    call set_cell_rel
    inc d
    ld a,0
    call set_cell_rel
    inc e
    ld a,0
    call set_cell_rel
    dec d
    ld a,0
    call set_cell_rel
    ret

draw_big_rel:
    ; D=x, E=y rel; base tile in ENE_PIC
    ld a,(ENE_PIC)
    ld (TMP),a
    ld b,4
dbr_row:
    push bc
    push de
    ld c,4
dbr_col:
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
    jr nz,dbr_col
    pop de
    pop bc
    inc e
    djnz dbr_row
    ret

draw_battle_hud:
    call draw_status
    ; enemy hp on row 21
    ld a,21
    ld b,1
    call clear_rows
    ld hl,(ENE_NAME)
    ld de,VRAM+21*40+2
    ld b,$62
    call print_str
    ld hl,str_hud_hp
    ld de,VRAM+21*40+12
    ld b,$62
    call print_str
    ld a,(ENE_HP)
    ld l,a
    ld h,0
    ld de,VRAM+21*40+15
    ld b,$62
    call print_num16_at
    ld a,$2D
    ld (VRAM+21*40+18),a
    ld a,(ENE_MAX)
    ld l,a
    ld h,0
    ld de,VRAM+21*40+19
    ld b,$62
    call print_num16_at
    ret

; ---------- player attack ----------
bm_fight:
    ; animate: player frame B stepping right
    ld d,4
    ld e,15
    call erase_sprite2
    ld d,7
    ld e,15
    ld a,27
    call draw_sprite2
    ld b,5
    call wait_frames
    ld d,7
    ld e,15
    call erase_sprite2
    ld d,11
    ld e,15
    ld a,27
    call draw_sprite2
    call snd_hit
    ; monster flash
    ld d,28
    ld e,15
    call erase_sprite2
    ld b,4
    call wait_frames
    ld d,28
    ld e,15
    ld a,35
    call draw_sprite2
    ld b,4
    call wait_frames
    ld d,28
    ld e,15
    call erase_sprite2
    ld d,28
    ld e,15
    ld a,31
    call draw_sprite2
    ; player back
    ld d,11
    ld e,15
    call erase_sprite2
    ld d,4
    ld e,15
    ld a,23
    call draw_sprite2
    ; damage
    call atk_total
    ld c,a
    ld a,(ENE_DEF)
    srl a
    ld b,a
    ld a,c
    sub b
    jr nc,bf_dmg_ok
    ld a,1
bf_dmg_ok:
    ld c,a
    ld b,5
    call rand_mod
    add a,c
    ld c,a              ; dmg in C
    ; boss sword check
    ld a,(IS_BOSS)
    or a
    jr z,bf_apply
    ld a,(PL_SWD)
    cp 3
    jr z,bf_apply
    ld c,1
    ld a,(WARNED)
    or a
    jr nz,bf_apply
    ld a,1
    ld (WARNED),a
    push bc
    ld hl,str_need_swords
    call msg_wait
    pop bc
bf_apply:
    ; show log: name? use "YOU HIT n DAMAGE" via you_hit + num + dmg
    ld a,19
    ld b,2
    call clear_rows
    ld hl,str_you_hit
    ld de,VRAM+19*40+2
    ld b,$70
    call print_str
    ld a,c
    push bc
    ld l,a
    ld h,0
    ld b,$70
    call print_num16_at   ; DE advanced by print_str
    ld hl,str_dmg
    ld b,$70
    call print_str
    pop bc
    ld b,45
    call wait_frames
    ; ene_hp -= dmg
    ld a,(ENE_HP)
    sub c
    jr c,bf_win
    jr z,bf_win
    ld (ENE_HP),a
    jp bm_enemy_turn
bf_win:
    xor a
    ld (ENE_HP),a
    jp bm_win

; ---------- enemy turn ----------
bm_enemy_turn:
    call draw_battle_hud
    ; monster lunge left
    ld d,28
    ld e,15
    call erase_sprite2
    ld d,25
    ld e,15
    ld a,35
    call draw_sprite2
    ld b,5
    call wait_frames
    ld d,25
    ld e,15
    call erase_sprite2
    ld d,21
    ld e,15
    ld a,35
    call draw_sprite2
    call snd_hurt
    ; player flash
    ld d,4
    ld e,15
    call erase_sprite2
    ld b,4
    call wait_frames
    ld d,4
    ld e,15
    ld a,23
    call draw_sprite2
    ld d,21
    ld e,15
    call erase_sprite2
    ld d,28
    ld e,15
    ld a,31
    call draw_sprite2
    ; damage to player (def_total clobbers C, so load ENE_ATK after)
    call def_total
    srl a
    ld b,a
    ld a,(ENE_ATK)
    sub b
    jr nc,be_dmg_ok
    ld a,1
be_dmg_ok:
    ld c,a
    ld b,4
    call rand_mod
    add a,c
    ld c,a
    ; log
    ld a,19
    ld b,2
    call clear_rows
    ld hl,(ENE_NAME)
    ld de,VRAM+19*40+2
    ld b,$70
    call print_str
    ld hl,str_ene_hit
    ld b,$70
    call print_str
    ld a,c
    push bc
    ld l,a
    ld h,0
    ld b,$70
    call print_num16_at
    ld hl,str_dmg
    ld b,$70
    call print_str
    pop bc
    ld b,45
    call wait_frames
    ; hp -= dmg (16-bit)
    ld l,c
    ld h,0
    ld de,(PL_HP)
    ex de,hl
    or a
    sbc hl,de
    jr c,be_dead
    jr z,be_dead
    ld (PL_HP),hl
    jp bm_cmd
be_dead:
    ld hl,0
    ld (PL_HP),hl
    jp bm_death

; ---------- run ----------
bm_run:
    ld a,(IS_BOSS)
    or a
    jr nz,bm_run_ng
    call rand
    ld c,a
    ld a,(PL_TYPE)
    cp 1
    jr z,bm_run_thief
    ld a,c
    cp 180
    jr c,bm_run_ok
    jr bm_run_ng
bm_run_thief:
    ld a,c
    cp 215
    jr c,bm_run_ok
bm_run_ng:
    ld hl,str_ran_ng
    call msg_wait
    jp bm_enemy_turn
bm_run_ok:
    ; exp penalty: lose 10 (or all if less)
    ld hl,(PL_EXP)
    ld de,10
    or a
    sbc hl,de
    jr nc,bm_run_set
    ld hl,0
bm_run_set:
    ld (PL_EXP),hl
    ld hl,str_ran_ok
    call msg_wait
    jp dungeon_main

; ---------- talk ----------
bm_talk:
    ld a,(ENE_HUM)
    or a
    jr z,bm_talk_ng
    call rand
    cp 128
    jr nc,bm_talk_ng
    ld hl,str_talk_ok
    call msg_wait
    jp dungeon_main
bm_talk_ng:
    ld hl,str_talk_ng
    call msg_wait
    jp bm_enemy_turn

; ---------- item ----------
bm_item:
    ld a,(PL_POT)
    or a
    jr z,bi_none
    ld hl,(PL_HP)
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr z,bi_full
    ld hl,PL_POT
    dec (hl)
    ld hl,(PL_HP)
    ld de,12
    add hl,de
    ld de,(PL_LIM)
    or a
    sbc hl,de
    jr c,bi_set
    jr z,bi_setz
    ld hl,(PL_LIM)
    jr bi_set2
bi_set:
    add hl,de
bi_set2:
    ld (PL_HP),hl
    jr bi_done
bi_setz:
    ld hl,(PL_LIM)
    ld (PL_HP),hl
bi_done:
    ld hl,str_potion_use
    call msg_wait
    jp bm_enemy_turn
bi_none:
    ld hl,str_no_potion
    call msg_wait
    jp bm_cmd
bi_full:
    ld hl,str_inn_full
    call msg_wait
    jp bm_cmd

; ---------- win ----------
bm_win:
    call snd_victory
    ld hl,str_win
    call msg_box
    ld b,50
    call wait_frames
    ld hl,(PL_EXP)
    ld de,(ENE_EXP)
    add hl,de
    ld (PL_EXP),hl
    ld hl,(PL_GOLD)
    ld de,(ENE_GOLD)
    add hl,de
    ld (PL_GOLD),hl
    ld hl,str_got_exp
    call msg_wait
    ld a,(IS_BOSS)
    or a
    jp z,dungeon_main
    jp ending

; ---------- death ----------
bm_death:
    ld a,6
    call music_start
    ld hl,str_you_died
    call msg_wait
    ld hl,(PL_GOLD)
    srl h
    rr l
    ld (PL_GOLD),hl
    ld hl,(PL_LIM)
    srl h
    rr l
    ld (PL_HP),hl
    ld hl,str_wake
    call msg_wait
    jp town_main

; ---------- ending ----------
ending:
    ld a,5
    call music_start
    call clear_screen
    xor a
    out ($F0),a
    ld hl,str_book
    ld de,VRAM+4*40+6
    ld b,$47
    call print_str
    ld hl,str_end1
    ld de,VRAM+7*40+4
    ld b,$70
    call print_str
    ld hl,str_end2
    ld de,VRAM+8*40+4
    ld b,$70
    call print_str
    ld hl,str_end3
    ld de,VRAM+11*40+4
    ld b,$70
    call print_str
    ld hl,str_clear_time
    ld de,VRAM+14*40+10
    ld b,$70
    call print_str
    ld hl,str_end4
    ld de,VRAM+17*40+16
    ld b,$62
    call print_str
    ld hl,str_thanks
    ld de,VRAM+19*40+9
    ld b,$37
    call print_str
    call wait_ok
    jp START

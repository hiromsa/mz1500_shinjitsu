; ============================================================
; sound: PSG driver (E9 = both PSGs), ch0 melody, ch1 bass,
; ch2 SE, noise on F2 for hits. Songs loop.
; ============================================================
MUS_TOP1 equ VARS+46
MUS_TOP1_H equ VARS+47
MUS_TOP2 equ VARS+48
MUS_TOP2_H equ VARS+49

psg_mute_all:
    ld a,$9F
    out ($F2),a
    out ($F3),a
    ld a,$BF
    out ($F2),a
    out ($F3),a
    ld a,$DF
    out ($F2),a
    out ($F3),a
    ld a,$FF
    out ($F2),a
    out ($F3),a
    ret

; set PSG tone on both PSGs (port E9): A=reg(0..2), HL=divider n
; preserves HL, BC
psg_port: db $E9
psg_set_tone:
    push bc
    push hl
    ld c,a              ; reg
    ld a,l
    and $0F
    ld b,a              ; low nibble
    ld a,c
    rlca
    rlca
    rlca
    rlca
    rlca
    or $80
    or b
    out ($E9),a
    pop hl
    ; second byte must be divider bits 4..9: (HL >> 4) & $3F
    push hl
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    ld a,l
    and $3F
    out ($E9),a
    pop hl
    pop bc
    ret

; set volume: A=reg, C=attenuation (0 loud..15 mute), both PSGs
psg_set_vol:
    rlca
    rlca
    rlca
    rlca
    rlca
    or $90
    or c
    out ($E9),a
    ret

; note on: A=midi note, B=reg. Uses note_tbl.
note_on:
    push bc
    sub 36
    add a,a
    ld l,a
    ld h,0
    ld de,note_tbl
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl            ; HL=divider
    pop bc
    ld a,b              ; A=reg
    call psg_set_tone
    ret

note_off:
    ld a,b
    ld c,15
    call psg_set_vol
    ret

; ---------------- music engine ----------------
; music_start: A=song id (1 town, 2 dungeon, 3 battle)
music_start:
    ld c,a
    ld a,(MUS_SONG)
    cp c
    ret z               ; already playing
    ld a,c
    ld (MUS_SONG),a
    call psg_mute_all
    ; find song hdr: songs table, 5 bytes each (tempo, ch1 dw, ch2 dw)
    dec a
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl           ; *8? no: 5 bytes/entry -> *5
    ; recompute *5
    ld a,(MUS_SONG)
    dec a
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de           ; *5
    ld de,song_tbl
    add hl,de
    ld a,(hl)
    ld (MUS_WAIT),a     ; tempo as initial wait too
    ld (TMP2),a         ; save tempo
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (MUS_TOP1),de
    ld (MUS_POS1),de
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (MUS_TOP2),de
    ld (MUS_POS2),de
    xor a
    ld (MUS_LEN1),a
    ld (MUS_LEN2),a
    ld a,1
    ld (MUS_TICK),a
    ; volumes: melody att 3, bass att 5
    ld a,0
    ld c,3
    call psg_set_vol
    ld a,1
    ld c,5
    call psg_set_vol
    ret

music_stop:
    xor a
    ld (MUS_SONG),a
    call psg_mute_all
    ret

; one frame tick
music_tick:
    ld hl,FRAME
    inc (hl)
    ld a,(MUS_SONG)
    or a
    ret z
    ld hl,MUS_TICK
    dec (hl)
    ret nz
    ; step: reload tick from song tempo
    ld a,(MUS_SONG)
    dec a
    ld l,a
    ld h,0
    ld e,l
    ld d,h
    add hl,hl
    add hl,hl
    add hl,de
    ld de,song_tbl
    add hl,de
    ld a,(hl)
    ld (MUS_TICK),a
    ; ch1
    ld hl,MUS_LEN1
    ld a,(hl)
    or a
    jr z,mt_fetch1
    dec (hl)
    jr nz,mt_ch2
mt_fetch1:
    ld hl,(MUS_POS1)
    ld a,(hl)
    cp $FF
    jr z,mt_loop1
    ld c,a              ; note
    inc hl
    ld a,(hl)           ; len
    inc hl
    ld (MUS_POS1),hl
    ld (MUS_LEN1),a
    ld a,c
    or a
    jr z,mt_rest1
    ld b,0
    call note_on
    jr mt_ch2
mt_rest1:
    ld b,0
    call note_off
    jr mt_ch2
mt_loop1:
    ld hl,(MUS_TOP1)
    ld (MUS_POS1),hl
    jr mt_fetch1
mt_ch2:
    ld hl,MUS_LEN2
    ld a,(hl)
    or a
    jr z,mt_fetch2
    dec (hl)
    ret nz
mt_fetch2:
    ld hl,(MUS_POS2)
    ld a,(hl)
    cp $FF
    jr z,mt_loop2
    ld c,a
    inc hl
    ld a,(hl)
    inc hl
    ld (MUS_POS2),hl
    ld (MUS_LEN2),a
    ld a,c
    or a
    jr z,mt_rest2
    ld b,1
    call note_on
    ret
mt_rest2:
    ld b,1
    call note_off
    ret
mt_loop2:
    ld hl,(MUS_TOP2)
    ld (MUS_POS2),hl
    jr mt_fetch2

; poll used in wait loops: one frame + tick
music_poll:
    call wait_vblank_edge
    call music_tick
    ret

; ---------------- SE ----------------
; click: tiny blip on reg2
snd_click:
    ld a,$E9
    ld (psg_port),a
    ld hl,120
    ld a,2
    call psg_set_tone
    ld a,2
    ld c,6
    call psg_set_vol
    ld b,2
    call wait_frames
    ld a,2
    ld c,15
    call psg_set_vol
    ret

; step: two short noise taps (footsteps), clearly unlike the bump thud
snd_step:
    ld a,$E5            ; white noise rate1
    out ($F2),a
    ld a,$F5            ; noise vol att 5
    out ($F2),a
    ld b,1
    call wait_frames
    ld a,$FF
    out ($F2),a
    ld b,1
    call wait_frames
    ld a,$F8            ; second tap, quieter
    out ($F2),a
    ld b,1
    call wait_frames
    ld a,$FF
    out ($F2),a
    ret

; bump: low dull thud (tone drops 140Hz -> 109Hz) + noise crunch
snd_bump:
    ld a,$E9
    ld (psg_port),a
    ld hl,800
    ld a,2
    call psg_set_tone
    ld a,2
    ld c,1
    call psg_set_vol
    ld a,$E5
    out ($F2),a
    ld a,$F4
    out ($F2),a
    ld b,3
    call wait_frames
    ld hl,1023
    ld a,2
    call psg_set_tone
    ld a,$FF
    out ($F2),a
    ld b,3
    call wait_frames
    ld a,2
    ld c,15
    call psg_set_vol
    ret

; hit: noise burst on F2
snd_hit:
    ld a,$E5            ; white noise rate1
    out ($F2),a
    ld a,$F0            ; noise vol att 0 on PSG1
    out ($F2),a
    ld b,4
    call wait_frames
    ld a,$FF
    out ($F2),a
    ret

snd_hurt:
    ld a,$E9
    ld (psg_port),a
    ld hl,900
    ld a,2
    call psg_set_tone
    ld a,2
    ld c,4
    call psg_set_vol
    ld b,6
    call wait_frames
    ld a,2
    ld c,15
    call psg_set_vol
    ret

; generic short sequence on reg0: HL -> (midi,frames) pairs, 0=end
play_seq:
    ld a,(hl)
    or a
    ret z
    inc hl
    ld c,(hl)
    inc hl
    push hl
    push bc
    ld b,0
    call note_on
    ld a,0
    ld c,3
    call psg_set_vol
    pop bc
    ld b,c
    call wait_frames
    pop hl
    jr play_seq

snd_chest:
    ld hl,seq_chest
    call play_seq
    ld b,0
    call note_off
    ret
snd_levelup:
    ld hl,seq_level
    call play_seq
    ld b,0
    call note_off
    ret
snd_victory:
    ld hl,seq_vict
    call play_seq
    ld b,0
    call note_off
    ret
seq_chest: db 72,6, 76,6, 79,10, 0
seq_level: db 60,5, 64,5, 67,5, 72,12, 0
seq_vict:  db 67,5, 67,5, 67,5, 72,14, 0

; ---------------- songs ----------------
song_tbl:
    db 9
    dw s_town_1, s_town_2
    db 10
    dw s_dun_1, s_dun_2
    db 6
    dw s_bat_1, s_bat_2
    db 8
    dw s_title_1, s_title_2
    db 9
    dw s_end_1, s_end_2
    db 11
    dw s_over_1, s_over_2
; town: gentle C major
s_town_1:
    db 71,4, 74,4, 71,4, 67,4, 69,4, 72,4, 69,4, 66,4
    db 67,4, 71,4, 74,4, 76,4, 74,12, 0,4, 71,4, 74,4
    db 71,4, 67,4, 67,4, 71,4, 64,4, 67,4, 69,4, 72,2
    db 71,2, 69,4, 66,4, 67,12, 0,4, 72,4, 76,4, 74,4
    db 72,4, 71,4, 74,4, 72,4, 71,4, 69,4, 72,4, 71,4
    db 69,4, 71,4, 69,2, 67,2, 66,4, 62,4, 67,4, 71,4
    db 74,4, 76,2, 74,2, 72,4, 69,4, 66,4, 69,4, 67,4
    db 71,4, 69,4, 66,4, 67,12, 0,4
    db $FF
s_town_2:
    db 55,4, 50,4, 47,4, 50,4, 57,4, 48,4, 50,4, 57,4
    db 55,4, 47,4, 50,4, 47,4, 50,4, 57,4, 54,4, 50,4
    db 55,4, 50,4, 47,4, 50,4, 52,4, 47,4, 55,4, 47,4
    db 57,4, 52,4, 50,4, 57,4, 55,4, 50,4, 55,4, 0,4
    db 48,4, 55,4, 52,4, 55,4, 47,4, 50,4, 55,4, 47,4
    db 57,4, 48,4, 52,4, 57,4, 50,4, 57,4, 50,4, 54,4
    db 55,4, 50,4, 47,4, 55,4, 48,4, 55,4, 57,4, 52,4
    db 50,4, 47,4, 50,4, 57,4, 55,4, 50,4, 55,8
    db $FF
; dungeon: sparse A minor
s_dun_1:
    db 0,8, 64,4, 67,4, 66,6, 63,2, 64,8, 0,8, 67,4
    db 71,4, 70,6, 69,2, 67,8, 0,4, 71,4, 72,4, 69,4
    db 67,4, 66,4, 64,4, 0,4, 66,4, 63,4, 59,4, 63,4
    db 64,12, 0,4, 71,4, 76,4, 74,4, 72,4, 71,8, 0,4
    db 69,4, 67,4, 66,4, 64,4, 66,4, 63,12, 0,4, 0,4
    db 64,4, 67,4, 71,4, 72,4, 69,4, 66,4, 63,4, 64,4
    db 67,4, 66,4, 63,4, 64,8, 0,8
    db $FF
s_dun_2:
    db 52,4, 0,4, 52,2, 55,2, 54,4, 52,4, 0,4, 47,4
    db 0,4, 52,4, 0,4, 52,2, 55,2, 54,4, 48,4, 0,4
    db 47,4, 0,4, 55,4, 0,4, 57,4, 0,4, 52,4, 0,4
    db 48,4, 0,4, 47,4, 0,4, 54,4, 47,4, 52,4, 47,2
    db 55,2, 52,4, 0,4, 52,4, 47,4, 55,4, 52,4, 51,4
    db 47,4, 54,4, 47,4, 48,4, 55,4, 57,4, 52,4, 47,4
    db 54,4, 47,4, 0,4, 52,4, 0,4, 52,2, 55,2, 54,4
    db 57,4, 52,4, 47,4, 54,4, 48,4, 57,4, 47,4, 54,4
    db 52,8, 0,8
    db $FF
; battle: driving
s_bat_1:
    db 62,2, 62,2, 69,2, 69,2, 70,2, 69,2, 67,2, 65,2
    db 64,2, 64,2, 69,2, 69,2, 67,2, 65,2, 64,2, 61,2
    db 62,2, 62,2, 69,2, 69,2, 74,2, 72,2, 70,2, 69,2
    db 67,2, 69,2, 70,2, 67,2, 69,4, 0,4, 62,2, 62,2
    db 69,2, 69,2, 70,2, 69,2, 67,2, 65,2, 67,2, 67,2
    db 74,2, 74,2, 72,2, 70,2, 69,2, 67,2, 65,2, 67,2
    db 69,2, 74,2, 73,2, 69,2, 64,2, 67,2, 62,4, 69,2
    db 65,2, 62,4, 0,4, 74,2, 72,2, 74,2, 76,2, 77,4
    db 74,4, 72,2, 70,2, 72,2, 74,2, 76,4, 72,4, 70,2
    db 69,2, 70,2, 72,2, 74,4, 70,4, 69,2, 68,2, 69,2
    db 71,2, 73,4, 69,4, 62,2, 62,2, 69,2, 69,2, 65,2
    db 65,2, 62,2, 62,2, 70,2, 70,2, 67,2, 67,2, 64,2
    db 64,2, 61,2, 61,2, 62,2, 65,2, 69,2, 74,2, 73,2
    db 69,2, 64,2, 67,2, 62,4, 69,2, 62,2, 62,4, 0,4
    db $FF
s_bat_2:
    db 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2
    db 57,2, 57,2, 49,2, 57,2, 57,2, 57,2, 49,2, 57,2
    db 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2
    db 55,2, 55,2, 46,2, 55,2, 57,2, 57,2, 52,2, 49,2
    db 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 50,2
    db 55,2, 55,2, 50,2, 55,2, 55,2, 55,2, 50,2, 55,2
    db 50,2, 50,2, 53,2, 53,2, 57,2, 57,2, 52,2, 49,2
    db 50,2, 50,2, 57,2, 53,2, 50,4, 0,4, 50,2, 50,2
    db 53,2, 57,2, 50,2, 50,2, 53,2, 57,2, 48,2, 48,2
    db 52,2, 55,2, 48,2, 48,2, 52,2, 55,2, 46,2, 46,2
    db 50,2, 46,2, 46,2, 46,2, 50,2, 46,2, 57,2, 57,2
    db 49,2, 57,2, 57,2, 57,2, 52,2, 49,2, 50,2, 50,2
    db 50,2, 50,2, 50,2, 50,2, 50,2, 50,2, 55,2, 55,2
    db 46,2, 55,2, 57,2, 57,2, 52,2, 49,2, 50,2, 53,2
    db 57,2, 53,2, 57,2, 52,2, 49,2, 52,2, 50,2, 50,2
    db 57,2, 53,2, 50,4, 0,4
    db $FF
; title (placeholder - to be replaced by composed song)
s_title_1:
    db 67,4, 72,6, 71,2, 72,2, 74,2, 76,6, 74,2, 72,4
    db 69,4, 65,4, 69,4, 72,4, 71,2, 69,2, 67,12, 0,4
    db 67,4, 72,6, 71,2, 72,2, 74,2, 76,4, 79,4, 76,4
    db 72,4, 74,6, 72,2, 71,4, 69,2, 71,2, 72,12, 0,4
    db 77,6, 76,2, 74,4, 72,4, 76,6, 74,2, 72,4, 67,4
    db 69,4, 74,4, 72,4, 71,4, 72,8, 76,4, 79,4, 77,6
    db 76,2, 74,4, 77,4, 76,6, 74,2, 72,4, 71,4, 69,4
    db 72,4, 74,6, 71,2, 72,12, 0,4
    db $FF
s_title_2:
    db 48,4, 55,2, 55,2, 48,4, 55,4, 47,4, 55,4, 57,4
    db 52,4, 53,4, 48,2, 48,2, 53,4, 57,4, 55,4, 50,4
    db 55,2, 57,2, 47,2, 55,2, 48,4, 55,2, 55,2, 48,4
    db 55,4, 52,4, 47,4, 57,4, 52,4, 50,4, 57,4, 55,4
    db 50,4, 48,4, 55,4, 48,2, 50,2, 52,2, 55,2, 53,4
    db 48,2, 48,2, 53,4, 57,4, 52,4, 48,2, 48,2, 52,4
    db 55,4, 50,4, 53,4, 55,4, 47,4, 48,4, 55,4, 48,4
    db 55,4, 53,4, 57,4, 50,4, 57,4, 55,4, 47,4, 52,4
    db 55,4, 57,4, 52,4, 55,4, 50,4, 48,4, 55,2, 55,2
    db 48,8
    db $FF
; ending (placeholder)
s_end_1:
    db 69,6, 70,2, 72,4, 65,4, 67,6, 69,2, 70,4, 67,4
    db 65,4, 69,4, 74,4, 72,4, 67,12, 0,4, 70,6, 72,2
    db 74,4, 70,4, 69,6, 70,2, 72,4, 69,4, 67,4, 70,4
    db 69,4, 67,4, 65,12, 0,4, 74,6, 76,2, 77,4, 74,4
    db 72,6, 74,2, 76,4, 72,4, 70,6, 72,2, 74,4, 70,4
    db 72,12, 0,4, 69,4, 72,4, 77,4, 76,2, 74,2, 74,6
    db 72,2, 70,4, 67,4, 69,4, 65,4, 67,4, 64,4, 65,12
    db 60,4
    db $FF
s_end_2:
    db 53,4, 48,4, 57,4, 48,4, 52,4, 48,4, 55,4, 48,4
    db 50,4, 57,4, 53,4, 57,4, 48,4, 55,4, 52,4, 55,4
    db 46,4, 50,4, 53,4, 46,4, 57,4, 48,4, 53,4, 57,4
    db 55,4, 46,4, 48,4, 55,4, 53,4, 48,4, 53,4, 0,4
    db 50,4, 57,4, 53,4, 57,4, 57,4, 52,4, 48,4, 52,4
    db 46,4, 50,4, 53,4, 46,4, 48,4, 55,4, 52,4, 55,4
    db 53,4, 48,4, 57,4, 48,4, 46,4, 53,4, 55,4, 50,4
    db 48,4, 57,4, 48,4, 55,4, 53,4, 48,4, 53,8
    db $FF
; game over (placeholder, short)
s_over_1:
    db 64,6, 62,2, 60,4, 59,4, 60,6, 59,2, 57,4, 56,4
    db 57,4, 59,4, 60,4, 59,2, 57,2, 57,12, 0,4
    db $FF
s_over_2:
    db 57,8, 55,8, 53,8, 52,8, 50,8, 52,8, 57,12, 0,4
    db $FF

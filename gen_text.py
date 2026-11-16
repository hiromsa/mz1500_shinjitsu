#!/usr/bin/env python3
# SHINJITSU NO TOU - text strings (MZ display codes, $FF terminated)
KANA = {
'ア':0xA3,'イ':0x85,'ウ':0xA4,'エ':0xA5,'オ':0xA6,
'カ':0x94,'キ':0x87,'ク':0x88,'ケ':0x9C,'コ':0x82,
'サ':0x98,'シ':0x84,'ス':0x92,'セ':0x90,'ソ':0x83,
'タ':0x91,'チ':0x81,'ツ':0x9A,'テ':0x97,'ト':0x93,
'ナ':0x95,'ニ':0x89,'ネ':0xAF,'ノ':0x8B,
'ハ':0x86,'ヒ':0x96,'フ':0xA2,'ヘ':0xAB,'ホ':0xAA,
'マ':0x8A,'ミ':0x8E,'ム':0xB0,'メ':0xAD,'モ':0x8D,
'ヤ':0xA7,'ユ':0xA8,'ヨ':0xA9,
'ラ':0xB4,'リ':0x8C,'ル':0xAE,'レ':0xAC,'ロ':0x9B,
'ワ':0xA0,'ヲ':0xA1,'ン':0x99,
'ァ':0x9E,'ィ':0xB2,'ゥ':0xB6,'ェ':0xBA,'ォ':0xBE,
'ャ':0x9F,'ュ':0xB3,'ョ':0xB7,'ッ':0xBB,
'ー':0xBF,'、':0xB5,'。':0xBD,'「':0x9D,'」':0xB1,
'円':0xDC,'金':0xD5,'年':0xD8,'日':0xD0,'時':0xD9,'分':0xDA,'秒':0xDB,
}
DAKU = {'ガ':'カ','ギ':'キ','グ':'ク','ゲ':'ケ','ゴ':'コ',
'ザ':'サ','ジ':'シ','ズ':'ス','ゼ':'セ','ゾ':'ソ',
'ダ':'タ','ヂ':'チ','ヅ':'ツ','デ':'テ','ド':'ト',
'バ':'ハ','ビ':'ヒ','ブ':'フ','ベ':'ヘ','ボ':'ホ'}
HANDAKU = {'パ':'ハ','ピ':'ヒ','プ':'フ','ペ':'ヘ','ポ':'ホ'}
def enc(s):
    out=[]
    for ch in s:
        if ch in DAKU: out += [KANA[DAKU[ch]], 0xBC]
        elif ch in HANDAKU: out += [KANA[HANDAKU[ch]], 0xB8]
        elif ch in KANA: out.append(KANA[ch])
        elif 'A'<=ch<='Z': out.append(ord(ch)-ord('A')+1)
        elif '0'<=ch<='9': out.append(ord(ch)-ord('0')+0x20)
        elif ch==' ': out.append(0)
        elif ch=='.': out.append(0x2E)
        elif ch==':': out.append(0x4F)
        elif ch=='!': out.append(0x61)
        elif ch=='?': out.append(0x49)
        elif ch=='-': out.append(0x2A)
        elif ch=='/': out.append(0x2D)
        elif ch=='+': out.append(0x6A)
        elif ch=='*': out.append(0x6B)
        elif ch=='>': out.append(0x57)
        elif ch=='<': out.append(0x51)
        elif ch=='=': out.append(0x2B)
        elif ch=='(': out.append(0x68)
        elif ch==')': out.append(0x69)
        elif ch=='%': out.append(0x64)
        else: raise ValueError(f"no code for {ch!r} in {s!r}")
    return out

STRINGS = {
"title": "SHINJITSU NO TOU",
"subtitle": "- シンジツノショ ヲ トリモドセ -",
"push": "PUSH SPACE",
"make_title": "キャラクター ヲ ツクロウ",
"q_type": "タイプ ヲ エランデ クダサイ",
"type1": "センシ",
"type2": "ドロボウ",
"type3": "ショウニン",
"type_desc1": "コウゲキ ト タイリョク ガ タカイ",
"type_desc2": "バランス ガ ヨク テクニック ガ ウマイ",
"type_desc3": "ショジキン ガ オオイ",
"town_name": "マチ",
"m_hospital": "ビョウイン",
"m_inn": "ヤドヤ",
"m_temple": "ジイン",
"m_shop": "ミセ",
"m_tower": "トウヘ イク",
"hosp_wel": "ビョウイン: カイフク 100G / ヤクソウ 50G",
"hosp_heal": "ゼンカイフク シマス (100G)",
"hosp_potion": "ヤクソウ ヲ カウ (50G)",
"hosp_lim": "LIM ヲ フヤス (300G)",
"bye": "モドル",
"inn_wel": "ヤドヤ: スコシ カイフク (20G)",
"inn_do": "ヤスム (20G)",
"temp_wel": "ジイン: レベルアップ デキマス!",
"temp_do": "レベルアップ スル",
"temp_notyet": "マダ ケイケンチ ガ タリナイ",
"shop_wel": "ミセ: ブキ ト ボウグ",
"healed": "スッカリ ヨク ナリマシタ!",
"no_money": "オカネ ガ タリマセン!",
"got_potion": "ヤクソウ ヲ テニイレタ!",
"lim_up": "LIM ガ 2 アガッタ!",
"leveled": "レベル ガ アガッタ!",
"rested": "スコシ カイフク シタ",
"hud_hp": "HP",
"hud_lv": "LV",
"hud_g": "G",
"hud_floor": "F",
"encounter": "モンスター ガ アラワレタ!",
"cmd_fight": "タタカウ",
"cmd_run": "ニゲル",
"cmd_talk": "ハナス",
"cmd_item": "ドウグ",
"you_hit": "ノ コウゲキ!",
"ene_hit": "ノ コウゲキ!",
"dmg": "ノ ダメージ!",
"miss": "ミス!",
"you_died": "チカラ ツキタ...",
"wake": "メガ サメルト マチニ イタ。キン ノ ハンブン ヲ ウシナッタ",
"win": "タオシタ!",
"got_exp": "ケイケンチ ト オカネ ヲ エタ",
"ran_ok": "ニゲキッタ! ケイケンチ スコシ ヘッタ",
"ran_ng": "ニゲラレナイ!",
"talk_ok": "ハナシ ガ ツウジタ! タタカイ ハ オワッタ",
"talk_ng": "ハナシ ハ ツウジナイ!",
"potion_use": "ヤクソウ ヲ ツカッタ! HP カイフク",
"no_potion": "ヤクソウ ガ ナイ!",
"chest": "タカラバコ ダ!",
"chest_gold": "G テニイレタ!",
"chest_potion": "ヤクソウ ダッタ!",
"chest_feather": "モドルノハネ ダッタ!",
"chest_lim": "チカラノミ ダッタ! LIM+2",
"feather_use": "モドルノハネ! マチニ モドッタ",
"no_feather": "ハネ ガ ナイ!",
"spirit1": "セイレイ: ヨク キタ、ユウシャヨ。",
"spirit2": "コレ ハ セイケン。 ウケトレバ ケイケンチ ハ ハンブン ニ ナル。",
"spirit3": "ソレデモ ウケト リマスカ?",
"yes": "ハイ",
"no": "イイエ",
"got_sword": "セイケン ヲ テニイレタ! コウゲキ+6",
"spirit_no": "ソウカ... ヒツヨウニ ナッタラ マタイラッシャイ",
"spirit_done": "セイケン ハ モウ ナイ。 ダイリザード ヲ タオセ!",
"need_swords": "セイケン ガ タリナイ! ダメージ ガ ツウジナイ",
"boss_name": "ダイリザード",
"boss_appear": "ダイリザード ガ アラワレタ!",
"book": "シンジツノショ ヲ テニイレタ!!",
"end1": "ダイリザード ヲ タオシ、シンジツノショ ヲ",
"end2": "トリモドシタ! ヒメ ノ ノロイ ハ トケ、",
"end3": "クニ ニ ヘイワ ガ モドッタ。",
"end4": "THE END",
"thanks": "THANK YOU FOR PLAYING!",
"over": "GAME OVER",
"start_from": "SPACE: スタート",
"howto1": "ヤジルシ: イドウ / Z: ケッテイ",
"howto2": "SPACE: ドウグ / X: マチヘ モドル?",
"item_menu": "ドウグ: Z=ヤクソウ X=ハネ",
"floor_in": "トウ ニ ハイッタ",
"buy": "カウ",
"sell_none": "ウレル モノ ハ ナイ",
"atk": "ATK",
"def": "DEF",
"exp": "EXP",
"next": "NEXT",
"sword": "セイケン",
"have": "コ",
"weapon": "ブキ",
"armor": "ボウグ",
"ene0": "スライム",
"ene1": "コウモリ",
"ene2": "ヘビ",
"ene3": "オオカミ",
"ene4": "ゾンビ",
"ene5": "ゴブリン",
"ene6": "ドロボウ",
"ene7": "アクマ",
"ene8": "キングバット",
"ene9": "ドラゴン",
"ene10": "キュウケツキ",
"ene11": "ダークナイト",
"wpn0": "スデ",
"wpn1": "コンボウ",
"wpn2": "ドウノツルギ",
"wpn3": "テツノツルギ",
"wpn4": "ハガネノツルギ",
"wpn5": "ユウシャノツルギ",
"arm0": "フク",
"arm1": "キノフク",
"arm2": "カワヨロイ",
"arm3": "テツヨロイ",
"arm4": "ハガネヨロイ",
"equipped": "ソウビ シタ!",
"discard": "フルイ ノ ハ ステタ",
"temple_wel2": "ケイケンチ ヲ ミテ アゲヨウ",
"shop_w_wpn": "ブキ ヲ カウ",
"shop_w_arm": "ボウグ ヲ カウ",
"inn_full": "モウ カイフク シテイル",
"hosp_full": "ケガ ハ シテイナイ",
"town_wel": "マチ ニ ツイタ",
"spirit_ask2": "Z: ハイ / X: イイエ",
"boss_book": "タカラバコ ニ シンジツノショ!",
"clear_time": "クリア オメデトウ!",
}
out=["; generated by gen_text.py"]
for name,s in STRINGS.items():
    codes = enc(s)
    out.append(f"str_{name}: DB " + ",".join(f"${c:02X}" for c in codes) + ",$FF")
with open("text.inc","w") as fh: fh.write("\n".join(out)+"\n")
print("text.inc:", len(STRINGS), "strings")

#!/usr/bin/env python3
# Convert songs_mml.txt (MML subset) into sound.asm song data.
# Game format: (midi, len) pairs, len units: whole=16, quarter=4.
# Tempo byte = round(900 / BPM).
import re, sys

SEMI = {'c':0,'d':2,'e':4,'f':5,'g':7,'a':9,'b':11}

def parse_mml(s):
    notes = []  # (midi or 0, units)
    octv = 4
    deflen = 4
    i = 0
    s = s.replace('|', ' ').lower()
    while i < len(s):
        ch = s[i]
        if ch in ' \t':
            i += 1; continue
        if ch == 'o':
            octv = int(s[i+1]); i += 2; continue
        if ch == '>':
            octv += 1; i += 1; continue
        if ch == '<':
            octv -= 1; i += 1; continue
        if ch == 'l':
            j = i+1
            while j < len(s) and s[j].isdigit(): j += 1
            deflen = int(s[i+1:j]); i = j; continue
        if ch in SEMI or ch == 'r':
            j = i+1
            acc = 0
            if ch != 'r' and j < len(s) and s[j] in '+#':
                acc = 1; j += 1
            elif ch != 'r' and j < len(s) and s[j] == '-':
                acc = -1; j += 1
            k = j
            while k < len(s) and s[k].isdigit(): k += 1
            ln = int(s[j:k]) if k > j else deflen
            units = 16.0 / ln
            dots = 0
            while k < len(s) and s[k] == '.':
                dots += 1; k += 1
            units *= (2 - 0.5 ** dots) if dots else 1
            assert units == int(units), f"non-integer units {units} at {s[max(0,i-6):i+8]!r}"
            units = int(units)
            if ch == 'r':
                notes.append((0, units))
            else:
                midi = (octv + 1) * 12 + SEMI[ch] + acc
                # SN76489 divider is 10-bit: midi < 46 needs divider > 1023
                # and cannot sound as written; transpose up an octave.
                while midi < 46:
                    midi += 12
                notes.append((midi, units))
            i = k; continue
        raise ValueError(f"unexpected char {ch!r} at {i} in {s!r}")
    return notes

def main():
    text = open('songs_mml.txt').read()
    songs = {}
    cur = None
    for line in text.splitlines():
        m = re.match(r'(\w+) \(BPM=(\d+)\)', line)
        if m:
            cur = m.group(1); songs[cur] = {'bpm': int(m.group(2))}
        elif line.startswith('MELODY:'):
            songs[cur]['mel'] = parse_mml(line[7:])
        elif line.startswith('BASS:'):
            songs[cur]['bass'] = parse_mml(line[5:])
    order = ['OPENING', 'TOWN', 'DUNGEON', 'BATTLE', 'ENDING', 'GAMEOVER']
    labels = {'OPENING': ('s_title_1', 's_title_2'), 'TOWN': ('s_town_1', 's_town_2'),
              'DUNGEON': ('s_dun_1', 's_dun_2'), 'BATTLE': ('s_bat_1', 's_bat_2'),
              'ENDING': ('s_end_1', 's_end_2'), 'GAMEOVER': ('s_over_1', 's_over_2')}
    out = {}
    for name in order:
        sg = songs[name]
        tm = sum(u for _, u in sg['mel']); tb = sum(u for _, u in sg['bass'])
        allnotes = [n for n, _ in sg['mel'] + sg['bass'] if n]
        tempo = round(900 / sg['bpm'])
        print(f"{name}: BPM {sg['bpm']} -> tempo {tempo}; mel {len(sg['mel'])} notes/{tm} units, "
              f"bass {len(sg['bass'])}/{tb} units; range {min(allnotes)}..{max(allnotes)}; match={tm==tb}")
        assert tm == tb, f"{name}: channel length mismatch"
        assert min(allnotes) >= 36 and max(allnotes) <= 84, f"{name}: note out of range"
        for ch_key in ('mel', 'bass'):
            lbl = labels[name][0 if ch_key == 'mel' else 1]
            lines = [f"{lbl}:"]
            pairs = sg[ch_key]
            for i in range(0, len(pairs), 8):
                chunk = pairs[i:i+8]
                lines.append("    db " + ", ".join(f"{n},{u}" for n, u in chunk))
            lines.append("    db $FF")
            out[lbl] = "\n".join(lines)
        out[f"TEMPO_{name}"] = tempo
    # patch sound.asm
    src = open('sound.asm').read()
    for lbl, block in out.items():
        if lbl.startswith('TEMPO'): continue
        pat = re.compile(re.escape(lbl) + r":\n(?:    db .*\n)+")
        assert pat.search(src), lbl
        src = pat.sub(block + "\n", src, count=1)
    # tempos in song_tbl order: town, dun, bat, title, end, over
    tempos = [out['TEMPO_TOWN'], out['TEMPO_DUNGEON'], out['TEMPO_BATTLE'],
              out['TEMPO_OPENING'], out['TEMPO_ENDING'], out['TEMPO_GAMEOVER']]
    tbl_pat = re.compile(r"song_tbl:\n(?:    db \d+\n    dw \w+, \w+\n)+")
    entries = [('s_town_1','s_town_2'), ('s_dun_1','s_dun_2'), ('s_bat_1','s_bat_2'),
               ('s_title_1','s_title_2'), ('s_end_1','s_end_2'), ('s_over_1','s_over_2')]
    tbl = "song_tbl:\n" + "".join(f"    db {t}\n    dw {a}, {b}\n" for t, (a, b) in zip(tempos, entries))
    assert tbl_pat.search(src)
    src = tbl_pat.sub(tbl, src, count=1)
    open('sound.asm', 'w').write(src)
    print("sound.asm updated")

if __name__ == '__main__':
    main()

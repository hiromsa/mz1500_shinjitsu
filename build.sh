#!/bin/bash
set -e
cd "$(dirname "$0")"
python3 gen_maps.py
python3 gen_tiles.py
python3 gen_text.py
python3 gen_notes.py
~/tools/bin/sjasmplus lizard.asm --raw=LIZARD.bin --lst=LIZARD.lst --sym=LIZARD.sym
python3 - << 'EOF'
import struct
body=open('LIZARD.bin','rb').read()
name=b'SHINJITSU\x0d'+b'\x00'*8
hdr=bytes([1])+name[:17]+struct.pack('<HHH',len(body),0x1200,0x1200)+bytes(128-1-17-6)
open('SHINJITSU.mzt','wb').write(hdr+body)
print('SHINJITSU.mzt', len(body),'bytes body')
EOF

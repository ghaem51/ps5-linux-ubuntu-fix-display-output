#!/usr/bin/env python3
"""Capture the local monitor identity without distributing it in Git."""
from pathlib import Path
import sys

connector = Path(sys.argv[1] if len(sys.argv) > 1 else '/sys/class/drm/card0-DP-1')
b = (connector/'edid').read_bytes()
if len(b) < 256 or len(b) % 128 or b[:8] != bytes.fromhex('00ffffffffffff00'):
    raise SystemExit('Invalid or incomplete EDID')
if any(sum(b[i:i+128]) % 256 for i in range(0, len(b), 128)):
    raise SystemExit('Invalid EDID checksum')
if b'DELL G2724D' not in b:
    raise SystemExit('Only Dell G2724D is validated by this project')
target = False
for offset in range(128, len(b), 128):
    block = b[offset:offset+128]
    if block[0] != 2 or not 4 <= block[2] <= 109: continue
    for start in range(block[2], 110, 18):
        d = block[start:start+18]
        if not int.from_bytes(d[:2], 'little'): continue
        clock = int.from_bytes(d[:2], 'little')*10
        x=d[2]+((d[4]>>4)<<8); xb=d[3]+((d[4]&15)<<8)
        y=d[5]+((d[7]>>4)<<8); yb=d[6]+((d[7]&15)<<8)
        hf=d[8]+((d[11]>>6)<<8); hs=d[9]+(((d[11]>>4)&3)<<8)
        vf=(d[10]>>4)+(((d[11]>>2)&3)<<4); vs=(d[10]&15)+((d[11]&3)<<4)
        if (clock,x,x+hf,x+hf+hs,x+xb,y,y+vf,y+vf+vs,y+yb,d[17]) == (497750,2560,2608,2640,2720,1440,1443,1448,1525,0x1a): target=True
if not target: raise SystemExit('Exact validated 1440p120 timing is missing')
destination = Path(__file__).resolve().parent/'snapshots/monitor.edid'
destination.parent.mkdir(parents=True, exist_ok=True)
if destination.exists() and destination.read_bytes() != b:
    raise SystemExit('A different monitor snapshot already exists; review before replacing it')
destination.write_bytes(b)
print('Local Dell EDID saved. This file is ignored by Git; do not publish it.')

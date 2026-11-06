#!/usr/bin/env python3
"""Print base and CTA detailed timings without third-party dependencies."""
from pathlib import Path
import sys

b = Path(sys.argv[1]).read_bytes()
if len(b) < 128 or len(b) % 128 or b[:8] != bytes.fromhex('00ffffffffffff00'):
    raise SystemExit('Invalid EDID length or header')
for offset in range(0, len(b), 128):
    if sum(b[offset:offset + 128]) % 256:
        raise SystemExit(f'Invalid checksum at block {offset // 128}')
def timing(d):
    clock = int.from_bytes(d[:2], 'little') * 10000
    if not clock:
        if d[3] == 0xfc:
            print('Monitor:', d[5:18].decode('ascii', errors='replace').strip())
        return
    x, xb = d[2] + ((d[4] >> 4) << 8), d[3] + ((d[4] & 15) << 8)
    y, yb = d[5] + ((d[7] >> 4) << 8), d[6] + ((d[7] & 15) << 8)
    if not (x + xb) * (y + yb):
        raise SystemExit('Invalid timing totals')
    refresh = clock / ((x + xb) * (y + yb))
    print(f'Detailed timing: {x}x{y} {refresh:.3f} Hz, pixel clock {clock / 1e6:.3f} MHz')
for offset in range(54, 126, 18):
    timing(b[offset:offset + 18])
for offset in range(128, len(b), 128):
    block = b[offset:offset + 128]
    if block[0] == 2 and 4 <= block[2] <= 109:
        for start in range(block[2], 110, 18):
            timing(block[start:start + 18])
print('These are EDID timings; driver-accepted modes must be checked with modetest.')

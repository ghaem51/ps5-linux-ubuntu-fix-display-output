#!/usr/bin/env python3
"""Check the live PS5 ABI and emit compile-time layout assertions."""
from pathlib import Path
import struct

blob = Path('/sys/kernel/btf/vmlinux').read_bytes()
magic, version, flags, hdr, to, tl, so, sl = struct.unpack_from('<HBBIIIII', blob)
if magic != 0xeb9f or version != 1:
    raise SystemExit('Unsupported kernel BTF')
strings = blob[hdr + so:hdr + so + sl]
def name(offset):
    return strings[offset:strings.index(0, offset)].decode()
types = [None]
pos, end = hdr + to, hdr + to + tl
while pos < end:
    no, info, target = struct.unpack_from('<III', blob, pos)
    pos += 12
    kind, count = (info >> 24) & 31, info & 65535
    sizes = {1: 4, 3: 12, 4: count * 12, 5: count * 12,
             6: count * 8, 13: count * 8, 14: 4, 15: count * 12,
             17: 4, 19: count * 12}
    if not 1 <= kind <= 19:
        raise SystemExit(f'Unsupported BTF kind {kind}')
    length = sizes.get(kind, 0)
    types.append((name(no), kind, target, count, blob[pos:pos + length]))
    pos += length
def describe(tid):
    if not tid:
        return 'void'
    text, kind, target, _, _ = types[tid]
    if kind == 2:
        return describe(target) + '*'
    if kind == 10:
        return 'const ' + describe(target)
    if kind in (8, 9, 11, 18):
        return describe(target)
    return text
functions = [t for t in types[1:] if t[1] == 12 and t[0] == 'isHdmiModeValid']
if len(functions) != 1:
    raise SystemExit('Cannot uniquely identify isHdmiModeValid')
proto = types[functions[0][2]]
args = [describe(struct.unpack_from('<II', proto[4], n * 8)[1]) for n in range(proto[3])]
expected = ['const drm_display_mode*', 'const drm_display_info*', 'int']
if args != expected or describe(proto[2]) not in ('_Bool', 'bool'):
    raise SystemExit(f'Unsupported live function prototype: {args}, return {describe(proto[2])}')
checks = ['/* Generated from live kernel BTF; do not edit. */']
for struct_name in ('drm_display_mode', 'drm_display_info', 'drm_hdmi_info', 'drm_scdc', 'drm_scrambling'):
    matches = [t for t in types[1:] if t[0] == struct_name and t[1] == 4]
    if not matches:
        raise SystemExit(f'Missing BTF structure: {struct_name}')
    layouts = {(t[2], t[4]) for t in matches}
    if len(layouts) != 1:
        raise SystemExit(f'Ambiguous BTF structure: {struct_name}')
    t = matches[0]
    checks.append(f'static_assert(sizeof(struct {struct_name}) == {t[2]});')
    for n in range(t[3]):
        no, tid, bits = struct.unpack_from('<III', t[4], n * 12)
        member = name(no)
        if not member or bits >> 24:
            continue
        checks.append(f'static_assert(offsetof(struct {struct_name}, {member}) == {bits // 8});')
Path(__file__).with_name('live-layout.h').write_text('\n'.join(checks) + '\n')
print('Live BTF: bool isHdmiModeValid(const mode *, const info *, int); structure assertions generated.')

#!/usr/bin/env python3
"""Validate the built observer against installed kernel module metadata."""
from pathlib import Path
import platform
import re
import subprocess
import hashlib

root = Path(__file__).resolve().parent
release = platform.release()
module = root / 'ps5_verde_1440.ko'
if (root / 'build-btf.sha256').read_text().strip() != hashlib.sha256(Path('/sys/kernel/btf/vmlinux').read_bytes()).hexdigest():
    raise SystemExit('Live kernel BTF differs from build-time kernel; rebuild first.')
def output(*args):
    return subprocess.check_output(args, text=True)
reference = next(Path(f'/lib/modules/{release}/kernel').rglob('*.ko'))
def section_size(path):
    match = re.search(r'\.gnu\.linkonce\.this_module\s+\S+\s+\S+\s+\S+\s+([0-9a-fA-F]+)', output('readelf', '-SW', str(path)))
    if not match:
        raise SystemExit('Missing module structure section')
    return int(match[1], 16)
if section_size(module) != section_size(reference):
    raise SystemExit('Module structure size differs from installed kernel')
if output('modinfo', '-F', 'vermagic', str(module)) != output('modinfo', '-F', 'vermagic', str(reference)):
    raise SystemExit('Module vermagic differs from installed kernel')
symbols = {}
for line in Path(f'/lib/modules/{release}/build/Module.symvers').read_text().splitlines():
    crc, name, *_ = line.split()
    symbols[name] = int(crc, 16)
versions = output('modprobe', '--show-modversions', str(module))
if not versions.strip():
    raise SystemExit('Missing module symbol versions')
for line in versions.splitlines():
    crc, name = line.split()
    if symbols.get(name) != int(crc, 16):
        raise SystemExit(f'Imported symbol version mismatch: {name}')
print('Module vermagic, structure size, and imported symbol CRCs match installed kernel.')

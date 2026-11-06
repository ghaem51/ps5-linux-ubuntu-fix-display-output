#!/usr/bin/env bash
# Provide a native objtool without modifying the installed kernel headers.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KVER=$(uname -r)
BASE=${KVER%%[-+]*}
[[ $BASE =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
INSTALLED=/lib/modules/$KVER/build/tools/objtool/objtool
if python3 - "$INSTALLED" <<'PY'
from pathlib import Path
import sys
try:
    b = Path(sys.argv[1]).read_bytes()
except OSError:
    raise SystemExit(1)
raise SystemExit(0 if b[:4] == b'\x7fELF' and b[5] == 1 and int.from_bytes(b[18:20], 'little') == 62 else 1)
PY
then
    printf '%s\n' "$INSTALLED"
    exit 0
fi
CACHE=$ROOT/.build
mkdir -p "$CACHE"
SRC=${KERNEL_SOURCE:-$CACHE/linux-$BASE}
if [[ ! -f $SRC/tools/objtool/Makefile ]]; then
    [[ -z ${KERNEL_SOURCE:-} ]] || { echo 'KERNEL_SOURCE lacks objtool sources.' >&2; exit 1; }
    URL=https://cdn.kernel.org/pub/linux/kernel/v${BASE%%.*}.x
    curl -fL --retry 2 "$URL/linux-$BASE.tar.xz" -o "$CACHE/linux.tar.xz" >&2
    curl -fL --retry 2 "$URL/sha256sums.asc" -o "$CACHE/sha256sums.asc" >&2
    python3 - "$CACHE" "$BASE" <<'PY'
from pathlib import Path
import hashlib, sys
p = Path(sys.argv[1]); filename = f'linux-{sys.argv[2]}.tar.xz'
expected = [line.split()[0] for line in (p/'sha256sums.asc').read_text().splitlines() if len(line.split()) == 2 and line.split()[1].lstrip('*') == filename]
h = hashlib.sha256()
with (p/'linux.tar.xz').open('rb') as f:
    for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
if len(expected) != 1 or h.hexdigest() != expected[0]: raise SystemExit('Kernel archive checksum mismatch')
PY
    tar -xJf "$CACHE/linux.tar.xz" -C "$CACHE"
fi
[[ $(make -s -C "$SRC" kernelversion) == "$BASE" ]] || { echo 'Kernel source version mismatch.' >&2; exit 1; }
mkdir -p "$CACHE/objtool"
make -C "$SRC/tools/objtool" O="$CACHE/objtool/" -j"${JOBS:-4}" >&2
printf '%s\n' "$CACHE/objtool/objtool"

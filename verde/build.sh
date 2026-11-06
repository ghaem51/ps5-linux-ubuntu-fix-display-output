#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 "$ROOT/check-abi.py"
python3 "$ROOT/test-policy.py"
CC=${CC:-gcc}
if command -v gcc-14 >/dev/null && [[ $CC == gcc ]]; then CC=gcc-14; fi
KBUILD=/lib/modules/$(uname -r)/build
NATIVE_OBJTOOL=${NATIVE_OBJTOOL:-$(bash "$ROOT/native-objtool.sh")}
[[ -x $NATIVE_OBJTOOL ]] || { echo 'Missing native objtool.'; exit 1; }
make -C "$KBUILD" M="$ROOT" CC="$CC" "objtool=$NATIVE_OBJTOOL" modules
sha256sum /sys/kernel/btf/vmlinux | cut -d ' ' -f 1 > "$ROOT/build-btf.sha256"
python3 "$ROOT/verify.py"

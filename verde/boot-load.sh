#!/usr/bin/env bash
# Called by the optional boot service. Failure leaves stock display setup usable.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! python3 "$ROOT/verify.py"; then
    echo 'VERDE override skipped: kernel compatibility check failed.'
    exit 0
fi
for attempt in {1..20}; do
    if python3 - "$ROOT/monitor.edid" <<'PY'
from pathlib import Path
import sys
try:
    live = Path('/sys/class/drm/card0-DP-1/edid').read_bytes()
    expected = Path(sys.argv[1]).read_bytes()
except OSError:
    raise SystemExit(1)
raise SystemExit(0 if live and live == expected else 1)
PY
    then
        if [[ -e /sys/module/ps5_verde_1440 ]]; then
            echo 'VERDE experiment module is already loaded.'
        else
            insmod "$ROOT/ps5_verde_1440.ko" allow=1
        fi
        exit 0
    fi
    sleep 1
done
echo 'VERDE override skipped: investigated Dell monitor is not connected.'

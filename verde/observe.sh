#!/usr/bin/env bash
# Load logging-only probe and ask the driver to enumerate modes again.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
python3 "$ROOT/check-abi.py"
python3 "$ROOT/verify.py"
# sysfs reports size zero even for readable EDID data; cmp -s may use that
# metadata and return a false mismatch. Compare the actual bytes instead.
python3 - "$ROOT/../snapshots/monitor.edid" <<'PY'
from pathlib import Path
import sys
current = Path('/sys/class/drm/card0-DP-1/edid').read_bytes()
expected = Path(sys.argv[1]).read_bytes()
if not expected or current != expected:
    raise SystemExit(f'Connected EDID differs from snapshot ({len(current)} vs {len(expected)} bytes); stopping.')
print(f'Monitor EDID matches snapshot ({len(current)} bytes).')
PY
messages=$(dmesg)
if command -v journalctl >/dev/null; then
    messages+=$'\n'"$(journalctl -k -b --no-pager -o cat --grep='HDMI IC Type' 2>/dev/null || true)"
fi
if ! grep -F 'HDMI IC Type [VERDE]' <<< "$messages" >/dev/null; then
    echo 'Cannot confirm VERDE from the kernel log; stopping.'; exit 1
fi
if [[ -e /sys/module/ps5_verde_1440 ]]; then
    [[ $(cat /sys/module/ps5_verde_1440/parameters/allow) == N ]] || {
        echo 'An override-enabled module is loaded. Unload it before observation.'; exit 1;
    }
else
    insmod "$ROOT/ps5_verde_1440.ko" allow=0
fi
echo 'Observation only: display validation results remain unchanged.'
shopt -s nullglob
triggers=(/sys/kernel/debug/dri/[0-9]*/DP-1/trigger_hotplug)
if (( ${#triggers[@]} == 1 )); then
    printf '1\n' > "${triggers[0]}"
    # Enumeration may happen asynchronously. This is a bounded diagnostic wait.
    sleep 2
else
    echo 'No unique debug hotplug trigger. Unplug/reconnect HDMI, then run:'
    echo "sudo dmesg | grep ps5_verde_1440"
fi
dmesg | grep 'ps5_verde_1440' | tail -20
echo 'To unload the observer: sudo rmmod ps5_verde_1440'

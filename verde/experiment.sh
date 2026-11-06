#!/usr/bin/env bash
# Expose only the investigated timing; the desktop user selects it separately.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
python3 "$ROOT/check-abi.py"
python3 "$ROOT/verify.py"
python3 - "$ROOT/../snapshots/monitor.edid" <<'PY'
from pathlib import Path
import sys
if Path('/sys/class/drm/card0-DP-1/edid').read_bytes() != Path(sys.argv[1]).read_bytes():
    raise SystemExit('Connected monitor EDID changed; stopping.')
PY
messages=$(dmesg)
# Verbose DRM tracing can evict boot and observation messages from the
# finite kernel ring buffer. The current boot's kernel journal retains them.
if command -v journalctl >/dev/null; then
    journal_messages=$(journalctl -k -b --no-pager -o cat \
        --grep='HDMI IC Type|ps5_verde_1440:' 2>/dev/null || true)
    messages+=$'\n'"$journal_messages"
fi
grep -F 'HDMI IC Type [VERDE]' <<< "$messages" >/dev/null || {
    echo 'Cannot confirm VERDE; stopping.'; exit 1;
}
grep -E 'ps5_verde_1440: 1440p120 original=0 eligible=1 .*force=0 allow=0' <<< "$messages" >/dev/null || {
    echo 'A successful observation of the eligible rejected timing is required first.'; exit 1;
}
if [[ -e /sys/module/ps5_verde_1440 ]]; then
    if [[ $(cat /sys/module/ps5_verde_1440/parameters/allow) == Y ]]; then
        echo 'Temporary override is already loaded.'
        exit 0
    fi
    rmmod ps5_verde_1440
fi
if ! insmod "$ROOT/ps5_verde_1440.ko" allow=1; then
    echo 'Could not load the experiment. Restoring observation-only module.'
    insmod "$ROOT/ps5_verde_1440.ko" allow=0 || true
    exit 1
fi
echo 'Temporary exact-timing override loaded. No display mode was selected.'
echo 'Reconnect HDMI to enumerate modes, then open Settings > Displays.'
echo 'Try 2560x1440 at 120 Hz with HDR off and use the desktop confirmation prompt.'
echo 'If the picture fails, do not confirm; allow the desktop to revert.'
echo 'After reverting/selecting 1080p120, remove the experiment: sudo rmmod ps5_verde_1440'
echo 'The existing 1080p120 boot configuration is unchanged.'

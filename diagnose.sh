#!/usr/bin/env bash
# Read-only display inspection. Run from the normal host terminal.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$ROOT/logs"
exec > >(tee "$ROOT/logs/diagnosis.log") 2>&1
run() {
    printf '\n$'; printf ' %q' "$@"; printf '\n'
    "$@" 2>&1 || true
}
run uname -a
run cat /proc/cmdline
run systemctl --no-pager status ps5-display-init.service
run systemctl cat ps5-display-init.service
run journalctl -b -u ps5-display-init.service --no-pager -n 100
run modetest -M amdgpu -c
printf '\nActive CRTC modes (large property blobs omitted):\n'
modetest -M amdgpu -p 2>&1 | awk '
    /^CRTCs:/ { crtcs=1; print; next }
    /^Planes:/ { exit }
    crtcs && (/^id[[:space:]]/ || /^[0-9]+[[:space:]]/ || /^  #/) { print }
' || true
if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] && command -v gdbus >/dev/null; then
    run gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
        --object-path /org/gnome/Mutter/DisplayConfig \
        --method org.gnome.Mutter.DisplayConfig.GetCurrentState
fi
for connector in /sys/class/drm/card*-*; do
    [[ -f $connector/status ]] || continue
    run cat "$connector/status" "$connector/modes"
    if [[ $(cat "$connector/status") == connected ]]; then
        cp "$connector/edid" "$ROOT/logs/${connector##*/}.edid"
        run python3 "$ROOT/read-edid.py" "$connector/edid"
    fi
done
for parameter in /sys/module/hdmi/parameters/*; do
    [[ -f $parameter ]] && run cat "$parameter"
done
printf '\nRelevant kernel messages:\n'
dmesg 2>&1 | grep -Ei 'hdmi|edid|mode.*(invalid|reject|fail)|link.*(fail|train)|1440' | tail -100 || true
echo "Report saved: $ROOT/logs/diagnosis.log"

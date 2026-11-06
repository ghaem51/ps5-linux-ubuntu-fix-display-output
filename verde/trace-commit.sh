#!/usr/bin/env bash
# Temporarily enable DRM diagnostics around one desktop mode change.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
PARAM=/sys/module/drm/parameters/debug
previous=$(cat "$PARAM")
[[ $previous =~ ^(0[xX][0-9a-fA-F]+|[0-9]+)$ ]] || { echo 'Unexpected DRM debug mask'; exit 1; }
restore() { printf '%s\n' "$previous" > "$PARAM"; }
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$ROOT/../logs"
log=$ROOT/../logs/atomic-$(date +%Y%m%d-%H%M%S).log
started=$(date +%s)
# Driver, KMS and atomic diagnostics; preserve any previously enabled bits.
printf '0x%x\n' "$((previous | 0x16))" > "$PARAM"
echo 'DRM trace enabled for up to 45 seconds.'
echo 'In Settings > Displays, try 2560x1440 at 120 Hz once.'
echo 'Return here and press Enter after the attempt (or wait 45 seconds).'
read -r -t 45 _ || true
restore
trap - EXIT
journalctl -k -b --since="@$started" --no-pager -o short-monotonic > "$log"
echo "Full kernel trace saved: $log"
echo 'Relevant validation messages:'
grep -Ei 'fail|invalid|reject|error|bandwidth|validation|1440|497750|ps5_verde' "$log" | tail -100 || true
echo "Original DRM debug mask restored: $previous"

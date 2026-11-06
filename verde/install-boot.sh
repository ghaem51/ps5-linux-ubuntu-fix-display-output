#!/usr/bin/env bash
# Install the physically confirmed, kernel-specific workaround for future boots.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
python3 "$ROOT/verify.py"
for artifact in "$ROOT/../snapshots/monitor.edid" "$ROOT/boot-load.sh" "$ROOT/boot-display.sh"; do
    [[ -s $artifact ]] || { echo "Missing required local file: $artifact"; exit 1; }
done
[[ -x /usr/local/sbin/ps5-display-init ]] || { echo 'Original display initializer missing.'; exit 1; }
[[ -f /etc/systemd/system/ps5-display-init.service ]] || { echo 'Original display unit missing.'; exit 1; }
DEST=/usr/local/lib/ps5-verde-1440
UNIT=/etc/systemd/system/ps5-verde-1440.service
DROPIN=/etc/systemd/system/ps5-display-init.service.d/1440p120.conf
for path in "$DEST" "$UNIT" "$DROPIN"; do
    [[ ! -e $path ]] || { echo "$path already exists; refusing replacement."; exit 1; }
done
install -d -m755 "$DEST"
install -m644 "$ROOT/ps5_verde_1440.ko" "$ROOT/build-btf.sha256" "$ROOT/verify.py" "$DEST/"
install -m644 "$ROOT/../snapshots/monitor.edid" "$DEST/monitor.edid"
install -m755 "$ROOT/boot-load.sh" "$ROOT/boot-display.sh" "$DEST/"
cat > "$UNIT" <<'UNIT'
[Unit]
Description=Load verified PS5 VERDE Dell 1440p120 workaround
After=systemd-udev-trigger.service
Before=ps5-display-init.service display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/lib/ps5-verde-1440/boot-load.sh
TimeoutStartSec=30
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
UNIT
install -d -m755 "${DROPIN%/*}"
cat > "$DROPIN" <<'DROPIN'
[Unit]
Description=Initialize PS5 display at 1440p120 with 1080p120 fallback
Wants=ps5-verde-1440.service
After=ps5-verde-1440.service

[Service]
ExecStart=
ExecStart=/usr/local/lib/ps5-verde-1440/boot-display.sh
DROPIN
chmod 644 "$UNIT" "$DROPIN"
systemctl daemon-reload
systemctl enable ps5-verde-1440.service
echo 'Installed for future boots. The current display was not restarted.'
echo 'Original initializer and boot command line remain available as fallback.'
echo "Remove boot setup with: sudo $ROOT/remove-boot.sh"

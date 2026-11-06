#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
systemctl disable ps5-verde-1440.service
rm -f /etc/systemd/system/ps5-display-init.service.d/1440p120.conf
rm -f /etc/systemd/system/ps5-verde-1440.service
rm -rf -- /usr/local/lib/ps5-verde-1440
systemctl daemon-reload
echo 'Boot workaround removed. Original 1080p120 initializer will run next boot.'
echo 'The currently loaded module and active display were left running.'

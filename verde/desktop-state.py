#!/usr/bin/env python3
"""Read Mutter's selected mode through the desktop session D-Bus."""
import json
import os
import subprocess
import sys
import gi

gi.require_version('Gio', '2.0')
from gi.repository import Gio

if os.geteuid() == 0:
    raise SystemExit('Run as your desktop user, without sudo.')
try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    result = bus.call_sync(
        'org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig',
        'org.gnome.Mutter.DisplayConfig', 'GetCurrentState', None, None,
        Gio.DBusCallFlags.NONE, 10000, None)
except Exception as error:
    raise SystemExit(f'Cannot query desktop session: {error}')
serial, monitors, logical, properties = result.unpack()
print('Mutter serial:', serial)
for spec, modes, props in monitors:
    print('Monitor:', spec)
    for mode_id, width, height, rate, preferred_scale, scales, mode_props in modes:
        if mode_props.get('is-current') or (width == 2560 and height == 1440):
            print(json.dumps({'id': mode_id, 'width': width, 'height': height,
                              'refresh': rate, 'properties': mode_props}, default=str))
print('Logical desktop assignments:', json.dumps(logical, default=str))
print('\nRecent desktop display errors:')
subprocess.run(['journalctl', '--user', '-b', '--no-pager', '--since=-15min',
                '-n', '60', '--grep=monitor|modeset|atomic|CRTC|KMS|drm|Failed to apply'], check=False)
print('\nRecent initialization-service runs:')
subprocess.run(['journalctl', '-b', '-u', 'ps5-display-init.service', '--no-pager', '-n', '12'], check=False)

#!/usr/bin/env bash
# Read-only, concise comparison of DRM scanout and the experimental validation.
set -uo pipefail
printf 'Active GPU timing:\n'
modetest -M amdgpu -p 2>&1 | awk '
    /^CRTCs:/ { active=1; print; next }
    /^Planes:/ { exit }
    active && (/^id[[:space:]]/ || /^[0-9]+[[:space:]]/ || /^  #/) { print }
'
printf '\n1440p modes exposed by driver:\n'
modetest -M amdgpu -c 2>&1 | grep -E 'opened device|connected|#[0-9]+ 2560x1440' || true
printf '\nExperiment parameter:\n'
cat /sys/module/ps5_verde_1440/parameters/allow 2>/dev/null || true
printf '\nRecent display experiment messages:\n'
dmesg 2>&1 | grep -E 'ps5_verde_1440|hdmi:.*(fail|error)|amdgpu.*(fail|error)' | tail -25 || true

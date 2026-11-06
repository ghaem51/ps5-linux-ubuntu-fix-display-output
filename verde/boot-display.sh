#!/usr/bin/env bash
# Preserve the working initializer as a fallback; no kernel command-line edit.
set -uo pipefail
export LC_ALL=C
fallback() {
    echo 'Using original 1080p120 display initializer.'
    exec /usr/local/sbin/ps5-display-init
}
[[ -r /sys/module/ps5_verde_1440/parameters/allow ]] || fallback
[[ $(cat /sys/module/ps5_verde_1440/parameters/allow) == Y ]] || fallback
listing=$(/usr/bin/modetest -M amdgpu -c 2>&1) || fallback
connector=$(awk '$3 == "connected" && $4 == "DP-1" { print $1; exit }' <<< "$listing")
[[ -n $connector ]] || fallback
# Discovery and atomic validation use the same exact timing predicate.
grep -Eq '#[0-9]+ 2560x1440 120\.00 .*497750 ' <<< "$listing" || fallback
echo "Initializing connector $connector at 2560x1440 120Hz, max bpc 8"
output=$(
    { sleep 2; printf '\n'; } |
    /usr/bin/modetest -M amdgpu -w "${connector}:max bpc:8" \
        -s "${connector}:2560x1440-120" 2>&1
)
result=$?
printf '%s\n' "$output"
if [[ $result != 0 ]] || grep -Eqi 'failed|permission denied|no such file|cannot|could not' <<< "$output"; then
    fallback
fi
echo '1440p120 initialization completed.'

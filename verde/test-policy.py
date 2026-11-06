#!/usr/bin/env python3
"""Execute the actual C timing predicate against positive/negative cases."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent
source = (root / 'ps5_verde_1440.c').read_text()
predicate = source[source.index('static bool target_timing('):source.index('static int entry(')]
harness = r'''
#include <stdbool.h>
#include <assert.h>
#include <stddef.h>
#define DRM_MODE_FLAG_PHSYNC 1
#define DRM_MODE_FLAG_NVSYNC 8
#define DRM_MODE_TYPE_DRIVER 64
struct drm_display_mode {
    int clock, hdisplay, hsync_start, hsync_end, htotal, hskew;
    int vdisplay, vsync_start, vsync_end, vtotal, vscan, flags, type;
};
PREDICATE
int main(void) {
    struct drm_display_mode base = {
        .clock=497750, .hdisplay=2560, .hsync_start=2608,
        .hsync_end=2640, .htotal=2720, .vdisplay=1440,
        .vsync_start=1443, .vsync_end=1448, .vtotal=1525,
        .flags=9, .type=64
    }, changed;
    assert(target_timing(&base));
    changed=base; changed.type=0; assert(target_timing(&changed));
    assert(!target_timing(NULL));
    changed=base; changed.clock=591300; assert(!target_timing(&changed));
    changed=base; changed.clock=497749; assert(!target_timing(&changed));
    changed=base; changed.vtotal++; assert(!target_timing(&changed));
    changed=base; changed.hsync_start++; assert(!target_timing(&changed));
    changed=base; changed.flags|=16; assert(!target_timing(&changed));
    changed=base; changed.type=32; assert(!target_timing(&changed));
    changed=base; changed.hdisplay=1920; assert(!target_timing(&changed));
    changed=base; changed.vscan=2; assert(!target_timing(&changed));
    changed=base; changed.hskew=1; assert(!target_timing(&changed));
    changed=base; changed.type=0; changed.clock=591300; assert(!target_timing(&changed));
    return 0;
}
'''.replace('PREDICATE', predicate)
with tempfile.TemporaryDirectory() as directory:
    c = Path(directory) / 'policy.c'
    binary = Path(directory) / 'policy'
    c.write_text(harness)
    subprocess.run(['gcc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(c), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print('Timing predicate: discovery and atomic copies accepted; 11 invalid/mismatched cases rejected.')

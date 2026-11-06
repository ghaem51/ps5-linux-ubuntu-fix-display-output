// SPDX-License-Identifier: GPL-2.0-only
/* Probe approach informed by TaoEffects' GPL-2.0-only ps5_hdmi_hfr.c:
 * https://github.com/ps5-linux/ps5-linux-patches/issues/65
 * Reworked here for the three-argument ABI and exact Dell timing policy.
 */
/* Local, temporary experiment for the Dell G2724D's EDID 1440p120 timing.
 * Default: observe only. No boot hooks and no converter register writes.
 */
#define pr_fmt(fmt) "ps5_verde_1440: " fmt
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/ps5.h>
#include <drm/drm_modes.h>
#include <drm/drm_connector.h>
#include "live-layout.h"

static bool allow;
module_param(allow, bool, 0400);
MODULE_PARM_DESC(allow, "Experimental: allow the exact Dell 1440p120 timing (default false)");

/* Fail compilation if the installed headers expose a different ABI. */
static_assert(__same_type(typeof(&isHdmiModeValid),
              bool (*)(const struct drm_display_mode *, const struct drm_display_info *, int)));

struct observation {
    bool target;
    bool eligible;
    int max_tmds;
    int force;
    bool scdc;
    bool scrambling;
};

static bool target_timing(const struct drm_display_mode *m)
{
    return m && m->clock == 497750 &&
        m->hdisplay == 2560 && m->hsync_start == 2608 &&
        m->hsync_end == 2640 && m->htotal == 2720 && !m->hskew &&
        m->vdisplay == 1440 && m->vsync_start == 1443 &&
        m->vsync_end == 1448 && m->vtotal == 1525 && m->vscan <= 1 &&
        m->flags == (DRM_MODE_FLAG_PHSYNC | DRM_MODE_FLAG_NVSYNC) &&
        /* Atomic MODE_ID blobs retain timings but omit discovery type flags.
         * Keep exact timing/capability checks for that zero-type copy too.
         */
        ((m->type & DRM_MODE_TYPE_DRIVER) || !m->type);
}

static int entry(struct kretprobe_instance *ri, struct pt_regs *regs)
{
    struct observation *o = (void *)ri->data;
    const struct drm_display_mode *m = (void *)regs->di;
    const struct drm_display_info *info = (void *)regs->si;

    memset(o, 0, sizeof(*o));
    o->target = target_timing(m);
    if (!o->target || !info)
        return 0;
    o->force = (int)regs->dx;
    o->max_tmds = info->max_tmds_clock;
    o->scdc = info->hdmi.scdc.supported;
    o->scrambling = info->hdmi.scdc.scrambling.supported;
    o->eligible = !o->force && info->is_hdmi &&
        o->max_tmds >= 497750 && o->scdc && o->scrambling;
    return 0;
}

static int returned(struct kretprobe_instance *ri, struct pt_regs *regs)
{
    struct observation *o = (void *)ri->data;
    bool original = (regs_return_value(regs) & 0xff) != 0;

    if (!o->target)
        return 0;
    pr_info_ratelimited("1440p120 original=%u eligible=%u max_tmds=%d scdc=%u scrambling=%u force=%d allow=%u\n",
        original, o->eligible, o->max_tmds, o->scdc,
        o->scrambling, o->force, allow);
    if (allow && !original && o->eligible)
        regs_set_return_value(regs, 1);
    return 0;
}

static struct kretprobe probe = {
    .kp.symbol_name = "isHdmiModeValid",
    .entry_handler = entry,
    .handler = returned,
    .data_size = sizeof(struct observation),
    .maxactive = 32,
};

static int __init verde_init(void)
{
    int ret = register_kretprobe(&probe);
    if (ret)
        return ret;
    pr_info("loaded: %s; exact Dell EDID timing only\n",
            allow ? "EXPERIMENTAL override" : "observation only");
    return 0;
}

static void __exit verde_exit(void)
{
    unregister_kretprobe(&probe);
    pr_info("unloaded; missed observations=%d\n", probe.nmissed);
}
module_init(verde_init);
module_exit(verde_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("PS5 VERDE 1440p120 validation observer and opt-in experiment");

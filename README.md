# PS5 Ubuntu VERDE 1440p120 workaround

A narrowly targeted, temporary kernel probe lets a PS5 Slim running Ubuntu expose and commit the Dell G2724D's exact 2560×1440 at 120 Hz EDID timing.

Tested on Ubuntu 26.04.1 / custom PS5 kernel 7.2.3 / VERDE HDMI converter / Dell G2724D. Both active DRM scanout and the monitor output were confirmed at 1440p120. Display boot initialization was also confirmed after reboot. A separate pre-existing firmware service cycle affected NetworkManager/GDM startup; see [the Wi-Fi repository](https://github.com/ghaem51/ps5-linux-ubuntu-fix-wifi).

This is an experimental workaround for this configuration, not general VERDE high-refresh support. It uses a kretprobe to change one validation result, not a replacement kernel or HDMI register patch. Other monitors, HDR, 144 Hz, suspend/resume, long-duration stability and HDMI audio are not validated.

## Prerequisites and local monitor capture

Matching kernel headers, live `/sys/kernel/btf/vmlinux`, `CONFIG_KPROBES`, `CONFIG_KRETPROBES`, and the three-argument PS5 `isHdmiModeValid` ABI are required. The build checks the live BTF signature and structure layouts, then module vermagic, size and imported symbol CRCs.

```bash
sudo apt install build-essential python3 python3-gi libelf-dev libdw-dev pkg-config curl xz-utils binutils kmod libdrm-tests
python3 prepare-monitor.py
cd verde
./build.sh
```

`prepare-monitor.py` validates the monitor model, EDID checksums and exact target timing and captures your local EDID. That file includes the monitor identifier and is ignored by Git. No personal EDID is distributed.

Some PS5 header packages ship an ARM64 objtool despite an x86-64 kernel. The build uses an installed x86-64 tool when available; otherwise it builds a native one from matching kernel.org sources. This may download/extract a full kernel archive. To reuse existing matching sources, set `KERNEL_SOURCE=/path/to/linux-7.2.3`; to supply a native tool directly, set `NATIVE_OBJTOOL=/path/to/objtool`. GCC matching the kernel is preferred; GCC 15 was used on the tested setup, with compatibility checks.

## Observe before overriding

```bash
sudo ./observe.sh
```

Reconnect HDMI if no debug hotplug trigger exists, then inspect `sudo dmesg | grep ps5_verde_1440`. Observation leaves validation results unchanged. Expected evidence: the exact target rejected (`original=0`) while sink gates pass (`eligible=1`), with TMDS >=497750 kHz and SCDC/scrambling enabled. The script checks the current boot journal if verbose logging evicted earlier messages from dmesg.

## Temporary experiment

```bash
sudo ./experiment.sh
```

Reconnect HDMI, select 2560×1440 at 120 Hz in Settings → Displays with HDR off, and use the desktop confirmation/revert prompt. A blank/corrupt image should not be confirmed. A kernel fault can prevent a software revert, so keep your working 1080p120 boot path. Do not restart the initialization service during a desktop test.

```bash
sudo ./check-output.sh
python3 desktop-state.py  # without sudo
```

Confirm active DRM scanout **and** the monitor OSD; a Settings label alone is insufficient. The first implementation exposed the mode but missed its zero-type atomic MODE_ID copy, causing `-EINVAL` and leaving 1080p active. The corrected predicate handles both copies; regression cases cover this distinction.

To remove the temporary probe, first select working 1080p120, then `sudo rmmod ps5_verde_1440`. Unloading alone does not restore an already-selected mode. Reboot also unloads it unless boot persistence is installed.

## Optional boot persistence after physical confirmation

Boot persistence requires an existing, working `/usr/local/sbin/ps5-display-init` 1080p120 initializer and `/etc/systemd/system/ps5-display-init.service`. Those local files are not distributed here because their original authorship was not established during review. If they are absent, use the temporary experiment only; the boot installer deliberately refuses to proceed.

From `verde/`:

```bash
sudo ./install-boot.sh
```

This installs root-owned module files, a loader service, and a drop-in for `ps5-display-init.service`. It checks the kernel BTF fingerprint and exact monitor EDID before loading, then attempts 1440p120 at 8 bpc. The original initializer is retained as a 1080p120 fallback. No live desktop restart or kernel command-line change occurs. Software checks cannot detect every physical no-signal failure.

After a kernel update, rebuild: the old module is intentionally skipped when compatibility changes. The installer refuses to overwrite an existing installation; remove the old boot integration before reinstalling. `sudo ./remove-boot.sh` restores the original boot unit behavior without unloading the live module. GNOME's saved desktop configuration remains separate.

## Diagnostics and tests

`../diagnose.sh` collects service/mode information. `trace-commit.sh` enables bounded DRM logging around one mode attempt and restores the prior mask. Logs contain local monitor identifiers; review before sharing. Run `python3 test-policy.py` for timing-predicate regression tests. Runtime hardware checks remain necessary.

## Research and license

Inspired by the [VERDE Slim high-refresh investigation](https://github.com/ps5-linux/ps5-linux-patches/issues/65), which reports 1080p high-refresh tests, and inspection of the [PS5 kernel patch set](https://github.com/ps5-linux/ps5-linux-patches/blob/main/linux.patch). This implementation targets a newer, three-argument ABI and the exact Dell 1440p120 timing; it does not establish generic converter capability.

GPL-2.0-only. No kernel sources, binaries, local EDIDs, logs or backups are committed.

## Development and validation

Implementation and review were assisted by OpenAI Codex. Hardware results were checked interactively by the repository owner on one PS5 Slim. These are community workarounds with limited hardware coverage, not an official Sony or Ubuntu release. See `CREDITS.md` and `REVIEW.md` for provenance and review limits.

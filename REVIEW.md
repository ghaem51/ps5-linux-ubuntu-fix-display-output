# Pre-publication review

Reviewed locally on 2026-11-06. This is a source and packaging review, not an independent security or legal certification.

## Privacy

Tracked files and reachable commit history were checked for the known local monitor serial, saved Wi-Fi network name, personal email, home-directory path, private-key headers and common access-token patterns. No such data was found. Logs, EDIDs, build outputs, downloaded kernel trees and backups are ignored and not committed. Commit authorship intentionally uses the public GitHub handle and its no-reply address; publishing under a named account is not anonymous.

## Provenance and scope

See `CREDITS.md` for dependencies and upstream sources. Repository code is marked GPL-2.0-only; downloaded Linux source keeps its own notices and is not included in Git. Public documentation describes limited hardware coverage and AI-assisted development, and does not claim official support, independent certification, or a generic driver repair.

## Test limits

Shell syntax and Python compilation checks passed locally. The GitHub Actions workflow has not run because this repository has not been published. Audit changes were made only to the publication copy, not installed system files. Hardware observations describe the original troubleshooting session; they do not mean every later packaging/error-path change was exercised on hardware.

## Display-specific review

The upstream issue's code sample explicitly declares GPL-2.0-only. The local source and credits now acknowledge TaoEffects and distinguish that report's 1080p results from the local 1440p tests. Pre-existing local initializer/unit snapshots of unestablished authorship were removed from the publication files and initial published history. Boot persistence now explicitly requires a locally supplied working initializer.

The standalone module was rebuilt successfully using matching installed headers and a native objtool built from existing matching sources. Live BTF/layout and module compatibility checks passed. A deliberately changed kernel BTF fingerprint was rejected. Timing-policy tests cover discovery and zero-type atomic copies plus 11 invalid/mismatched cases. The local-monitor capture utility validated the actual EDID, which remains ignored.

Original hardware outcome: active DRM scanout and monitor output confirmed 1440p120; the user reported display initialization working after reboot. This remains an experimental kernel-return override for one timing, converter and monitor. It can cause a blank display or kernel fault; the desktop revert prompt and boot fallback cannot guarantee recovery in every failure. Removal of the probe does not restore an already-selected mode. No broad refresh-rate overrides or kernel-register writes were introduced in review.

The audit changed only attribution comments in the kernel source and packaging/preflight files, not the tested timing predicate. Downloading/extracting fresh source via the native-tool bootstrap and installing the revised package were not exercised during this review.

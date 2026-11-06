# Credits and source provenance

Repository-specific scripts were developed during an AI-assisted troubleshooting session and are offered under GPL-2.0-only. No firmware, kernel binaries, downloaded Linux source tree, or local machine logs are distributed in Git.

- [ps5-linux/ps5-linux-patches](https://github.com/ps5-linux/ps5-linux-patches): the underlying PS5 kernel work and the interfaces these workarounds use. This repository is independent and does not claim upstream endorsement.
- [Linux kernel](https://www.kernel.org/): installed headers, module infrastructure, media/UVC drivers and native build tools. Source archives downloaded by build scripts retain their original license notices and are excluded from Git. Checksums are compared with kernel.org's HTTPS checksum list; detached signatures are not verified by these scripts.

- [TaoEffects, PS5 Slim high-refresh investigation, issue #65](https://github.com/ps5-linux/ps5-linux-patches/issues/65): the GPL-2.0-only `ps5_hdmi_hfr.c` example informed the kretprobe approach and hook structure used here. The local implementation changes the function ABI handling, timing policy, sink-capability gates, observation logic and atomic-copy handling. The upstream report tested high-refresh 1080p; it does not establish this project's 1440p results.

The pre-existing local display initializer and unit were excluded from the publication copy because their authorship was not established. Boot integration requires users to supply an already-working initializer; no license is asserted over their local files.

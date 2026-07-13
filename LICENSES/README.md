# Licensing map

- Repository build scripts, XG-040G-MD support helpers, and One-KVM patches:
  `GPL-3.0-only`.
- `luci-app-one-kvm`: `Apache-2.0`.
- `gostc` prebuilt binary: `Apache-2.0` plus the upstream non-commercial
  Commons Clause recorded in `GOSTC-Commons-Clause.txt`. This is a source-
  available dependency, not an OSI-approved open-source license.
- `easytier-core` prebuilt binary: `LGPL-3.0-only`; the corresponding text is
  stored at `package/easytier-core/files/COPYING`, together with this
  repository's GPL-3.0 text as required by LGPLv3.
- `libyuv`: `BSD-3-Clause`; `libx265`: `GPL-2.0-only`; the focused FFmpeg
  runtime retains FFmpeg's GPL/LGPL notices and becomes GPL-enabled through
  x264/x265.
- `kmod-airoha-an7581-oc`: `GPL-2.0-only`; it is adapted from the board-gated
  PLL module in `Ljzd-PRO/xg040g-openwrt-switch` commit
  `22bd32ab0cb417138763174f3840a67584ff63cf`.
- `luci-app-xg040g-performance`: `Apache-2.0`; the policy and monitoring
  backend remains `GPL-3.0-only`.
- Git submodules retain their upstream licenses and copyright notices.

The corresponding full license texts are stored in this directory. The root
`LICENSE` is the GPL-3.0-only text used for repository files without a more
specific per-component license declaration.

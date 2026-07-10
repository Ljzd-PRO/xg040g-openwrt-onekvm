# 2026-07-10 One-KVM full-profile build report

This report records the first successful local build of the full host-only
One-KVM profile for XG-040G-MD. No firmware was flashed during this build
report cycle.

## Scope

- Profile: `onekvm`
- OpenWrt commit: `4984eff3c34a5b8d7995e2b2a0a3823bba31c1fc`
- One-KVM commit: `7753c83e27d20ba31d19daafdddedada7e89e32c`
- Project commit used by the formal build:
  `c02b7f7eb6edc57af9bbf18d9075c9413b1123eb`
- Builder: Docker arm64, isolated source mode, `-j10`
- Output directory: `output/onekvm-formal-20260710-192355`

## Build Result

The formal `onekvm` build completed successfully.

- Exit status: `0`
- Elapsed wall time: `51:43.46`
- Maximum resident set size: `4,404,308 KiB`
- Swaps: `0`

Generated firmware:

| Artifact | Size | SHA256 |
| --- | ---: | --- |
| `openwrt-airoha-an7581-nokia_xg-040g-md-tcboot-squashfs-sysupgrade.bin` | `58,491,175` bytes / `55.78 MiB` | `e945f6fd34ce0e83c57d003974882c51f94960b887fdb3462c0c2e19e869d1c8` |
| `openwrt-airoha-an7581-nokia_xg-040g-md-tcboot-squashfs-factory.bin` | `69,206,016` bytes / `66.00 MiB` | `725c0bc92bd4759f8ed0f0104f06bc8e9a9a3b7779541a2821ab77c26165d83b` |
| `openwrt-airoha-an7581-nokia_xg-040g-md-tcboot-initramfs-uImage.itb` | `53,920,056` bytes / `51.42 MiB` | `512b04642c176d361bc8a03b23253fb5b7b4ee5c405e83416fa6808ac18e2df9` |

Exported upgrade APKs:

| Package | Version | Size | SHA256 |
| --- | --- | ---: | --- |
| `one-kvm` | `0.2.3-r3` | `8,511,805` bytes / `8.12 MiB` | `b9d5c9eb97cc43c25aa9c1d406a2bee9c62d47e1ec2b4de57c2a7f30a9e83bb8` |
| `luci-app-one-kvm` | `20260710-r1` | `6,132` bytes | `e0f0ec2336ff502f46e4784cf45407031f2e3384f50208daeea0b0e064c0d464` |
| `luci-i18n-one-kvm-zh-cn` | `0` | `1,885` bytes | `4bc5b81c090f5f3fe85e8c2cc09cc9dfd7f1c0a32ff19795c54f711df5b876a5` |

The sysupgrade image is below the release gate of `80 MiB`.

## Verification

Passed:

- `./scripts/verify-output.sh onekvm output/onekvm-formal-20260710-192355`
- `./scripts/verify-output.sh minimal output/minimal-formal-20260710-190054`
- `./scripts/validate.sh`
- `git diff --check`
- `shasum -a 256 -c output/onekvm-formal-20260710-192355/SHA256SUMS.local`

The `onekvm` manifest contains the expected full-profile runtime packages,
including:

- `one-kvm`, `luci-app-one-kvm`, `luci-i18n-one-kvm-zh-cn`
- `xg040g-onekvm-runtime`
- `ttyd`, `gostc`, `easytier-core`, `frpc`
- `libffmpeg-onekvm`, `libx264`, `libx265`, `libvpx1.16`, `libopus`
- `alsa-lib`, `alsa-utils`, `kmod-usb-audio`
- `rclone`, `dnsmasq-full`, `kmod-usb-storage-uas`, `kmod-usb-serial-ch341`

The manifest does not contain the forbidden host-only exclusions:

- `kmod-usb-mtu3`
- `kmod-usb-gadget`
- `kmod-usb-gadget-hid`
- `kmod-usb-gadget-mass-storage`
- `usbgadget`
- `libffmpeg-mini`
- `libffmpeg-full`

## Open Items

The hot-cache offline `onekvm` build was started as an additional release
confidence check at `output/onekvm-offline-20260710-202232`. It was still
running when this report was first committed. The purpose is to verify that
feed, Cargo and npm dependencies can be reused without network access.

Device flashing and runtime smoke tests were intentionally skipped per user
instruction. The following checks remain pending until a later flash/test
cycle:

- `sysupgrade -T`
- LuCI and SSH post-upgrade smoke test
- USB host root hub and empty UDC runtime validation
- One-KVM service startup and memory smoke test
- `one-kvm-codec-check`
- MS2109, CH9329, USB3 KVMSTORE, PXE and rclone/WebDAV hardware checks


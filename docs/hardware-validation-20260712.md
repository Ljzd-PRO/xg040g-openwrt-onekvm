# 2026-07-12 full-profile hardware validation

## Scope

This run validates the host-only One-KVM profile on a second XG-040G-MD.
The device was upgraded with preserved configuration. USB3 external storage and
an actual PXE client boot were explicitly deferred; server-side PXE transfer was
still checked.

## Platform

- OpenWrt source: `4984eff3c34a5b8d7995e2b2a0a3823bba31c1fc`
- One-KVM source: `7753c83e27d20ba31d19daafdddedada7e89e32c`
- Project metadata commit: `b192104ecfbe74d0897977185332ff00ee3386e3`
- Final sysupgrade: `openwrt-airoha-an7581-nokia_xg-040g-md-tcboot-squashfs-sysupgrade.bin`
- Final image size: 58,491,175 bytes (55.78 MiB)
- Final image SHA256: `3f3462a888fbb41225ab5ecc4ab21d17067fe3244066e678c072994f5fb5b9c1`
- Host mode: two xHCI controllers, four USB root hubs, no UDC
- Installed packages: `one-kvm 0.2.3-r4`, `luci-app-one-kvm 20260710-r3`,
  `xg040g-kvm-support 0.1.0-r2`, and runtime ABI `1.0.0-r1`
- One-KVM service: disabled in the image by default; enabled on the test device
  after user initialization

## Completed checks

### MS2109 video and audio

- USB device `345f:2109` bound to UVC and USB Audio drivers.
- `/dev/video0`, `/dev/video1`, and `/dev/media0` were created.
- V4L2 advertised MJPEG up to 1920x1080 at 60 fps.
- Direct V4L2 capture produced a non-empty MJPEG frame.
- ALSA captured a non-empty 48 kHz stereo WAV sample.
- One-KVM health, authenticated MJPEG stream, snapshot, and Opus audio APIs
  worked. The final snapshot was 273,650 bytes. Idle `VmRSS` was 21,660 KiB;
  `MemAvailable` was 149,284 KiB out of 326,292 KiB total.

### CH340 and CH9329

- USB device `1a86:7523` bound to `ch341` and created `/dev/ttyUSB0`.
- `ch9329-detect` created `/dev/ch9329 -> /dev/ttyUSB0`.
- The tested controller did not answer at 115200 baud. At the upstream default
  of 9600 baud, One-KVM detected CH9329 firmware `V3.8`, reported the backend
  online, and read the LED state.
- An authenticated WebSocket test sent Caps Lock down/up twice. The reported LED
  state toggled and returned to its initial value.
- Relative mouse `+3` and `-3` X movements completed without serial or HID
  errors. The connection closed normally and One-KVM reset HID state.

### Software codecs and extensions

- `one-kvm-codec-check` initialized H.264/libx264, H.265/libx265, VP8/libvpx,
  and VP9/libvpx-vp9 and encoded one 1280x720 frame with each encoder.
- ttyd, GOSTC, EasyTier, and FRPC binaries were present and remained stopped by
  default. One-KVM could start and stop ttyd through its extension API.
- The device does not expose a supported hardware video encoder; these checks
  cover software encoding only.

### LuCI recovery and service isolation

- LuCI reported runtime, installed package, ROM, LuCI, and runtime ABI versions.
- The final image boots with LuCI RPC/menu files at mode 0644 and helper scripts
  at 0755; `luci.one-kvm` loads without a post-flash permission repair.
- A reversible wrapper was placed over `/usr/bin/one-kvm`. The recovery RPC
  restored the ROM SHA256 and preserved the original disabled service state.
- The feeds-provided ustreamer instance was found to compete for `/dev/video0`
  and port 8080. The final package disables that legacy instance on first boot,
  including when an older preserved UCI configuration had enabled it, and
  leaves video lifecycle management to One-KVM.
- The initialized account data under `/etc/one-kvm` survived the preserved-
  configuration sysupgrade. Authenticated login returned HTTP 200.

### PXE and rclone helpers

- The PXE bridge and DHCP/TFTP service were isolated on `lan4`; management
  remained on another LAN port.
- HTTP and TFTP fetched current `ipxe.efi` and `undionly.kpxe` files, with
  matching SHA256 values on both sides.
- An rclone local-backend fixture validated dry-run, cloud-cache refresh, and
  final `tftp`, `netboot`, and `iso` publication. A simulated source failure did
  not delete existing cached files.

## Deferred checks

- USB3 `KVMSTORE` SuperSpeed link, automatic mount, and sustained I/O.
- DHCP and iPXE execution from a physical PXE client.
- Authentication and transfer against a real WebDAV account.
- Physical ATX relay backends.

The deferred checks do not affect the completed MS2109 or CH9329 closures. A
release should remain a prerelease until the remaining storage, boot-client, and
real cloud-remote checks are complete.

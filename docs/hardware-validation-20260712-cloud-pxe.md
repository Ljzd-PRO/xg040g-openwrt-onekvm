# Cloud PXE firmware validation, 2026-07-12

## Firmware

The full `onekvm` image was flashed to the second XG-040G-MD through the
LjzdPRO-Station wireless SSH path. Configuration was preserved.

```text
sysupgrade bytes: 58859815
sysupgrade sha256: 776d5b2cc47e603cf47e67c0e6712c21ed1d98795391001e9d009ac72293efa8
xg040g-cloud-pxe: 0.1.0-r2
luci-app-one-kvm: 20260710-r6
```

The first r1 hardware pass found that `od` was not present in the image. The
remote-path control-character check was changed to the BusyBox `hexdump`
applet, the package release was bumped to r2, and the corrected image was
rebuilt and flashed. This is why the r1 image must not be published.

## Network and services

Only one Ethernet cable was available. It was moved from LAN4 to LAN2 before
the upgrade. Management recovered over `xg040g-f5040c.local` and
`169.254.6.204` without DHCP. LAN4 remained `10.40.0.1/24`, with PXE uplink
disabled.

- Dropbear, LuCI HTTP/HTTPS, One-KVM 8080, and local PXE HTTP 8081 listened.
- Cloud PXE 8083 was disabled before and after the test.
- The firewall contained the dedicated LAN4 TCP 8083 allow rule.
- Four xHCI root hubs were present and `/sys/class/udc` remained empty.
- One-KVM account data, UCI state, enabled service, and firmware binary match
  survived both preserved-configuration upgrades.
- Overlay had about 164.1 MiB available; `MemAvailable` was about 160 MiB after
  the codec test.

## Cloud PXE RPC closure

The exact LuCI RPC path was exercised with an unsaved local rclone fixture:

1. `test_cloud_pxe_config` returned `VALID=1` and `REACHABLE=1`.
2. `save_cloud_pxe` enabled a local backend rooted at the managed netboot
   directory.
3. rclone listened on `10.40.0.1:8083` and returned `boot-select.ipxe`.
4. The enabled selector chained to `cloud.ipxe`.
5. `clear_cloud_pxe` stopped rclone, removed the listener, cleared the saved
   config, and restored the selector to the user-owned local `boot.ipxe`.

The embedded loader hashes matched the pinned build assets:

```text
4437f1fa12b365f3f85dd227a791db9b4ebed1ac0aa41eec832113af54cf4a77  ipxe.efi
f94fe30630b89a647eb550a747e9390fe2f9d7463f29279ab958c689f99f6229  undionly.kpxe
```

H.264, H.265, VP8, and VP9 completed the 1280x720 single-frame codec check.

## Deferred in this topology

The single cable could provide either management/upstream access or a LAN4
PXE client link, but not both. A real remote-provider boot of FirPE and
SystemRescue through 8083 was therefore not repeated. The local rclone HTTP
data-plane closure proves the firmware and LuCI path; provider throughput and
range-request behavior still need the two-cable topology.

MS2109 and CH340 did not enumerate after the final reboot. Rebinding the
`1fab0000.usb` xHCI controller did not create a USB device, so a physical
replug is required before marking the post-flash USB regression complete.

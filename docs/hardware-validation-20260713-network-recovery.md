# 2026-07-13 switch, PXE and recovery validation

## Scope

This run validates the DHCP-managed switch topology, RFC 3927 fallback,
LAN4-only PXE services, the One-KVM LuCI controls, and the 12-second OpenWrt
failsafe configuration on the second XG-040G-MD.

The device was flashed with the `final-r2` development image. Two runtime
issues found during the test were fixed in the repository and hot-applied to
the device: the dedicated PXE HTTP instance and the LuCI PXE/reset RPC files.
The final `final-r5` image and APKs contain those fixes but were not flashed,
as requested.

The clean `final-r5` build completed with exit status 0. Its sysupgrade is
58,634,535 bytes with SHA256
`6bde8920860fcf3241539f08ded7fa871dea7d4572376e66120d398ea9b8f1f8`.
The manifest contains `xg040g-switch-management 1.0.0-r2`,
`xg040g-kvm-support 0.1.0-r3`, `luci-app-one-kvm 20260710-r5`, and
`one-kvm 0.2.3-r4`.

## Network migration

- The schema migration backed up the previous configuration and created
  `br-lan` from `lan2`, `lan3`, and `eth1` (the 2.5G port).
- `lan4` is the sole member of `br-pxe`; no WAN interface or normal
  LAN-to-WAN forwarding remains.
- The stable management MAC is `02:4d:55:f5:04:0c` and the resulting hostname
  is `xg040g-f5040c`.
- A temporary DHCP server assigned `192.168.1.100`. The IPv4LL address and
  `avahi-autoipd` were removed while that lease was active.
- After the DHCP server was stopped and the lease was lost, the device waited
  for the configured grace period and reclaimed `169.254.6.204/16`. Management
  through the same `.local` identity and the link-local address was verified
  from the directly connected Windows host.
- The DHCP test server and its temporary Windows firewall rule were removed at
  the end of the run.

## PXE isolation

- dnsmasq binds DHCP, DNS and TFTP to `br-pxe`; it does not bind these services
  to the management bridge.
- A dedicated `xg040g-pxe-http` procd service listens on
  `10.40.0.1:8081` with `/mnt/kvmstore/netboot` as its document root. It does
  not expose LuCI, ubus or CGI.
- The initial use of `tftp-interface` was rejected by dnsmasq 2.93 and was
  replaced by the supported interface binding. The final source contains only
  the corrected form.
- LuCI successfully enabled `pxe -> lan` forwarding plus management-side
  masquerade, refreshed its displayed state, then disabled both again.
  `fw4 check` passed in each state. The device was left with
  `allow_uplink=0` and no `firewall.pxe_uplink` section.
- A physical LAN4 PXE client and an end-to-end BIOS/UEFI boot remain deferred.

## Recovery and LuCI

- Both build profiles set `CONFIG_TARGET_PREINIT_TIMEOUT=12`. Boot logging
  showed preinit selecting LAN2 first, matching the intended failsafe port.
  Entering failsafe with the physical button is still deferred.
- The One-KVM status page passed desktop and 390x844 mobile checks. Long
  hardware JSON now wraps without horizontal overflow.
- The reset dialog fits the mobile viewport, names all deleted data, keeps the
  confirmation button disabled until the acknowledgement is checked, and
  supports cancellation without changing data.
- A confirmed reset stopped One-KVM, recreated `/etc/one-kvm` as mode `0700`,
  preserved `/etc/config/one-kvm`, restarted the previously enabled service,
  and returned `needs_setup=true`.
- An RPC call without the literal confirmation value was rejected. A temporary
  custom data directory was also rejected before deletion, and the configured
  directory was restored to `/etc/one-kvm`.

## KVM and resource smoke tests

- The MS2109 remained available as two V4L2 nodes plus USB Audio.
- CH340 enumerated as `1a86:7523`, created `/dev/ttyUSB0`, and the hotplug rule
  created `/dev/ch9329`.
- One-KVM detected the CH9329 backend online at 9600 baud. An authenticated
  WebSocket test toggled Caps Lock on and back off and sent relative mouse
  movements `+3` and `-3` without serial or HID errors.
- `one-kvm-codec-check` initialized and encoded a 1280x720 frame with H.264,
  H.265, VP8, and VP9.
- One-KVM RSS remained about 21 MiB. The final snapshot had 145,952 KiB
  `MemAvailable`; overlay had 164.6 MiB free out of 169.6 MiB.
- Two xHCI controllers exposed four root hubs and `/sys/class/udc` remained
  empty, as required by the host-only profile.

## Deferred hardware checks

- USB3 `KVMSTORE` SuperSpeed link, automount and sustained I/O.
- Physical BIOS/UEFI PXE boot and packet capture on the management bridge.
- Real WebDAV authentication and transfer.
- Physical 2.5G link negotiation and cross-port throughput.
- Physical OpenWrt failsafe entry and tcboot Web U-Boot recovery.

The WebDAV and Hyper-V UEFI/BIOS PXE items were subsequently closed in
`hardware-validation-20260712-webdav-hyperv-pxe.md`. USB3 KVMSTORE remains the
release-blocking hardware item.

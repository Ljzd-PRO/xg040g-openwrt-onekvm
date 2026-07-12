# 2026-07-12 WebDAV and Hyper-V PXE validation

## Environment

- Remote host: Windows 11 with Hyper-V and WinFsp.
- WebDAV client: rclone v1.74.4, vendor `other`.
- PXE server: XG-040G-MD LAN4, `10.40.0.1/24`.
- PXE clients: Hyper-V Generation 2 UEFI and Generation 1 BIOS VMs on an
  external Intel I219-V switch.
- HTTP staging: Windows `10.40.0.2:8080`; XG TFTP and chain HTTP remained on
  `10.40.0.1`.
- Cloud credentials and `rclone.conf` are intentionally excluded.

## WebDAV results

- rclone successfully listed the account root and `/Downloads`.
- A 1 MiB random probe was uploaded, downloaded and deleted. Both copies had
  SHA256 `e519316195dcb62557f35fbb79769a9413e9df08fcdfbaee8983a9088d5b02d1`.
- Remote cleanup was verified.
- `Firpe 维护系统/FirPE-V2.0.3.img` was advertised as 1,073,741,824 bytes and
  downloaded in 78.7 seconds. Its local SHA256 is
  `f9ede7bea4f14fdbb318132d276b124c807db8b434a8bf27f10a8758d1755f4a`.
- WinFsp mounted `/Downloads` through `rclone mount`. The first MiB read via
  the mount and from the full local download both had SHA256
  `c1f403eaf6f887625b10e74df8ee3ed97e04cf62bf749f103e484f665b4ee6df`.

## Boot assets

- The FirPE image contains an MBR-partitioned 1 GiB FAT32 filesystem. DISM
  reports two valid WIM indexes: network mode and offline mode.
- FirPE's `11pex64.wim`, BCD, `boot.sdi` and `BOOTX64.EFI` matched the
  previously extracted cache byte for byte.
- The final FirPE chain uses wimboot 2.9.0, SHA256
  `5f067ccdc4d084d5bf77b6c853bd0f8402dfc2b4cd1b103d358993ae97fae8e3`.
- It uses the pinned minimal `PXEBCD`, SHA256
  `cdfbe2ed2be42e15ee4832f2c73893607db2ca4c95c34df9e0b61568845b4de2`.
- SystemRescue 13.01 amd64 ISO size was 1,357,627,392 bytes. Its SHA256
  matched the official value
  `56289b690bc87c85d2b9eb35790319b2d42cbdafbeae476b601dc0576b040b65`.
- `vmlinuz`, `sysresccd.img`, both CPU microcode images, `airootfs.sfs` and
  `airootfs.sha512` were served from the Windows staging root.

## FirPE findings

The first generic iPXE EFI returned to Hyper-V firmware. Rebuilding
`snponly.efi` with an embedded chain to the XG fixed UEFI SNP compatibility.

The FirPE image's generic BCD defaults to `\grldr`, and its custom WIM lacks a
boot manager at the paths from which wimboot can auto-extract one. wimboot
2.9.0 reported `FATAL: no bootloader file found`. The working configuration is:

- explicitly load FirPE's `bootmgfw.efi`;
- use the known minimal `PXEBCD` as virtual file `BCD`;
- expose `boot.sdi` and the selected WIM as virtual files `boot.sdi` and
  `boot.wim`;
- select FirPE network/offline images with `index=1` and `index=2`.

Both indexes reached the FirPE desktop in the Generation 2 VM. The final menu
defaults to network mode after ten seconds and keeps offline mode selectable.

## PXE results

- Generation 2 received `10.40.0.154`, fetched `ipxe.efi` by TFTP, fetched the
  XG chain script from port 8081, and loaded the Windows-hosted menu by HTTP.
- FirPE network mode and offline mode both reached their desktop.
- SystemRescue fetched the kernel, microcode, initramfs, 1.13 GiB squashfs and
  checksum, then reached its automatic root shell.
- A temporary, non-persistent SystemRescue SSH boot verified:
  - kernel `6.18.34-1-lts` on x86_64;
  - `eth0` at `10.40.0.154/24`;
  - 3.8 GiB total and 2.4 GiB available memory;
  - `/` mounted as the expected `airootfs` overlay.
- Generation 1 received `10.40.0.155`, fetched `undionly.kpxe`, chained by
  HTTP and displayed the same iPXE menu.

## Isolation and retained state

From SystemRescue, XG port 8081 and Windows staging port 8080 were reachable.
XG SSH, LuCI and One-KVM ports were blocked. An external ping returned
`Destination Net Unreachable`, confirming that PXE uplink remained disabled.

Both test VMs are stopped but retained, as is the external switch. The HTTP
staging scheduled task remains available because no USB3 KVMSTORE is currently
connected. The production menu was restored after testing; temporary root
password parameters and askpass files were removed.

## Deferred item

USB3 KVMSTORE link speed, ext4 auto-mount, sustained I/O and migration of the
HTTP assets from Windows to XG remain deferred until an external disk is
available. PXE itself is validated; its current large-file backend is Windows
HTTP staging rather than KVMSTORE.

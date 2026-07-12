# Cloud PXE without USB storage

The `onekvm` profile includes `xg040g-cloud-pxe`, a read-only HTTP data plane
backed by any rclone remote. LAN2, LAN3, or the 2.5G port reaches the upstream
network while LAN4 remains the isolated PXE port.

## Traffic flow

- DHCP and the small iPXE loader use LAN4 TFTP and `10.40.0.1:8081`.
- Cloud boot payloads use `rclone serve http` on `10.40.0.1:8083`.
- rclone reaches the provider through the management bridge, so PXE uplink/NAT
  may remain disabled.
- The data plane is read-only, uses no VFS disk cache, and is reachable only
  through the PXE firewall rule.

## Configuration

Open **Services > One-KVM > Cloud PXE**, paste a standard rclone INI file,
select a named path such as `kvmcloud:/Downloads`, and test it before enabling
the service. Multiple remote sections are accepted. Inline remotes are rejected
so credentials never become command-line arguments.

The configuration is stored at `/etc/xg040g/rclone.conf` with mode `0600` and
is preserved as a package conffile. It is outside `/etc/one-kvm`, so resetting
One-KVM data does not remove it.

## Remote layout

The active remote path is treated as the HTTP root and should contain:

```text
wimboot
firpe/PXEBCD
firpe/boot.sdi
firpe/bootmgfw.efi
firpe/boot.wim
systemrescue/sysresccd/...
```

Enabling Cloud PXE installs a managed selector and cloud menu under
`/mnt/kvmstore/netboot`. Disabling it makes the selector chain to the existing
`boot.ipxe`; that user-owned local menu is never overwritten.

The service uses a 4 MiB buffer, 16 MiB initial read chunks, a 64 MiB chunk
limit, and no persistent cache. Provider range-request quality and upstream
bandwidth determine boot reliability.

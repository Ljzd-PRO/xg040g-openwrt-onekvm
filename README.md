# XG-040G-MD OpenWrt One-KVM

Unofficial, reproducible OpenWrt firmware builds for the Nokia XG-040G-MD,
with a native One-KVM package and LuCI management page.

The project intentionally uses a host-only USB design. HDMI capture is expected
to use an MS2109 UVC adapter, while keyboard and mouse control use a
CH340/CH341 + CH9329 serial HID adapter. AN7581 USB gadget/UDC virtual media is
not enabled; PXE and USB3 storage provide the installation-media path instead.

## Current status

- OpenWrt tcboot boot, LuCI, SSH and four xHCI root hubs: verified.
- Native One-KVM binary and LuCI package installation: verified.
- MS2109 video, CH9329 HID and USB3 external-disk workflows: pending hardware.
- AN7581 MTU3/UDC experiments: archived as unsupported.

The first public firmware release is expected to be a prerelease until the
pending hardware paths have been exercised end to end.


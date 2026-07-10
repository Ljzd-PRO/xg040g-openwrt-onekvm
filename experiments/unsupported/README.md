# Unsupported AN7581 USB device-mode experiments

These patches are retained as community research and are not used by either
firmware profile or GitHub Actions.

Both AN7581 controller windows could register an MTU3 UDC, but diagnostic runs
reported `IP_DEV_CAP=0`, `CAP_EPINFO=0`, and zero Tx/Rx gadget endpoints. A
minimal HID gadget therefore failed to bind on both `usb0` and `usb1`.

The supported firmware design remains USB host-only. Do not apply these patches
to a device that needs the normal two-controller xHCI topology.


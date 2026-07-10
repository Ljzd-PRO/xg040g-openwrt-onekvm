# AN7581 MTU3 UDC probe experiment

This experiment tries to expose one AN7581 USB controller as a MediaTek MTU3
USB peripheral controller so `/sys/class/udc` can appear on XG-040G-MD.

The experiment keeps `usb1` as xHCI host and changes `usb0` to MTU3
peripheral-only, high-speed/USB2 first.

This directory is archival and is not connected to `scripts/build.sh`. The UDC
registered, but exposed zero usable gadget endpoints, so the route was
abandoned in favor of the host-only design.

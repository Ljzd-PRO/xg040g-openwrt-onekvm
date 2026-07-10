# AN7581 MTU3 endpoint diagnostic experiment

This experiment keeps the previous MTU3 UDC probe path, then adds read-only
diagnostic logging around the MTU3 MAC/IPPC resources and endpoint capability
registers.

Variants:

- `usb0` keeps `usb0` as MTU3 peripheral-only and `usb1` as xHCI host.
- `usb1` restores `usb0` as xHCI host and tries `usb1` as MTU3 peripheral-only.

The experiment intentionally avoids register writes outside the upstream MTU3
driver's normal init path. Its purpose is to explain why the current UDC reports
zero usable Tx/Rx endpoints before trying any riskier hardware-specific changes.

Observed result on both variants:

```text
IP_DEV_CAP=0x00000000
CAP_EPINFO=0x00000000
Tx endpoints=0
Rx endpoints=0
```

The UDC name appeared in sysfs, but HID binding failed with `-19`. No further
register-write experiments are included in this repository.

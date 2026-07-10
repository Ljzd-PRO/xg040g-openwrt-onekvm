#!/bin/sh
set -eu

gadget="/sys/kernel/config/usb_gadget/codex_udc_probe"

cleanup() {
	if [ -d "$gadget" ]; then
		if [ -f "$gadget/UDC" ]; then
			echo "" > "$gadget/UDC" 2>/dev/null || true
		fi
		rm -f "$gadget/configs/c.1/hid.usb0" 2>/dev/null || true
		rmdir "$gadget/functions/hid.usb0" 2>/dev/null || true
		rmdir "$gadget/configs/c.1/strings/0x409" 2>/dev/null || true
		rmdir "$gadget/configs/c.1" 2>/dev/null || true
		rmdir "$gadget/strings/0x409" 2>/dev/null || true
		rmdir "$gadget" 2>/dev/null || true
	fi
}

cleanup
trap cleanup EXIT

if ! grep -qs " /sys/kernel/config " /proc/mounts; then
	mount -t configfs none /sys/kernel/config
fi

udc="$(ls /sys/class/udc | head -n 1)"
if [ -z "$udc" ]; then
	echo "NO_UDC"
	exit 2
fi

mkdir -p "$gadget"
cd "$gadget"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

mkdir -p strings/0x409
echo "codex-an7581-diag" > strings/0x409/serialnumber
echo "Codex" > strings/0x409/manufacturer
echo "AN7581 HID probe" > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "HID probe" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower

mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
printf '\005\001\011\006\241\001\005\007\031\340\051\347\025\000\045\001\165\001\225\010\201\002\225\001\165\010\201\001\225\005\165\001\005\010\031\001\051\005\221\002\225\001\165\003\221\001\225\006\165\010\025\000\045\145\005\007\031\000\051\145\201\000\300' > functions/hid.usb0/report_desc

ln -s functions/hid.usb0 configs/c.1/
echo "$udc" > UDC

test -e /dev/hidg0
echo "BOUND_UDC=$udc"
ls -la /dev/hidg0

cleanup

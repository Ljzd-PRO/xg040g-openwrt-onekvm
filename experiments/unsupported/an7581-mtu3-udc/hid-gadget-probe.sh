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

trap cleanup EXIT INT TERM

grep -qs ' /sys/kernel/config ' /proc/mounts || mount -t configfs none /sys/kernel/config

udc="$(ls /sys/class/udc | head -n 1)"
if [ -z "$udc" ]; then
	echo "NO_UDC=1"
	exit 2
fi

cleanup
mkdir -p "$gadget"
cd "$gadget"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct
mkdir -p strings/0x409
echo 0123456789 > strings/0x409/serialnumber
echo Codex > strings/0x409/manufacturer
echo AN7581-UDC-Probe > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "Config 1" > configs/c.1/strings/0x409/configuration

mkdir -p functions/hid.usb0
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
printf '\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x01\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x01\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xc0' > functions/hid.usb0/report_desc

ln -s functions/hid.usb0 configs/c.1/
echo "$udc" > UDC
sleep 1

echo "BOUND_UDC=$udc"
ls -la /sys/class/udc
ls -la /dev/hidg* 2>/dev/null || true

if [ -e /dev/hidg0 ]; then
	echo "HIDG0_PRESENT=1"
else
	echo "HIDG0_PRESENT=0"
	exit 3
fi

#!/usr/bin/env bash
set -euo pipefail

profile="${1:?profile required}"
out_dir="${2:?output directory required}"
prefix="openwrt-airoha-an7581-nokia_xg-040g-md-tcboot"
manifest="$out_dir/$prefix.manifest"

required_files=(
	"$prefix-squashfs-factory.bin"
	"$prefix-squashfs-sysupgrade.bin"
	"$prefix-initramfs-uImage.itb"
	"$prefix.manifest"
	"SHA256SUMS.local"
	"BUILD-METADATA.json"
)

for file in "${required_files[@]}"; do
	test -s "$out_dir/$file" || {
		echo "Missing build output: $file" >&2
		exit 1
	}
done

(cd "$out_dir" && sha256sum -c SHA256SUMS.local)

required_packages=(luci luci-ssl dropbear uhttpd kmod-usb3)
if [[ "$profile" == "onekvm" ]]; then
	required_packages+=(one-kvm luci-app-one-kvm xg040g-kvm-support)
fi

for package in "${required_packages[@]}"; do
	grep -q "^${package} - " "$manifest" || {
		echo "Required package missing from manifest: $package" >&2
		exit 1
	}
done

for package in kmod-usb-mtu3 kmod-usb-gadget kmod-usb-gadget-hid kmod-usb-gadget-mass-storage; do
	if grep -q "^${package} - " "$manifest"; then
		echo "Forbidden host-only package present: $package" >&2
		exit 1
	fi
done

echo "Output verification passed for $profile"

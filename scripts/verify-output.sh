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

if [[ "$profile" == "onekvm" ]]; then
	required_files+=("APK-METADATA.json")
fi

for file in "${required_files[@]}"; do
	test -s "$out_dir/$file" || {
		echo "Missing build output: $file" >&2
		exit 1
	}
done

(cd "$out_dir" && sha256sum -c SHA256SUMS.local)

required_packages=(
	luci
	luci-ssl
	dropbear
	uhttpd
	kmod-usb3
	dnsmasq-full
	avahi-autoipd
	avahi-nodbus-daemon
	xg040g-switch-management
)
if [[ "$profile" == "onekvm" ]]; then
	required_packages+=(
		one-kvm
		luci-app-one-kvm
		luci-i18n-one-kvm-zh-cn
		xg040g-kvm-support
		xg040g-cloud-pxe
		xg040g-onekvm-runtime
		bash
		ttyd
		gostc
		easytier-core
		frpc
		luci-app-frpc
		luci-i18n-frpc-zh-cn
		kmod-tun
		kmod-video-uvc
		v4l-utils
		ustreamer
		usbutils
		dnsmasq-full
		block-mount
		kmod-usb-storage
		kmod-usb-storage-uas
		kmod-fs-ext4
		kmod-usb-serial-ch341
		rclone
		rclone-config
		fuse3-utils
		ca-bundle
		kmod-sound-core
		kmod-usb-audio
		alsa-lib
		alsa-utils
		libopus
		libyuv
		libx264
		libx265
		libvpx1.16
		libffmpeg-onekvm
		gpiod-tools
		kmod-hid
		kmod-hid-generic
		kmod-usb-hid
		kmod-usb-acm
		kmod-usb-serial-cp210x
		kmod-usb-serial-ftdi
		kmod-usb-serial-pl2303
	)
fi

for package in "${required_packages[@]}"; do
	grep -q "^${package} - " "$manifest" || {
		echo "Required package missing from manifest: $package" >&2
		exit 1
	}
done

if [[ "$profile" == "minimal" ]]; then
	for package in one-kvm luci-app-one-kvm xg040g-kvm-support; do
		if grep -q "^${package} - " "$manifest"; then
			echo "Full-profile package present in minimal image: $package" >&2
			exit 1
		fi
	done
fi

grep -q '^CONFIG_TARGET_PREINIT_TIMEOUT=12$' "$out_dir/config.buildinfo"
grep -q '^CONFIG_PACKAGE_xg040g-switch-management=y$' "$out_dir/config.buildinfo"

for package in \
	kmod-usb-mtu3 \
	kmod-usb-gadget \
	kmod-usb-gadget-hid \
	kmod-usb-gadget-mass-storage \
	usbgadget \
	libffmpeg-mini \
	libffmpeg-full
do
	if grep -q "^${package} - " "$manifest"; then
		echo "Forbidden host-only package present: $package" >&2
		exit 1
	fi
done

sysupgrade_size="$(wc -c < "$out_dir/$prefix-squashfs-sysupgrade.bin" | tr -d " ")"
if [[ "$profile" == "onekvm" && "$sysupgrade_size" -gt 83886080 ]]; then
	echo "One-KVM sysupgrade image exceeds the 80 MiB release gate: $sysupgrade_size bytes" >&2
	exit 1
fi

if [[ "$profile" == "onekvm" ]]; then
	for package in one-kvm luci-app-one-kvm luci-i18n-one-kvm-zh-cn; do
		apk_count="$(find "$out_dir/apk" -maxdepth 1 -type f -name "${package}-*.apk" -print | wc -l | tr -d " ")"
		if [[ "$apk_count" -ne 1 ]]; then
			echo "Expected exactly one exported APK for $package, found $apk_count." >&2
			exit 1
		fi
		grep -Fq "\"name\": \"$package\"" "$out_dir/APK-METADATA.json" || {
			echo "APK metadata is missing $package." >&2
			exit 1
		}
	done

	for symbol in kmod-usb-mtu3 kmod-usb-gadget kmod-usb-gadget-hid kmod-usb-gadget-mass-storage; do
		if grep -q "^CONFIG_PACKAGE_${symbol}=y$" "$out_dir/config.buildinfo"; then
			echo "Forbidden host-only config symbol enabled: CONFIG_PACKAGE_${symbol}" >&2
			exit 1
		fi
	done
	grep -q '^CONFIG_PACKAGE_libffmpeg-onekvm=y$' "$out_dir/config.buildinfo"
	grep -q '^CONFIG_PACKAGE_xg040g-onekvm-runtime=y$' "$out_dir/config.buildinfo"
fi

echo "Output verification passed for $profile"

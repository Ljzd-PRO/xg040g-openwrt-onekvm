#!/usr/bin/env bash
set -euo pipefail

profile="${1:?profile required}"
build_dir="${2:?build directory required}"
release_dir="${3:?release directory required}"
prefix="openwrt-airoha-an7581-nokia_xg-040g-md-tcboot"
asset_prefix="xg040g-$profile"

rm -rf "${release_dir:?}"
mkdir -p "$release_dir"

cp "$build_dir/$prefix-squashfs-factory.bin" "$release_dir/$asset_prefix-factory.bin"
cp "$build_dir/$prefix-squashfs-sysupgrade.bin" "$release_dir/$asset_prefix-sysupgrade.bin"
cp "$build_dir/$prefix-initramfs-uImage.itb" "$release_dir/$asset_prefix-initramfs.itb"
cp "$build_dir/$prefix.manifest" "$release_dir/$asset_prefix.manifest"
cp "$build_dir/BUILD-METADATA.json" "$release_dir/$asset_prefix-build-metadata.json"

if [[ "$profile" == "onekvm" ]]; then
	test -s "$build_dir/APK-METADATA.json"
	cp "$build_dir/APK-METADATA.json" "$release_dir/$asset_prefix-apk-metadata.json"
	mapfile -t apk_files < <(find "$build_dir/apk" -maxdepth 1 -type f -name '*.apk' -print | sort)
	if [[ "${#apk_files[@]}" -ne 3 ]]; then
		echo "Expected three standalone One-KVM APK assets, found ${#apk_files[@]}." >&2
		exit 1
	fi
	cp "${apk_files[@]}" "$release_dir/"
fi

for name in config.buildinfo feeds.buildinfo version.buildinfo profiles.json; do
	if [[ -s "$build_dir/$name" ]]; then
		cp "$build_dir/$name" "$release_dir/$asset_prefix-$name"
	fi
done

checksum_tmp="$(mktemp)"
trap 'rm -f "$checksum_tmp"' EXIT
(
	cd "$release_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > "$checksum_tmp"
)
mv "$checksum_tmp" "$release_dir/SHA256SUMS"

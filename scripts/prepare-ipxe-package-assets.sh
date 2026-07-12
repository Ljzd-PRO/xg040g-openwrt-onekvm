#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?package directory required}"
dl_dir="${2:?download cache required}"
commit='6ba010eaada9c089c92804969f9181d88d7ccc7c'
archive="$dl_dir/ipxe-$commit.tar.gz"
expected='ddb214a35ec68dc6c9419f314907b1b69ecddebe698c7a51f5bde11dceeb5d1c'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
asset_dir="$package_dir/xg040g-cloud-pxe/files/usr/share/xg040g-cloud-pxe"
efi_hash='4437f1fa12b365f3f85dd227a791db9b4ebed1ac0aa41eec832113af54cf4a77'
bios_hash='f94fe30630b89a647eb550a747e9390fe2f9d7463f29279ab958c689f99f6229'

verify_assets() {
	printf '%s  %s\n%s  %s\n' \
		"$efi_hash" "$asset_dir/ipxe.efi" \
		"$bios_hash" "$asset_dir/undionly.kpxe" | sha256sum -c -
}

if [[ "${REBUILD_IPXE:-0}" != '1' ]] && verify_assets; then
	exit 0
fi

if [[ "$(uname -m)" != 'x86_64' ]]; then
	echo 'Pinned iPXE assets are missing or invalid; regenerate them in the amd64 builder.' >&2
	exit 1
fi

if [[ ! -s "$archive" ]]; then
	curl -fL --retry 3 -o "$archive.tmp" "https://codeload.github.com/ipxe/ipxe/tar.gz/$commit"
	mv "$archive.tmp" "$archive"
fi
echo "$expected  $archive" | sha256sum -c -
tar -xzf "$archive" -C "$work"
source_dir="$work/ipxe-$commit/src"
embed="$work/embed.ipxe"
cat > "$embed" <<'EOF'
#!ipxe
dhcp
chain http://10.40.0.1:8081/boot-select.ipxe
EOF

make -C "$source_dir" -j"${JOBS:-4}" bin-x86_64-efi/snponly.efi EMBED="$embed"
make -C "$source_dir" -j"${JOBS:-4}" bin/undionly.kpxe EMBED="$embed"
install -m 0644 "$source_dir/bin-x86_64-efi/snponly.efi" "$asset_dir/ipxe.efi"
install -m 0644 "$source_dir/bin/undionly.kpxe" "$asset_dir/undionly.kpxe"
verify_assets

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$repo_root/dist/source-with-submodules.tar.zst}"
output_dir="$(dirname "$output")"
bundle_name="xg040g-openwrt-onekvm-source"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$output_dir" "$tmp/$bundle_name"
output_dir="$(cd "$output_dir" && pwd)"
output="$output_dir/$(basename "$output")"

"$repo_root/scripts/bootstrap.sh" --offline >/dev/null
git -C "$repo_root" archive HEAD | tar -x -C "$tmp/$bundle_name"

while IFS='|' read -r name path url commit _version; do
	[[ -n "$name" && "$name" != \#* ]] || continue
	rm -rf "$tmp/$bundle_name/$path"
	mkdir -p "$(dirname "$tmp/$bundle_name/$path")"
	git clone --quiet --no-hardlinks "$repo_root/$path" "$tmp/$bundle_name/$path"
	git -C "$tmp/$bundle_name/$path" remote set-url origin "$url"
	git -C "$tmp/$bundle_name/$path" checkout --quiet --detach "$commit"
done < "$repo_root/locks/sources.lock"

if tar --help 2>&1 | grep -q -- '--sort'; then
	epoch="$(git -C "$repo_root" show -s --format=%ct HEAD)"
	tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
		-C "$tmp" -cf - "$bundle_name" | zstd -T0 -19 -o "$output"
else
	tar -C "$tmp" -cf - "$bundle_name" | zstd -T0 -19 -o "$output"
fi

sha256sum "$output"


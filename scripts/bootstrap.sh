#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_file="$repo_root/locks/sources.lock"
offline=0

if [[ "${1:-}" == "--offline" ]]; then
	offline=1
elif [[ -n "${1:-}" ]]; then
	echo "Usage: $0 [--offline]" >&2
	exit 64
fi

if [[ ! -s "$lock_file" ]]; then
	echo "Missing source lock: $lock_file" >&2
	exit 1
fi

if [[ -d "$repo_root/.git" ]]; then
	if [[ "$offline" == "1" ]]; then
		git -C "$repo_root" submodule update --init --recursive --no-fetch
	else
		git -C "$repo_root" submodule update --init --recursive
	fi
fi

while IFS='|' read -r name path url commit version; do
	[[ -n "$name" && "$name" != \#* ]] || continue
	abs_path="$repo_root/$path"

	if [[ ! -e "$abs_path/.git" ]]; then
		if [[ "$offline" == "1" ]]; then
			echo "Source $name is missing in offline mode: $path" >&2
			exit 1
		fi
		mkdir -p "$abs_path"
		git -C "$abs_path" init
		git -C "$abs_path" remote add origin "$url"
		git -C "$abs_path" fetch --depth 1 origin "$commit"
		git -C "$abs_path" checkout --detach FETCH_HEAD
	fi

	actual="$(git -C "$abs_path" rev-parse HEAD)"
	if [[ "$actual" != "$commit" ]]; then
		echo "$name commit mismatch: expected $commit, got $actual" >&2
		exit 1
	fi

	printf '%s\t%s\t%s\n' "$name" "$actual" "$version"
done < "$lock_file"


#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

git diff --check
"$repo_root/scripts/bootstrap.sh" --offline >/dev/null

while IFS='|' read -r name path _url commit _version; do
	[[ -n "$name" && "$name" != \#* ]] || continue
	actual="$(git -C "$path" rev-parse HEAD)"
	recorded="$(git ls-tree HEAD "$path" | awk '{ print $3 }')"
	[[ "$actual" == "$commit" ]] || {
		echo "$name checkout does not match sources.lock" >&2
		exit 1
	}
	[[ "$recorded" == "$commit" ]] || {
		echo "$name gitlink does not match sources.lock" >&2
		exit 1
	}
	[[ -z "$(git -C "$path" status --porcelain --untracked-files=no)" ]] || {
		echo "$name submodule has tracked changes" >&2
		exit 1
	}
done < locks/sources.lock

if git ls-files | grep -E '(^|/)(output|backups|downloads|repos|session-pages|tmp-web)/|(^|/)cookies[^/]*|(^|/)tcboot\.bin$|(^|/)rclone\.conf$|\.(pem|key)$'; then
	echo "Forbidden private/generated path is tracked" >&2
	exit 1
fi

if git grep -nE 'api[.]day[.]app/|/Users/[^/]+/|[A-Za-z]:/Users/' -- . ':(exclude)scripts/validate.sh'; then
	echo "A private endpoint or user-specific absolute path is tracked" >&2
	exit 1
fi

bash -n scripts/*.sh
while IFS= read -r script; do
	sh -n "$script"
done < <(git ls-files 'package/*/files/*' | xargs grep -l '^#!/bin/sh' 2>/dev/null || true)

node --check package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git -C upstream/one-kvm archive HEAD | tar -x -C "$tmp"
for patch_file in package/one-kvm/patches/*.patch; do
	patch -d "$tmp" -p1 --dry-run < "$patch_file" >/dev/null
	patch -d "$tmp" -p1 < "$patch_file" >/dev/null
done

[[ "$(grep -c '^src-git ' locks/feeds.conf)" == "5" ]]
grep -Eq '^CONFIG_TARGET_airoha_an7581_DEVICE_nokia_xg-040g-md-tcboot=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-kvm-support=y$' configs/onekvm.config
grep -Eq '^PKG_LICENSE:=GPL-3.0-only$' package/one-kvm/Makefile
grep -Eq '^PKG_HASH:=74b90415bbd17803aa8d9a06b6f2c0ee91bdfe4407931c6c4cac037575e0a41f$' package/one-kvm/Makefile
test -s package/one-kvm/files/Cargo.lock

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck scripts/*.sh
	while IFS= read -r script; do
		shellcheck -s sh "$script"
	done < <(git ls-files 'package/*/files/*' | xargs grep -l '^#!/bin/sh' 2>/dev/null || true)
fi

if command -v actionlint >/dev/null 2>&1; then
	actionlint
fi

if command -v docker >/dev/null 2>&1; then
	case "$(uname -m)" in
		x86_64|amd64) platform=linux/amd64 ;;
		arm64|aarch64) platform=linux/arm64 ;;
		*) platform=linux/amd64 ;;
	esac
	docker build --check --platform "$platform" -f docker/Dockerfile docker >/dev/null
fi

echo "Repository validation passed"

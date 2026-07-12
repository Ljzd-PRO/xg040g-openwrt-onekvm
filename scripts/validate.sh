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
package_shell_scripts() {
	while IFS= read -r -d '' script; do
		IFS= read -r first_line < "$script" || true
		[[ "$first_line" == '#!/bin/sh' ]] && printf '%s\0' "$script"
	done < <(find package -type f -print0)
}

while IFS= read -r -d '' script; do
	sh -n "$script"
done < <(package_shell_scripts)

node --check package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js
jq empty package/luci-app-one-kvm/root/usr/share/luci/menu.d/luci-app-one-kvm.json
jq empty package/luci-app-one-kvm/root/usr/share/rpcd/acl.d/luci-app-one-kvm.json

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/one-kvm" "$tmp/openwrt" "$tmp/packages" "$tmp/luci"
git -C upstream/one-kvm archive HEAD | tar -x -C "$tmp/one-kvm"
git -C "$tmp/one-kvm" init -q
for patch_file in package/one-kvm/patches/*.patch; do
	git -C "$tmp/one-kvm" apply --check "$repo_root/$patch_file"
	git -C "$tmp/one-kvm" apply "$repo_root/$patch_file"
done

git -C upstream/openwrt archive HEAD \
	package/kernel/linux/modules/sound.mk \
	target/linux/airoha/an7581/base-files/etc/board.d/02_network | tar -x -C "$tmp/openwrt"
git -C "$tmp/openwrt" init -q
for patch_file in patches/openwrt/common/*.patch; do
	git -C "$tmp/openwrt" apply --check "$repo_root/$patch_file"
	git -C "$tmp/openwrt" apply "$repo_root/$patch_file"
done
for patch_file in patches/openwrt/onekvm/*.patch; do
	git -C "$tmp/openwrt" apply --check "$repo_root/$patch_file"
	git -C "$tmp/openwrt" apply "$repo_root/$patch_file"
done

packages_commit="$(awk '$1 == "src-git" && $2 == "packages" { split($3, parts, "\\^"); print parts[2] }' locks/feeds.conf)"
luci_commit="$(awk '$1 == "src-git" && $2 == "luci" { split($3, parts, "\\^"); print parts[2] }' locks/feeds.conf)"
git --git-dir=.cache/feeds/packages.git archive "$packages_commit" libs/libx264 net/frp utils/ttyd | tar -x -C "$tmp/packages"
git -C "$tmp/packages" init -q
for patch_file in patches/packages/onekvm/*.patch; do
	git -C "$tmp/packages" apply --check "$repo_root/$patch_file"
	git -C "$tmp/packages" apply "$repo_root/$patch_file"
done
git --git-dir=.cache/feeds/luci.git archive "$luci_commit" applications/luci-app-package-manager | tar -x -C "$tmp/luci"
git -C "$tmp/luci" init -q
for patch_file in patches/luci/onekvm/*.patch; do
	git -C "$tmp/luci" apply --check "$repo_root/$patch_file"
	git -C "$tmp/luci" apply "$repo_root/$patch_file"
done
# Debian dash rejects the upstream OpenWrt script's fd 200 redirection even
# though BusyBox ash accepts it. ShellCheck below still validates sh semantics.
bash -n "$tmp/luci/applications/luci-app-package-manager/root/usr/libexec/package-manager-call"

[[ "$(grep -c '^src-git ' locks/feeds.conf)" == "5" ]]
grep -Eq '^CONFIG_TARGET_airoha_an7581_DEVICE_nokia_xg-040g-md-tcboot=y$' configs/minimal.config
grep -Eq '^CONFIG_IMAGEOPT=y$' configs/minimal.config
grep -Eq '^CONFIG_PREINITOPT=y$' configs/minimal.config
grep -Eq '^CONFIG_TARGET_PREINIT_TIMEOUT=12$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_xg040g-switch-management=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-kvm-support=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-onekvm-runtime=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-switch-management=y$' configs/onekvm.config
grep -Eq '^CONFIG_IMAGEOPT=y$' configs/onekvm.config
grep -Eq '^CONFIG_PREINITOPT=y$' configs/onekvm.config
grep -Eq '^CONFIG_TARGET_PREINIT_TIMEOUT=12$' configs/onekvm.config
grep -Eq '^PKG_LICENSE:=GPL-3.0-only$' package/xg040g-switch-management/Makefile
grep -q "dhcp-userclass=set:kvm_ipxe,iPXE" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q "sha256_match=true" scripts/test-webdav.sh
grep -q "XG040G-PXE-UEFI-VERIFY" scripts/hyperv-pxe-lab.ps1
grep -q "XG040G-PXE-HTTP" scripts/windows-pxe-http.ps1
grep -q "VMConnect window not found" scripts/capture-vmconnect.ps1
grep -q "Start-VM -Name.*VmName" scripts/run-hyperv-pxe-boot.ps1
grep -q "Register-ScheduledTask.*TaskPrefix" scripts/register-vmconnect-tools.ps1
grep -q "wimboot/releases/download/v2.9.0/wimboot" scripts/prepare-firpe-ipxe-assets.ps1
grep -q "cdfbe2ed2be42e15ee4832f2c73893607db2ca4c95c34df9e0b61568845b4de2" scripts/prepare-firpe-ipxe-assets.ps1
grep -q "bin-x86_64-efi/snponly.efi" scripts/build-ipxe-embedded.sh
grep -q "rm -f bin/embedded.o bin/undionly.kpxe" scripts/build-ipxe-embedded.sh
grep -q "archisobasedir=systemrescue/sysresccd" docs/pxe-boot-menu.ipxe
grep -q 'kernel.*wimboot gui index=1' docs/pxe-boot-menu.ipxe
grep -q 'initrd -n boot.wim.*boot.wim' docs/pxe-boot-menu.ipxe
grep -q "list interface 'pxe'" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
if grep -q 'tftp-interface' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode; then
	echo 'Unsupported dnsmasq tftp-interface option is present.' >&2
	exit 1
fi
grep -q "procd_set_param command /usr/sbin/uhttpd" package/xg040g-switch-management/files/etc/init.d/xg040g-pxe-http
grep -q "args: { enabled: false }" package/luci-app-one-kvm/root/usr/share/rpcd/ucode/one-kvm.uc
grep -q "codeValue(hwcheck.output)" package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js
grep -q "option port '8082'" package/xg040g-kvm-support/files/etc/config/xg040g-kvm
grep -Eq '^CONFIG_PACKAGE_libffmpeg-onekvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_kmod-usb-audio=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_ttyd=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_gostc=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_easytier-core=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_frpc=y$' configs/onekvm.config
grep -Eq '^CONFIG_BUILD_PATENTED=y$' configs/onekvm.config
grep -Eq '^# CONFIG_PACKAGE_libffmpeg-mini is not set$' configs/onekvm.config
grep -Eq '^PKG_LICENSE:=GPL-3.0-only$' package/one-kvm/Makefile
grep -Eq '^PKG_HASH:=74b90415bbd17803aa8d9a06b6f2c0ee91bdfe4407931c6c4cac037575e0a41f$' package/one-kvm/Makefile
grep -Eq '^  DEPENDS:.*\+xg040g-onekvm-runtime' package/one-kvm/Makefile
grep -Eq '^PKG_HASH:=2a100487a4f3ccd27ad82132c4f8e6ac253c9696428f0d3fd4c53170e1c3682e$' package/gostc/Makefile
grep -Eq '^PKG_HASH:=df08c842f2ab2b8e9922f13c686a1d0f5a5219775cfdabb3e4a8599c6772201f$' package/easytier-core/Makefile
grep -Eq '^GOSTC_BINARY_HASH:=5d8ab3176d096a899604377f9a1f9b15a64b537fd4d3698dac4d49001960d4b6$' package/gostc/Makefile
grep -Eq '^EASYTIER_BINARY_HASH:=88fd4f8ec30b0766251578cdc82631eddc3710d6dd913547224a4afc34693d36$' package/easytier-core/Makefile
grep -q 'LicenseRef-GOSTC-Commons-Clause' package/gostc/Makefile
test -s package/easytier-core/files/COPYING
test ! -e package/one-kvm/patches/0002-openwrt-disable-audio.patch
test ! -e package/one-kvm/patches/0003-openwrt-ffmpeg-yuv-fallbacks.patch
test -s package/one-kvm/files/Cargo.lock

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck scripts/*.sh
	while IFS= read -r -d '' script; do
		shellcheck -s sh "$script"
	done < <(package_shell_scripts)
	shellcheck --severity=error -s sh "$tmp/luci/applications/luci-app-package-manager/root/usr/libexec/package-manager-call"
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

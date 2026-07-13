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
scripts/test-pxe-port-topology.sh
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
node --check package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/cloud-pxe.js
node --check package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/pxe.js
node --check package/luci-app-xg040g-performance/htdocs/luci-static/resources/view/xg040g-performance/overview.js
jq empty package/luci-app-one-kvm/root/usr/share/luci/menu.d/luci-app-one-kvm.json
jq empty package/luci-app-one-kvm/root/usr/share/rpcd/acl.d/luci-app-one-kvm.json
jq empty package/luci-app-xg040g-performance/root/usr/share/luci/menu.d/luci-app-xg040g-performance.json
jq empty package/luci-app-xg040g-performance/root/usr/share/rpcd/acl.d/luci-app-xg040g-performance.json
test -s docs/releases/v2026.07.13-rc1.md
grep -Fq '# v2026.07.13-rc1' docs/releases/v2026.07.13-rc1.md
grep -Fq 'workflow_dispatch:' .github/workflows/release.yml
# shellcheck disable=SC2016
grep -Fq 'docs/releases/$RELEASE_TAG.md' .github/workflows/release.yml
grep -Fq 'build_run_id:' .github/workflows/release.yml
if grep -Fq '*.{bin,itb}' .github/workflows/firmware.yml; then
	echo 'Firmware attestation paths must not use unsupported brace globs.' >&2
	exit 1
fi
# shellcheck disable=SC2016
grep -Fq 'release/${{ matrix.profile }}/*.bin' .github/workflows/firmware.yml
# shellcheck disable=SC2016
grep -Fq 'release/${{ matrix.profile }}/*.itb' .github/workflows/firmware.yml

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

prepare_feed_cache() {
	local name="$1"
	local source url commit cache_repo attempt

	source="$(awk -v feed="$name" '$1 == "src-git" && $2 == feed { print $3 }' locks/feeds.conf)"
	[[ -n "$source" && "$source" == *^* ]] || {
		echo "Feed $name is missing or not pinned in locks/feeds.conf" >&2
		return 1
	}
	url="${source%^*}"
	commit="${source##*^}"
	cache_repo="$repo_root/.cache/feeds/$name.git"

	if [[ ! -d "$cache_repo" ]]; then
		mkdir -p "$(dirname "$cache_repo")"
		git -c init.defaultBranch=main init --bare -q "$cache_repo"
	fi
	git --git-dir="$cache_repo" rev-parse --is-bare-repository >/dev/null 2>&1 || {
		echo "Feed cache is not a bare Git repository: $cache_repo" >&2
		return 1
	}

	if ! git --git-dir="$cache_repo" cat-file -e "${commit}^{commit}" 2>/dev/null; then
		if git --git-dir="$cache_repo" remote get-url origin >/dev/null 2>&1; then
			git --git-dir="$cache_repo" remote set-url origin "$url"
		else
			git --git-dir="$cache_repo" remote add origin "$url"
		fi

		for attempt in 1 2 3; do
			if git --git-dir="$cache_repo" -c http.lowSpeedLimit=1000 \
				-c http.lowSpeedTime=60 fetch --no-tags --depth=1 origin "$commit" \
				&& git --git-dir="$cache_repo" cat-file -e "${commit}^{commit}"; then
				break
			fi
			echo "Feed $name fetch attempt $attempt failed; retrying." >&2
			sleep "$((attempt * 5))"
		done
	fi

	git --git-dir="$cache_repo" cat-file -e "${commit}^{commit}" || {
		echo "Unable to prepare feed $name at $commit" >&2
		return 1
	}
	printf '%s\n' "$commit"
}

packages_commit="$(prepare_feed_cache packages)"
luci_commit="$(prepare_feed_cache luci)"
git --git-dir=.cache/feeds/packages.git archive "$packages_commit" libs/libx264 net/frp utils/ttyd | tar -x -C "$tmp/packages"
git -C "$tmp/packages" init -q
for patch_file in patches/packages/onekvm/*.patch; do
	git -C "$tmp/packages" apply --check "$repo_root/$patch_file"
	git -C "$tmp/packages" apply "$repo_root/$patch_file"
done
git --git-dir=.cache/feeds/luci.git archive "$luci_commit" \
	luci.mk \
	applications/luci-app-frpc \
	applications/luci-app-package-manager \
	modules/luci-mod-status | tar -x -C "$tmp/luci"
git -C "$tmp/luci" init -q
for patch_file in patches/luci/common/*.patch; do
	git -C "$tmp/luci" apply --check "$repo_root/$patch_file"
	git -C "$tmp/luci" apply "$repo_root/$patch_file"
done
for patch_file in patches/luci/onekvm/*.patch; do
	git -C "$tmp/luci" apply --check "$repo_root/$patch_file"
	git -C "$tmp/luci" apply "$repo_root/$patch_file"
done
# Debian dash rejects the upstream OpenWrt script's fd 200 redirection even
# though BusyBox ash accepts it. ShellCheck below still validates sh semantics.
bash -n "$tmp/luci/applications/luci-app-package-manager/root/usr/libexec/package-manager-call"
node --check "$tmp/luci/applications/luci-app-frpc/htdocs/luci-static/resources/view/frpc.js"
jq empty "$tmp/luci/applications/luci-app-frpc/root/usr/share/luci/menu.d/luci-app-frpc.json"
node --check "$tmp/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/29_ports.js"
grep -q 'const seen_ports = new Set()' \
	"$tmp/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/29_ports.js"

[[ "$(grep -c '^src-git ' locks/feeds.conf)" == "5" ]]
grep -Eq '^CONFIG_TARGET_airoha_an7581_DEVICE_nokia_xg-040g-md-tcboot=y$' configs/minimal.config
grep -Eq '^CONFIG_IMAGEOPT=y$' configs/minimal.config
grep -Eq '^CONFIG_PREINITOPT=y$' configs/minimal.config
grep -Eq '^CONFIG_TARGET_PREINIT_TIMEOUT=12$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_xg040g-switch-management=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_kmod-airoha-an7581-oc=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_xg040g-performance=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_luci-app-xg040g-performance=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_luci-i18n-xg040g-performance-zh-cn=y$' configs/minimal.config
grep -Eq '^CONFIG_PACKAGE_one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-one-kvm=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-frpc=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-i18n-frpc-zh-cn=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-kvm-support=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-cloud-pxe=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-onekvm-runtime=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-switch-management=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-monitoring-defaults=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_kmod-airoha-an7581-oc=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_xg040g-performance=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-xg040g-performance=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-i18n-xg040g-performance-zh-cn=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-app-statistics=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_luci-i18n-statistics-zh-cn=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_collectd-mod-thermal=y$' configs/onekvm.config
grep -Eq '^CONFIG_IMAGEOPT=y$' configs/onekvm.config
grep -Eq '^CONFIG_PREINITOPT=y$' configs/onekvm.config
grep -Eq '^CONFIG_TARGET_PREINIT_TIMEOUT=12$' configs/onekvm.config
grep -Eq '^PKG_LICENSE:=GPL-3.0-only$' package/xg040g-switch-management/Makefile
grep -Eq '^PKG_LICENSE:=GPL-2.0-only$' package/kmod-airoha-an7581-oc/Makefile
grep -Eq '^PKG_LICENSE:=GPL-3.0-only$' package/xg040g-performance/Makefile
grep -Eq '^PKG_LICENSE:=Apache-2.0$' package/luci-app-xg040g-performance/Makefile
grep -q 'nokia,xg-040g-md-tcboot' package/kmod-airoha-an7581-oc/src/airoha-an7581-oc.c
grep -q 'Loading this module never changes' package/kmod-airoha-an7581-oc/Makefile
grep -q "option overclock '0'" package/xg040g-performance/files/etc/config/xg040g-performance
grep -q "option frequency '1200'" package/xg040g-performance/files/etc/config/xg040g-performance
grep -q "option thermal_revert '85'" package/xg040g-performance/files/etc/config/xg040g-performance
grep -q "option thermal_emergency '95'" package/xg040g-performance/files/etc/config/xg040g-performance
grep -q "network.@globals\[0\].packet_steering=2" package/xg040g-performance/files/etc/uci-defaults/30-xg040g-performance-defaults
grep -q "0 | 1 | 2" package/xg040g-performance/files/etc/uci-defaults/30-xg040g-performance-defaults
grep -q "option packet_steering '\$packet_steering'" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q '/etc/init.d/packet_steering restart' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q "option port 'none'" package/xg040g-switch-management/files/etc/config/xg040g-management
grep -q "SCHEMA_VERSION='2'" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q $'\treturn 0' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q "if \[ \"\$reload\" = '1' \]; then" package/xg040g-switch-management/files/usr/sbin/xg040g-pxe-uplink
grep -q 'allow-interfaces=br-lan' package/xg040g-switch-management/files/etc/uci-defaults/25-xg040g-avahi-management-only
grep -q 'ucidef_set_interface_lan "lan2 lan3 lan4 eth1" dhcp' patches/openwrt/common/0001-airoha-xg040g-switch-pxe-default.patch
grep -q 'set-pxe-port <none|lan2|lan3|lan4|eth1>' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q 'start-stop-daemon -S -b' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
if grep -q 'nohup' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode; then
	echo 'PXE deferred reload must not depend on a separately packaged nohup binary.' >&2
	exit 1
fi
grep -q "dhcp-userclass=set:kvm_ipxe,iPXE" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q 'boot-select.ipxe' package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q "dest_port '8083'" package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode
grep -q -- '--read-only' package/xg040g-cloud-pxe/files/etc/init.d/xg040g-cloud-pxe
grep -q -- '--vfs-cache-mode off' package/xg040g-cloud-pxe/files/etc/init.d/xg040g-cloud-pxe
grep -q 'hexdump -v' package/xg040g-cloud-pxe/files/usr/sbin/xg040g-cloud-pxe
grep -q "commit='6ba010eaada9c089c92804969f9181d88d7ccc7c'" scripts/prepare-ipxe-package-assets.sh
grep -q "efi_hash='4437f1fa12b365f3f85dd227a791db9b4ebed1ac0aa41eec832113af54cf4a77'" scripts/prepare-ipxe-package-assets.sh
grep -q "bios_hash='f94fe30630b89a647eb550a747e9390fe2f9d7463f29279ab958c689f99f6229'" scripts/prepare-ipxe-package-assets.sh
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
grep -q "args: { port: 'port', confirm: 'confirm' }" package/luci-app-one-kvm/root/usr/share/rpcd/ucode/one-kvm.uc
grep -q "method: 'set_pxe_port'" package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/pxe.js
grep -q "codeValue(hwcheck.output)" package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js
for msgid in 'Start' 'Stop' 'Restart' 'Enable boot' 'Disable boot' 'Running' 'Stopped'; do
	grep -Fq "msgid \"$msgid\"" package/luci-app-one-kvm/po/zh_Hans/one-kvm.po
done
grep -q "option port '8082'" package/xg040g-kvm-support/files/etc/config/xg040g-kvm
grep -q "set luci_statistics.collectd_thermal.enable='1'" \
	package/xg040g-monitoring-defaults/files/90-xg040g-monitoring
grep -q "set luci_statistics.collectd_rrdtool.DataDir='/tmp/rrd'" \
	package/xg040g-monitoring-defaults/files/90-xg040g-monitoring
for interface in br-lan br-pxe eth1 lan2 lan3 lan4; do
	grep -q "add_list luci_statistics.collectd_interface.Interfaces='$interface'" \
		package/xg040g-monitoring-defaults/files/90-xg040g-monitoring
done
grep -q 'xg040g.performance' package/luci-app-xg040g-performance/root/usr/share/rpcd/acl.d/luci-app-xg040g-performance.json
grep -q 'OVERCLOCK' package/luci-app-xg040g-performance/htdocs/luci-static/resources/view/xg040g-performance/overview.js
for forbidden in xg040g-switchd 'CONFIG_PACKAGE_tc-full=y' 'CONFIG_PACKAGE_irqbalance=y'; do
	if grep -Fq "$forbidden" configs/minimal.config configs/onekvm.config; then
		echo "Unsupported switch optimization is enabled: $forbidden" >&2
		exit 1
	fi
done
grep -Eq '^CONFIG_PACKAGE_libffmpeg-onekvm=y$' configs/onekvm.config
grep -Eq '^PKG_RELEASE:=4$' package/xg040g-cloud-pxe/Makefile
# shellcheck disable=SC2016
grep -Fq ': > $(1)/etc/xg040g/rclone.conf' package/xg040g-cloud-pxe/Makefile
test ! -e package/xg040g-cloud-pxe/files/etc/xg040g/rclone.conf
grep -Eq '^CONFIG_PACKAGE_kmod-usb-audio=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_ttyd=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_gostc=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_easytier-core=y$' configs/onekvm.config
grep -Eq '^CONFIG_PACKAGE_frpc=y$' configs/onekvm.config
# shellcheck disable=SC2016
grep -q 'INSTALL_CONF.*files/$(2).config.*etc/config/$(2)' "$tmp/packages/net/frp/Makefile"
# shellcheck disable=SC2016
grep -q 'INSTALL_BIN.*files/$(2).init.*etc/init.d/$(2)' "$tmp/packages/net/frp/Makefile"
grep -q "frpc_luci_exists: frpcLuci" package/luci-app-one-kvm/root/usr/share/rpcd/ucode/one-kvm.uc
grep -q "frpcManagementButton(status)" package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js
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

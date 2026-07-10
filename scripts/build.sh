#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-}"

if [[ -z "$profile" ]]; then
	echo "Usage: $0 <minimal|onekvm> [options]" >&2
	exit 64
fi
shift

source_mode="isolated"
jobs=""
out_dir=""
incremental=0
offline=0
allow_dirty=0
build_verbosity="${BUILD_VERBOSITY:-s}"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--source-mode)
			source_mode="${2:?missing source mode}"
			shift 2
			;;
		--jobs)
			jobs="${2:?missing jobs value}"
			shift 2
			;;
		--output)
			out_dir="${2:?missing output path}"
			shift 2
			;;
		--incremental)
			incremental=1
			shift
			;;
		--offline)
			offline=1
			shift
			;;
		--allow-dirty)
			allow_dirty=1
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 64
			;;
	esac
done

case "$profile" in
	minimal)
		config_file="$repo_root/configs/minimal.config"
		with_local_packages=0
		;;
	onekvm)
		config_file="$repo_root/configs/onekvm.config"
		with_local_packages=1
		;;
	*)
		echo "Unknown profile: $profile" >&2
		exit 64
		;;
esac

case "$source_mode" in
	isolated|direct) ;;
	*)
		echo "Source mode must be isolated or direct" >&2
		exit 64
		;;
esac

if [[ "$profile" == "onekvm" && "$source_mode" == "direct" ]]; then
	echo "The onekvm profile applies isolated source/feed patches and requires --source-mode isolated." >&2
	exit 1
fi

case "$build_verbosity" in
	s|sc|c) ;;
	*)
		echo "BUILD_VERBOSITY must be s, sc, or c" >&2
		exit 64
		;;
esac

if [[ "$source_mode" == "direct" && "$(uname -s)" == "Darwin" ]]; then
	echo "Direct mode is unavailable on the default case-insensitive macOS filesystem; use isolated mode." >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "Docker is required." >&2
	exit 1
fi

if [[ "$offline" == "1" ]]; then
	"$repo_root/scripts/bootstrap.sh" --offline
else
	"$repo_root/scripts/bootstrap.sh"
fi

if [[ "$allow_dirty" != "1" ]]; then
	while IFS='|' read -r name path _url _commit _version; do
		[[ -n "$name" && "$name" != \#* ]] || continue
		if [[ -n "$(git -C "$repo_root/$path" status --porcelain --untracked-files=no)" ]]; then
			echo "Tracked changes found in submodule $path; use --allow-dirty only for local development." >&2
			exit 1
		fi
	done < "$repo_root/locks/sources.lock"
fi

if [[ -z "$jobs" ]]; then
	if command -v nproc >/dev/null 2>&1; then
		jobs="$(nproc)"
	else
		jobs="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
	fi
fi

case "$(uname -m)" in
	x86_64|amd64) platform="linux/amd64"; arch_tag="amd64" ;;
	arm64|aarch64) platform="linux/arm64"; arch_tag="arm64" ;;
	*) echo "Unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
esac

docker_host_path() {
	case "$(uname -s)" in
		MINGW*|MSYS*|CYGWIN*) cygpath -aw "$1" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) export MSYS2_ARG_CONV_EXCL='*' ;;
esac

timestamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${out_dir:-$repo_root/output/$profile-$timestamp}"
mkdir -p "$out_dir" "$repo_root/.cache/dl" "$repo_root/.cache/dl/npm" "$repo_root/.cache/feeds"
out_dir="$(cd "$out_dir" && pwd)"

builder_image="${BUILDER_IMAGE:-xg040g-openwrt-builder:ubuntu24.04-$arch_tag}"
if [[ "${SKIP_BUILDER_BUILD:-0}" == "1" ]]; then
	if ! docker image inspect "$builder_image" >/dev/null 2>&1; then
		echo "SKIP_BUILDER_BUILD=1 requested, but image is missing: $builder_image" >&2
		exit 1
	fi
	echo "Reusing existing builder image: $builder_image"
else
	docker build --platform "$platform" -t "$builder_image" \
		-f "$(docker_host_path "$repo_root/docker/Dockerfile")" \
		"$(docker_host_path "$repo_root/docker")"
fi

docker_args=(
	--rm
	--platform "$platform"
	-e "PROFILE=$profile"
	-e "JOBS=$jobs"
	-e "SOURCE_MODE=$source_mode"
	-e "INCREMENTAL=$incremental"
	-e "OFFLINE=$offline"
	-e "WITH_LOCAL_PACKAGES=$with_local_packages"
	-e "BUILD_VERBOSITY=$build_verbosity"
	-e "CONFIG_FILE=/project/${config_file#"$repo_root/"}"
	-e FORCE_UNSAFE_CONFIGURE=1
	-v "$(docker_host_path "$repo_root"):/project:ro"
	-v "$(docker_host_path "$repo_root/.cache/dl"):/dl"
	-v "$(docker_host_path "$repo_root/.cache/feeds"):/feed-cache"
	-v "$(docker_host_path "$out_dir"):/out"
)

if [[ "$source_mode" == "isolated" ]]; then
	if [[ -n "${WORK_DIR:-}" ]]; then
		mkdir -p "$WORK_DIR"
		work_dir="$(cd "$WORK_DIR" && pwd)"
		docker_args+=( -v "$(docker_host_path "$work_dir"):/work" )
	else
		work_volume="${WORK_VOLUME:-xg040g-openwrt-$profile-work}"
		docker volume create "$work_volume" >/dev/null
		docker_args+=( -v "$work_volume:/work" )
	fi
else
	docker_args+=( -v "$(docker_host_path "$repo_root/upstream/openwrt"):/work/openwrt" )
fi

docker run "${docker_args[@]}" "$builder_image" bash -lc '
	set -euo pipefail

	for safe_dir in \
		/project \
		/project/upstream/openwrt \
		/project/upstream/one-kvm \
		/project/.git/modules/upstream/openwrt \
		/project/.git/modules/upstream/one-kvm
	do
		git config --global --add safe.directory "$safe_dir"
	done

	openwrt_commit="$(grep "^openwrt|" /project/locks/sources.lock | cut -d"|" -f4)"
	one_kvm_commit="$(grep "^one-kvm|" /project/locks/sources.lock | cut -d"|" -f4 || true)"

	if [[ "$SOURCE_MODE" == "isolated" ]]; then
		if [[ ! -d /work/openwrt/.git ]]; then
			rm -rf /work/openwrt
			git clone --no-hardlinks /project/upstream/openwrt /work/openwrt
		fi
		cd /work/openwrt
		git fetch --no-tags /project/upstream/openwrt "$openwrt_commit"
		git checkout -f --detach "$openwrt_commit"
		git reset --hard "$openwrt_commit"
		if [[ "$INCREMENTAL" == "1" ]]; then
			git clean -xfd -e build_dir -e staging_dir
		else
			git clean -xfd
		fi
	else
		cd /work/openwrt
		test "$(git rev-parse HEAD)" = "$openwrt_commit"
	fi

	apply_patch_series() {
		local tree="$1"
		local series_dir="$2"
		local patch_file

		[[ -d "$series_dir" ]] || return 0
		while IFS= read -r patch_file; do
			echo "Applying profile patch: ${patch_file#/project/}"
			patch -d "$tree" -p1 --forward < "$patch_file"
		done < <(find "$series_dir" -maxdepth 1 -type f -name "*.patch" | sort)
	}

	if [[ "$PROFILE" == "onekvm" ]]; then
		apply_patch_series /work/openwrt /project/patches/openwrt/onekvm
	fi

	cleanup_direct() {
		if [[ "$SOURCE_MODE" == "direct" ]]; then
			rm -rf package/xg040g-local feeds.conf
		fi
	}
	trap cleanup_direct EXIT

	if [[ "$INCREMENTAL" == "1" ]]; then
		rm -rf bin tmp logs .config feeds package/feeds dl
	else
		rm -rf build_dir staging_dir bin tmp logs .config feeds package/feeds dl
	fi
	ln -s /dl dl

	prepare_feed_cache() {
		local name="$1"
		local url="$2"
		local commit="$3"
		local cache_repo="/feed-cache/${name}.git"
		local attempt

		if [[ ! -d "$cache_repo" ]]; then
			mkdir -p "$cache_repo"
			git init --bare "$cache_repo" >/dev/null
		fi

		if git --git-dir="$cache_repo" cat-file -e "${commit}^{commit}" 2>/dev/null; then
			return 0
		fi
		if [[ "$OFFLINE" == "1" ]]; then
			echo "Feed $name commit $commit is missing from the offline cache." >&2
			return 1
		fi

		if git --git-dir="$cache_repo" remote get-url origin >/dev/null 2>&1; then
			git --git-dir="$cache_repo" remote set-url origin "$url"
		else
			git --git-dir="$cache_repo" remote add origin "$url"
		fi

		for attempt in 1 2 3; do
			if git --git-dir="$cache_repo" -c http.lowSpeedLimit=1000 \
				-c http.lowSpeedTime=60 fetch --no-tags --depth=1 origin "$commit" \
				&& git --git-dir="$cache_repo" cat-file -e "${commit}^{commit}"; then
				return 0
			fi
			echo "Feed $name fetch attempt $attempt failed; retrying." >&2
			sleep "$((attempt * 5))"
		done

		echo "Unable to cache feed $name at $commit." >&2
		return 1
	}

	: > feeds.conf
	while read -r kind name source; do
		[[ -n "$kind" && "$kind" != \#* ]] || continue
		[[ "$kind" == "src-git" ]] || {
			echo "Unsupported feed type in locks/feeds.conf: $kind" >&2
			exit 1
		}
		url="${source%^*}"
		commit="${source##*^}"
		[[ "$url" != "$source" && -n "$commit" ]] || {
			echo "Feed $name is not pinned to a commit." >&2
			exit 1
		}
		prepare_feed_cache "$name" "$url" "$commit"
		printf "src-git %s file:///feed-cache/%s.git^%s\n" "$name" "$name" "$commit" >> feeds.conf
	done < /project/locks/feeds.conf

	./scripts/feeds update -a
	if [[ "$PROFILE" == "onekvm" ]]; then
		apply_patch_series /work/openwrt/feeds/packages /project/patches/packages/onekvm
		apply_patch_series /work/openwrt/feeds/luci /project/patches/luci/onekvm
	fi
	cp /project/locks/feeds.conf feeds.conf
	./scripts/feeds install -a -f

	if [[ "$WITH_LOCAL_PACKAGES" == "1" ]]; then
		test -d /project/package
		rm -rf package/xg040g-local
		mkdir -p package/xg040g-local
		cp -a /project/package/. package/xg040g-local/
		find package/xg040g-local -type f -path "*/files/etc/init.d/*" -exec chmod 0755 {} +
		find package/xg040g-local -type f -path "*/files/etc/uci-defaults/*" -exec chmod 0755 {} +
		find package/xg040g-local -type f -path "*/files/usr/bin/*" -exec chmod 0755 {} +
		find package/xg040g-local -type f -path "*/files/usr/sbin/*" -exec chmod 0755 {} +

		test -n "$one_kvm_commit"
		one_kvm_version="$(sed -n "s/^PKG_VERSION:=//p" /project/package/one-kvm/Makefile)"
		one_kvm_subdir="$(sed -n "s/^PKG_SOURCE_SUBDIR:=//p" /project/package/one-kvm/Makefile)"
		test -n "$one_kvm_version"
		test -n "$one_kvm_subdir"
		one_kvm_archive="/dl/one-kvm-${one_kvm_version}.tar.gz"
		one_kvm_archive_tmp="${one_kvm_archive}.tmp.$$"
		git -C /project/upstream/one-kvm archive \
			--format=tar --prefix="${one_kvm_subdir}/" "$one_kvm_commit" \
			| gzip -n -9 > "$one_kvm_archive_tmp"
		mv "$one_kvm_archive_tmp" "$one_kvm_archive"
	fi

	cp "$CONFIG_FILE" .config
	make defconfig
	cp .config /out/config.after-defconfig
	git rev-parse HEAD > /out/source-commit.txt

	make download -j"$JOBS" \
		ONE_KVM_CARGO_OFFLINE="$OFFLINE" \
		ONE_KVM_NPM_OFFLINE="$OFFLINE"
	/usr/bin/time -v make -j"$JOBS" \
		ONE_KVM_CARGO_OFFLINE="$OFFLINE" \
		ONE_KVM_NPM_OFFLINE="$OFFLINE" \
		"V=$BUILD_VERBOSITY" 2>&1 | tee /out/build.log

	target_dir="bin/targets/airoha/an7581"
	prefix="openwrt-airoha-an7581-nokia_xg-040g-md-tcboot"
	test -d "$target_dir"
	mapfile -t manifest_files < <(find "$target_dir" -maxdepth 1 -type f \
		-name "openwrt-airoha-an7581-*.manifest" -print)
	if [[ "${#manifest_files[@]}" -ne 1 ]]; then
		echo "Expected exactly one target manifest, found ${#manifest_files[@]}." >&2
		exit 1
	fi
	cp -a "$target_dir"/"$prefix"-* /out/
	cp -a "${manifest_files[0]}" "/out/$prefix.manifest"
	cp -a "$target_dir"/*.buildinfo "$target_dir"/profiles.json "$target_dir"/sha256sums /out/

	if [[ "$PROFILE" == "onekvm" ]]; then
		mkdir -p /out/apk
		apk_records="/out/apk/.records.jsonl"
		: > "$apk_records"
		for package_name in one-kvm luci-app-one-kvm luci-i18n-one-kvm-zh-cn; do
			mapfile -t package_files < <(find bin/packages -type f -name "${package_name}-*.apk" -print)
			if [[ "${#package_files[@]}" -ne 1 ]]; then
				echo "Expected exactly one APK for $package_name, found ${#package_files[@]}." >&2
				exit 1
			fi
			apk_file="${package_files[0]}"
			apk_base="$(basename "$apk_file")"
			cp -a "$apk_file" "/out/apk/$apk_base"
			apk_version="${apk_base#${package_name}-}"
			apk_version="${apk_version%.apk}"
			apk_size="$(wc -c < "$apk_file" | tr -d " ")"
			apk_sha256="$(sha256sum "$apk_file" | cut -d" " -f1)"
			jq -n \
				--arg name "$package_name" \
				--arg version "$apk_version" \
				--arg file "apk/$apk_base" \
				--arg sha256 "$apk_sha256" \
				--argjson bytes "$apk_size" \
				"{name:\$name,version:\$version,file:\$file,bytes:\$bytes,sha256:\$sha256}" \
				>> "$apk_records"
		done
		jq -s \
			--arg runtime_abi "xg040g-onekvm-runtime-v1" \
			"{runtime_abi:\$runtime_abi,packages:.}" \
			"$apk_records" > /out/APK-METADATA.json
		rm -f "$apk_records"
	fi

	project_commit="$(git -C /project rev-parse HEAD 2>/dev/null || echo source-archive)"
	factory_bytes="$(wc -c < "/out/$prefix-squashfs-factory.bin" | tr -d " ")"
	sysupgrade_bytes="$(wc -c < "/out/$prefix-squashfs-sysupgrade.bin" | tr -d " ")"
	initramfs_bytes="$(wc -c < "/out/$prefix-initramfs-uImage.itb" | tr -d " ")"
	jq -n \
		--arg profile "$PROFILE" \
		--arg project_commit "$project_commit" \
		--arg openwrt_commit "$openwrt_commit" \
		--arg one_kvm_commit "$one_kvm_commit" \
		--arg source_mode "$SOURCE_MODE" \
		--arg platform "$(uname -m)" \
		--arg jobs "$JOBS" \
		--argjson factory_bytes "$factory_bytes" \
		--argjson sysupgrade_bytes "$sysupgrade_bytes" \
		--argjson initramfs_bytes "$initramfs_bytes" \
		"{profile:\$profile,project_commit:\$project_commit,openwrt_commit:\$openwrt_commit,one_kvm_commit:\$one_kvm_commit,source_mode:\$source_mode,builder_arch:\$platform,jobs:(\$jobs|tonumber),firmware:{factory_bytes:\$factory_bytes,sysupgrade_bytes:\$sysupgrade_bytes,initramfs_bytes:\$initramfs_bytes}}" \
		> /out/BUILD-METADATA.json

	(
		cd /out
		checksum_files=( "$prefix"-* "$prefix.manifest" BUILD-METADATA.json )
		if [[ "$PROFILE" == "onekvm" ]]; then
			checksum_files+=( APK-METADATA.json apk/*.apk )
		fi
		sha256sum "${checksum_files[@]}" > SHA256SUMS.local
	)
'

"$repo_root/scripts/verify-output.sh" "$profile" "$out_dir"
echo "Build complete: $out_dir"

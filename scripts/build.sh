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

timestamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${out_dir:-$repo_root/output/$profile-$timestamp}"
mkdir -p "$out_dir" "$repo_root/.cache/dl"
out_dir="$(cd "$out_dir" && pwd)"

builder_image="${BUILDER_IMAGE:-xg040g-openwrt-builder:ubuntu24.04-$arch_tag}"
docker build --platform "$platform" -t "$builder_image" -f "$repo_root/docker/Dockerfile" "$repo_root/docker"

docker_args=(
	--rm
	--platform "$platform"
	-e "PROFILE=$profile"
	-e "JOBS=$jobs"
	-e "SOURCE_MODE=$source_mode"
	-e "INCREMENTAL=$incremental"
	-e "WITH_LOCAL_PACKAGES=$with_local_packages"
	-e "CONFIG_FILE=/project/${config_file#"$repo_root/"}"
	-e FORCE_UNSAFE_CONFIGURE=1
	-v "$repo_root:/project:ro"
	-v "$repo_root/.cache/dl:/dl"
	-v "$out_dir:/out"
)

if [[ "$source_mode" == "isolated" ]]; then
	if [[ -n "${WORK_DIR:-}" ]]; then
		mkdir -p "$WORK_DIR"
		work_dir="$(cd "$WORK_DIR" && pwd)"
		docker_args+=( -v "$work_dir:/work" )
	else
		work_volume="${WORK_VOLUME:-xg040g-openwrt-$profile-work}"
		docker volume create "$work_volume" >/dev/null
		docker_args+=( -v "$work_volume:/work" )
	fi
else
	docker_args+=( -v "$repo_root/upstream/openwrt:/work/openwrt" )
fi

docker run "${docker_args[@]}" "$builder_image" bash -lc '
	set -euo pipefail

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

	cleanup_direct() {
		if [[ "$SOURCE_MODE" == "direct" ]]; then
			rm -rf package/xg040g-local git-src/one-kvm feeds.conf
		fi
	}
	trap cleanup_direct EXIT

	if [[ "$INCREMENTAL" == "1" ]]; then
		rm -rf bin tmp logs .config feeds package/feeds dl
	else
		rm -rf build_dir staging_dir bin tmp logs .config feeds package/feeds dl
	fi
	ln -s /dl dl
	cp /project/locks/feeds.conf feeds.conf

	./scripts/feeds update -a
	./scripts/feeds install -a -f

	if [[ "$WITH_LOCAL_PACKAGES" == "1" ]]; then
		test -d /project/package
		rm -rf package/xg040g-local
		mkdir -p package/xg040g-local
		cp -a /project/package/. package/xg040g-local/
		find package/xg040g-local -type f -path "*/files/etc/init.d/*" -exec chmod 0755 {} +
		find package/xg040g-local -type f -path "*/files/usr/bin/*" -exec chmod 0755 {} +
		find package/xg040g-local -type f -path "*/files/usr/sbin/*" -exec chmod 0755 {} +

		test -n "$one_kvm_commit"
		rm -rf git-src/one-kvm
		mkdir -p git-src
		git clone --no-checkout --no-hardlinks /project/upstream/one-kvm git-src/one-kvm
		git -C git-src/one-kvm checkout --detach "$one_kvm_commit"
	fi

	cp "$CONFIG_FILE" .config
	make defconfig
	cp .config /out/config.after-defconfig
	git rev-parse HEAD > /out/source-commit.txt

	make download -j"$JOBS"
	/usr/bin/time -v make -j"$JOBS" V=sc 2>&1 | tee /out/build.log

	target_dir="bin/targets/airoha/an7581"
	prefix="openwrt-airoha-an7581-nokia_xg-040g-md-tcboot"
	test -d "$target_dir"
	cp -a "$target_dir"/"$prefix"-* /out/
	cp -a "$target_dir"/"$prefix".manifest /out/
	cp -a "$target_dir"/*.buildinfo "$target_dir"/profiles.json "$target_dir"/sha256sums /out/

	project_commit="$(git -C /project rev-parse HEAD 2>/dev/null || echo source-archive)"
	jq -n \
		--arg profile "$PROFILE" \
		--arg project_commit "$project_commit" \
		--arg openwrt_commit "$openwrt_commit" \
		--arg one_kvm_commit "$one_kvm_commit" \
		--arg source_mode "$SOURCE_MODE" \
		--arg platform "$(uname -m)" \
		--arg jobs "$JOBS" \
		"{profile:\$profile,project_commit:\$project_commit,openwrt_commit:\$openwrt_commit,one_kvm_commit:\$one_kvm_commit,source_mode:\$source_mode,builder_arch:\$platform,jobs:(\$jobs|tonumber)}" \
		> /out/BUILD-METADATA.json

	(cd /out && sha256sum "$prefix"-* > SHA256SUMS.local)
'

"$repo_root/scripts/verify-output.sh" "$profile" "$out_dir"
echo "Build complete: $out_dir"

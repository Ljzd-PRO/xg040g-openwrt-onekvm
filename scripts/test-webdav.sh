#!/bin/sh
set -eu

STORE="${KVMSTORE:-/mnt/kvmstore}"
CONF="${RCLONE_CONFIG_FILE:-$STORE/secrets/rclone.conf}"
REMOTE="${KVM_RCLONE_REMOTE:-kvmcloud:}"
ROOT="${KVM_WEBDAV_ROOT:-/Downloads}"
PROBE_DIR="${KVM_WEBDAV_PROBE_DIR:-XG040G-WebDAV-Test}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="/tmp/xg040g-webdav-$STAMP"
REMOTE_ROOT="${REMOTE%/}${ROOT}"
REMOTE_PROBE="$REMOTE_ROOT/$PROBE_DIR/$STAMP"
if grep -qs " $STORE " /proc/mounts; then
	LOG_DIR="${KVM_WEBDAV_LOG_DIR:-$STORE/logs}"
else
	LOG_DIR="${KVM_WEBDAV_LOG_DIR:-/tmp}"
fi
LOG="$LOG_DIR/webdav-test-$STAMP.log"

case "$REMOTE" in
	*:) ;;
	*) echo "KVM_RCLONE_REMOTE must end with a colon" >&2; exit 64 ;;
esac

[ -s "$CONF" ] || { echo "Missing rclone config: $CONF" >&2; exit 2; }

mkdir -p "$WORK" "$LOG_DIR"
chmod 700 "$WORK"

cleanup() {
	rclone --config "$CONF" deletefile "$REMOTE_PROBE/upload.bin" >/dev/null 2>&1 || true
	rclone --config "$CONF" rmdir "$REMOTE_PROBE" >/dev/null 2>&1 || true
	rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

echo "Writing WebDAV test details to $LOG"
exec >>"$LOG" 2>&1

echo "timestamp=$STAMP"
echo "remote_root=$REMOTE_ROOT"
echo "rclone_version=$(rclone version | sed -n '1p')"
echo "listing_begin"
rclone --config "$CONF" lsf --max-depth 2 "$REMOTE_ROOT"
echo "listing_end"

dd if=/dev/urandom of="$WORK/upload.bin" bs=1024 count=1024 2>/dev/null
UPLOAD_SHA256="$(sha256sum "$WORK/upload.bin" | awk '{print $1}')"

rclone --config "$CONF" mkdir "$REMOTE_PROBE"
rclone --config "$CONF" copyto --retries 3 --low-level-retries 10 \
	"$WORK/upload.bin" "$REMOTE_PROBE/upload.bin"
rclone --config "$CONF" copyto --retries 3 --low-level-retries 10 \
	"$REMOTE_PROBE/upload.bin" "$WORK/download.bin"

DOWNLOAD_SHA256="$(sha256sum "$WORK/download.bin" | awk '{print $1}')"
[ "$UPLOAD_SHA256" = "$DOWNLOAD_SHA256" ] || {
	echo "sha256_match=false"
	exit 4
}

rclone --config "$CONF" deletefile "$REMOTE_PROBE/upload.bin"
rclone --config "$CONF" rmdir "$REMOTE_PROBE"

echo "upload_sha256=$UPLOAD_SHA256"
echo "download_sha256=$DOWNLOAD_SHA256"
echo "sha256_match=true"
echo "cleanup_verified=true"
echo "log=$LOG"

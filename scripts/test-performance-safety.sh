#!/bin/sh
set -eu

root="$(cd -- "$(dirname "$0")/.." && pwd)"
cpuctl="$root/package/xg040g-performance/files/usr/sbin/xg040g-cpuctl"
rpc="$root/package/xg040g-performance/files/usr/libexec/rpcd/xg040g.performance"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/bin" "$tmp/state" "$tmp/thermal/thermal_zone0"
cat > "$tmp/jshn.sh" <<'EOF'
json_init() { : "$JSON_UNSET"; }
json_add_boolean() { :; }
json_add_string() { :; }
json_add_int() { :; }
json_add_object() { :; }
json_close_object() { :; }
json_add_array() { :; }
json_close_array() { :; }
json_dump() { echo '{"status":"ok"}'; }
EOF
printf '%s\n' airoha_thermal > "$tmp/thermal/thermal_zone0/type"
printf '%s\n' 45000 > "$tmp/thermal/thermal_zone0/temp"

cat > "$tmp/bin/uci" <<'EOF'
#!/bin/sh
case "$*" in
	*"get xg040g-performance.cpu.frequency"*) echo 1200 ;;
	*"get xg040g-performance.cpu.overclock"*) echo 0 ;;
	*"get xg040g-performance.cpu.thermal_revert"*) echo 85 ;;
	*"get xg040g-performance.cpu.thermal_emergency"*) echo 95 ;;
	*"get network.@globals[0]"*) exit 1 ;;
	*"set network.globals=globals"*|*"set network.globals.packet_steering=2"*|*"commit network"*) exit 0 ;;
	*"batch"*) cat >/dev/null ;;
	*) exit 1 ;;
esac
EOF

cat > "$tmp/bin/rpc-cpuctl" <<'EOF'
#!/bin/sh
echo '{"status":"ok"}'
EOF

cat > "$tmp/bin/packet-steering" <<'EOF'
#!/bin/sh
exit 0
EOF

cat > "$tmp/bin/jsonfilter" <<'EOF'
#!/bin/sh
input="$(cat)"
case "$*" in
	*'@.mode'*) printf '%s\n' "$input" | sed -n 's/.*"mode":[[:space:]]*\([0-9][0-9]*\).*/\1/p' ;;
esac
EOF

cat > "$tmp/bin/modprobe" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$XG040G_TEST_MODPROBE_LOG"
case "$1" in
	-r)
		rm -rf "$XG040G_TEST_SYSFS"
		;;
	airoha-an7581-oc)
		mkdir -p "$XG040G_TEST_SYSFS"
		printf '%s\n' 1200 > "$XG040G_TEST_SYSFS/actual_mhz"
		printf '%s\n' 1200 > "$XG040G_TEST_SYSFS/requested_mhz"
		printf '%s\n' 0 > "$XG040G_TEST_SYSFS/allow_overclock"
		printf '%s\n' 0 > "$XG040G_TEST_SYSFS/last_error"
		;;
esac
exit 0
EOF

cat > "$tmp/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF

chmod +x "$tmp/bin/uci" "$tmp/bin/modprobe" "$tmp/bin/logger" \
	"$tmp/bin/rpc-cpuctl" "$tmp/bin/packet-steering" "$tmp/bin/jsonfilter"

run_cpuctl() {
	PATH="$tmp/bin:$PATH" \
	XG040G_CPU_SYSFS="$tmp/no-pll-sysfs" \
	XG040G_CPU_POLICY="$tmp/no-cpufreq" \
	XG040G_THERMAL_ROOT="$tmp/thermal" \
	XG040G_PERFORMANCE_STATE_DIR="$tmp/state" \
	XG040G_LEGACY_ACTIVE="$tmp/legacy-active" \
	XG040G_CPU_LOCK_DIR="$tmp/cpuctl.lock" \
	XG040G_JSHN_LIB="$tmp/jshn.sh" \
	XG040G_TEST_MODPROBE_LOG="$tmp/modprobe.log" \
	XG040G_TEST_SYSFS="$tmp/no-pll-sysfs" \
		sh "$cpuctl" "$@"
}

run_cpuctl apply-config
run_cpuctl set 1200
run_cpuctl restore-stock
run_cpuctl status | grep -q '"status":"ok"'

printf '{"mode":2}' | PATH="$tmp/bin:$PATH" \
	XG040G_CPUCTL="$tmp/bin/rpc-cpuctl" \
	XG040G_PACKET_STEERING_INIT="$tmp/bin/packet-steering" \
	sh "$rpc" call set_steering | grep -q '"status":"ok"'

printf '%s\n' 1400 > "$tmp/state/cpu-overclock-active"
run_cpuctl apply-config
[ ! -e "$tmp/state/cpu-overclock-active" ]

if [ -s "$tmp/modprobe.log" ]; then
	echo 'stock startup or recovery unexpectedly loaded the PLL module' >&2
	cat "$tmp/modprobe.log" >&2
	exit 1
fi

if run_cpuctl set 1300 >/dev/null 2>&1; then
	echo 'mocked overclock unexpectedly passed its readback check' >&2
	exit 1
fi
grep -qx 'airoha-an7581-oc' "$tmp/modprobe.log"
grep -qx -- '-r airoha-an7581-oc' "$tmp/modprobe.log"

if grep -q 'AUTOLOAD' "$root/package/kmod-airoha-an7581-oc/Makefile"; then
	echo 'PLL module must not be auto-loaded' >&2
	exit 1
fi

grep -q 'unexpected PLL readback' \
	"$root/package/kmod-airoha-an7581-oc/src/airoha-an7581-oc.c"
grep -q 'actual == 1300 || actual == 1400' \
	"$root/package/kmod-airoha-an7581-oc/src/airoha-an7581-oc.c"
grep -q 'pll_driver_loaded' "$cpuctl"

echo 'performance stock-path safety tests passed'

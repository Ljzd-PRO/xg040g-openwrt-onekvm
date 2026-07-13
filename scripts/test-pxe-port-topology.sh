#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
network_mode="$repo_root/package/xg040g-switch-management/files/usr/sbin/xg040g-network-mode"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

uci() {
	case "$*" in
		*-q\ get\ xg040g-management.main.management_mac*) printf '%s\n' '02:12:34:56:78:9a' ;;
		*-q\ get\ xg040g-management.main.hostname*) printf '%s\n' 'xg040g-56789a' ;;
		*-q\ get\ network.globals.packet_steering*|*-q\ get\ network.@globals\[0\].packet_steering*)
			[[ "${TEST_PACKET_STEERING:-missing}" != missing ]] || return 1
			printf '%s\n' "$TEST_PACKET_STEERING"
			;;
		*) return 1 ;;
	esac
}

export XG040G_NETWORK_MODE_LIBRARY=1
# shellcheck source=/dev/null
source "$network_mode"

fail() {
	echo "PXE topology test failed: $*" >&2
	exit 1
}

assert_line() {
	grep -Fqx "$2" "$1" || fail "missing '$2' in $1"
}

assert_absent() {
	if grep -Fq "$2" "$1"; then
		fail "unexpected '$2' in $1"
	fi
}

join_lines() {
	awk 'BEGIN { first = 1 } { gsub(/\r/, ""); if (!first) printf " "; printf "%s", $0; first = 0 } END { print "" }'
}

for steering in 0 1 2 invalid missing; do
	TEST_PACKET_STEERING="$steering"
	expected_steering="$steering"
	case "$steering" in invalid|missing) expected_steering=2 ;; esac
	for pxe_port in none lan2 lan3 lan4 eth1; do
		dir="$tmp/$steering-$pxe_port"
		mkdir -p "$dir"
		write_network "$dir/network" "$pxe_port"
		write_dhcp "$dir/dhcp" "$pxe_port"
		write_firewall "$dir/firewall" "$pxe_port"
		assert_line "$dir/network" "$(printf "\toption packet_steering '%s'" "$expected_steering")"

		memberships="$(awk '$1 == "list" && $2 == "ports" { gsub(/\047/, "", $3); print $3 }' "$dir/network" | sort | join_lines)"
		[[ "$memberships" == 'eth1 lan2 lan3 lan4' ]] || fail "$pxe_port does not assign every physical port exactly once"

		lan_ports="$(awk '
			$1 == "config" && $2 == "device" { section = $3 }
			section == "\047br_lan\047" && $1 == "list" && $2 == "ports" { gsub(/\047/, "", $3); print $3 }
		' "$dir/network" | sort | join_lines)"

		if [[ "$pxe_port" == none ]]; then
			[[ "$lan_ports" == 'eth1 lan2 lan3 lan4' ]] || fail 'default bridge does not contain all four ports'
			assert_absent "$dir/network" "config device 'br_pxe'"
			assert_absent "$dir/network" "config interface 'pxe'"
			assert_absent "$dir/dhcp" "config dhcp 'pxe'"
			assert_absent "$dir/dhcp" "option enable_tftp '1'"
			assert_absent "$dir/firewall" "config zone 'pxe'"
		else
			expected="$(printf '%s\n' eth1 lan2 lan3 lan4 | grep -Fxv "$pxe_port" | sort | join_lines)"
			[[ "$lan_ports" == "$expected" ]] || fail "$pxe_port remains in br-lan"
			assert_line "$dir/network" "$(printf "\tlist ports '%s'" "$pxe_port")"
			assert_line "$dir/network" "config interface 'pxe'"
			assert_line "$dir/dhcp" "config dhcp 'pxe'"
			assert_line "$dir/dhcp" "$(printf "\toption enable_tftp '1'")"
			assert_line "$dir/firewall" "config zone 'pxe'"
		fi
	done
done

for invalid in '' lan1 'lan2 lan3' '../eth1' 'lan4;reboot'; do
	if valid_pxe_port "$invalid"; then
		fail "invalid PXE port was accepted: $invalid"
	fi
done

echo 'PXE_PORT_TOPOLOGY_TEST=PASS'

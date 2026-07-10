#!/usr/bin/env ucode
'use strict';

import { popen, access } from 'fs';
import { init_enabled, init_action } from 'luci.sys';

function shellquote(s) {
	return `'${replace(s, "'", "'\\''")}'`;
}

function fileExists(path) {
	return !!access(path);
}

function execCommand(cmd) {
	let pp = popen(cmd, 'r');
	if (!pp)
		return null;

	let output = pp.read('all');
	pp.close();
	return output ? trim(output) : null;
}

function validPort(value) {
	if (type(value) != 'string' || !match(value, /^[0-9]+$/))
		return '8080';

	let port = int(value);
	return port >= 1 && port <= 65535 ? '' + port : '8080';
}

const methods = {
	get_status: {
		call: function() {
			let pid = execCommand("pidof one-kvm 2>/dev/null | cut -d' ' -f1");
			let configEnabled = execCommand("uci -q get one-kvm.main.enabled || echo 0");
			let port = validPort(execCommand("uci -q get one-kvm.main.http_port || echo 8080"));
			let listen = execCommand("netstat -ltn 2>/dev/null | grep -Fq -- " + shellquote(':' + port + ' ') + " && echo 1 || echo 0");
			let udcCount = execCommand("find /sys/class/udc -mindepth 1 -maxdepth 1 2>/dev/null | wc -l");

			return {
				pid: pid,
				running: pid != null && pid != '',
				config_enabled: configEnabled == '1',
				binary_exists: fileExists('/usr/bin/one-kvm'),
				boot_enabled: init_enabled('one-kvm'),
				http_port: port,
				listening: listen == '1',
				video0_exists: fileExists('/dev/video0'),
				ch9329_exists: fileExists('/dev/ch9329'),
				host_only: udcCount == '0'
			};
		}
	},

	get_version: {
		call: function() {
			return {
				version: fileExists('/usr/bin/one-kvm') ? execCommand(shellquote('/usr/bin/one-kvm') + ' --version 2>&1') : null
			};
		}
	},

	get_hwcheck: {
		call: function() {
			return {
				output: fileExists('/usr/sbin/one-kvm-hwcheck') ? execCommand('/usr/sbin/one-kvm-hwcheck 2>&1') : null
			};
		}
	},

	service_action: {
		args: { action: 'action' },
		call: function(req) {
			let action = req && req.args ? req.args.action : '';
			const valid = ['start', 'stop', 'restart', 'reload', 'enable', 'disable'];

			if (index(valid, action) < 0)
				return { success: false, error: 'Invalid action' };

			let result = init_action('one-kvm', action);
			return { success: result === 0, action: action, exit_code: result };
		}
	}
};

return { 'luci.one-kvm': methods };

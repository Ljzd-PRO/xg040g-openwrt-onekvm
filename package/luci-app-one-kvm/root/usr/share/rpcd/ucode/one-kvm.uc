#!/usr/bin/env ucode
'use strict';

import { popen, access, readfile, writefile, unlink } from 'fs';
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

function binaryVersion(path) {
	return fileExists(path) ? execCommand(shellquote(path) + ' --version 2>&1') : null;
}

function fileHash(path) {
	return fileExists(path) ? execCommand('sha256sum ' + shellquote(path) + " 2>/dev/null | cut -d' ' -f1") : null;
}

function packageVersion(name) {
	let output = execCommand('apk query --fields name,version --format json --installed ' + shellquote(name) + ' 2>/dev/null');
	if (!output)
		return null;

	try {
		let records = json(output);
		if (type(records) == 'array' && length(records) > 0 && records[0].version)
			return records[0].version;
	} catch (e) {
		return null;
	}

	return null;
}

function validPort(value) {
	if (type(value) != 'string' || !match(value, /^[0-9]+$/))
		return '8080';

	let port = int(value);
	return port >= 1 && port <= 65535 ? '' + port : '8080';
}

function cloudPxeCall(action, config, remotePath, enabled) {
	let temp = null;
	if (config != null) {
		if (type(config) != 'string' || length(config) > 65536)
			return { success: false, error: 'config_too_large' };
		temp = execCommand('mktemp /tmp/xg040g-cloud-pxe-rpc.XXXXXX');
		if (!temp)
			return { success: false, error: 'temporary_file_failed' };
		writefile(temp, config);
		execCommand('chmod 0600 ' + shellquote(temp));
	}

	let cmd = '/usr/sbin/xg040g-cloud-pxe ' + action;
	if (config != null)
		cmd += ' ' + shellquote(temp) + ' ' + shellquote(remotePath || '');
	if (action == 'save')
		cmd += ' ' + (enabled ? '1' : '0');
	let output = execCommand(cmd + ' 2>&1');
	if (temp != null)
		unlink(temp);
	return {
		success: output != null && match(output, /(VALID|SAVED|CLEARED)=1/) != null,
		output: output
	};
}

const methods = {
	get_status: {
		call: function() {
			let pid = execCommand("pidof one-kvm 2>/dev/null | cut -d' ' -f1");
			let frpcPid = execCommand("pidof frpc 2>/dev/null | cut -d' ' -f1");
			let frpcBinary = fileExists('/usr/bin/frpc');
			let frpcInit = fileExists('/etc/init.d/frpc');
			let frpcConfig = fileExists('/etc/config/frpc');
			let frpcLuci = fileExists('/www/luci-static/resources/view/frpc.js') &&
				fileExists('/usr/share/luci/menu.d/luci-app-frpc.json');
			let configEnabled = execCommand("uci -q get one-kvm.main.enabled || echo 0");
			let port = validPort(execCommand("uci -q get one-kvm.main.http_port || echo 8080"));
			let listen = execCommand("netstat -ltn 2>/dev/null | grep -Fq -- " + shellquote(':' + port + ' ') + " && echo 1 || echo 0");
			let udcCount = execCommand("find /sys/class/udc -mindepth 1 -maxdepth 1 2>/dev/null | wc -l");
			let dataDir = execCommand("uci -q get one-kvm.main.data_dir || echo /etc/one-kvm");
			let pxeUplink = execCommand("uci -q get xg040g-management.pxe.allow_uplink || echo 0");

			return {
				pid: pid,
				running: pid != null && pid != '',
				config_enabled: configEnabled == '1',
				binary_exists: fileExists('/usr/bin/one-kvm'),
				boot_enabled: init_enabled('one-kvm'),
				http_port: port,
				listening: pid != null && pid != '' && listen == '1',
				video0_exists: fileExists('/dev/video0'),
				ch9329_exists: fileExists('/dev/ch9329'),
				host_only: udcCount == '0',
				data_dir: dataDir,
				reset_supported: dataDir == '/etc/one-kvm',
				pxe_uplink: pxeUplink == '1',
				pxe_address: '10.40.0.1',
				pxe_http_port: '8081',
				frpc_binary_exists: frpcBinary,
				frpc_init_exists: frpcInit,
				frpc_config_exists: frpcConfig,
				frpc_luci_exists: frpcLuci,
				frpc_available: frpcBinary && frpcInit && frpcConfig && frpcLuci,
				frpc_running: frpcPid != null && frpcPid != '',
				frpc_boot_enabled: frpcInit ? init_enabled('frpc') : false
			};
		}
	},

	get_version: {
		call: function() {
			return {
				version: binaryVersion('/usr/bin/one-kvm')
			};
		}
	},

	get_versions: {
		call: function() {
			let runtimePath = '/usr/bin/one-kvm';
			let romPath = '/rom/usr/bin/one-kvm';
			let runtimeExists = fileExists(runtimePath);
			let romExists = fileExists(romPath);
			let runtimeHash = fileHash(runtimePath);
			let romHash = fileHash(romPath);
			let differs = runtimeExists && romExists && runtimeHash != null && romHash != null && runtimeHash != romHash;
			let matchesRom = runtimeExists && romExists && runtimeHash != null && romHash != null && runtimeHash == romHash;

			return {
				runtime_version: binaryVersion(runtimePath),
				installed_version: packageVersion('one-kvm'),
				rom_version: binaryVersion(romPath),
				luci_version: packageVersion('luci-app-one-kvm'),
				runtime_abi_version: packageVersion('xg040g-onekvm-runtime'),
				runtime_sha256: runtimeHash,
				rom_sha256: romHash,
				runtime_exists: runtimeExists,
				rom_exists: romExists,
				matches_rom: matchesRom,
				differs_from_rom: differs,
				overlay_override: romExists && (!runtimeExists || differs),
				recovery_available: romExists
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
	},

	restore_firmware_binary: {
		call: function() {
			if (!fileExists('/usr/sbin/one-kvm-restore-firmware'))
				return { success: false, error: 'Recovery helper is missing' };

			let output = execCommand('/usr/sbin/one-kvm-restore-firmware 2>&1');
			let success = output != null && match(output, /(^|\n)RESTORE_OK=1($|\n)/) != null;
			return {
				success: success,
				output: output,
				error: success ? null : 'Firmware binary restore failed'
			};
		}
	},

	set_pxe_uplink: {
		args: { enabled: false },
		call: function(req) {
			let value = req && req.args ? req.args.enabled : null;
			let enable = value === true || value == 1 || value == '1';
			let disable = value === false || value == 0 || value == '0';
			if (!enable && !disable)
				return { success: false, error: 'Invalid PXE uplink value' };

			let action = enable ? 'enable' : 'disable';
			let output = execCommand('/usr/sbin/xg040g-pxe-uplink ' + action + ' 2>&1');
			let state = execCommand("uci -q get xg040g-management.pxe.allow_uplink || echo 0");
			return {
				success: state == (enable ? '1' : '0'),
				enabled: state == '1',
				output: output
			};
		}
	},

	get_cloud_pxe: {
		call: function() {
			let enabled = execCommand("uci -q get xg040g-kvm.cloud_pxe.enabled || echo 0");
			let remotePath = execCommand("uci -q get xg040g-kvm.cloud_pxe.remote_path || true");
			let running = execCommand("netstat -ltn 2>/dev/null | grep -Fq '10.40.0.1:8083' && echo 1 || echo 0");
			return {
				enabled: enabled == '1',
				running: running == '1',
				remote_path: remotePath || '',
				config: readfile('/etc/xg040g/rclone.conf') || '',
				address: 'http://10.40.0.1:8083'
			};
		}
	},

	test_cloud_pxe_config: {
		args: { config: 'config', remote_path: 'remote_path' },
		call: function(req) {
			let args = req && req.args ? req.args : {};
			return cloudPxeCall('test', args.config, args.remote_path, false);
		}
	},

	save_cloud_pxe: {
		args: { config: 'config', remote_path: 'remote_path', enabled: false },
		call: function(req) {
			let args = req && req.args ? req.args : {};
			return cloudPxeCall('save', args.config, args.remote_path, args.enabled === true || args.enabled == 1);
		}
	},

	cloud_pxe_action: {
		args: { action: 'action' },
		call: function(req) {
			let action = req && req.args ? req.args.action : '';
			if (index(['start', 'stop', 'restart'], action) < 0)
				return { success: false, error: 'invalid_action' };
			let result = init_action('xg040g-cloud-pxe', action);
			return { success: result === 0, action: action, exit_code: result };
		}
	},

	clear_cloud_pxe: {
		args: { confirm: 'confirm' },
		call: function(req) {
			let confirm = req && req.args ? req.args.confirm : '';
			if (confirm != 'CLEAR')
				return { success: false, error: 'confirmation_required' };
			let output = execCommand('/usr/sbin/xg040g-cloud-pxe clear CLEAR 2>&1');
			return { success: output != null && match(output, /CLEARED=1/) != null, output: output };
		}
	},

	reset_data: {
		args: { confirm: 'confirm' },
		call: function(req) {
			let confirmation = req && req.args ? req.args.confirm : null;
			if (confirmation != 'RESET')
				return { success: false, error: 'Confirmation is required' };
			if (!fileExists('/usr/sbin/one-kvm-reset-data'))
				return { success: false, error: 'Reset helper is missing' };

			let output = execCommand('/usr/sbin/one-kvm-reset-data 2>&1');
			let success = output != null && match(output, /(^|\n)RESET_OK=1($|\n)/) != null;
			return {
				success: success,
				output: output,
				error: success ? null : 'One-KVM data reset failed'
			};
		}
	}
};

return { 'luci.one-kvm': methods };

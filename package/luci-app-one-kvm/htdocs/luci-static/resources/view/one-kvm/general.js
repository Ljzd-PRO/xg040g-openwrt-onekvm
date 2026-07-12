'use strict';
'require view';
'require form';
'require rpc';
'require poll';
'require uci';
'require ui';

const callGetStatus = rpc.declare({
	object: 'luci.one-kvm',
	method: 'get_status'
});

const callGetVersions = rpc.declare({
	object: 'luci.one-kvm',
	method: 'get_versions'
});

const callGetHwcheck = rpc.declare({
	object: 'luci.one-kvm',
	method: 'get_hwcheck'
});

const callServiceAction = rpc.declare({
	object: 'luci.one-kvm',
	method: 'service_action',
	params: ['action']
});

const callRestoreFirmwareBinary = rpc.declare({
	object: 'luci.one-kvm',
	method: 'restore_firmware_binary'
});

const callSetPxeUplink = rpc.declare({
	object: 'luci.one-kvm',
	method: 'set_pxe_uplink',
	params: ['enabled']
});

const callResetData = rpc.declare({
	object: 'luci.one-kvm',
	method: 'reset_data',
	params: ['confirm']
});

function badge(ok, yes, no) {
	return E('span', { 'style': 'color:' + (ok ? 'green' : '#777') }, ok ? yes : no);
}

function button(label, action, style) {
	return E('button', {
		'class': 'btn cbi-button ' + (style || 'cbi-button-apply'),
		'click': function(ev) {
			ev.preventDefault();
			return L.resolveDefault(callServiceAction(action), {}).then(function(res) {
				if (!res || !res.success)
					ui.addNotification(null, E('p', _('Service action failed: ') + action), 'error');
				else
					ui.addTimeLimitedNotification(null, E('p', _('Service action completed: ') + action), 3000, 'info');
			});
		}
	}, label);
}

function shortHash(value) {
	return value ? value.substring(0, 12) : '-';
}

function codeValue(value, title) {
	return E('code', {
		'style': 'white-space:normal;overflow-wrap:anywhere',
		'title': title || value || ''
	}, value || '-');
}

function restoreFirmwareBinary() {
	ui.showModal(_('Restore firmware binary'), [
		E('p', {}, _('Replace the active One-KVM program with the copy built into this firmware? The service will be stopped and restarted only when it is enabled in UCI.')),
		E('div', { 'class': 'right' }, [
			E('button', {
				'class': 'btn',
				'click': function() { ui.hideModal(); }
			}, _('Cancel')),
			' ',
			E('button', {
				'class': 'btn cbi-button-negative important',
				'click': function(ev) {
					const target = ev.currentTarget;
					target.disabled = true;
					return L.resolveDefault(callRestoreFirmwareBinary(), {}).then(function(res) {
						ui.hideModal();
						if (!res || !res.success) {
							ui.addNotification(null, E('p', {}, _('Firmware binary restore failed.')), 'error');
							return;
						}
						ui.addTimeLimitedNotification(null, E('p', {}, _('Firmware binary restored.')), 5000, 'info');
					});
				}
			}, _('Restore'))
		])
	]);
}

function restoreButton(versions) {
	const attrs = {
		'class': 'btn cbi-button cbi-button-negative',
		'title': _('Restore the active executable from /rom/usr/bin/one-kvm'),
		'click': function(ev) {
			ev.preventDefault();
			restoreFirmwareBinary();
		}
	};
	if (!versions.recovery_available)
		attrs.disabled = true;

	return E('button', attrs, _('Restore firmware binary'));
}

function applyPxeUplink(enabled) {
	return L.resolveDefault(callSetPxeUplink(enabled), {}).then(function(res) {
		if (!res || !res.success) {
			ui.addNotification(null, E('p', {}, _('Failed to update PXE uplink.')), 'error');
			return;
		}
		ui.addTimeLimitedNotification(null, E('p', {}, enabled ?
			_('PXE uplink enabled.') : _('PXE uplink disabled.')), 5000, 'info');
		window.setTimeout(function() { window.location.reload(); }, 500);
	});
}

function pxeUplinkButton(status) {
	return E('button', {
		'class': 'btn cbi-button ' + (status.pxe_uplink ? 'cbi-button-negative' : 'cbi-button-apply'),
		'click': function(ev) {
			ev.preventDefault();
			if (status.pxe_uplink)
				return applyPxeUplink(false);

			ui.showModal(_('Enable PXE uplink'), [
				E('p', {}, _('PXE clients will be routed to the upstream management network through NAT. LAN4 remains isolated from device management services.')),
				E('div', { 'class': 'right' }, [
					E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
					E('button', {
						'class': 'btn cbi-button-positive important',
						'click': function() {
							ui.hideModal();
							return applyPxeUplink(true);
						}
					}, _('Enable'))
				])
			]);
		}
	}, status.pxe_uplink ? _('Disable PXE uplink') : _('Enable PXE uplink'));
}

function resetOneKvmData() {
	let confirmButton;
	const checkbox = E('input', {
		'type': 'checkbox',
		'change': function(ev) { confirmButton.disabled = !ev.currentTarget.checked; }
	});

	confirmButton = E('button', {
		'class': 'btn cbi-button-negative important',
		'disabled': true,
		'click': function(ev) {
			const target = ev.currentTarget;
			target.disabled = true;
			target.textContent = _('Resetting...');
			return L.resolveDefault(callResetData('RESET'), {}).then(function(res) {
				ui.hideModal();
				if (!res || !res.success) {
					let message = _('One-KVM data reset failed.');
					const output = res && res.output ? res.output : '';
					if (output.indexOf('unsupported_data_directory') >= 0)
						message = _('Reset refused because One-KVM uses a custom data directory.');
					else if (output.indexOf('data_directory_is_symlink') >= 0)
						message = _('Reset refused because /etc/one-kvm is a symbolic link.');
					else if (output.indexOf('operation_in_progress') >= 0)
						message = _('Another One-KVM data reset is already running.');
					else if (output.indexOf('service_did_not_stop') >= 0)
						message = _('One-KVM did not stop; no data was deleted.');
					else if (output.indexOf('service_restart_failed') >= 0)
						message = _('Data was reset, but One-KVM could not be restarted.');
					ui.addNotification(null, E('p', {}, message), 'error');
					return;
				}
				ui.addTimeLimitedNotification(null, E('p', {}, _('One-KVM data was reset. Complete setup again before use.')), 8000, 'info');
			});
		}
	}, _('Reset data'));

	ui.showModal(_('Reset One-KVM data'), [
		E('p', { 'style': 'font-weight:bold;color:#b00' }, _('This permanently deletes the One-KVM account, password, database, sessions, certificates, updates and every file under /etc/one-kvm.')),
		E('p', {}, _('OpenWrt settings, /etc/config/one-kvm, the firmware binary and KVMSTORE are not deleted.')),
		E('label', { 'style': 'display:flex;gap:8px;align-items:flex-start;margin:1em 0' }, [
			checkbox,
			E('span', {}, _('I understand that the One-KVM data cannot be recovered.'))
		]),
		E('div', { 'class': 'right' }, [
			E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
			confirmButton
		])
	]);
}

function resetDataButton(status) {
	const attrs = {
		'class': 'btn cbi-button cbi-button-negative',
		'click': function(ev) { ev.preventDefault(); resetOneKvmData(); },
		'title': status.reset_supported ? _('Delete all One-KVM data and return to setup') : _('Reset is only available when the data directory is /etc/one-kvm')
	};
	if (!status.reset_supported)
		attrs.disabled = true;
	return E('button', attrs, _('Reset One-KVM data'));
}

function frpcMissingText(status) {
	if (!status.frpc_binary_exists && !status.frpc_luci_exists)
		return _('frpc and luci-app-frpc are missing');
	if (!status.frpc_binary_exists)
		return _('frpc binary is missing');
	if (!status.frpc_luci_exists)
		return _('luci-app-frpc is missing');
	if (!status.frpc_init_exists || !status.frpc_config_exists)
		return _('FRPC service files are incomplete');
	return '';
}

function frpcManagementButton(status) {
	const missing = frpcMissingText(status);
	if (!status.frpc_available)
		return E('button', {
			'class': 'btn cbi-button',
			'disabled': true,
			'title': missing
		}, _('Open FRPC management'));

	return E('a', {
		'class': 'btn cbi-button cbi-button-action',
		'href': L.url('admin/services/frpc'),
		'title': _('Configure the standalone FRPC service')
	}, _('Open FRPC management'));
}

function frpcStatus(status) {
	if (!status.frpc_available)
		return E('span', { 'style': 'color:#b00' }, frpcMissingText(status));

	return E('span', {}, [
		badge(status.frpc_running, status.frpc_running ? _('Running') : _('Stopped'), _('Stopped')),
		' / ',
		status.frpc_boot_enabled ? _('Boot enabled') : _('Boot disabled'),
		' / ',
		E('a', { 'href': L.url('admin/services/frpc') }, _('Open configuration'))
	]);
}

function renderStatus(status, versions, hwcheck) {
	const url = 'http://' + window.location.hostname + ':' + (status.http_port || '8080') + '/';
	let overlayText;
	if (!versions.runtime_exists)
		overlayText = _('Active binary missing');
	else if (!versions.rom_exists)
		overlayText = _('Firmware copy unavailable');
	else if (versions.matches_rom)
		overlayText = _('Matches firmware copy');
	else
		overlayText = _('Overlay override active');

	return E('div', { 'class': 'cbi-section', 'id': 'onekvm-status' }, [
		E('h3', _('One-KVM Status')),
		E('table', { 'class': 'table' }, [
			E('tr', {}, [ E('td', {}, _('Service')), E('td', {}, badge(status.running, _('Running'), _('Stopped'))) ]),
			E('tr', {}, [ E('td', {}, _('Config')), E('td', {}, badge(status.config_enabled, _('Enabled'), _('Disabled'))) ]),
			E('tr', {}, [ E('td', {}, _('Boot')), E('td', {}, badge(status.boot_enabled, _('Enabled'), _('Disabled'))) ]),
			E('tr', {}, [ E('td', {}, _('Binary')), E('td', {}, badge(status.binary_exists, _('Installed'), _('Missing'))) ]),
			E('tr', {}, [ E('td', {}, _('Running binary version')), E('td', {}, codeValue(versions.runtime_version)) ]),
			E('tr', {}, [ E('td', {}, _('Installed One-KVM APK')), E('td', {}, codeValue(versions.installed_version)) ]),
			E('tr', {}, [ E('td', {}, _('Firmware ROM version')), E('td', {}, codeValue(versions.rom_version)) ]),
			E('tr', {}, [ E('td', {}, _('Runtime ABI package')), E('td', {}, codeValue(versions.runtime_abi_version)) ]),
			E('tr', {}, [ E('td', {}, _('LuCI package version')), E('td', {}, codeValue(versions.luci_version)) ]),
			E('tr', {}, [ E('td', {}, _('Overlay state')), E('td', {}, badge(versions.matches_rom, overlayText, overlayText)) ]),
			E('tr', {}, [ E('td', {}, _('Active SHA256')), E('td', {}, codeValue(shortHash(versions.runtime_sha256), versions.runtime_sha256)) ]),
			E('tr', {}, [ E('td', {}, _('ROM SHA256')), E('td', {}, codeValue(shortHash(versions.rom_sha256), versions.rom_sha256)) ]),
			E('tr', {}, [ E('td', {}, _('HTTP')), E('td', {}, [
				badge(status.listening, _('Listening'), _('Not listening')),
				' ',
				E('a', { 'href': url, 'target': '_blank', 'rel': 'noreferrer' }, url)
			]) ]),
			E('tr', {}, [ E('td', {}, _('Video')), E('td', {}, badge(status.video0_exists, _('/dev/video0 found'), _('/dev/video0 missing'))) ]),
			E('tr', {}, [ E('td', {}, _('CH9329')), E('td', {}, badge(status.ch9329_exists, _('/dev/ch9329 found'), _('/dev/ch9329 missing'))) ]),
			E('tr', {}, [ E('td', {}, _('PXE port')), E('td', {}, codeValue('LAN4 / 10.40.0.1:8081')) ]),
			E('tr', {}, [ E('td', {}, _('PXE upstream access')), E('td', {}, badge(status.pxe_uplink, _('Enabled through NAT'), _('Local KVMSTORE only'))) ]),
			E('tr', {}, [ E('td', {}, _('FRPC remote access')), E('td', {}, frpcStatus(status)) ]),
			E('tr', {}, [ E('td', {}, _('One-KVM data directory')), E('td', {}, codeValue(status.data_dir)) ]),
			E('tr', {}, [ E('td', {}, _('Hardware check')), E('td', {}, codeValue(hwcheck.output)) ])
		]),
		E('div', { 'class': 'cbi-page-actions' }, [
			button(_('Start'), 'start', 'cbi-button-apply'), ' ',
			button(_('Stop'), 'stop', 'cbi-button-reset'), ' ',
			button(_('Restart'), 'restart', 'cbi-button-reload'), ' ',
			button(_('Enable boot'), 'enable', 'cbi-button-apply'), ' ',
			button(_('Disable boot'), 'disable', 'cbi-button-reset'), ' ',
			restoreButton(versions), ' ',
			pxeUplinkButton(status), ' ',
			frpcManagementButton(status), ' ',
			resetDataButton(status)
		])
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('one-kvm'),
			L.resolveDefault(callGetStatus(), {}),
			L.resolveDefault(callGetVersions(), {}),
			L.resolveDefault(callGetHwcheck(), {})
		]);
	},

	render: function(data) {
		let m, s, o;
		const status = data[1] || {};
		const versions = data[2] || {};
		const hwcheck = data[3] || {};

		m = new form.Map('one-kvm', _('One-KVM'),
			_('Host-only One-KVM service for UVC/MS2109 video capture and CH9329 serial HID. OTG and USB gadget mass-storage are disabled on this firmware.'));

		s = m.section(form.NamedSection, 'main', 'one-kvm', _('Service'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable service'));
		o.default = '0';

		o = s.option(form.Value, 'bind_address', _('Bind address'));
		o.datatype = 'ipaddr';
		o.placeholder = '0.0.0.0';

		o = s.option(form.Value, 'http_port', _('HTTP port'));
		o.datatype = 'port';
		o.placeholder = '8080';

		o = s.option(form.Value, 'data_dir', _('Data directory'));
		o.placeholder = '/etc/one-kvm';

		o = s.option(form.ListValue, 'log_level', _('Log level'));
		o.value('error', _('Error'));
		o.value('warn', _('Warn'));
		o.value('info', _('Info'));
		o.value('verbose', _('Verbose'));
		o.value('debug', _('Debug'));
		o.value('trace', _('Trace'));
		o.default = 'info';

		s = m.section(form.NamedSection, 'main', 'one-kvm', _('Hardware'));
		s.anonymous = true;

		o = s.option(form.Value, 'video_device', _('Video device'));
		o.placeholder = '/dev/video0';

		o = s.option(form.ListValue, 'hid_backend', _('HID backend'));
		o.value('ch9329', 'CH9329');
		o.value('none', _('Disabled'));
		o.default = 'ch9329';

		o = s.option(form.Value, 'ch9329_port', _('CH9329 port'));
		o.depends('hid_backend', 'ch9329');
		o.placeholder = '/dev/ch9329';

		o = s.option(form.ListValue, 'ch9329_baudrate', _('CH9329 baudrate'));
		o.depends('hid_backend', 'ch9329');
		o.value('9600', '9600');
		o.value('115200', '115200');
		o.default = '9600';

		o = s.option(form.Flag, 'ch9329_hybrid_mouse', _('Hybrid mouse mode'));
		o.depends('hid_backend', 'ch9329');
		o.default = '0';

		s = m.section(form.NamedSection, 'main', 'one-kvm', _('HTTPS'));
		s.anonymous = true;
		s.optional = true;

		o = s.option(form.Flag, 'https_enabled', _('Enable HTTPS'));
		o.default = '0';

		o = s.option(form.Value, 'https_port', _('HTTPS port'));
		o.depends('https_enabled', '1');
		o.datatype = 'port';
		o.placeholder = '8443';

		o = s.option(form.Value, 'ssl_cert', _('Certificate path'));
		o.depends('https_enabled', '1');

		o = s.option(form.Value, 'ssl_key', _('Private key path'));
		o.depends('https_enabled', '1');

		poll.add(function() {
			return Promise.all([
				L.resolveDefault(callGetStatus(), {}),
				L.resolveDefault(callGetVersions(), {}),
				L.resolveDefault(callGetHwcheck(), {})
			]).then(function(result) {
				const el = document.getElementById('onekvm-status');
				if (el)
					el.replaceWith(renderStatus(result[0] || {}, result[1] || {}, result[2] || {}));
			});
		}, 5);

		return m.render().then(function(formNode) {
			return E([], [
				renderStatus(status, versions, hwcheck),
				formNode
			]);
		});
	}
});

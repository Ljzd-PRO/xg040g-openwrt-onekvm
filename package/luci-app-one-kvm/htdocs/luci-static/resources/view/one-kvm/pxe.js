'use strict';
'require view';
'require rpc';
'require poll';
'require ui';

const callGetSettings = rpc.declare({
	object: 'luci.one-kvm',
	method: 'get_pxe_settings'
});

const callSetPort = rpc.declare({
	object: 'luci.one-kvm',
	method: 'set_pxe_port',
	params: ['port', 'confirm']
});

const callSetUplink = rpc.declare({
	object: 'luci.one-kvm',
	method: 'set_pxe_uplink',
	params: ['enabled']
});

function portLabel(port) {
	switch (port) {
	case 'lan2': return 'LAN2';
	case 'lan3': return 'LAN3';
	case 'lan4': return 'LAN4';
	case 'eth1': return _('2.5G port');
	default: return _('Disabled (all ports are switch ports)');
	}
}

function stateText(ok, yes, no) {
	return E('span', { 'style': 'color:' + (ok ? 'green' : '#777') }, ok ? yes : no);
}

function bridgeMode(port) {
	if (port.master == 'br-pxe')
		return _('PXE dedicated');
	if (port.master == 'br-lan')
		return _('Switch and management');
	return _('Not attached to a bridge');
}

function renderStatus(state) {
	const active = !!state.active;
	const ports = Array.isArray(state.ports) ? state.ports : [];
	return E('div', { 'id': 'pxe-settings-status' }, [
		E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Current status')),
			E('div', { 'class': 'table' }, [
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left', 'style': 'width:33%' }, _('PXE dedicated port')), E('div', { 'class': 'td left' }, portLabel(state.port))]),
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('Management switch ports')), E('div', { 'class': 'td left' }, E('code', {}, state.lan_ports || '-'))]),
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('PXE interface')), E('div', { 'class': 'td left' }, active ? stateText(state.pxe_ready, _('Ready at 10.40.0.1/24'), _('Not ready')) : _('Disabled'))]),
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('DHCP / TFTP')), E('div', { 'class': 'td left' }, active ? stateText(state.dnsmasq_running && state.tftp_enabled, _('Running'), _('Stopped')) : _('Disabled'))]),
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('Local boot HTTP')), E('div', { 'class': 'td left' }, active ? stateText(state.local_http_running, _('Listening on port 8081'), _('Stopped')) : _('Disabled'))]),
				E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('Cloud PXE HTTP')), E('div', { 'class': 'td left' }, active ? stateText(state.cloud_http_running, _('Listening on port 8083'), _('Stopped')) : _('Disabled'))])
			])
		]),
		E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Physical ports')),
			E('div', { 'class': 'table' }, [
				E('div', { 'class': 'tr table-titles' }, [
					E('div', { 'class': 'th' }, _('Port')),
					E('div', { 'class': 'th' }, _('Link')),
					E('div', { 'class': 'th' }, _('Mode'))
				])
			].concat(ports.map(function(port) {
				return E('div', { 'class': 'tr' }, [
					E('div', { 'class': 'td' }, portLabel(port.id)),
					E('div', { 'class': 'td' }, port.carrier ? _('Connected') : _('Disconnected')),
					E('div', { 'class': 'td' }, bridgeMode(port))
				]);
			})))
		])
	]);
}

function applyPort(port, currentPort) {
	if (port == currentPort) {
		ui.addTimeLimitedNotification(null, E('p', {}, _('The selected PXE port is already active.')), 3000, 'info');
		return;
	}

	const disabling = port == 'none';
	ui.showModal(disabling ? _('Restore all ports to switch mode') : _('Confirm PXE port change'), [
		E('p', {}, disabling ?
			_('PXE services will stop and all four physical ports will join the management switch.') :
			_('The selected port will immediately leave the management switch and become the dedicated PXE port. LuCI, SSH and mDNS will no longer be reachable through that port.')),
		E('p', { 'class': 'alert-message warning' }, _('If this management session uses the selected port, the page will disconnect. Move the management cable to another port. This setting has no automatic rollback.')),
		E('div', { 'class': 'right' }, [
			E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
			E('button', {
				'class': 'btn cbi-button-positive important',
				'click': function(ev) {
					ev.currentTarget.disabled = true;
					return L.resolveDefault(callSetPort(port, 'APPLY'), {}).then(function(res) {
						if (!res || !res.success) {
							ui.hideModal();
							ui.addNotification(null, E('p', {}, _('Failed to save the PXE port configuration.')), 'error');
							return;
						}
						ui.showModal(_('Applying network configuration'), [
							E('p', {}, _('The configuration was saved and the network is restarting. Reconnect through any remaining switch port if this page becomes unavailable.'))
						]);
						window.setTimeout(function() { window.location.reload(); }, 10000);
					});
				}
			}, disabling ? _('Restore switch mode') : _('Apply PXE port'))
		])
	]);
}

function updateUplink(enabled) {
	return L.resolveDefault(callSetUplink(enabled), {}).then(function(res) {
		if (!res || !res.success) {
			ui.addNotification(null, E('p', {}, _('Failed to update PXE upstream access.')), 'error');
			return false;
		}
		ui.addTimeLimitedNotification(null, E('p', {}, enabled ? _('PXE upstream access enabled.') : _('PXE upstream access disabled.')), 4000, 'info');
		return true;
	});
}

function uplinkControl(state) {
	const checkbox = E('input', {
		'type': 'checkbox',
		'checked': state.allow_uplink ? '' : null,
		'disabled': state.active ? null : '',
		'change': function(ev) {
			const input = ev.currentTarget;
			const enabled = input.checked;
			if (!enabled) {
				input.disabled = true;
				return updateUplink(false).then(function(ok) {
					input.disabled = false;
					if (!ok)
						input.checked = true;
				});
			}

			input.checked = false;
			ui.showModal(_('Enable PXE upstream access'), [
				E('p', {}, _('PXE clients will be routed through NAT to the management network. They will still be blocked from device management services.')),
				E('div', { 'class': 'right' }, [
					E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
					E('button', {
						'class': 'btn cbi-button-positive important',
						'click': function() {
							ui.hideModal();
							input.disabled = true;
							return updateUplink(true).then(function(ok) {
								input.disabled = false;
								input.checked = ok;
							});
						}
					}, _('Enable'))
				])
			]);
		}
	});

	return E('div', { 'class': 'cbi-value' }, [
		E('label', { 'class': 'cbi-value-title' }, _('Allow PXE clients to access the upstream network')),
		E('div', { 'class': 'cbi-value-field' }, [
			checkbox,
			E('div', { 'class': 'cbi-value-description' }, state.active ?
				_('Disabled by default. When enabled, only PXE-to-management forwarding and NAT are added.') :
				_('Select a PXE dedicated port before enabling upstream access.'))
		])
	]);
}

return view.extend({
	load: function() {
		return L.resolveDefault(callGetSettings(), {});
	},

	render: function(state) {
		state = state || { port: 'none', ports: [] };
		const select = E('select', { 'id': 'pxe-port-select', 'class': 'cbi-input-select' }, [
			E('option', { 'value': 'none', 'selected': state.port == 'none' ? '' : null }, _('Disabled (all ports are switch ports)')),
			E('option', { 'value': 'lan2', 'selected': state.port == 'lan2' ? '' : null }, 'LAN2'),
			E('option', { 'value': 'lan3', 'selected': state.port == 'lan3' ? '' : null }, 'LAN3'),
			E('option', { 'value': 'lan4', 'selected': state.port == 'lan4' ? '' : null }, 'LAN4'),
			E('option', { 'value': 'eth1', 'selected': state.port == 'eth1' ? '' : null }, _('2.5G port'))
		]);

		poll.add(function() {
			return L.resolveDefault(callGetSettings(), {}).then(function(next) {
				const node = document.getElementById('pxe-settings-status');
				if (node)
					node.replaceWith(renderStatus(next || {}));
			});
		}, 5);

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('PXE Settings')),
			renderStatus(state),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Persistent port assignment')),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'for': 'pxe-port-select' }, _('PXE dedicated port')),
					E('div', { 'class': 'cbi-value-field' }, select)
				]),
				uplinkControl(state),
				E('div', { 'class': 'cbi-page-actions' }, [
					E('button', {
						'class': 'btn cbi-button cbi-button-apply',
						'click': function(ev) {
							ev.preventDefault();
							applyPort(select.value, state.port || 'none');
						}
					}, _('Apply port assignment'))
				])
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});

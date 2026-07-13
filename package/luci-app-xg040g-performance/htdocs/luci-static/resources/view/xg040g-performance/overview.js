'use strict';
'require view';
'require rpc';
'require poll';
'require ui';

const callStatus = rpc.declare({
	object: 'xg040g.performance',
	method: 'status',
	expect: { '': {} }
});

const callSetSteering = rpc.declare({
	object: 'xg040g.performance',
	method: 'set_steering',
	params: [ 'mode' ],
	expect: { '': {} }
});

const callApplyCpu = rpc.declare({
	object: 'xg040g.performance',
	method: 'apply_cpu',
	params: [ 'frequency', 'overclock', 'confirm' ],
	expect: { '': {} }
});

const callRestoreStock = rpc.declare({
	object: 'xg040g.performance',
	method: 'restore_stock',
	expect: { '': {} }
});

function mhz(value) {
	return value ? _('%d MHz').format(value) : _('Unavailable');
}

function temperature(value) {
	return value > 0 ? _('%s C').format((value / 1000).toFixed(1)) : _('Unavailable');
}

function steeringName(value) {
	switch (Number(value)) {
	case 0: return _('Disabled');
	case 1: return _('Automatic');
	case 2: return _('All CPU cores');
	default: return _('Unknown');
	}
}

function statusTable(status) {
	const interfaces = status.interfaces || {};
	const eth0 = interfaces.eth0 || {};
	const eth1 = interfaces.eth1 || {};
	const bridges = status.bridges || {};
	const active = status.active_mhz > 1200;
	const rows = [
		[ _('Actual CPU frequency'), mhz(status.actual_mhz) ],
		[ _('Saved startup policy'), status.configured_overclock ? _('%d MHz overclock').format(status.configured_mhz) : _('Stock 1200 MHz') ],
		[ _('Current overclock state'), active ? _('Active') : _('Disabled') ],
		[ _('SoC temperature'), temperature(status.temperature_millic) ],
		[ _('Thermal rollback / emergency'), _('%d C / %d C').format(status.thermal_revert || 85, status.thermal_emergency || 95) ],
		[ _('Kernel driver error'), String(status.last_error || 0) ],
		[ _('Standard cpufreq'), status.cpufreq_available ? _('Available') : _('Unavailable on tcboot ATF') ],
		[ _('Packet steering'), steeringName(status.packet_steering) ],
		[ _('eth0 RX queues / RPS masks'), _('%d / %s').format(eth0.rx_queues || 0, eth0.rps_masks || '-') ],
		[ _('eth1 RX queues / RPS masks'), _('%d / %s').format(eth1.rx_queues || 0, eth1.rps_masks || '-') ],
		[ _('2.5G link'), eth1.carrier ? _('%d Mbit/s, %s').format(eth1.speed_mbps || 0, eth1.operstate || '-') : _('Disconnected') ],
		[ _('br-lan members'), bridges.br_lan || '-' ],
		[ _('br-pxe members'), bridges.br_pxe || '-' ],
		[ _('NET_RX per CPU'), (status.net_rx || []).join(' / ') || '-' ]
	];

	return E('table', { 'class': 'table' }, rows.map((row) => E('tr', {}, [
		E('td', { 'class': 'td left', 'width': '38%' }, row[0]),
		E('td', { 'class': 'td left' }, String(row[1]))
	])));
}

return view.extend({
	load: function() {
		return L.resolveDefault(callStatus(), {});
	},

	render: function(initialStatus) {
		const statusNode = E('div', { 'id': 'xg040g-performance-status' }, statusTable(initialStatus || {}));
		const steeringSelect = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': '0' }, _('Disabled')),
			E('option', { 'value': '1' }, _('Automatic')),
			E('option', { 'value': '2' }, _('All CPU cores'))
		]);
		const frequencySelect = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': '1200' }, _('1200 MHz (stock)')),
			E('option', { 'value': '1300' }, _('1300 MHz (experimental)')),
			E('option', { 'value': '1400' }, _('1400 MHz (experimental)'))
		]);

		steeringSelect.value = String(initialStatus.packet_steering != null ? initialStatus.packet_steering : 2);
		frequencySelect.value = String(initialStatus.configured_mhz || 1200);

		const refresh = () => L.resolveDefault(callStatus(), {}).then((status) => {
			statusNode.replaceChildren(statusTable(status || {}));
			return status;
		});

		const handleResult = (promise, message) => promise.then((result) => {
			if (result && result.error)
				throw new Error(result.message || result.error);
			statusNode.replaceChildren(statusTable(result || {}));
			ui.addNotification(null, E('p', {}, message), 'info');
			return result;
		}).catch((error) => {
			ui.addNotification(null, E('p', {}, error.message || String(error)), 'danger');
		});

		const applySteering = ui.createHandlerFn(this, () => handleResult(
			callSetSteering(Number(steeringSelect.value)),
			_('Packet steering settings were applied.')
		));

		const applyCpu = ui.createHandlerFn(this, () => {
			const frequency = Number(frequencySelect.value);
			if (frequency === 1200)
				return handleResult(callApplyCpu(1200, false, ''), _('Stock CPU settings were applied.'));

			const confirmation = E('input', {
				'class': 'cbi-input-text',
				'placeholder': 'OVERCLOCK',
				'autocomplete': 'off'
			});
			ui.showModal(_('Confirm experimental overclock'), [
				E('p', {}, _('Overclocking changes the AN7581 CPU PLL without changing voltage. It may cause overheating, data loss or an unreachable device. The firmware will monitor temperature, but this cannot remove all risk.')),
				E('p', {}, _('Type OVERCLOCK to apply %d MHz and save it for future boots.').format(frequency)),
				confirmation,
				E('div', { 'class': 'right' }, [
					E('button', {
						'class': 'btn',
						'click': ui.createHandlerFn(this, ui.hideModal)
					}, _('Cancel')),
					' ',
					E('button', {
						'class': 'btn cbi-button-negative',
						'click': ui.createHandlerFn(this, () => {
							if (confirmation.value !== 'OVERCLOCK') {
								ui.addNotification(null, E('p', {}, _('The confirmation text does not match.')), 'warning');
								return;
							}
							ui.hideModal();
							return handleResult(callApplyCpu(frequency, true, confirmation.value), _('The experimental CPU frequency was applied.'));
						})
					}, _('Apply overclock'))
				])
			]);
		});

		const restoreStock = ui.createHandlerFn(this, () => handleResult(
			callRestoreStock(),
			_('The CPU was restored to the stock 1200 MHz policy.')
		).then(() => {
			frequencySelect.value = '1200';
		}));

		poll.add(refresh, 5);

		return E([], [
			E('h2', {}, _('Switch Performance')),
			E('p', {}, _('Full-core RPS can distribute different receive flows across all four CPU cores. It does not turn the 2.5G port into a hardware-switched port and does not accelerate a single flow across multiple cores.')),
			statusNode,
			E('h3', {}, _('Packet steering')),
			E('div', { 'class': 'cbi-section' }, [
				steeringSelect,
				' ',
				E('button', {
					'class': 'btn cbi-button cbi-button-apply',
					'click': applySteering
				}, _('Apply RPS mode'))
			]),
			E('h3', {}, _('CPU frequency')),
			E('div', { 'class': 'cbi-section' }, [
				frequencySelect,
				' ',
				E('button', {
					'class': 'btn cbi-button cbi-button-apply',
					'click': applyCpu
				}, _('Apply CPU policy')),
				' ',
				E('button', {
					'class': 'btn cbi-button cbi-button-reset',
					'click': restoreStock
				}, _('Restore stock 1200 MHz'))
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});

'use strict';
'require view';
'require rpc';
'require ui';

const callGet = rpc.declare({ object: 'luci.one-kvm', method: 'get_cloud_pxe' });
const callTest = rpc.declare({
	object: 'luci.one-kvm', method: 'test_cloud_pxe_config', params: ['config', 'remote_path']
});
const callSave = rpc.declare({
	object: 'luci.one-kvm', method: 'save_cloud_pxe', params: ['config', 'remote_path', 'enabled']
});
const callAction = rpc.declare({ object: 'luci.one-kvm', method: 'cloud_pxe_action', params: ['action'] });
const callClear = rpc.declare({ object: 'luci.one-kvm', method: 'clear_cloud_pxe', params: ['confirm'] });

function values() {
	return {
		config: document.getElementById('cloud-pxe-config').value,
		remote_path: document.getElementById('cloud-pxe-remote').value.trim(),
		enabled: document.getElementById('cloud-pxe-enabled').checked
	};
}

function notifyResult(res, ok, failed) {
	if (res && res.success)
		ui.addTimeLimitedNotification(null, E('p', {}, ok), 4000, 'info');
	else
		ui.addNotification(null, E('p', {}, failed + (res && res.output ? ' (' + res.output + ')' : '')), 'error');
}

function clearConfig() {
	ui.showModal(_('Clear Cloud PXE configuration'), [
		E('p', {}, _('This stops Cloud PXE and permanently removes the saved rclone configuration, including credentials. Local KVMSTORE files are not deleted.')),
		E('div', { 'class': 'right' }, [
			E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
			E('button', {
				'class': 'btn cbi-button-negative important',
				'click': function(ev) {
					ev.currentTarget.disabled = true;
					return L.resolveDefault(callClear('CLEAR'), {}).then(function(res) {
						ui.hideModal();
						if (res && res.success) {
							document.getElementById('cloud-pxe-config').value = '';
							document.getElementById('cloud-pxe-remote').value = '';
							document.getElementById('cloud-pxe-enabled').checked = false;
						}
						notifyResult(res, _('Cloud PXE configuration cleared.'), _('Failed to clear Cloud PXE configuration.'));
					});
				}
			}, _('Clear'))
		])
	]);
}

return view.extend({
	load: function() { return L.resolveDefault(callGet(), {}); },

	render: function(state) {
		state = state || {};
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Cloud PXE')),
			E('p', {}, _('Serve boot files directly from any rclone remote over a read-only HTTP data plane. LAN4 remains isolated and no USB disk is required.')),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Status')),
				E('div', { 'class': 'table' }, [
					E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left', 'style': 'width:33%' }, _('Service')), E('div', { 'class': 'td left' }, state.running ? _('Running') : _('Stopped'))]),
					E('div', { 'class': 'tr' }, [E('div', { 'class': 'td left' }, _('Data plane')), E('div', { 'class': 'td left' }, E('code', {}, state.address || 'http://10.40.0.1:8083'))])
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'for': 'cloud-pxe-enabled' }, _('Enable Cloud PXE')),
					E('div', { 'class': 'cbi-value-field' }, E('input', { 'id': 'cloud-pxe-enabled', 'type': 'checkbox', 'checked': state.enabled ? '' : null }))
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'for': 'cloud-pxe-remote' }, _('Active remote path')),
					E('div', { 'class': 'cbi-value-field' }, [E('input', { 'id': 'cloud-pxe-remote', 'class': 'cbi-input-text', 'style': 'width:100%', 'maxlength': '1024', 'value': state.remote_path || '', 'placeholder': 'kvmcloud:/Downloads' }), E('div', { 'class': 'cbi-value-description' }, _('Use a named rclone remote followed by a path. Inline remotes are rejected.'))])
				]),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'for': 'cloud-pxe-config' }, _('rclone configuration')),
					E('div', { 'class': 'cbi-value-field' }, [E('textarea', { 'id': 'cloud-pxe-config', 'class': 'cbi-input-textarea', 'rows': '16', 'style': 'width:100%;font-family:monospace;white-space:pre;overflow:auto', 'spellcheck': 'false' }, state.config || ''), E('div', { 'class': 'cbi-value-description' }, _('Paste standard rclone INI configuration. Multiple remote sections are supported; maximum size is 64 KiB.'))])
				]),
				E('div', { 'class': 'cbi-page-actions' }, [
					E('button', { 'class': 'btn cbi-button-action', 'click': function(ev) { ev.preventDefault(); const v = values(); return L.resolveDefault(callTest(v.config, v.remote_path), {}).then(function(res) { notifyResult(res, _('Remote test succeeded.'), _('Remote test failed.')); }); } }, _('Test unsaved configuration')),
					' ', E('button', { 'class': 'btn cbi-button-apply', 'click': function(ev) { ev.preventDefault(); const v = values(); return L.resolveDefault(callSave(v.config, v.remote_path, v.enabled), {}).then(function(res) { notifyResult(res, _('Cloud PXE configuration saved.'), _('Failed to save Cloud PXE configuration.')); }); } }, _('Save & Apply')),
					' ', E('button', { 'class': 'btn', 'click': function(ev) { ev.preventDefault(); return L.resolveDefault(callAction('restart'), {}).then(function(res) { notifyResult(res, _('Cloud PXE restarted.'), _('Cloud PXE restart failed.')); }); } }, _('Restart')),
					' ', E('button', { 'class': 'btn cbi-button-negative', 'click': function(ev) { ev.preventDefault(); clearConfig(); } }, _('Clear configuration'))
				])
			])
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});

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

const callGetVersion = rpc.declare({
	object: 'luci.one-kvm',
	method: 'get_version'
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

function renderStatus(status, version, hwcheck) {
	const url = 'http://' + window.location.hostname + ':' + (status.http_port || '8080') + '/';

	return E('div', { 'class': 'cbi-section', 'id': 'onekvm-status' }, [
		E('h3', _('One-KVM Status')),
		E('table', { 'class': 'table' }, [
			E('tr', {}, [ E('td', {}, _('Service')), E('td', {}, badge(status.running, _('Running'), _('Stopped'))) ]),
			E('tr', {}, [ E('td', {}, _('Config')), E('td', {}, badge(status.config_enabled, _('Enabled'), _('Disabled'))) ]),
			E('tr', {}, [ E('td', {}, _('Boot')), E('td', {}, badge(status.boot_enabled, _('Enabled'), _('Disabled'))) ]),
			E('tr', {}, [ E('td', {}, _('Binary')), E('td', {}, badge(status.binary_exists, _('Installed'), _('Missing'))) ]),
			E('tr', {}, [ E('td', {}, _('Version')), E('td', {}, version.version || '-') ]),
			E('tr', {}, [ E('td', {}, _('HTTP')), E('td', {}, [
				badge(status.listening, _('Listening'), _('Not listening')),
				' ',
				E('a', { 'href': url, 'target': '_blank', 'rel': 'noreferrer' }, url)
			]) ]),
			E('tr', {}, [ E('td', {}, _('Video')), E('td', {}, badge(status.video0_exists, _('/dev/video0 found'), _('/dev/video0 missing'))) ]),
			E('tr', {}, [ E('td', {}, _('CH9329')), E('td', {}, badge(status.ch9329_exists, _('/dev/ch9329 found'), _('/dev/ch9329 missing'))) ]),
			E('tr', {}, [ E('td', {}, _('Hardware check')), E('td', {}, E('code', {}, hwcheck.output || '-')) ])
		]),
		E('div', { 'class': 'cbi-page-actions' }, [
			button(_('Start'), 'start', 'cbi-button-apply'), ' ',
			button(_('Stop'), 'stop', 'cbi-button-reset'), ' ',
			button(_('Restart'), 'restart', 'cbi-button-reload'), ' ',
			button(_('Enable boot'), 'enable', 'cbi-button-apply'), ' ',
			button(_('Disable boot'), 'disable', 'cbi-button-reset')
		])
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('one-kvm'),
			L.resolveDefault(callGetStatus(), {}),
			L.resolveDefault(callGetVersion(), {}),
			L.resolveDefault(callGetHwcheck(), {})
		]);
	},

	render: function(data) {
		let m, s, o;
		const status = data[1] || {};
		const version = data[2] || {};
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
		o.default = '115200';

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
				L.resolveDefault(callGetVersion(), {}),
				L.resolveDefault(callGetHwcheck(), {})
			]).then(function(result) {
				const el = document.getElementById('onekvm-status');
				if (el)
					el.replaceWith(renderStatus(result[0] || {}, result[1] || {}, result[2] || {}));
			});
		}, 5);

		return m.render().then(function(formNode) {
			return E([], [
				renderStatus(status, version, hwcheck),
				formNode
			]);
		});
	}
});

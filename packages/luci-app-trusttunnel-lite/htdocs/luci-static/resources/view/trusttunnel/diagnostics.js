'use strict';
'require view';
'require rpc';
'require dom';
'require ui';

var callDiagnose = rpc.declare({ object: 'luci.trusttunnel', method: 'diagnose' });
var callPing = rpc.declare({
	object: 'luci.trusttunnel', method: 'ping', params: [ 'target' ]
});
var callProbe = rpc.declare({ object: 'luci.trusttunnel', method: 'probe' });
var callCheckDomain = rpc.declare({
	object: 'luci.trusttunnel', method: 'check_domain', params: [ 'domain' ]
});

// A verdict word instead of a colored dot: on a narrow screen and in a
// dark theme color reads worse than text, and LuCI's alert-message class
// already carries both the background and the padding — no own CSS is
// needed, which matters for the package weight.
var VERDICT_CLASS = { ok: 'success', warn: 'warning', fail: 'danger', skip: 'info' };

function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '30%' }, label),
		E('td', { 'class': 'td left' }, value)
	]);
}

function badge(ok, textOk, textBad) {
	return E('span', {
		'style': 'padding:2px 8px;border-radius:3px;color:#fff;background:' +
			(ok ? '#2e7d32' : '#c62828')
	}, ok ? textOk : textBad);
}

function verdictWord(v) {
	if (v === 'ok')   return _('everything checks out');
	if (v === 'warn') return _('works, with remarks');
	if (v === 'fail') return _('there are problems');
	return _('not checked');
}

// The status of one check — a short word of fixed width, so the list
// reads as a column rather than a ragged edge.
function checkMark(status) {
	var t = { ok: _('ok'), warn: _('check'), fail: _('problem'), skip: _('skipped') };
	var c = { ok: '#2e7d32', warn: '#ef6c00', fail: '#c62828', skip: '#757575' };
	return E('span', {
		'style': 'display:inline-block;min-width:6.5em;font-weight:bold;color:' + c[status]
	}, t[status] || status);
}

// The check texts come from the backend in English: the backend reports
// FACTS, while the wording belongs to the interface. Literal _() calls are
// used here, not a dynamic _(variable) call: this way the strings are
// guaranteed to land in the catalog and get translated regardless of how
// the theme resolves translation at runtime. An unknown string passes
// through as-is — these are details like addresses and numbers that have
// nothing to translate.
var DIAG_TEXT = {
	'Endpoint address': _('Endpoint address'),
	'Credentials': _('Credentials'),
	'TLS host name': _('TLS host name'),
	'TrustTunnel client': _('TrustTunnel client'),
	'tun device': _('tun device'),
	'Enabled': _('Enabled'),
	'Running': _('Running'),
	'Tunnel device': _('Tunnel device'),
	'Route attached to the device': _('Route attached to the device'),
	'Tunnel carrier': _('Tunnel carrier'),
	'MTU matches settings': _('MTU matches settings'),
	'Routing rule': _('Routing rule'),
	'Routing table': _('Routing table'),
	'nftables table': _('nftables table'),
	'Firewall zone': _('Firewall zone'),
	'Endpoint reachable': _('Endpoint reachable'),
	'Traffic goes through the tunnel': _('Traffic goes through the tunnel'),

	'Fill in the address on the Settings page, or import the server config.': _('Fill in the address on the Settings page, or import the server config.'),
	'Both the user name and the password are required.': _('Both the user name and the password are required.'),
	'Without it the TLS session uses the bare address, which many servers reject.': _('Without it the TLS session uses the bare address, which many servers reject.'),
	'Run install.sh — the package does not ship the client binary.': _('Run install.sh — the package does not ship the client binary.'),
	'Install kmod-tun.': _('Install kmod-tun.'),
	'Turn on Enable on the Settings page, then press Start.': _('Turn on Enable on the Settings page, then press Start.'),
	'Press Start and read the client log below.': _('Press Start and read the client log below.'),
	'The device belongs to the client, not to this package. Read the client log below.': _('The device belongs to the client, not to this package. Read the client log below.'),
	'The device exists but the client has not established the tunnel yet. This is the client side, not the routing — read the client log.': _('The device exists but the client has not established the tunnel yet. This is the client side, not the routing — read the client log.'),
	'Restart the service so the client picks up the configured value.': _('Restart the service so the client picks up the configured value.'),
	'Marked traffic falls into the killswitch instead of the tunnel. Restart the service.': _('Marked traffic falls into the killswitch instead of the tunnel. Restart the service.'),
	'Run /etc/init.d/firewall reload — traffic into the tunnel is dropped without the zone.': _('Run /etc/init.d/firewall reload — traffic into the tunnel is dropped without the zone.'),
	'Check the address, and that the router itself has internet access.': _('Check the address, and that the router itself has internet access.'),
	'The tunnel is up but traffic is not using it.': _('The tunnel is up but traffic is not using it.'),
	'A request bound to the device can fail even on a healthy tunnel, because the default route lives in the marked table. Judge by a LAN client instead.': _('A request bound to the device can fail even on a healthy tunnel, because the default route lives in the marked table. Judge by a LAN client instead.'),

	'not set': _('not set'),
	'not installed': _('not installed'),
	'installed': _('installed'),
	'missing': _('missing'),
	'yes': _('yes'),
	'no': _('no'),
	'present': _('present'),
	'absent': _('absent'),
	'up': _('up'),
	'no carrier': _('no carrier'),
	'the client has not created one': _('the client has not created one'),
	'not attached': _('not attached'),
	'loaded in fw4': _('loaded in fw4'),
	'not in the live ruleset': _('not in the live ruleset'),
	'the router itself has no internet access': _('the router itself has no internet access'),
	'/dev/net/tun present': _('present')
};

function dtr(s) {
	return (s && DIAG_TEXT[s]) ? DIAG_TEXT[s] : (s || '');
}

var GROUP_TITLE = {
	config:  _('Configuration'),
	prereq:  _('Prerequisites'),
	service: _('Service'),
	kernel:  _('Kernel state'),
	network: _('Network')
};

return view.extend({
	// The page has no form and saves nothing, so LuCI's Save/Apply
	// buttons are unnecessary here.
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	// The check list with hints is about 35 rows. Showing all of them
	// always is wrong for two reasons. When everything is fine there is
	// nothing to read: the "it works" answer fits in one line. When there
	// is a problem, it has to be found, and it drowns among the green rows.
	//
	// Therefore: problems and remarks go on top, the rest hides behind a
	// button. The length cannot be cut with two columns: the reader's
	// task is to find the FIRST problem top-down, and in two columns
	// "first" stops being unambiguous.
	renderChecks: function(list) {
		var order = [ 'config', 'prereq', 'service', 'kernel', 'network' ];
		var byGroup = {};
		list.forEach(function(c) {
			if (!byGroup[c.group]) byGroup[c.group] = [];
			byGroup[c.group].push(c);
		});

		var parts = [];
		order.forEach(function(g) {
			if (!byGroup[g]) return;
			var rows = [];
			byGroup[g].forEach(function(c) {
				rows.push(E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left', 'width': '20%' }, checkMark(c.status)),
					E('td', { 'class': 'td left', 'width': '33%' }, dtr(c.label)),
					E('td', { 'class': 'td left' }, dtr(c.detail))
				]));
				// The hint is shown only where there is something to fix,
				// and on its own full-width row: next to the value it would
				// eat space from the value itself on a narrow screen.
				if (c.hint)
					rows.push(E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td left' }, ''),
						E('td', { 'class': 'td left', 'colspan': '2' },
							E('em', {}, dtr(c.hint)))
					]));
			});
			parts.push(E('h4', { 'style': 'margin:1em 0 0.3em' }, GROUP_TITLE[g] || g));
			parts.push(E('table', { 'class': 'table' }, rows));
		});
		return parts;
	},

	renderDiagnose: function(res) {
		var counts = res.counts || {};
		var checks = res.checks || [];
		var problems = checks.filter(function(c) {
			return c.status === 'fail' || c.status === 'warn';
		});
		var passed = checks.filter(function(c) {
			return c.status !== 'fail' && c.status !== 'warn';
		});

		var parts = [
			E('div', {
				'class': 'alert-message ' + (VERDICT_CLASS[res.verdict] || 'info')
			}, [
				E('strong', {}, verdictWord(res.verdict)),
				E('br'),
				_('checks passed: %d, remarks: %d, problems: %d, skipped: %d')
					.format(counts.ok || 0, counts.warn || 0, counts.fail || 0, counts.skip || 0)
			])
		];

		if (problems.length)
			parts.push.apply(parts, this.renderChecks(problems));

		if (!passed.length)
			return parts;

		var restBox = E('div', { 'style': 'display:none' }, this.renderChecks(passed));
		var labelShow = problems.length
			? _('Show the checks that passed')
			: _('Show all checks');
		var btn = E('button', { 'class': 'cbi-button' }, labelShow);
		btn.addEventListener('click', function(ev) {
			ev.preventDefault();
			var hidden = restBox.style.display === 'none';
			restBox.style.display = hidden ? '' : 'none';
			btn.textContent = hidden ? _('Hide') : labelShow;
		});

		parts.push(E('div', { 'style': 'margin-top:1em' }, btn), restBox);
		return parts;
	},

	handleDiagnose: function(container) {
		dom.content(container, E('p', { 'class': 'spinning' },
			_('Running checks — this takes a few seconds…')));
		return callDiagnose().then(function(res) {
			dom.content(container, this.renderDiagnose(res));
		}.bind(this)).catch(function(e) {
			// catch is mandatory: without it a rejected call — an ubus
			// timeout, a permissions failure, an overloaded router — would
			// leave the page showing "checking…" forever. A stuck spinner
			// is worse than an error message: it looks like a working check
			// that will never finish.
			dom.content(container, E('div', { 'class': 'alert-message danger' },
				e.message || String(e)));
		});
	},

	handlePing: function(container) {
		dom.content(container, E('p', { 'class': 'spinning' }, _('Pinging…')));
		return callPing('').then(function(res) {
			if (res.error)
				return dom.content(container, E('p', {}, res.error));
			var rows = (res.results || []).map(function(r) {
				return E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td left' }, r.host),
					E('td', { 'class': 'td left' }, r.loss + '%'),
					E('td', { 'class': 'td left' }, r.avg !== null
						? (r.min + ' / ' + r.avg + ' / ' + r.max + ' ms') : '—')
				]);
			});
			dom.content(container, E('table', { 'class': 'table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th left' }, _('Host')),
					E('th', { 'class': 'th left' }, _('Loss')),
					E('th', { 'class': 'th left' }, _('min / avg / max'))
				])
			].concat(rows)));
		}).catch(function(e) {
			// Without this, a rejected call — an ubus timeout, a
			// permissions failure, an overloaded router — leaves the panel
			// stuck on "Pinging…" forever. On the diagnostics page a stuck
			// spinner is worse than a missing feature: it looks like a
			// working check that will never finish.
			dom.content(container, E('p', {}, e.message || String(e)));
		});
	},

	handleProbe: function(container) {
		dom.content(container, E('p', { 'class': 'spinning' }, _('Checking…')));
		return callProbe().then(function(res) {
			dom.content(container, E('table', { 'class': 'table' }, [
				row(_('Through the tunnel'), res.tunnel.ip
					? E('code', {}, res.tunnel.ip)
					: E('span', { 'style': 'color:#c62828' }, res.tunnel.error)),
				row(_('Directly'), res.direct.ip
					? E('code', {}, res.direct.ip)
					: E('span', { 'style': 'color:#c62828' }, res.direct.error))
			]));
		}).catch(function(e) {
			dom.content(container, E('p', {}, e.message || String(e)));
		});
	},

	handleCheckDomain: function(input, container) {
		var d = input.value.trim();
		if (!d) return;
		dom.content(container, E('p', { 'class': 'spinning' }, _('Checking…')));
		return callCheckDomain(d).then(function(res) {
			if (res.error)
				return dom.content(container, E('p', {}, res.error));
			var tunnel = (res.verdict.indexOf('tunnel') === 0);
			dom.content(container, E('table', { 'class': 'table' }, [
				row(_('Normalized'), E('code', {}, res.normalized)),
				row(_('Verdict'), badge(tunnel, _('through the tunnel'), _('direct'))),
				row(_('Why'), res.reason)
			]));
		}).catch(function(e) {
			dom.content(container, E('p', {}, e.message || String(e)));
		});
	},

	render: function() {
		var self = this;
		var diagBox = E('div', { 'style': 'margin-top:1em' },
			E('p', { 'class': 'spinning' }, _('Running checks — this takes a few seconds…')));
		var pingBox = E('div', {});
		var probeBox = E('div', {});
		var domainBox = E('div', {});
		var domainInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text',
			'placeholder': 'youtube.com', 'style': 'width:16em'
		});

		// The check runs immediately on open: this tab is visited precisely
		// to see the state, and an extra click adds nothing. The button
		// below is for re-running after fixes.
		this.handleDiagnose(diagBox);

		// Enter in the domain field does the same as the button: typing a
		// domain and pressing Enter is more natural than reaching for the
		// mouse, and the tool is used for several domains in a row.
		domainInput.addEventListener('keydown', function(ev) {
			if (ev.key === 'Enter') {
				ev.preventDefault();
				self.handleCheckDomain(domainInput, domainBox);
			}
		});

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('Diagnostics')),

			E('div', { 'class': 'cbi-section' }, [
				E('p', {}, _('Checks the whole chain — configuration, prerequisites, service, kernel state and network — and says what to do about anything it finds.')),
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': function() { return self.handleDiagnose(diagBox); }
				}, _('Check again')),
				diagBox
			]),

			// The tools live here, not on the status page: they are
			// on-demand actions, and they are needed at the same time
			// diagnostics is opened — when something does not work. On the
			// status page they would lengthen a page that should answer at
			// a glance.
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Check a domain')),
				E('p', {}, _('The tool to reach for when a particular site does not work: it says whether that domain goes through the tunnel, and why.')),
				E('div', {}, [
					domainInput, ' ',
					E('button', {
						'class': 'cbi-button cbi-button-action',
						'click': ui.createHandlerFn(this, 'handleCheckDomain', domainInput, domainBox)
					}, _('Check'))
				]),
				domainBox
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Ping the server')),
				E('p', {}, _('Loss and round-trip time for every configured address.')),
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(this, 'handlePing', pingBox)
				}, _('Ping')),
				pingBox
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Compare the external address')),
				E('p', {}, _('Shows the address seen through the tunnel next to the one seen directly. The same address in both means traffic is not using the tunnel.')),
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(this, 'handleProbe', probeBox)
				}, _('Compare')),
				probeBox
			])
		]);
	}
});

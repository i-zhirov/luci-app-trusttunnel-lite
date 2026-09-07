'use strict';
'require view';
'require poll';
'require rpc';
'require ui';
'require dom';

var callStatus = rpc.declare({ object: 'luci.trusttunnel', method: 'status' });
var callService = rpc.declare({
	object: 'luci.trusttunnel', method: 'service', params: [ 'action' ]
});
var callVersions = rpc.declare({
	object: 'luci.trusttunnel', method: 'versions', params: [ 'refresh' ]
});
var callLog = rpc.declare({
	object: 'luci.trusttunnel', method: 'log', params: [ 'lines' ]
});

// This page answers ONE question: does it work or not. Previously there was a
// table of twelve rows — device, ip rule, routing table, nft table, size of
// the bypass set, nftset support in dnsmasq. All of these are names of
// internal mechanisms, not things a person manages and learns from; judging
// "does the tunnel work" from them had to be done by hand, cross-checking
// green badges against each other.
//
// Now the state is condensed into one phrase with concrete numbers, and the
// link-by-link breakdown with explanations lives on the Diagnostics tab —
// that is where it belongs and it is not duplicated here.
function verdict(st) {
	var host = st.endpoint_hostname || (st.addresses || [])[0] || '';

	if (!st.client_installed)
		return { level: 'danger',
			head: _('The TrustTunnel client is not installed'),
			detail: _('Run install.sh: the package does not ship the client binary.') };

	if (!st.running)
		return st.enabled
			? { level: 'danger', head: _('The service is not running'),
			    detail: _('Press Start and read the client log below.') }
			: { level: 'info', head: _('The service is off'),
			    detail: _('Press Start to run it now, or turn on "Start on boot" in Settings.') };

	if (!st.device_up)
		return { level: 'warning',
			head: host ? _('Connecting to %s').format(host) : _('Connecting to the server'),
			detail: _('The client is running but the tunnel is not established yet. If this persists, the client log below says why.') };

	return { level: 'success',
		head: host ? _('All LAN traffic goes through %s').format(host)
		           : _('All LAN traffic goes through the tunnel'),
		detail: _('Domains from the "do not bypass" list are sent out directly.') };
}

function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '30%' }, label),
		E('td', { 'class': 'td left' }, value)
	]);
}

return view.extend({
	handleAction: function(action, ev) {
		ui.showModal(_('Please wait'), [ E('p', { 'class': 'spinning' }, _('Running…')) ]);
		return callService(action).then(function(res) {
			ui.hideModal();
			// not_running: the init script's own return code for `start` is
			// unreliable (see the service action in luci.trusttunnel) — the
			// backend re-checked via procd and found nothing running.
			if (res && res.not_running)
				ui.addNotification(null, E('p', {}, _('The service did not start. The client log below says why.')), 'warning');
			else if (res && res.code !== 0)
				ui.addNotification(null, E('pre', {}, res.output || _('Command failed')), 'warning');
			else
				ui.addNotification(null, E('p', {}, _('Done')), 'info');
		}).catch(function(e) {
			ui.hideModal();
			ui.addNotification(null, E('p', {}, e.message || String(e)), 'danger');
		});
	},

	// The verdict and the facts are rendered SEPARATELY because they live in
	// different places on the page: the verdict takes the full width (it is
	// the headline answer), while the facts sit next to the versions. The
	// poll updates both blocks from one call. The verdict bar is shown ONLY
	// when something is wrong. That is when it is needed: it says what to do,
	// and the prominence is justified. When everything works, a full-width
	// bar would say "all good" — that is, it would occupy the most visible
	// spot on the page without giving any reason for action. In that case
	// the state stands as an ordinary row in the table on the left, first.
	renderVerdict: function(st) {
		var v = verdict(st);
		if (v.level === 'success')
			return E('div', {});
		return E('div', { 'class': 'alert-message ' + v.level },
			v.detail
				? [ E('strong', {}, v.head), E('br'), v.detail ]
				: [ E('strong', {}, v.head) ]);
	},

	renderFacts: function(st) {
		var v = verdict(st);
		var rows = [];

		// The state comes first and only on success: on failure the bar
		// above says it, and there is no point duplicating it here.
		if (v.level === 'success')
			rows.push(row(_('State'),
				E('span', { 'style': 'color:#2e7d32;font-weight:bold' }, _('working'))));

		rows.push(row(_('Mode'), _('Everything through VPN')));

		if (st.endpoint_hostname)
			rows.push(row(_('Server'), E('code', {}, st.endpoint_hostname)));

		return E('table', { 'class': 'table' }, rows);
	},

	renderVersions: function(v, box) {
		var self = this;
		var rows = [
			row(_('Package'), v.package || _('unknown')),
			row(_('TrustTunnel client'), v.client || _('not installed'))
		];

		// latest == null means "the check failed": no network, no cache, or
		// the repository does not have a single release yet. This is NOT the
		// same as "no updates", and it must be said in different words —
		// otherwise the user would think they are on the latest version when
		// no check happened.
		if (v.latest == null)
			rows.push(row(_('Update check'), _('unavailable — no network and no cached result')));
		else if (v.update_available)
			rows.push(row(_('Update'), E('span', {}, [
				E('strong', {}, _('%s is available').format(v.latest)), ' — ',
				_('run install.sh again to update')
			])));
		// Installed newer than the last known release is not "up to date"
		// but a special case: either a build from main, or a cache that
		// could not be refreshed. Say it in its own words, not with a
		// blanket reassuring answer.
		else if (v.ahead)
			rows.push(row(_('Update'),
				_('the installed version is newer than the latest release (%s)').format(v.latest)));
		else
			rows.push(row(_('Update'), _('up to date')));

		if (v.stale)
			rows.push(row(_('Update check'), _('GitHub unreachable, showing the last cached result')));

		// The button is essential precisely because the answer is cached:
		// without it the only way to learn about a new release before the
		// cache expires is to reboot the router (the cache lives in /var,
		// i.e. tmpfs).
		return E('div', {}, [
			E('table', { 'class': 'table' }, rows),
			E('div', { 'style': 'margin-top:.5em' }, E('button', {
				'class': 'cbi-button cbi-button-neutral',
				'click': ui.createHandlerFn(this, function() {
					return callVersions(true).then(function(nv) {
						dom.content(box, self.renderVersions(nv, box));
					}).catch(function(e) {
						ui.addNotification(null, E('p', {}, e.message || String(e)), 'danger');
					});
				})
			}, _('Check now')))
		]);
	},

	load: function() {
		return callStatus();
	},

	render: function(st) {
		var self = this;
		var verdictBox = E('div', {}, this.renderVerdict(st));
		var factsBox = E('div', {}, this.renderFacts(st));
		var versionBox = E('div', {}, E('em', {}, _('Checking…')));
		var logBox = E('pre', {
			'style': 'max-height:22em;overflow:auto;margin:0'
		}, '');

		// Versions are requested ONCE at render time, not via poll: the
		// network part is cached, and repeating even a cached call every
		// ten seconds serves no purpose.
		callVersions(false).then(function(v) {
			dom.content(versionBox, self.renderVersions(v, versionBox));
		}).catch(function(e) {
			dom.content(versionBox, E('em', {}, e.message || String(e)));
		});

		poll.add(function() {
			return callStatus().then(function(s) {
				dom.content(verdictBox, self.renderVerdict(s));
				dom.content(factsBox, self.renderFacts(s));
			});
		}, 10);

		poll.add(function() {
			return callLog(80).then(function(r) {
				logBox.textContent = (r.lines || []).join('\n');
			});
		}, 10);

		// The two blocks sit side by side via flex-wrap, NOT via a grid
		// with media queries: both are narrow and self-contained, and
		// flex-basis makes them stack on a phone by itself, without its own
		// CSS. It is the same trick used to lay out form rows in the theme
		// itself (.cbi-value is display:flex).
		//
		// The form cannot be split this way: its rows are ALREADY two-column
		// (a 180px label + field), and the content is capped at 1180px, so a
		// second column would leave the field about 370px and squash the
		// descriptions under it.
		var pair = E('div', {
			'style': 'display:flex;flex-wrap:wrap;gap:0 1.5em'
		}, [
			E('div', { 'style': 'flex:1 1 24em;min-width:0' }, [
				E('h3', {}, _('Now')),
				factsBox
			]),
			E('div', { 'style': 'flex:1 1 24em;min-width:0' }, [
				E('h3', {}, _('Versions')),
				versionBox
			])
		]);

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('TrustTunnel')),

			E('div', { 'class': 'cbi-section' }, [
				verdictBox,
				E('div', { 'style': 'margin-top:1em' }, [
					E('button', {
						'class': 'cbi-button cbi-button-apply',
						'click': ui.createHandlerFn(this, 'handleAction', 'start')
					}, _('Start')),
					' ',
					E('button', {
						'class': 'cbi-button cbi-button-reset',
						'click': ui.createHandlerFn(this, 'handleAction', 'stop')
					}, _('Stop')),
					' ',
					E('button', {
						'class': 'cbi-button cbi-button-action',
						'click': ui.createHandlerFn(this, 'handleAction', 'restart')
					}, _('Restart'))
				])
			]),

			E('div', { 'class': 'cbi-section' }, [ pair ]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Client log')),
				logBox
			])
		]);
	}
});

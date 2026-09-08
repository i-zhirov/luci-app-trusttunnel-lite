# Implementation Plan: TT-11 — settings.js view

- **Created**: 2026-09-08
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-11/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation — no code copied from the inherited file into the plan; field names ARE the UCI schema; identical behavior; CI gates: JS syntax + LuCI require checks"

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature, commit c43e20a).
`settings.js` changed substantially (now 367 lines); the issue contract was updated.
**The actualized contract below — matching the file at c43e20a and the TT-09 issue — is the
authority for this plan. Where any earlier draft conflicts, the actualized text wins and
propagates into every section (Summary, Technical Context, Entities, Contracts, Tasks).**

Facts the plan is rebuilt around:

- **Routing tab replaces the Exclusions tab**: the page declares
  `m.section(form.Section, 'routing_profile', _('Routing profiles'))` — a `form.Section`,
  NOT `NamedSection`, with `addremove = true`, `anonymous = true`, `sortable = true`, and
  the section description "A profile decides what goes through the tunnel. VPN mode tunnels
  everything except the bypass rules; bypass mode tunnels only the VPN rules. Rules accept a
  domain, *.domain, an IP address, IP:port, or a CIDR range.". Options in declaration order:
  `name` (Value, `optional = false`; validate: empty → `_('Name is required')`; unique-name
  scan over `data.trusttunnel['routing_profile'] || []` comparing
  `secs[i]['.name'] !== section_id && secs[i].name === value` →
  `_('Another profile already has this name')`), `mode` (ListValue `vpn` →
  `_('VPN — tunnel everything except the bypass rules')`, `bypass` →
  `_('Bypass — tunnel only the VPN rules')`, `default 'vpn'`, `rmempty = false`),
  `vpn_rules` (DynamicList, placeholder `telegram.org`) and `bypass_rules` (DynamicList,
  placeholder `bank.example`) — both wired to the shared `validateRule`. The legacy
  `domains` NamedSection, `_('Exclusions')`, and the `direct` option are NOT rendered.
- **`validateRule`** (shared by both rule lists): empty → true; `v = value.toLowerCase()`;
  `/^\*:[0-9]+$/` → true (wildcard port, `*:port`); `/^\*\./` → strip one leading `*.`
  (`v.slice(2)`); `/^[0-9a-f:.\[\]\/]+$/` → true (IP / IP:port / [v6]:port / CIDR); the
  hostname regex `/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/` →
  true; else `_('Not a valid domain, IP address or CIDR range')`.
- **Server tab adds three fields** (declared between `post_quantum` and `has_ipv6`):
  `custom_sni` (Value, `optional = true`, placeholder `example.com`; validate: empty ok,
  else lowercase first, then the hostname regex, else `_('Use the format example.com')`);
  `client_random` (Value, `optional = true`, placeholder `0a0b0c/0f0f0f`; validate: empty
  ok; `> 64` chars → `_('At most 64 characters')`; `value.split('/')` — more than 2 parts /
  empty prefix / non-hex prefix → `_('Enter hex digits only, e.g. 0a0b0c or 0a0b0c/0f0f0f')`;
  odd prefix length → `_('The hex prefix must be a whole number of bytes')`; non-hex or odd
  mask → `_('The mask must be hex digits, a whole number of bytes')`; mask length ≠ prefix
  length → `_('The mask must be the same length as the prefix')`); and `routing_profile`
  (ListValue; FIRST value `''` → `_('None — everything through the tunnel')`; then the
  `.name` values of `data.trusttunnel['routing_profile'] || []`; then the stored
  `data.trusttunnel.endpoint.routing_profile` when it names a deleted profile).
- **Unguarded population read pinned**: the current file reads
  `var current = data.trusttunnel.endpoint.routing_profile;` directly — there is no
  `|| {}` guard on `endpoint`. A config without an `endpoint` section throws at render.
  This is today's behavior; per the PRD "fix nothing" rule the reimplementation reproduces
  the unguarded access exactly, and the probe pins it (Task 1 Step 3, server group) so the
  reimplementation cannot silently "fix" or forget it. Flagged in Risks.
- **Import flow sets 12 fields, every one guarded** (matching TT-09's 12-key response):
  `hostname`, `username`, `password`, `certificate` (truthy checks); `custom_sni`
  (truthy); `client_random` (truthy); `protocol` (truthy); `anti_dpi` (`!= null`);
  `has_ipv6` (`!= null`); `skip_verification` (`!= null`); `address` from `res.addresses`
  (non-empty array); `dns_upstream` from `res.dns_upstreams` (non-empty array). Then
  `uci.save()` (PENDING, not applied), `ui.hideModal()`, the `'info'` notification
  `_('Imported. Review the fields and press Save & Apply.')`, and
  `window.setTimeout(function(){ location.reload(); }, 800)`.
- **Key list grew**: the file now has 79 unique `_()` keys (verified by extraction from
  c43e20a: 80 matches, 79 unique — the pre-rebase 56-key contract lost 4 and gained 27;
  every key exists in `po/ru/trusttunnel.po`). The baseline capture, the probe's keys
  group, and the Task 6 key-diff all use this count.
- Field inventory in Task 1's baseline must come from the REBASED settings.js.

## Summary

Rewrite the inherited GPL-2.0 view `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js` in place as a functionally identical, independently expressed LuCI client view, written from the behavioral contract pinned in this plan (not by transforming the inherited text). The page is one `form.Map` with `m.tabbed = true` and four tabs — General (`main`), Server (`endpoint`), Routing (`routing_profile`, a `form.Section` with addremove/anonymous/sortable — this tab REPLACES the old Exclusions tab; the legacy `domains` section is not rendered), Network (`network`) — plus the fork-written import flow (modal textarea → `luci.trusttunnel/import_config` RPC → 12 guarded `uci.set` calls → pending `uci.save()` → notification → 800 ms reload) and the client-side validators (`custom_sni`, `client_random`, profile `name` uniqueness, shared `validateRule` for `vpn_rules`/`bypass_rules`, `fwmark`, `table`).

Work is ordered as: capture the current behavior as an automated baseline first (CI gates + translation-key extraction + a structural probe that encodes the whole pinned contract and is validated against the inherited file as the oracle), then re-express the file in four chunks (scaffold → General+Server → Routing+Network → import flow), with each chunk driven red→green by the probe and the two CI gates, and finish with an equivalence pass (probe fully green, key-list diff, gate negative controls, manual LuCI checklist) and the clean-room clean-tree check mandated by the PRD.

## Technical Context

- **Language/Version**: JavaScript, LuCI client-side resource style: `'use strict';`, `'require …'` directives, top-level `return view.extend({...})` (the LuCI view loader wraps the file in a function — the CI syntax gate parses it wrapped in `(function(){ ... })`). ES5-compatible expression; no modules, no build step.
- **Primary Dependencies**:
  - LuCI client modules: `view` (`view.extend`), `form` (`form.Map`, `form.NamedSection`, `form.Section`, `form.Flag`, `form.Value`, `form.ListValue`, `form.TextValue`, `form.DynamicList`, `form.Button`), `uci` (`uci.load`, `uci.set`, `uci.save`), `rpc` (`rpc.declare`), `ui` (`ui.showModal`, `ui.hideModal`, `ui.addNotification`, `ui.createHandlerFn`).
  - LuCI runtime globals (no require needed, not in the CI module list): `_()` translation, `E()` element builder, `window.setTimeout`, `location.reload`.
  - rpcd backend object `luci.trusttunnel`, method `import_config` (TT-09) — the only RPC the view calls.
- **Storage**: UCI config `trusttunnel` (sections `main`, `endpoint`, `routing_profile` — anonymous, addremove, sortable, the profile rows — and `network`; the legacy `domains` section survives in the schema only as the no-profile fallback and is NOT rendered). The view reads it via `uci.load('trusttunnel')`; the import flow writes via `uci.set` + `uci.save()` — save persists to `/etc/config/trusttunnel` as PENDING (no apply, no service restart); the user must press Save & Apply to activate. This is the "import applies nothing" contract condition.
- **Testing**: no JS unit-test framework in the repo. The gates are the two CI steps in `.github/workflows/ci.yml`:
  1. **JavaScript syntax** — `node` + `vm.Script` wrapping the source in `(function(){\n...\n})` (a plain `node --check` is unreliable for views ending in a top-level `return`).
  2. **LuCI module requires** — for each file in `view/trusttunnel/*.js` and each module in `ui dom rpc uci form view poll fs network validation`: if the file contains a call `module.name(` (regex `(^|[^A-Za-z0-9_.$])${m}\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(`) it must also contain the exact line `'require ${m}'`.
  This plan adds a structural node probe (scratch, new test text) that asserts the pinned field contract textually, plus the translation-key-list diff and the manual LuCI checklist.
- **Target Platform**: LuCI on OpenWrt 22.03+ (apk 25.12 / opkg 22.03–24.10), browser side; the view is served by `luci.mk` from `htdocs/`. Dev machine: macOS with node v25.6.0 (present; gates can run locally).

## Research

### Current view behavior (pinned contract — the specification to reproduce)

Observed from the current file (read 2026-09-09; 367 lines at commit c43e20a). Structure: `'use strict';` → requires `view`, `form`, `uci`, `rpc`, `ui` (in that order) → `var callImport = rpc.declare({object:'luci.trusttunnel', method:'import_config', params:['text']})` → `return view.extend({load, handleImport, render})`. `load()` returns `uci.load('trusttunnel')`. `render(data)` builds `new form.Map('trusttunnel', _('TrustTunnel'))`, sets `m.tabbed = true`, declares the sections in order **main, endpoint, routing_profile, network** (each becomes a tab; titles are the tab names) — `main`/`endpoint`/`network` are `form.NamedSection`, `routing_profile` is `form.Section` with `addremove`/`anonymous`/`sortable` all `true` — and returns `m.render()`. Options render in declaration order — order is part of the contract. The full field inventory is in **Entities**; the import flow and validator semantics are in **Contracts**.

Notes on expression-level facts the reimplementation must preserve (each verified against the current file):

- The `_import` button is the FIRST option of the Server tab and carries a `form.Button` with `inputtitle _('Import…')`, `inputstyle 'action'`, `onclick` wired via `ui.createHandlerFn(this, 'handleImport')`.
- `log_level` ListValue values use the raw strings as labels (`'info'`, `'debug'`, `'trace'`); `protocol` labels are literals `'HTTP/2'` and `'HTTP/3 (QUIC)'` — none of these are `_()` keys.
- `dns_upstream`: 8 presets, values as listed in Entities; only the last two labels are built with `_('plain DNS')`; the six Cloudflare/Quad9/AdGuard labels are raw literals (not `_()` keys).
- `custom_sni` validate lowercases the value BEFORE matching, then tests the hostname regex; empty passes. `client_random` validate follows the pinned sequence in Contracts (length → split → prefix hex/even → mask hex/even → mask length); empty passes. Both are `optional = true`.
- `routing_profile` ListValue: `o.value('', _('None — everything through the tunnel'))` is added FIRST; the profile names come from `data.trusttunnel['routing_profile'] || []` (each `.name`, value and label equal); the stored `data.trusttunnel.endpoint.routing_profile` is appended when it is non-empty and names no known profile. **The `endpoint` read is UNGUARDED** (`data.trusttunnel.endpoint.routing_profile` directly — reproduce as-is; see Actualization).
- The profile `name` validator compares against every OTHER section (`secs[i]['.name'] !== section_id`), so the current row's own name never trips the uniqueness check.
- `mode` ListValue labels ARE `_()` keys: `_('VPN — tunnel everything except the bypass rules')` / `_('Bypass — tunnel only the VPN rules')`; `default 'vpn'`, `rmempty = false`.
- `validateRule` is ONE shared function assigned to BOTH `vpn_rules` and `bypass_rules`; its body order is: empty → true; lowercase; `*:port` → true; strip one `*.`; loose `[0-9a-f:.\[\]/]+` → true; hostname regex → true; else the rejection string. Reproduce exactly — do not "fix" it (out of scope per PRD).
- `fwmark` has only `validate` (no datatype); `table` has BOTH `o.datatype = 'uinteger'` AND a `validate` function; both return `true` for an empty value. `mtu` has `datatype 'range(576,9000)'`; `lan_devices` is `optional = true`.
- Import `uci.set` calls: 12 guarded sets — truthy for `hostname`/`username`/`password`/`certificate`/`custom_sni`/`client_random`/`protocol`; `!= null` for `anti_dpi`/`has_ipv6`/`skip_verification`; non-empty array for `address` (from `res.addresses`) and `dns_upstream` (from `res.dns_upstreams`).
- The modal: title `_('Import endpoint configuration')`, one paragraph `_('Accepts both forms a server hands out: …')`, textarea with `rows: 14, style:'width:100%'` and placeholder `_('Paste the endpoint configuration generated by your server')`; buttons `_('Cancel')` (`class 'btn'`, `click: ui.hideModal`) and `_('Import')` (`class 'cbi-button cbi-button-positive'`, click via `ui.createHandlerFn(this, function(){...})`).
- Success path: `uci.save()` → `ui.hideModal()` → `ui.addNotification(null, E('p', {}, _('Imported. Review the fields and press Save & Apply.')), 'info')` → `window.setTimeout(function(){ location.reload(); }, 800)`.
- Error paths: `res.error` → `ui.addNotification(null, E('p', {}, res.error), 'danger')` and return; promise rejection → `ui.addNotification(null, E('p', {}, e.message || String(e)), 'danger')`.
- The file's long comments (the tabbed-page rationale, the pending-save explanation, the profile/TUN-device notes) are inherited expression; the new file's comments must be written in the implementer's own words and may only state the same mechanics.

### CI gates (exact commands from `.github/workflows/ci.yml`)

- **JavaScript syntax**: `node -e '<vm.Script wrapper>' packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/*.js` — the `-e` script reads each file, tries `new vm.Script("(function(){\n" + src + "\n})")`, prints `ok: <file>` per success and the error message per failure, exits 1 if any file failed.
- **LuCI module requires**: a shell loop over `mods="ui dom rpc uci form view poll fs network validation"` and over `view/trusttunnel/*.js`, using the call regex above and requiring the literal `'require ${m}'` line; exits 1 with `::error` lines on any undeclared module call.
- Both gates iterate the whole `view/trusttunnel/` directory, so the untouched `status.js` and `diagnostics.js` must keep passing (they do today; nothing in this issue touches them).

### TT-09 `import_config` contract (the view's only RPC)

From `.sdd/.current/issues/TT-09/issue.md` method 9: arg `text`; requires `/opt/trusttunnel_client/setup_wizard`; `tt://` prefix → `setup_wizard --mode non-interactive --deeplink <link> --settings <out>`, else secret temp file + `--endpoint_config <file>`; parses TOML-like output — shape-based parser over `key = value` lines: quoted strings (`hostname`, `username`, `password`, `certificate`, `custom_sni`, `client_random`), `upstream_protocol` (http2/http3 → `protocol`), booleans (`has_ipv6`, `skip_verification`, `anti_dpi` → `'1'`/`'0'`), arrays (`addresses`, `dns_upstreams`); on failure filters Rust panic noise and returns `{error}`. **Returns 12 keys**: `{hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]}` — **never touches UCI**; the view applies via `uci.set` + `uci.save`. ACL: `import_config` is in the `write` ubus list of `luci-app-trusttunnel` — unchanged. **Status note**: TT-09 is still Draft (no plan yet) — the contract text above is the implementation basis; device-level import verification depends on the backend, see Risks.

### Translation coverage check

All 79 unique `_()` keys used by the current view exist in `packages/luci-app-trusttunnel/po/ru/trusttunnel.po` (verified by extraction; the `.po` holds ~216 msgids incl. the header). The `.po` is NOT touched by this issue (TT-13 owns it). The full 79-key list is pinned in Contracts and enforced by the Task 1 baseline extraction + probe comparison. Untranslated literals that must stay literals (not wrapped in `_()`): the six Cloudflare/Quad9/AdGuard preset labels, the `'Cloudflare — '` / `'Quad9 — '` prefixes, `'HTTP/2'`, `'HTTP/3 (QUIC)'`, `'info'`, `'debug'`, `'trace'`.

### Clean-room constraints (from the PRD)

- Write from this plan's contract; never transform the inherited text. The probe and all scratch checks are new test text.
- The file is rewritten in place at the same path; per PRD every issue ends with a `git status` check — no `*.old` files, no old-vs-new diffs committed, and the final `git diff` of `settings.js` is reviewed as the new expression (the diff old-vs-new is the allowed review mechanism).
- No behavior changes: fix nothing, "fix" nothing (the loose `validateRule` regex, the unguarded `data.trusttunnel.endpoint.routing_profile` read, and the loose `fwmark`/`table` semantics included).

## Entities

The single data entity is the UCI config `trusttunnel`; the four sections below ARE the field inventory the view must reproduce (section order, option order within a section, widget type, labels, and properties are all contract). All option names are UCI schema names — reproduce exactly. Sections in render order: `main`, `endpoint`, `routing_profile`, `network`. No `domains` section is rendered.

### Section `main` (tab **General**, `form.NamedSection` 'main')

| # | Option | Widget | Title (`_()`) | Properties |
| --- | --- | --- | --- | --- |
| 1 | `enabled` | `form.Flag` | "Start on boot" | description "Whether the service starts when the router boots. The Start button on the Status page runs it right now."; `rmempty=false` |
| 2 | `log_level` | `form.ListValue` | "Log level" | values `info`→`info`, `debug`→`debug`, `trace`→`trace` (literal labels); description "debug and trace write a lot; leave them on only while investigating something." |

### Section `endpoint` (tab **Server**, `form.NamedSection` 'endpoint')

| # | Option | Widget | Title (`_()`) | Properties |
| --- | --- | --- | --- | --- |
| 1 | `_import` | `form.Button` | "Server configuration" | description "The fast path: paste what your server generated and the fields below fill themselves in."; `inputtitle _('Import…')`; `inputstyle 'action'`; `onclick` → `handleImport` via `ui.createHandlerFn` |
| 2 | `address` | `form.DynamicList` | "Addresses" | description "host:port or [ipv6]:port. With several addresses the client measures them and picks the fastest."; `placeholder '203.0.113.10:443'`; `rmempty=false` |
| 3 | `hostname` | `form.Value` | "TLS host name" | description "Used for the TLS session, not for routing. Without it many servers refuse the connection."; `datatype 'hostname'`; `rmempty=false` |
| 4 | `username` | `form.Value` | "User name" | `rmempty=false` |
| 5 | `password` | `form.Value` | "Password" | `password=true`; `rmempty=false` |
| 6 | `protocol` | `form.ListValue` | "Transport" | values `http2`→`HTTP/2`, `http3`→`HTTP/3 (QUIC)` (literal labels); description "QUIC is often faster, but some networks throttle or block UDP." |
| 7 | `anti_dpi` | `form.Flag` | "Anti-DPI" | description "Countermeasures against traffic inspection. Worth enabling if the connection establishes but keeps dropping." |
| 8 | `post_quantum` | `form.Flag` | "Post-quantum key exchange" | `default '1'` |
| 9 | `custom_sni` | `form.Value` | "Custom SNI" | description "Overrides the TLS Server Name. Needed when the server answers on an address that does not match its host name, e.g. behind a CDN or an IP-only setup."; `placeholder 'example.com'`; `optional=true`; `validate` (semantics in Contracts) |
| 10 | `client_random` | `form.Value` | "Client Random, hex prefix" | description "TLS Client Random prefix and mask. Anti-scan servers accept only clients with the matching prefix. Format: abcdef or abcdef/0f0f0f."; `placeholder '0a0b0c/0f0f0f'`; `optional=true`; `validate` (semantics in Contracts) |
| 11 | `routing_profile` | `form.ListValue` | "Routing profile" | description "The named profile that decides what goes through the tunnel. Profiles are managed on the Routing tab."; first value `''`→`_('None — everything through the tunnel')`; then `.name` values from `data.trusttunnel['routing_profile'] || []`; then the stored `data.trusttunnel.endpoint.routing_profile` (UNGUARDED read — reproduce as-is) when it names a deleted profile |
| 12 | `has_ipv6` | `form.Flag` | "Server carries IPv6" | `default '1'` |
| 13 | `skip_verification` | `form.Flag` | "Skip certificate verification" | description "Accepts any certificate, which removes the protection against a substituted server. Pin the certificate below instead whenever you can." |
| 14 | `certificate` | `form.TextValue` | "Pinned certificate (PEM)" | description "Leave empty to use the system trust store, which requires the ca-bundle package."; `rows=6`; `optional=true` |
| 15 | `dns_upstream` | `form.DynamicList` | "DNS used by the client itself" | description "Applies to what the TrustTunnel client resolves on its own — for example the exclusion domains it pre-resolves. Empty means the client default, AdGuard DNS unfiltered."; `placeholder 'tls://1.1.1.1'`; 8 presets (below) |

`dns_upstream` presets (value → label, in order):

| Value | Label |
| --- | --- |
| `tls://1.1.1.1` | `Cloudflare — DNS over TLS` (literal) |
| `tls://9.9.9.9` | `Quad9 — DNS over TLS` (literal) |
| `tls://dns.adguard-dns.com` | `AdGuard — DNS over TLS` (literal) |
| `https://cloudflare-dns.com/dns-query` | `Cloudflare — DNS over HTTPS` (literal) |
| `https://dns.quad9.net/dns-query` | `Quad9 — DNS over HTTPS` (literal) |
| `quic://dns.adguard-dns.com` | `AdGuard — DNS over QUIC` (literal) |
| `1.1.1.1:53` | `'Cloudflare — ' + _('plain DNS')` |
| `9.9.9.9:53` | `'Quad9 — ' + _('plain DNS')` |

### Section `routing_profile` (tab **Routing**, `form.Section` 'routing_profile')

Declared as `m.section(form.Section, 'routing_profile', _('Routing profiles'))` — NOT a NamedSection; `addremove = true`, `anonymous = true`, `sortable = true`. Section description: "A profile decides what goes through the tunnel. VPN mode tunnels everything except the bypass rules; bypass mode tunnels only the VPN rules. Rules accept a domain, *.domain, an IP address, IP:port, or a CIDR range."

| # | Option | Widget | Title (`_()`) | Properties |
| --- | --- | --- | --- | --- |
| 1 | `name` | `form.Value` | "Name" | description "Unique name; the Server tab assigns a profile by it."; `optional=false`; `validate` (empty → 'Name is required'; unique-name scan → 'Another profile already has this name'; semantics in Contracts) |
| 2 | `mode` | `form.ListValue` | "Mode" | values `vpn`→`_('VPN — tunnel everything except the bypass rules')`, `bypass`→`_('Bypass — tunnel only the VPN rules')`; `default 'vpn'`; `rmempty=false` |
| 3 | `vpn_rules` | `form.DynamicList` | "VPN rules" | description "Sent through the tunnel: in bypass mode these are the only destinations that go through; in VPN mode the list has no effect."; `placeholder 'telegram.org'`; `validate = validateRule` (shared) |
| 4 | `bypass_rules` | `form.DynamicList` | "Bypass rules" | description "Always sent out directly: in VPN mode these are the only destinations that bypass the tunnel; in bypass mode the list has no effect."; `placeholder 'bank.example'`; `validate = validateRule` (shared) |

### Section `network` (tab **Network**, `form.NamedSection` 'network')

Section description: "These rarely need changing. MTU is the exception: too high a value makes small pages load while TLS handshakes and large downloads stall."

| # | Option | Widget | Title (`_()`) | Properties |
| --- | --- | --- | --- | --- |
| 1 | `mtu` | `form.Value` | "MTU" | `datatype 'range(576,9000)'`; `default '1350'` |
| 2 | `lan_devices` | `form.Value` | "LAN interfaces" | description "Space-separated list whose forwarded traffic is considered. Empty means the device of the lan network."; `placeholder 'br-lan'`; `optional=true` |
| 3 | `blackhole_on_down` | `form.Flag` | "Drop traffic when the tunnel is down" | description "Adds a blackhole route so marked traffic is dropped instead of leaking to the provider."; `default '1'` |
| 4 | `include_router_traffic` | `form.Flag` | "Route the router's own traffic too" | description "By default only forwarded LAN traffic is routed. Enabling this also routes traffic originated by the router itself, including the update check." |
| 5 | `fwmark` | `form.Value` | "Firewall mark" | description "Decimal or 0x-prefixed hexadecimal. Change only on a conflict with mwan3, SQM or another package that marks packets."; `default '0x9527'`; `validate` (semantics in Contracts; NO datatype) |
| 6 | `table` | `form.Value` | "Routing table" | description "Any table id except 0 and the reserved 253-255."; `datatype 'uinteger'`; `default '880'`; `validate` (semantics in Contracts) |

## Contracts

N/A — no new API endpoints. Two contracts apply: the RPC contract (owned by TT-09, referenced above) and the UI behavior contract pinned here.

### RPC: `luci.trusttunnel/import_config`

- Declared once: `rpc.declare({ object: 'luci.trusttunnel', method: 'import_config', params: [ 'text' ] })`.
- Request: one arg `text` (the textarea content — config file text or `tt://` link).
- Response (TT-09, 12 keys): `{hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]}` on success; `{error}` on failure. The backend never writes UCI.

### Import modal flow (`handleImport`)

1. Open modal: `ui.showModal(_('Import endpoint configuration'), [ ... ])` containing the paragraph, the `rows: 14` textarea with the placeholder, and the two buttons as pinned in Research.
2. On **Import**: `callImport(ta.value)`; then:
   - `res.error` → `ui.addNotification(null, E('p', {}, res.error), 'danger')`, stop.
   - Twelve guarded sets, each with its EXACT guard form:
     1. `res.hostname` (truthy) → `uci.set('trusttunnel','endpoint','hostname',res.hostname)`
     2. `res.username` (truthy) → `username`
     3. `res.password` (truthy) → `password`
     4. `res.certificate` (truthy) → `certificate`
     5. `res.addresses && res.addresses.length` → `address`, `res.addresses`
     6. `res.custom_sni` (truthy) → `custom_sni`
     7. `res.client_random` (truthy) → `client_random`
     8. `res.protocol` (truthy) → `protocol`
     9. `res.anti_dpi != null` → `anti_dpi`
     10. `res.has_ipv6 != null` → `has_ipv6`
     11. `res.skip_verification != null` → `skip_verification`
     12. `res.dns_upstreams && res.dns_upstreams.length` → `dns_upstream`, `res.dns_upstreams`
   - `uci.save()` (PENDING — persists to `/etc/config` without applying; the page then shows unsaved changes and the user applies manually) → `ui.hideModal()` → `ui.addNotification(null, E('p', {}, _('Imported. Review the fields and press Save & Apply.')), 'info')` → `window.setTimeout(function(){ location.reload(); }, 800)`.
   - promise rejection → `ui.addNotification(null, E('p', {}, e.message || String(e)), 'danger')`.

### Unguarded population read (pinned, reproduce as-is)

In `render`, the `routing_profile` ListValue population reads the stored value with
`data.trusttunnel.endpoint.routing_profile` directly — NO `|| {}`/`|| []` guard on
`endpoint`. A UCI state without an `endpoint` section throws at render. This is today's
behavior; per the PRD "fix nothing" rule the reimplementation MUST reproduce the unguarded
expression exactly (the probe pins its presence — Task 1 Step 3, server group). Do not
"fix" it into a guarded read unless the probe is updated in the same change and the
equivalence oracle still passes (the plan's default is: reproduce as-is).

### Validators (exact semantics)

- **`custom_sni`** (returns `true` for empty value — `optional=true`): `v = value.toLowerCase()`; if `/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/` fails → `_('Use the format example.com')`; else `true`.
- **`client_random`** (returns `true` for empty value — `optional=true`): `value.length > 64` → `_('At most 64 characters')`; `parts = value.split('/')` — `parts.length > 2 || !parts[0] || !/^[0-9a-f]+$/i.test(parts[0])` → `_('Enter hex digits only, e.g. 0a0b0c or 0a0b0c/0f0f0f')`; `parts[0].length % 2 !== 0` → `_('The hex prefix must be a whole number of bytes')`; when `parts.length === 2`: `!/^[0-9a-f]+$/i.test(parts[1]) || parts[1].length % 2 !== 0` → `_('The mask must be hex digits, a whole number of bytes')`; `parts[1].length !== parts[0].length` → `_('The mask must be the same length as the prefix')`; else `true`.
- **`name`** (profile name, `optional=false`): empty → `_('Name is required')`; loop over `data.trusttunnel['routing_profile'] || []`: if `secs[i]['.name'] !== section_id && secs[i].name === value` → `_('Another profile already has this name')`; else `true`.
- **`validateRule`** (shared by `vpn_rules` and `bypass_rules`; returns `true` for empty value): `v = value.toLowerCase()`; `/^\*:[0-9]+$/` → `true`; `/^\*\./` → `v = v.slice(2)`; `/^[0-9a-f:.\[\]\/]+$/` → `true`; `/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/` → `true`; else `_('Not a valid domain, IP address or CIDR range')`.
- **`fwmark`** (returns `true` for empty value): if not `/^(0x[0-9a-fA-F]{1,8}|[0-9]{1,10})$/` → `_('Enter a decimal number or 0x-prefixed hexadecimal')`; else if not `/^0x/i` and `+value > 4294967295` → `_('Enter a decimal number no greater than 4294967295')`; else `true`.
- **`table`** (returns `true` for empty value): if not (`/^[0-9]+$/` and `1 <= +value <= 4294967294`) → `_('Enter a table id between 1 and 4294967294')`; else if `253 <= +value <= 255` → `_('Table ids 253, 254 and 255 are reserved by the system')`; else `true`.
- The legacy `direct` validator is GONE — do not re-introduce it or any `direct` option.

### Translation keys (79 unique, unchanged from the rebased file; all present in the `.po`)

The count is verified by extraction from the file at c43e20a (80 `_('...')` matches, 79 unique
after unescaping `\\.` escapes; the pre-rebase 56-key list lost 4 keys and gained 27). The
Task 1 baseline extraction is the authority; this list is the pinned expectation:

```
A profile decides what goes through the tunnel. VPN mode tunnels everything except the bypass rules; bypass mode tunnels only the VPN rules. Rules accept a domain, *.domain, an IP address, IP:port, or a CIDR range.
Accepts any certificate, which removes the protection against a substituted server. Pin the certificate below instead whenever you can.
Accepts both forms a server hands out: the configuration file text and a tt:// link. Nothing is saved until you press Save & Apply.
Addresses
Adds a blackhole route so marked traffic is dropped instead of leaking to the provider.
Always sent out directly: in VPN mode these are the only destinations that bypass the tunnel; in bypass mode the list has no effect.
Another profile already has this name
Anti-DPI
Any table id except 0 and the reserved 253-255.
Applies to what the TrustTunnel client resolves on its own — for example the exclusion domains it pre-resolves. Empty means the client default, AdGuard DNS unfiltered.
At most 64 characters
By default only forwarded LAN traffic is routed. Enabling this also routes traffic originated by the router itself, including the update check.
Bypass rules
Bypass — tunnel only the VPN rules
Cancel
Client Random, hex prefix
Countermeasures against traffic inspection. Worth enabling if the connection establishes but keeps dropping.
Custom SNI
DNS used by the client itself
Decimal or 0x-prefixed hexadecimal. Change only on a conflict with mwan3, SQM or another package that marks packets.
Drop traffic when the tunnel is down
Enter a decimal number no greater than 4294967295
Enter a decimal number or 0x-prefixed hexadecimal
Enter a table id between 1 and 4294967294
Enter hex digits only, e.g. 0a0b0c or 0a0b0c/0f0f0f
Firewall mark
General
Import
Import endpoint configuration
Imported. Review the fields and press Save & Apply.
Import…
LAN interfaces
Leave empty to use the system trust store, which requires the ca-bundle package.
Log level
MTU
Mode
Name
Name is required
Network
None — everything through the tunnel
Not a valid domain, IP address or CIDR range
Overrides the TLS Server Name. Needed when the server answers on an address that does not match its host name, e.g. behind a CDN or an IP-only setup.
Password
Paste the endpoint configuration generated by your server
Pinned certificate (PEM)
Post-quantum key exchange
QUIC is often faster, but some networks throttle or block UDP.
Route the router's own traffic too
Routing profile
Routing profiles
Routing table
Sent through the tunnel: in bypass mode these are the only destinations that go through; in VPN mode the list has no effect.
Server
Server carries IPv6
Server configuration
Skip certificate verification
Space-separated list whose forwarded traffic is considered. Empty means the device of the lan network.
Start on boot
Table ids 253, 254 and 255 are reserved by the system
TLS Client Random prefix and mask. Anti-scan servers accept only clients with the matching prefix. Format: abcdef or abcdef/0f0f0f.
TLS host name
The fast path: paste what your server generated and the fields below fill themselves in.
The hex prefix must be a whole number of bytes
The mask must be hex digits, a whole number of bytes
The mask must be the same length as the prefix
The named profile that decides what goes through the tunnel. Profiles are managed on the Routing tab.
These rarely need changing. MTU is the exception: too high a value makes small pages load while TLS handshakes and large downloads stall.
Transport
TrustTunnel
Unique name; the Server tab assigns a profile by it.
Use the format example.com
Used for the TLS session, not for routing. Without it many servers refuse the connection.
User name
VPN rules
VPN — tunnel everything except the bypass rules
Whether the service starts when the router boots. The Start button on the Status page runs it right now.
debug and trace write a lot; leave them on only while investigating something.
host:port or [ipv6]:port. With several addresses the client measures them and picks the fastest.
plain DNS
```

In source, the key "Route the router's own traffic too" is written `_('Route the router\'s own traffic too')` — the key-extraction regex MUST handle `\\` escapes AND unescape before dedup, or the key-list diff silently mangles one key.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js` | Rewrite (in place) | The four-tab settings page: `form.Map` tabbed scaffold, all 4 sections and 27 option rows (26 fields + the `_import` button; incl. the `routing_profile` `form.Section`), the import modal flow, the six validators (`custom_sni`, `client_random`, `name`, `validateRule`, `fwmark`, `table`); new expression from this plan's contract |
| `tests/zz_tt11_view_probe.js` | Create (scratch; deleted in Task 6) | Structural contract probe: parses the view source text, asserts every pinned field/property/validator/import-flow fact and the 79-key equality against the baseline file; prints `ok:`/`FAIL:` per assertion, exits 1 on any FAIL |
| `tests/zz_tt11_keys_baseline.txt` | Create (scratch; deleted in Task 6) | Sorted unique `_()` key list extracted from the CURRENT (inherited) file in Task 1 — the translation-keys oracle for the diff |
| `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`, `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`, `po/ru/trusttunnel.po`, `status.js`, `diagnostics.js`, `Makefile` | Keep (untouched) | Menu entry (`trusttunnel/settings`), ACL (write `import_config`), translations, sibling views, packaging — none change |

Scratch files live under `tests/zz_tt11_*` (do not match the `tests/test_*.sh` runner glob; ignored by the CI JS gates which only look in `view/trusttunnel/`); both are deleted in Task 6.

## Tasks

### [ ] Task 1: Capture the current baseline (gates, key list, contract probe)

**Files:**

- Read-only: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`, `.github/workflows/ci.yml`
- Create: `tests/zz_tt11_keys_baseline.txt`, `tests/zz_tt11_view_probe.js`

- [ ] **Step 1: Run both CI JS gates on the current file and record that they pass**

Run the exact "JavaScript syntax" and "LuCI module requires" commands from `.github/workflows/ci.yml` (the `node -e '...vm.Script...'` one-liner over `view/trusttunnel/*.js`, and the `mods="ui dom rpc uci form view poll fs network validation"` grep loop). Capture the output to `/tmp/tt11-gates-before.txt`.

Expected: both exit 0; every view file prints `ok:`; the requires step prints "every LuCI module used is declared". This is the green baseline the new file must reproduce.

- [ ] **Step 2: Extract the current translation-key list into the baseline file**

Run a node one-liner that reads `settings.js`, matches every `_('...')` string literal with the regex `/_\(\x27((?:[^\x27\\]|\\.)*)\x27\)/g` (the `\x27` form avoids quote-escaping problems; the escaped-apostrophe form `\\.` is REQUIRED — the key "Route the router's own traffic too" is written `_('Route the router\'s own traffic too')` and a naive `[^']*` match would silently miss it), UNESCAPES each capture (`\\(.)` → `$1` — required so the escaped-apostrophe key dedups to its plain form), sorts the unique strings, and writes them one per line to `tests/zz_tt11_keys_baseline.txt`.

Expected: exactly 79 lines (80 matches, 79 unique — the verified count of the rebased file: the pre-rebase 56-key contract lost 4 keys and gained 27), matching the 79-key contract list in this plan's Contracts section (spot-check several, incl. the escaped-apostrophe key).

- [ ] **Step 3: Write the contract probe and prove it is green against the current file**

Write `tests/zz_tt11_view_probe.js` (new test text — a plain node script, no LuCI dependencies) that takes a view file path as argv and asserts, printing `ok:`/`FAIL:` with a group tag per assertion and exiting 1 on any FAIL:

- **scaffold group**: `'use strict';` is the first line; the five `'require view|form|uci|rpc|ui'` lines exist; a `rpc.declare` call exists with object `luci.trusttunnel`, method `import_config`, params `['text']`; a `view.extend({` with `load:` calling `uci.load('trusttunnel')`; a `form.Map('trusttunnel'` with the title arg `_('TrustTunnel')`; `tabbed = true`; the four sections in declaration order — `form.NamedSection` `main` with title `_('General')`, `form.NamedSection` `endpoint` with title `_('Server')`, `form.Section` (NOT NamedSection) `'routing_profile'` with title `_('Routing profiles')` AND `addremove = true` AND `anonymous = true` AND `sortable = true`, `form.NamedSection` `network` with title `_('Network')`; the `routing_profile` and `network` section descriptions present; NO `form.NamedSection` for `domains`, NO `_('Exclusions')`, NO `direct` option anywhere (assert absence — the old tab is gone); `return m.render();`.
- **general group**: `enabled` is a `form.Flag` with `rmempty = false`; `log_level` is a `form.ListValue` with exactly the value triples `info, debug, trace` (label equals value) and its description key.
- **server group**: the 15 rows in declaration order: `_import` button FIRST, then `address, hostname, username, password, protocol, anti_dpi, post_quantum, custom_sni, client_random, routing_profile, has_ipv6, skip_verification, certificate, dns_upstream`; `_import`: `form.Button`, `inputtitle _('Import…')`, `inputstyle 'action'`, an `onclick` via `ui.createHandlerFn`; `address`: `form.DynamicList`, placeholder `203.0.113.10:443`, `rmempty = false`; `hostname`: `form.Value`, `datatype 'hostname'`, `rmempty = false`; `username`: `rmempty = false`; `password`: `password = true`, `rmempty = false`; `protocol`: `form.ListValue` with exactly `http2` and `http3`; `post_quantum` and `has_ipv6`: `default = '1'`; `custom_sni`: `form.Value`, placeholder `example.com`, `optional = true`, validate body contains `toLowerCase()` and the hostname regex and `_('Use the format example.com')`; `client_random`: `form.Value`, placeholder `0a0b0c/0f0f0f`, `optional = true`, validate body contains `64`, `split('/')`, the five rejection keys in order; `routing_profile`: `form.ListValue`, first value `''` with `_('None — everything through the tunnel')`, populated from `data.trusttunnel['routing_profile']` names (`.name`), with the stored-value fallback — AND the exact UNGUARDED expression `data.trusttunnel.endpoint.routing_profile` present (pins finding 7: reproduce-as-is; a guarded variant counts as a FAIL unless the plan's default is changed in the same change); `certificate`: `form.TextValue`, `rows = 6`, `optional = true`; `dns_upstream`: `form.DynamicList`, placeholder `tls://1.1.1.1`, and the 8 preset value→label pairs in the exact order from Entities (including the `'Cloudflare — ' + _('plain DNS')` concatenations).
- **routing group**: the 4 options in declaration order `name, mode, vpn_rules, bypass_rules`; `name`: `form.Value`, `optional = false`, validate body contains `_('Name is required')`, the loop over `data.trusttunnel['routing_profile']` comparing `secs[i]['.name'] !== section_id && secs[i].name === value`, and `_('Another profile already has this name')`; `mode`: `form.ListValue` with exactly `vpn` and `bypass` using the two `_()` labels, `default = 'vpn'`, `rmempty = false`; `vpn_rules` and `bypass_rules`: both `form.DynamicList`, placeholders `telegram.org` / `bank.example`, both assigned the SAME `validateRule` function; the `validateRule` body contains in order: `toLowerCase()`, `/^\*:[0-9]+$/`, `/^\*\./`, `slice(2)`, `/^[0-9a-f:.\[\]\/]+$/`, the hostname regex, and the rejection `_('Not a valid domain, IP address or CIDR range')`.
- **network group**: the 6 options in declaration order `mtu, lan_devices, blackhole_on_down, include_router_traffic, fwmark, table`; `mtu`: `datatype 'range(576,9000)'`, `default = '1350'`; `lan_devices`: `placeholder 'br-lan'`, `optional = true`; `blackhole_on_down`: `default = '1'`; `fwmark`: `default = '0x9527'`, `validate` with `/^(0x[0-9a-fA-F]{1,8}|[0-9]{1,10})$/`, `/^0x/i`, `4294967295`, and both fwmark rejection strings; `table`: `datatype 'uinteger'`, `default = '880'`, `validate` with `4294967294`, the range rejection string, and the reserved-ids rejection string.
- **import group**: a `handleImport` member exists; `ui.showModal` called with `_('Import endpoint configuration')`; the paragraph key and the placeholder key; a textarea with `rows: 14`; `ui.createHandlerFn` used for the Import button; `callImport(` invoked with `ta.value`; ALL TWELVE guarded `uci.set` calls present with their exact guard forms: truthy `res.hostname`, `res.username`, `res.password`, `res.certificate`, `res.custom_sni`, `res.client_random`, `res.protocol`; `res.anti_dpi != null`, `res.has_ipv6 != null`, `res.skip_verification != null`; `res.addresses && res.addresses.length` → `address`; `res.dns_upstreams && res.dns_upstreams.length` → `dns_upstream`; `uci.save()`; `ui.hideModal()`; `ui.addNotification` with `'info'` and `_('Imported. Review the fields and press Save & Apply.')`, with `'danger'` and `res.error`, and with `'danger'` and `e.message`; `window.setTimeout(` with `800` and `location.reload()`.
- **keys group**: the sorted unique `_()` keys extracted from the target file (same regex+unescape as Step 2) equal the contents of `tests/zz_tt11_keys_baseline.txt` line-for-line, and the count is 79.

Run: `node tests/zz_tt11_view_probe.js packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`

Expected: every assertion `ok:`, exit 0 — the probe encodes today's behavior (the equivalence oracle for all later tasks).

- [ ] **Step 4: Negative control — the probe can fail**

Temporarily corrupt one assertion in the probe (e.g. expect a wrong widget type for `mtu`). Run it against the current file — Expected: exit 1, that one assertion `FAIL:`. Restore the probe, re-run — Expected: exit 0.

**Verification**: `/tmp/tt11-gates-before.txt` shows both gates green on the inherited file; `tests/zz_tt11_keys_baseline.txt` holds exactly the 79 contract keys; the probe is green on the inherited file and proven able to fail. The baseline is the comparison target for every later task.

### [ ] Task 2: Re-express the scaffold — requires, RPC declaration, load, tabbed Map with the four sections

**Files:**

- Rewrite (in place): `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`
- Use: `tests/zz_tt11_view_probe.js`

- [ ] **Step 1: Replace the file content with the new scaffold (write the failing state)**

Overwrite `settings.js` with your own expression implementing only: `'use strict';`, the five `'require view'; 'require form'; 'require uci'; 'require rpc'; 'require ui';` directives, the `callImport` `rpc.declare` for `import_config`, and `return view.extend({ load: function(){ return uci.load('trusttunnel'); }, render: function(data){ ... } })` where `render` builds `new form.Map('trusttunnel', _('TrustTunnel'))`, sets `m.tabbed = true`, declares the four sections in order — `form.NamedSection` `main` with `_('General')`, `form.NamedSection` `endpoint` with `_('Server')`, `form.Section` `'routing_profile'` with `_('Routing profiles')` plus `s.addremove = true; s.anonymous = true; s.sortable = true;` and its description, and `form.NamedSection` `network` with `_('Network')` and its description — and returns `m.render()`. No options, no `handleImport` yet. Comments, if any, are your own words stating the tabbed-page and routing-profile mechanics.

- [ ] **Step 2: Run the probe — expected RED on the unimplemented chunks**

Run: `node tests/zz_tt11_view_probe.js packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`

Expected: exit 1; `scaffold` group assertions `ok:`; all `general`/`server`/`routing`/`network`/`import`/`keys` assertions `FAIL:` (options and the flow are not implemented yet). This is the red state for this chunk.

- [ ] **Step 3: Run both CI gates on the new file**

Run the "JavaScript syntax" and "LuCI module requires" commands from ci.yml.

Expected: both exit 0. The requires gate passes even though `ui` is not called yet (the gate only flags modules that ARE called but not declared — keep the `'require ui'` line from the start so the import task cannot forget it).

- [ ] **Step 4: Verify the chunk is complete**

Re-run the probe — Expected: `scaffold` group still fully green, every other group still `FAIL:` (deliberate), exit 1. Run the gates again — Expected: green.

**Verification**: the new skeleton passes both CI gates; the probe confirms the scaffold contract (four sections in order incl. the `form.Section` routing_profile with addremove/anonymous/sortable, map title, `tabbed`, `load`, RPC declaration, requires, absence of domains/Exclusions) while all field assertions are still red — the red state for the next chunks is established.

### [ ] Task 3: Re-express the General and Server tabs (all 15 rows, incl. the three new fields)

**Files:**

- Rewrite (in place): `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`
- Use: `tests/zz_tt11_view_probe.js`

- [ ] **Step 1: Confirm the red state for this chunk**

Run the probe — Expected: `general` and `server` groups `FAIL:` (fields absent), others unchanged.

- [ ] **Step 2: Implement the General and Server options**

Add to the existing sections, in new expression, exactly the options of Entities "Section `main`" and "Section `endpoint`": the `enabled` Flag (`rmempty=false`, description), the `log_level` ListValue (literal labels), the `_import` Button FIRST in the Server section (title/description/`inputtitle`/`inputstyle`/`onclick` via `ui.createHandlerFn(this, 'handleImport')` — the method itself comes in Task 5), then `address`, `hostname`, `username`, `password` (all three `rmempty=false`; `password=true`), `protocol` (literal labels), `anti_dpi`, `post_quantum` (`default='1'`), `custom_sni` (placeholder `example.com`, `optional=true`, the lowercase-first hostname-shape validator), `client_random` (placeholder `0a0b0c/0f0f0f`, `optional=true`, the length/split/hex/even/mask-length validator), `routing_profile` (ListValue: `''` → `_('None — everything through the tunnel')` first; the `.name` values of `data.trusttunnel['routing_profile'] || []`; then the stored value via the UNGUARDED `data.trusttunnel.endpoint.routing_profile` read when it names a deleted profile — reproduce the unguarded expression exactly), `has_ipv6` (`default='1'`), `skip_verification`, `certificate` (`rows=6`, `optional=true`), `dns_upstream` with its placeholder and the 8 presets exactly as listed. All titles/descriptions are the `_()` strings from the Contracts key list; the six Cloudflare/Quad9/AdGuard preset labels and `HTTP/2`/`HTTP/3 (QUIC)`/`info`/`debug`/`trace` stay raw literals.

- [ ] **Step 3: Run the probe — expected GREEN on this chunk**

Run the probe — Expected: `general` and `server` groups fully `ok:` (incl. the `routing_profile` population and the pinned unguarded read); `routing`, `network`, `import` groups still `FAIL:`; `keys` still `FAIL:` (the new file's keys are a subset of the 79 until Tasks 4–5 land); exit 1 overall.

- [ ] **Step 4: Run both CI gates**

Expected: both exit 0 (the `ui.createHandlerFn` call in the `onclick` now exercises the `ui` require — the gate confirms it is declared).

**Verification**: probe `general`+`server` groups green (widgets, order, defaults, `rmempty`, datatypes, placeholders, validators, all 8 presets with exact values/labels, routing_profile population), gates green; remaining groups still red.

### [ ] Task 4: Re-express the Routing and Network tabs (profile section + validators)

**Files:**

- Rewrite (in place): `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`
- Use: `tests/zz_tt11_view_probe.js`

- [ ] **Step 1: Confirm the red state for this chunk**

Run the probe — Expected: `routing` and `network` groups `FAIL:`, others as before.

- [ ] **Step 2: Implement the Routing and Network options**

Add to the existing sections, in new expression, exactly the options of Entities "Section `routing_profile`" and "Section `network`": the profile `name` (Value, `optional=false`, empty → `_('Name is required')`, the uniqueness scan against `data.trusttunnel['routing_profile'] || []` with the `secs[i]['.name'] !== section_id` self-exclusion → `_('Another profile already has this name')`), `mode` (ListValue with the two `_()` labels, `default='vpn'`, `rmempty=false`), `vpn_rules` (placeholder `telegram.org`) and `bypass_rules` (placeholder `bank.example`) both assigning the ONE shared `validateRule` function implementing the Contracts semantics (empty→true; lowercase; `*:port`→true; strip one `*.`; loose `[0-9a-f:.\[\]/]+`→true; hostname regex→true; rejection string); and the six network options with `mtu`'s `datatype 'range(576,9000)'` + `default '1350'`, `lan_devices`'s `placeholder 'br-lan'` + `optional=true`, `blackhole_on_down` `default '1'`, `include_router_traffic` (no default), and `fwmark` + `table` with their exact `validate` semantics from Contracts (both return `true` on empty; `table` keeps `datatype 'uinteger'` AND its validator; `fwmark` has no datatype). Do not "improve" the loose `validateRule` regex — reproduce the pinned semantics byte-for-byte in behavior. Do not render a `domains` section or a `direct` field.

- [ ] **Step 3: Run the probe — expected GREEN on this chunk**

Expected: `routing` and `network` groups fully `ok:` (including the `validateRule` regexes, the `*:port` handling, the name-uniqueness scan, and the fwmark/table validators with their rejection strings); `import` group still `FAIL:`; `keys` group still `FAIL:` (the Routing/Network keys are present now, but the import-flow keys are still missing); exit 1 overall.

- [ ] **Step 4: Run both CI gates**

Expected: both exit 0.

**Verification**: probe `routing`+`network` groups green (widgets, order, defaults, datatypes, validator regex sequences and messages, shared validateRule), gates green; only `import` and `keys` groups remain red.

### [ ] Task 5: Re-express the import flow (`handleImport` + modal, 12 guarded sets)

**Files:**

- Rewrite (in place): `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`
- Use: `tests/zz_tt11_view_probe.js`

- [ ] **Step 1: Confirm the red state for this chunk**

Run the probe — Expected: `import` group `FAIL:` (`handleImport` absent), `keys` group `FAIL:` (the import strings missing).

- [ ] **Step 2: Implement `handleImport` and the modal**

Add a `handleImport` member to `view.extend` implementing the Contracts "Import modal flow" exactly: `ui.showModal(_('Import endpoint configuration'), [ ... ])` with the paragraph, the `rows: 14` textarea (`style:'width:100%'`, placeholder key), the `Cancel` button (`class 'btn'`, `click: ui.hideModal`, `_('Cancel')`) and the `Import` button (`class 'cbi-button cbi-button-positive'`, click via `ui.createHandlerFn(this, function(){ ... })`, `_('Import')`); inside the handler: `callImport(ta.value)`; `res.error` → danger notification and stop; the TWELVE guarded `uci.set` calls with their exact guard forms (truthy for `hostname`/`username`/`password`/`certificate`/`custom_sni`/`client_random`/`protocol`; `!= null` for `anti_dpi`/`has_ipv6`/`skip_verification`; `res.addresses && res.addresses.length` → `address`; `res.dns_upstreams && res.dns_upstreams.length` → `dns_upstream`); `uci.save()` then `ui.hideModal()`, the `'info'` notification with `_('Imported. Review the fields and press Save & Apply.')`, and `window.setTimeout(function(){ location.reload(); }, 800)`; `.catch(function(e){ ui.addNotification(null, E('p', {}, e.message || String(e)), 'danger'); })`. The `onclick` wired in Task 3 now resolves to the real method.

- [ ] **Step 3: Run the probe — expected FIRST FULL GREEN**

Run the probe — Expected: every group including `import` and `keys` fully `ok:`, exit 0. This is the first complete pass of the whole contract against the new file.

- [ ] **Step 4: Run both CI gates**

Expected: both exit 0 (`ui`, `rpc`, `uci`, `form`, `view` all now called and declared).

**Verification**: full probe green — the new file satisfies every pinned contract fact and its `_()` key set equals the inherited file's 79 keys; both CI gates green.

### [ ] Task 6: Final verification — equivalence, gates with negative controls, manual LuCI checklist, clean tree

**Files:**

- Rewrite (in place): `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js` (already done — used for sabotage/restore in Step 2)
- Delete: `tests/zz_tt11_view_probe.js`, `tests/zz_tt11_keys_baseline.txt`
- Read-only: `.github/workflows/ci.yml`, `po/ru/trusttunnel.po`, `menu.d/` and `acl.d/` JSONs

- [ ] **Step 1: Re-run the full probe and both gates**

Run: `node tests/zz_tt11_view_probe.js packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js` — Expected: exit 0, every assertion `ok:`.

Run both ci.yml JS gates — Expected: both exit 0. Also run `python3 -c "import json,sys; json.load(open(sys.argv[1]))"` on the two JSON files (menu/acl) and `git diff --stat` to confirm only `settings.js` changed among package files.

- [ ] **Step 2: Negative controls — prove the gates check THIS file**

Sabotage 1: remove the `'require ui';` line from the new file. Run the requires gate — Expected: exit 1, `::error` naming `ui` (this is exactly the failure class the gate exists for). Restore the line.

Sabotage 2: introduce a syntax error (e.g. add a line `let x = ;`). Run the syntax gate — Expected: exit 1 with a `SyntaxError` naming `settings.js`. Restore.

Re-run both gates — Expected: both exit 0.

- [ ] **Step 3: Manual LuCI checklist (on a device/rootfs with TT-09's backend; document results)**

Run the checklist below, noting pass/fail per item:

1. **Render**: the Settings page shows the four tabs General/Server/Routing/Network; every field from the Entities tables is present with the right widget; defaults shown: `post_quantum` and `has_ipv6` on, `mode` vpn (on a new profile row), `mtu` 1350, `blackhole_on_down` on, `fwmark` `0x9527`, `table` 880; the import button shows "Import…"; the routing_profile list shows "None — everything through the tunnel" plus every profile name from `uci show trusttunnel`; preset labels appear exactly as pinned (including the untranslated literal labels).
2. **Every field saves to UCI**: edit each field (incl. multi-entry lists `address`/`dns_upstream`/`vpn_rules`/`bypass_rules`, the multiline `certificate`, `custom_sni`, `client_random`), Save & Apply, then on the router run `uci show trusttunnel` — values match what was entered, list options repeated per entry, no extra options.
3. **Routing tab profile UI**: click "Add" on the Routing tab → a new profile row appears (anonymous section); empty `name` blocks save with "Name is required"; naming a second profile the same as the first blocks save with "Another profile already has this name"; `mode` switches vpn/bypass with the exact labels; rules add and remove freely; profile rows drag-sort (sortable) and the order survives Save & Apply (`uci show trusttunnel` order).
4. **routing_profile assignment**: create profile `P` on the Routing tab, Save & Apply → the Server tab's Routing profile list shows `P`; select `P`, Save & Apply → `uci show trusttunnel` shows `endpoint.routing_profile='P'`; delete `P` (remove the row, save) → the Server tab still lists the stored `P` value (deleted-profile fallback) and saving keeps it; "None — everything through the tunnel" always present and selectable.
5. **Import from file text**: paste a server-generated config text → the modal closes, the info notification appears, after ~800 ms the page reloads with the imported fields filled — all of hostname/username/password/certificate/address/custom_sni/client_random/protocol/anti_dpi/has_ipv6/skip_verification/dns_upstream that the backend returned (12-field import); the page shows pending unsaved changes; BEFORE pressing Save & Apply the running service/config are untouched (no service restart; `uci show trusttunnel` on the router still shows the pre-import values) — the "import applies nothing" condition.
6. **Import from `tt://` link**: same flow with a deeplink; error path: paste garbage → a `danger` notification with the backend's error text, modal stays open, nothing changes.
7. **Validator rejections** (each must block save with the exact rejection string): `custom_sni` — `bad..name`, `has space`, `-x.com`, `foo.` → "Use the format example.com"; accepted: `example.com`, `sub.example.com`, `localhost`, empty; `client_random` — `zzzz` (non-hex), `abc` (odd), `abc/def` (odd mask), `abc/ab` (mask length mismatch), `a/b/c` (3 parts), 65 chars → the five exact rejection strings; accepted: `0a0b0c`, `0a0b0c/0f0f0f`, empty; profile `name` — empty → "Name is required", duplicate → "Another profile already has this name"; `vpn_rules`/`bypass_rules` (validateRule) — `bad..domain`, `has space`, `a b`, `*` → "Not a valid domain, IP address or CIDR range"; accepted: `bank.example`, `*.bank.example`, `*:443`, `192.0.2.1`, `203.0.113.10:443`, `[2001:db8::1]:443`, `2001:db8::/32`; `fwmark` — `0x123456789` (9 hex digits), `9999999999` (> 4294967295), `12x`, `0xGG` → rejected; accepted: `0x9527`, `9527`, `0xffffffff`; `table` — `0`, `253`, `254`, `255`, `4294967295`, `abc` → rejected (253–255 with the reserved-ids string); accepted: `1`, `252`, `256`, `880`, `4294967294`.
8. **Translation**: with the Russian locale, every `_()` string renders translated; the raw literals (preset labels, HTTP/2, HTTP/3 (QUIC), info/debug/trace) render untranslated as today.

Record the results (e.g. in the issue or a comment); if no device is available, state that this step is pending a device pass — it is the acceptance criterion "manual LuCI pass" and must be executed before the issue is closed.

- [ ] **Step 4: Key-list and clean-tree/clean-room check**

Run the key extraction of Task 1 Step 2 against the NEW file and diff against `tests/zz_tt11_keys_baseline.txt` — Expected: identical 79 keys (the probe already asserts this; this step is the visible diff). Then delete both scratch files and run `git status --porcelain` — Expected: only `packages/.../settings.js` among package files (plus the `.sdd/` spec files); NO `*.old` files, NO `tests/zz_tt11_*` left. Finally review `git diff` of `settings.js` — the diff old-vs-new is the clean-room review: confirm the new text is independent expression (no verbatim inherited lines, no inherited comment text), per the PRD's per-issue `git status` rule.

**Verification**: probe fully green, both gates green and proven to catch sabotage, manual checklist items pass (or are explicitly tracked as pending a device), scratch files deleted, `git status` clean of artifacts, `git diff` reviewed as new expression.

## Risks and Open Items

- **TT-09 is not yet planned (Draft)**: TT-11 is blocked by TT-09, which has no `plan.md` yet. The `import_config` contract (12-key response) is fully pinned in the TT-09 issue, so implementation can proceed; but the manual LuCI import checklist (Task 6 Step 3 items 5–6) can only be executed once the rewritten backend exists. Plan may need no adjustment — the contract is the source of truth.
- **Unguarded `data.trusttunnel.endpoint.routing_profile` read**: the population read throws at render when the UCI state has no `endpoint` section. This is today's behavior and the plan pins it (reproduce as-is, probe asserts the unguarded expression) per the PRD "fix nothing" rule. If implementation decides the crash must be guarded, that is a behavior change beyond this issue's scope and must be raised separately.
- **Probe is structural, not behavioral**: the node probe asserts source-text facts (widgets, order, defaults, regexes, strings), not rendered behavior. Runtime equivalence rests on the manual LuCI checklist; the CI gates remain the regression net. This is the same verification split the repo uses for the other views.
- **Ordering is contract**: option declaration order drives render order; the probe asserts section order (incl. `routing_profile` as the third, `form.Section` tab) and intra-section option order, and the import button's position before `address`.
- **The escaped-apostrophe key**: "Route the router's own traffic too" appears in source as `_('Route the router\'s own traffic too')`; the key-extraction regex MUST handle `\\` escapes AND unescape before dedup, or the key-list diff silently mangles one key (the probe's keys group would catch it).
- **Key count is 79, not 77**: the review's arithmetic (56 − 4 + 25 = 77) under-counted; extraction from c43e20a yields 79 unique keys (56 − 4 + 27; the old 56-key list was itself missing "debug and trace write a lot; leave them on only while investigating something."). The plan pins the VERIFIED 79; the Task 1 baseline extraction is the authority and the probe enforces equality mechanically.
- **Loose `validateRule` regex**: `[0-9a-f:.\[\]/]+` accepts things a stricter validator would reject (e.g. `1.2.3.4.5`). This is today's behavior; reproducing it is required, "fixing" it is out of scope per PRD. Same for the legacy `direct`-less rule set — no `domains` section is rendered.
- **Local node availability**: gates need node (v25.6.0 present on the dev machine). If a different machine lacks node, the gates still run in CI on every PR — local runs are a convenience, not a new dependency.
- **No new files shipped**: everything is an in-place rewrite plus two scratch files deleted by Task 6 — nothing new enters the built package (menu/acl/po untouched).

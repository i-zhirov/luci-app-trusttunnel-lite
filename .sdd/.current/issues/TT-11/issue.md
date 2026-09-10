# Issue TT-11: settings.js view

- **Status**: Validated
- **PRD**: `../../prd.md`
- **Blocked by**: TT-09
- **Effort**: M
- **Files**: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js`

## Context

`settings.js` was inherited and heavily edited (348 lines removed — the
catalog/lists tabs; the `form.Map` tab structure and field definitions are
inherited expression; the import flow and validators are fork work). It
renders the Settings page: a single tabbed page, because in LuCI each menu
item is a separate page and configuring the package is one session.

## Contract to reproduce

- `'use strict';` with LuCI requires (`view`, `form`, `uci`, `rpc`, `ui`).
- RPC: `luci.trusttunnel/import_config` (arg `text`).
- `load()`: `uci.load('trusttunnel')`.
- `form.Map('trusttunnel')` with `m.tabbed = true` — four tabs:
  1. **General** (`section main`): Flag `enabled` ("Start on boot",
     `rmempty=false`); ListValue `log_level` (info/debug/trace).
  2. **Server** (`section endpoint`): Import button (modal textarea
     accepting a config file text OR a `tt://` link; on success sets
     `trusttunnel.endpoint.{hostname,username,password,certificate}` and
     `address` via `uci.set` — PLUS, since main 2026-09-09:
     `custom_sni`, `client_random`, `protocol`, `anti_dpi`, `has_ipv6`,
     `skip_verification` (guarded truthy/null checks), `dns_upstream`
     (from `res.dns_upstreams`) — then `uci.save()` (PENDING, not applied
     — the "import applies nothing" condition), notification "Imported.
     Review the fields and press Save & Apply.", `location.reload()` after
     800 ms); DynamicList `address` (placeholder `203.0.113.10:443`,
     `rmempty=false`); Value `hostname` (datatype `hostname`,
     rmempty=false); Value `username` (rmempty=false); Value `password`
     (password input, rmempty=false); ListValue `protocol` (http2/http3);
     Flag `anti_dpi`; Flag `post_quantum` (default '1');
     Value `custom_sni` (optional, placeholder `example.com`, validate:
     empty ok, else lowercase hostname-shape regex
     `/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/`
     → error 'Use the format example.com'); Value `client_random`
     (optional, placeholder `0a0b0c/0f0f0f`, validate: empty ok, ≤64
     chars, `prefix[/mask]` hex digits, even length, mask same length as
     prefix — the client's own format); ListValue `routing_profile`
     (profiles populated from `data.trusttunnel['routing_profile']`
     `.name` values + the stored current value when it names a deleted
     profile; empty value option "None — everything through the tunnel");
     Flag `has_ipv6` (default '1'); Flag `skip_verification`; TextValue
     `certificate` (6 rows, optional); DynamicList `dns_upstream` with 8
     presets (tls://1.1.1.1, tls://9.9.9.9, tls://dns.adguard-dns.com,
     https://cloudflare-dns.com/dns-query, https://dns.quad9.net/dns-query,
     quic://dns.adguard-dns.com, 1.1.1.1:53, 9.9.9.9:53).
  3. **Routing** (added on main 2026-09-09, REPLACES the Exclusions tab;
     `form.Section` — not NamedSection — `'routing_profile'`, title
     "Routing profiles", `addremove = true`, `anonymous = true`,
     `sortable = true`): Value `name` (required — 'Name is required' when
     empty; unique-name validation against the other sections — 'Another
     profile already has this name'); ListValue `mode` ('vpn' → "VPN —
     tunnel everything except the bypass rules", 'bypass' → "Bypass —
     tunnel only the VPN rules", default 'vpn', rmempty=false);
     DynamicList `vpn_rules` and `bypass_rules` sharing `validateRule`:
     empty ok, lowercase first, `*:port` ok, strip `*.` prefix, then
     `[0-9a-f:.\[\]/]+` (IP / IP:port / [v6]:port / CIDR) or the hostname
     regex, else 'Not a valid domain, IP address or CIDR range'. The
     legacy `domains` section is NOT shown (it survives in the schema
     only as the no-profile fallback).
  4. **Network** (`section network`): Value `mtu` (datatype
     `range(576,9000)`, default 1350); Value `lan_devices`
     (space-separated, optional, placeholder `br-lan`); Flag
     `blackhole_on_down` (default 1); Flag `include_router_traffic`; Value
     `fwmark` with validator (decimal ≤ 4294967295 or `0x` + 1–8 hex
     digits, default `0x9527`); Value `table` with validator (uinteger
     1..4294967294, rejecting 253–255, default 880).
- Translation keys unchanged from today (the set grew on main with the
  profile fields — see the `.po` in TT-13).

## Acceptance criteria

- [ ] Four tabs with exactly the fields above, same defaults, same
      datatypes/validators.
- [ ] Import flow: text/`tt://` accepted, fields set via `uci.set` +
      pending `uci.save()`, notification + reload; nothing applied.
- [ ] LuCI require + JS syntax gates pass.
- [ ] Translation keys unchanged.

## How to verify

1. JS syntax + LuCI requires gates.
2. Manual LuCI pass: edit every field, save & apply, verify the UCI config
   lands with the same values as today; import from a file and from a
   `tt://` link; validator rejects invalid exclusions/fwmark/table values.
3. Compare the `_()` key list and field definitions against the current
   view — identical behavior.

## Notes

- Field names ARE the UCI schema — reproduce them exactly (see TT-15 for
  the defaults side).

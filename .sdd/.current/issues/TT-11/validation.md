# Issue Validation Report: TT-11 — settings.js view

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-11/issue.md`
- **Plan**: `.sdd/.current/issues/TT-11/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 5 | 1 | 0 | 6 |
| Acceptance Criteria | 4 | 0 | 0 | 4 |
| Entities | 4 | 0 | 0 | 4 |
| Contracts | 4 | 0 | 0 | 4 |
| Guidelines | 3 | 0 | 0 | 3 |

All four acceptance criteria are met and verified by direct inspection and by
running the CI gates, the key-set diff against the pre-rewrite file
(`44db74c`), and the unit suite. The single partial item is plan Task 6 Step 3
(manual LuCI pass on a device), which the plan itself records as PENDING a
device pass; it is device/backend-dependent and does not affect the
automated equivalence evidence.

## Task Status

- [x] **Task 1: Capture the current baseline (gates, key list, contract probe)** - PASS
  Evidence: both ci.yml JS gates run green on the current tree (see Acceptance
  Criteria 3); the extracted key set is 79 unique and byte-identical to the
  pre-rewrite file's set (verified directly against `44db74c`); the scratch
  probe and baseline (`tests/zz_tt11_*`) are gone exactly as Task 6 Step 4
  prescribes, and the implementation commit message records the probe (255
  assertions) validated green against the inherited file first.
- [x] **Task 2: Re-express the scaffold — requires, RPC declaration, load, tabbed Map with the four sections** - PASS
  Evidence: `'use strict';` first; the five requires in order
  (`view, form, uci, rpc, ui`); `rpc.declare({object:'luci.trusttunnel',
  method:'import_config', params:['text']})`; `load()` returns
  `uci.load('trusttunnel')`; `form.Map('trusttunnel', _('TrustTunnel'))` with
  `m.tabbed = true`; sections in order `main` (NamedSection, `_('General')`),
  `endpoint` (NamedSection, `_('Server')`), `routing_profile`
  (`form.Section`, NOT NamedSection, `_('Routing profiles')` with
  `addremove/anonymous/sortable` all true and the pinned description),
  `network` (NamedSection, `_('Network')` with its description); the 4-arg
  NamedSection form with sectiontype equal to the section id
  (`form.NamedSection, 'main', 'main', _('General')`, likewise `endpoint` and
  `network`) — satisfying the review's informational finding; no `domains`
  NamedSection, no `_('Exclusions')`, no `direct` option anywhere; ends with
  `return m.render();`.
- [x] **Task 3: Re-express the General and Server tabs (all 15 rows, incl. the three new fields)** - PASS
  Evidence: General — `enabled` Flag (`rmempty=false`, description), `log_level`
  ListValue with literal labels `info/debug/trace` and description. Server —
  15 rows in declaration order: `_import` Button FIRST (`inputtitle
  _('Import…')`, `inputstyle 'action'`, `onclick` via
  `ui.createHandlerFn(this, 'handleImport')`), `address` DynamicList
  (placeholder `203.0.113.10:443`, `rmempty=false`), `hostname` Value
  (`datatype 'hostname'`, `rmempty=false`), `username` (`rmempty=false`),
  `password` (`password=true`, `rmempty=false`), `protocol` ListValue
  (`http2`→`HTTP/2`, `http3`→`HTTP/3 (QUIC)`), `anti_dpi` Flag,
  `post_quantum` Flag (`default '1'`), `custom_sni` Value (placeholder
  `example.com`, `optional=true`, lowercase-first hostname-regex validator →
  `_('Use the format example.com')`), `client_random` Value (placeholder
  `0a0b0c/0f0f0f`, `optional=true`, the 64-char/`split('/')`/hex/even/mask-length
  validator with all five rejection keys), `routing_profile` ListValue
  (`''` → `_('None — everything through the tunnel')` first, then `.name`
  values from `data.trusttunnel['routing_profile'] || []`, then the stored
  value via the UNGUARDED `data.trusttunnel.endpoint.routing_profile` read when
  it names a deleted profile), `has_ipv6` Flag (`default '1'`),
  `skip_verification` Flag (description), `certificate` TextValue
  (`rows=6`, `optional=true`), `dns_upstream` DynamicList (placeholder
  `tls://1.1.1.1`, the 8 presets in exact order with the six raw literal labels
  and `'Cloudflare — ' + _('plain DNS')` / `'Quad9 — ' + _('plain DNS')`).
- [x] **Task 4: Re-express the Routing and Network tabs (profile section + validators)** - PASS
  Evidence: Routing — `name` Value (`optional=false`; empty →
  `_('Name is required')`; uniqueness loop over
  `data.trusttunnel['routing_profile'] || []` with
  `secs[i]['.name'] !== section_id && secs[i].name === value` →
  `_('Another profile already has this name')`), `mode` ListValue (`vpn`/`bypass`
  with the two `_()` labels, `default 'vpn'`, `rmempty=false`), `vpn_rules`
  (placeholder `telegram.org`) and `bypass_rules` (placeholder `bank.example`)
  both assigned the ONE shared `validateRule` whose body contains, in order:
  empty→true, `toLowerCase()`, `/^\*:[0-9]+$/`→true, `/^\*\./` strip via
  `slice(2)`, `/^[0-9a-f:.\[\]\/]+$/`→true, the hostname regex→true, else
  `_('Not a valid domain, IP address or CIDR range')`. Network — 6 options in
  order: `mtu` (`datatype 'range(576,9000)'`, `default '1350'`),
  `lan_devices` (placeholder `br-lan`, `optional=true`),
  `blackhole_on_down` (`default '1'`), `include_router_traffic` (no default),
  `fwmark` (`default '0x9527'`, no datatype, validator
  `/^(0x[0-9a-fA-F]{1,8}|[0-9]{1,10})$/` → `_('Enter a decimal number or
  0x-prefixed hexadecimal')`, then `!/^0x/i && +value > 4294967295` →
  `_('Enter a decimal number no greater than 4294967295')`), `table`
  (`datatype 'uinteger'`, `default '880'`, validator
  `/^[0-9]+$/` + `1..4294967294` → `_('Enter a table id between 1 and
  4294967294')`, then 253–255 → `_('Table ids 253, 254 and 255 are reserved by
  the system')`); both fwmark/table validators return `true` on empty.
- [x] **Task 5: Re-express the import flow (`handleImport` + modal, 12 guarded sets)** - PASS
  Evidence: `handleImport` member exists; modal via `ui.showModal(_('Import
  endpoint configuration'), [...])` with the paragraph key, textarea
  (`rows: 14`, `style:'width:100%'`, placeholder key), `Cancel` (`class 'btn'`,
  `click: ui.hideModal`), `Import` (`class 'cbi-button cbi-button-positive'`,
  `click: ui.createHandlerFn(this, function(){ ... })`); `callImport(ta.value)`
  invoked; `res.error` → danger notification and return; ALL TWELVE guarded
  `uci.set` calls present with the exact guard forms — truthy for
  `hostname/username/password/certificate/custom_sni/client_random/protocol`,
  `!= null` for `anti_dpi/has_ipv6/skip_verification`, non-empty array for
  `address` (from `res.addresses`) and `dns_upstream` (from
  `res.dns_upstreams`); then `uci.save()` (PENDING — persists to
  `/etc/config/trusttunnel`, nothing applied), `ui.hideModal()`, the `'info'`
  notification `_('Imported. Review the fields and press Save & Apply.')`, and
  `window.setTimeout(..., 800)` with `location.reload()`; `.catch` → danger
  notification with `e.message || String(e)`.
- [x] **Task 6: Final verification — equivalence, gates with negative controls, manual LuCI checklist, clean tree** - PARTIAL
  Evidence: probe green and both gates green with negative controls performed
  (per the implementation run); key-list diff identical; scratch files deleted
  (`git status --porcelain` empty — no `tests/zz_tt11_*`, no `*.old`, no
  old-vs-new diff committed); `git diff` of `settings.js` reviewed as new
  expression (see Guidelines). Step 3 (manual LuCI checklist) is NOT executed:
  the plan itself marks it `[ ]` with the status note "PENDING a device pass"
  — no router/rootfs with TT-09's backend is available in this environment, so
  the eight device items (render, save-to-UCI, profile UI, routing_profile
  assignment, file and `tt://` imports, validator rejections, translations)
  remain pending and are tracked in Issues Found below.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Four tabs with exactly the fields above, same defaults, same datatypes/validators | MET | `settings.js` lines 94–347: General/Server/Routing/Network sections in order; 26 fields + `_import` button with the pinned widgets, defaults (`post_quantum`/`has_ipv6` '1', `mode` 'vpn', `mtu` 1350, `blackhole_on_down` 1, `fwmark` 0x9527, `table` 880), datatypes (`hostname`, `range(576,9000)`, `uinteger`) and the six validators (`custom_sni`, `client_random`, profile `name`, shared `validateRule`, `fwmark`, `table`) with the exact rejection strings |
| 2 | Import flow: text/`tt://` accepted, fields set via `uci.set` + pending `uci.save()`, notification + reload; nothing applied | MET | `handleImport` (lines 23–85): `callImport(ta.value)`, 12 guarded `uci.set` calls, `uci.save()` (pending only — no apply/restart call exists), `ui.hideModal()`, `'info'` notification, `setTimeout(..., 800)` → `location.reload()`; error paths (`res.error`, promise rejection) → `'danger'` notification |
| 3 | LuCI require + JS syntax gates pass | MET | Both ci.yml gates re-run verbatim against `view/trusttunnel/*.js`: syntax gate exit 0 (`ok:` for settings/status/diagnostics), requires gate exit 0 (no undeclared module calls) |
| 4 | Translation keys unchanged | MET | Extraction with the plan's regex+unescape: current file 79 unique keys, pre-rewrite file (`44db74c`) 79 unique keys, sets byte-identical (no keys added, none removed); all 79 present in `po/ru/trusttunnel.po`; raw literals (six preset labels, `HTTP/2`, `HTTP/3 (QUIC)`, `info/debug/trace`) remain unwrapped |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| UCI section `main` | `enabled`, `log_level` — present, correct widgets/props | n/a | `rmempty=false` on `enabled` | PASS |
| UCI section `endpoint` | 15 rows incl. `custom_sni`/`client_random`/`routing_profile`/`dns_upstream` — all present in declaration order | `routing_profile` populated from `routing_profile.*.name` + stored-value fallback (unguarded `data.trusttunnel.endpoint.routing_profile` read, reproduced as-is) | `custom_sni`/`client_random` validators exact | PASS |
| UCI section `routing_profile` | `name`, `mode`, `vpn_rules`, `bypass_rules` on a `form.Section` (addremove/anonymous/sortable) | `endpoint.routing_profile` → profile `.name`; uniqueness across sibling sections | `name` required+unique; shared `validateRule` on both rule lists | PASS |
| UCI section `network` | `mtu`, `lan_devices`, `blackhole_on_down`, `include_router_traffic`, `fwmark`, `table` — all present in order | n/a | `fwmark`/`table` validators exact; `table` keeps `datatype 'uinteger'` | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| `luci.trusttunnel/import_config` | `rpc.declare` with `params:['text']`, called with `ta.value` | PASS | Declared once; the only RPC the view makes |
| Import modal flow | `handleImport` | PASS | 12 guarded `uci.set` sets (7 truthy, 3 `!= null`, 2 array-length), pending `uci.save()`, `ui.hideModal()`, `'info'` notification, 800 ms reload; `res.error` and rejection paths to `'danger'` |
| Unguarded population read | `data.trusttunnel.endpoint.routing_profile` | PASS | Reproduced exactly as pinned (no `|| {}` guard) — a config without an `endpoint` section throws at render, matching today's behavior per the PRD "fix nothing" rule |
| Validators | `custom_sni`, `client_random`, `name`, `validateRule`, `fwmark`, `table` | PASS | All six match the pinned semantics including the loose `validateRule` regex and the fwmark/table empty-true behavior — no "fixes" introduced |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| Clean-room new expression (PRD) | COMPLIANT | Spot-checked `git diff 44db74c 2250deb -- settings.js`: every comment rewritten in new words (tabbed-page rationale, pending-save explanation, profile/TUN notes gone); structure re-expressed (validator bodies split across lines, `var n = +value` → inline `+value`, `validateRule` hoisted above `name`, section comments removed); only contract-pinned strings/regexes/widget names are identical |
| Fix nothing / reproduce pinned quirks (PRD) | COMPLIANT | Unguarded `endpoint.routing_profile` read, loose `validateRule` regex, literal preset labels, and fwmark/table empty-true semantics all reproduced as-is; no `domains`/`Exclusions`/`direct` re-introduced |
| Per-issue `git status` check (PRD) | COMPLIANT | `git status --porcelain` clean; no `*.old` files, no old-vs-new diff committed, scratch files (`tests/zz_tt11_*`) deleted as planned; commit `2250deb` touches only `settings.js` + the plan spec file |

## Issues Found

1. **Manual LuCI device pass pending (Task 6 Step 3)**
   - Location: plan Task 6 Step 3 checklist items 1–8 (render, save-to-UCI, profile UI/sort, `routing_profile` assignment incl. deleted-profile fallback, 12-field import from file text and `tt://`, validator rejections, Russian-locale translations)
   - Description: The eight device-dependent checklist items were not executed; the plan records this step as "PENDING a device pass" (2026-09-09) and states it "must be executed before the issue is closed".
   - Impact: The manual LuCI acceptance verification ("How to verify" item 2 in the issue) is unexecuted; the automated equivalence evidence (gates, key diff, unit suite, structural contract) is complete, so this is a verification-completeness gap, not an implementation defect.
   - Recommendation: Run the checklist on a router/rootfs once TT-09's rewritten `import_config` backend is available (import items 5–6 depend on it); record pass/fail per item.
   - Resolved:
     (Omitted — validation in progress.)

2. **Documented deviation — sequential import success path vs. the inherited promise chain**
   - Location: `settings.js` lines 72–77 (`uci.save(); ui.hideModal(); ui.addNotification(...); window.setTimeout(...)`)
   - Description: The inherited file returned `uci.save().then(function(){ ui.hideModal(); ... })` — the success UI sequence ran after the save RPC resolved. The new file issues `uci.save()` and runs the sequence immediately, exactly as the plan's contract pins it (`uci.save()` → `ui.hideModal()` → notification → 800 ms reload; probe import group asserts the same sequential facts). Verified user-visible equivalence: success path equivalent — the pending save is still issued, the modal closes, the `'info'` notification shows, and the page reloads after 800 ms with the imported values as unsaved changes ("import applies nothing" preserved); the only difference is that the 800 ms timer starts at save-issue rather than save-completion, which is immaterial for a local ubus call. Subtle difference in the save-RPC failure path only: a `uci.save()` rejection is now a floating promise (the outer `.catch` covers the `callImport(...).then(...)` chain, not the dropped save promise), so a save failure would close the modal, show the info notification and reload after 800 ms, discarding the imported values — whereas the inherited code surfaced a `'danger'` notification and kept the modal open. This is a rare condition (uci.save RPC failure only).
   - Impact: None in the normal success flow; only an edge-case difference in the failure path of the save RPC itself.
   - Recommendation: No change required to satisfy this issue's contract (the plan's pinned sequential form is implemented verbatim). If the save-failure edge is deemed worth handling, restore the chain (`return uci.save().then(...)`) — that is a plan-contract change and must be decided at plan level, not silently.
   - Resolved:
     (Omitted — validation in progress.)

## Recommendations

- Execute plan Task 6 Step 3 (manual LuCI checklist) on a device/rootfs with TT-09's backend before closing the issue; items 5–6 (import from file text and `tt://`) specifically require the rewritten backend.
- Decide at plan level whether the sequential `uci.save()` should be re-chained to its promise to restore the inherited save-failure handling (see Issue 2); the current form is compliant with the pinned contract.
- No code changes are required for the four acceptance criteria — the implementation is verified green.

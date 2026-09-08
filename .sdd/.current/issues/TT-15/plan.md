# Implementation Plan: default UCI config

- **Created**: 2026-09-08
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-15/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: Clean-room reimplementation — the file is inherited functional data (a schema instance), so the rewrite is a transcription from the issue's contract text, not a copy of the file.

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
The default config changed; the issue contract was updated:

- **New endpoint options**: `custom_sni ''`, `client_random ''`,
  `routing_profile 'Default'` — the `endpoint` section now has 12 options.
- **New section**: `config routing_profile` (anonymous) with `name
  'Default'` and `option mode 'vpn'` (2 options), no rule lists. The
  section carries a 5-line comment block in the current file; the
  re-created file drops it (decision pinned in Task 2 Step 1).
- The option-set diff (Task 1/3) now spans **5 sections / 22 options**
  (the current file is 36 lines = 31 content lines + 5 comment lines);
  the TT-03 export-schema consistency check gains the new scalars and
  the resolved profile keys (`routing_profile.name/mode/vpn_rules/
  bypass_rules` — the 26-key set); the TT-11 field list gains the new
  fields (26 fields: 12 endpoint + 4 profile).
- Everything else unchanged.

## Summary

Re-create `packages/luci-app-trusttunnel/root/etc/config/trusttunnel` from the UCI schema contract in issue TT-15: five sections (`main`, `endpoint`, `network`, `routing_profile`, `domains`), 22 options, no list defaults, no legacy options, no comments. The committed old file is the equivalence oracle: the new file must be identical in option set and content except for cosmetic whitespace and the deliberately dropped comment block. No code and no tests are written — this is data; verification is diffing the option set against the contract, the old file, the TT-03 export schema, and the TT-11 field list.

## Technical Context

- **Language/Version**: none — OpenWrt UCI flat config data (ASCII text, no shell)
- **Primary Dependencies**: OpenWrt `uci` runtime reads it via `config_load trusttunnel` in `/usr/libexec/trusttunnel/uci-export` (TT-03) and `/etc/init.d/trusttunnel` (TT-06); LuCI view reads it via `uci.load('trusttunnel')` (TT-11)
- **Storage**: the file itself is the persisted config; declared a protected conffile in `packages/luci-app-trusttunnel/Makefile` (lines 64–66) so package updates never overwrite it
- **Testing**: no unit tests — verification is option-set/content diffs (acceptance criterion 1) and the CI rootfs `uci export` install check (acceptance criterion 2)
- **Target Platform**: OpenWrt routers (apk 25.12 / opkg 22.03–24.10 rootfs installs)

## Research

### Consumers of the file (contract holders)

- `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export` (TT-03): `config_load trusttunnel`, emits the records TSV — every file scalar except `endpoint.certificate` (deliberately excluded from export, TT-03 contract), plus list keys `endpoint.address`, `endpoint.dns_upstream`, `domains.direct` (one line per value; empty on defaults), plus the resolved profile keys `routing_profile.name/mode/vpn_rules/bypass_rules` emitted from the anonymous `routing_profile` section selected by `endpoint.routing_profile` (schema-keys marker at uci-export line 55).
- `packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` (TT-06): `config_load trusttunnel` at lines 21 and 177; reads the same sections/options.
- `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/settings.js` (TT-11): `uci.load('trusttunnel')`; edits exactly these fields — `main.enabled`, `main.log_level`; `endpoint.address`, `endpoint.hostname`, `endpoint.username`, `endpoint.password`, `endpoint.protocol`, `endpoint.anti_dpi`, `endpoint.post_quantum`, `endpoint.custom_sni`, `endpoint.client_random`, `endpoint.routing_profile`, `endpoint.has_ipv6`, `endpoint.skip_verification`, `endpoint.certificate`, `endpoint.dns_upstream`; `routing_profile.name`, `routing_profile.mode`, `routing_profile.vpn_rules`, `routing_profile.bypass_rules`; `network.mtu`, `network.lan_devices`, `network.blackhole_on_down`, `network.include_router_traffic`, `network.fwmark`, `network.table`. `domains.direct` is NOT shown in the UI (legacy fallback, migrated into the Default profile's `bypass_rules` by uci-defaults).
- `Makefile` conffiles block and `uninstall.sh` reference only the path, not the content.
- No test parses this file's text: the schema-completeness test (`schema_keys()` in `tests/test_init_apply.sh`) awk-parses `uci-export`'s source, not the config file.

### Format conventions

- Standard UCI layout: `config <type> '<name>'` and `option <key> '<value>'`, one TAB indent for options, single quotes, blank line between sections, no comments, trailing newline at EOF. **Comment decision (pinned):** the current file has a 5-line comment block above `config routing_profile`; comments are not part of the schema contract, so the re-created file carries NO comments, and the equivalence diff (Task 3 Step 1) strips `#` lines from both sides. This is the only `etc/config` file in the repo, so the conventions come from OpenWrt's stock config style.
- File mode must stay `100644` (data, not executable). The CI "Executable bits" gate (`.github/workflows/ci.yml` lines 33–51) lists only scripts; this file is not in it.
- The old file is committed and the worktree is clean, so the previous version stays available via `git show HEAD:<path>` — no `.old` copies may be kept (PRD Implementation Decisions).

### Discrepancy check (issue contract vs current file)

The contract in issue TT-15 matches the current file exactly: same 5 sections (`main`, `endpoint`, `network`, `routing_profile`, `domains`), same 22 options in the same order with the same values — including the endpoint scalars `custom_sni ''`, `client_random ''`, `routing_profile 'Default'` and the anonymous `routing_profile` section's `name 'Default'`, `mode 'vpn'`. The only `mode` in the file is `routing_profile.mode` (the issue's "NO mode" clause refers to the legacy flat option, superseded by the profile's mode); no `full_exclude_lists`, no `lists` section, no `intercept_dns`/`list_dns`/`list_resolver`/`list_doh_*`/`doh_network`, no `domains.bypass`, no `list` lines. Cross-checks agree: TT-03's export key set (26 keys incl. the resolved profile keys; `certificate` present in the file, excluded from export) and TT-11's 26-field UI list (every file option maps to a UI field, and every UI field maps to a file section/option — the four list fields map to empty list keys). **Zero discrepancies.**

## Entities

### UCI config `trusttunnel` (the file itself)

- **Fields** (order-sensitive; matches TT-03 export order):

  | Section | Options (default value) |
  | --- | --- |
  | `main` | `enabled '0'`, `log_level 'info'` |
  | `endpoint` | `hostname ''`, `username ''`, `password ''`, `protocol 'http2'`, `anti_dpi '0'`, `post_quantum '1'`, `skip_verification '0'`, `certificate ''`, `has_ipv6 '1'`, `custom_sni ''`, `client_random ''`, `routing_profile 'Default'` |
  | `network` | `mtu '1350'`, `table '880'`, `fwmark '0x9527'`, `blackhole_on_down '1'`, `include_router_traffic '0'`, `lan_devices ''` |
  | `routing_profile` (anonymous) | `name 'Default'`, `mode 'vpn'` (no rule lists) |
  | `domains` | (none) |

- **Validation**: exactly these options; list keys (`endpoint.address`, `endpoint.dns_upstream`, `domains.direct`, `routing_profile.vpn_rules`, `routing_profile.bypass_rules`) exist only as empty lists (no `list` lines) by default; no other sections or options ever.
- **Relationships**: consumed by `uci-export` (TT-03; resolves the anonymous `routing_profile` section into `routing_profile.*` records), init.d (TT-06), settings.js (TT-11); declared conffile in the package Makefile.
- **States**: n/a (config data).

## Contracts

N/A — no API endpoints. Cross-check contracts: TT-03 export key set and TT-11 field list (Tasks 3.3–3.4).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/etc/config/trusttunnel` | Rewrite | Re-created from the contract table above; 31 lines (5 section headers + 22 options + 4 blank separators; no comment block), mode 100644, identical option set |

## Tasks

### [ ] Task 1: Baseline — diff the current file against the contract

**Files:**

- None (read-only inspection; scratch outputs in `/tmp`)

- [ ] **Step 1: Record the tracked mode**

```sh
git ls-files -s packages/luci-app-trusttunnel/root/etc/config/trusttunnel
```

Expected: `100644 <hash> 0 ...` — data file, not executable (the CI executable gate does not list it).

- [ ] **Step 2: Extract the current option set**

```sh
awk -F"'" '/^config /{split($1,a," "); print "config " a[2]} /^\toption /{split($1,a," "); print "option " a[2]}' packages/luci-app-trusttunnel/root/etc/config/trusttunnel > /tmp/tt15-current-keys.txt
```

The extractor matches only `config`/`option` lines, so the comment block is ignored, and the anonymous section prints as `config routing_profile`.

- [ ] **Step 3: Diff against the contract key list**

```sh
cat > /tmp/tt15-contract-keys.txt <<'EOF'
config main
option enabled
option log_level
config endpoint
option hostname
option username
option password
option protocol
option anti_dpi
option post_quantum
option skip_verification
option certificate
option has_ipv6
option custom_sni
option client_random
option routing_profile
config network
option mtu
option table
option fwmark
option blackhole_on_down
option include_router_traffic
option lan_devices
config routing_profile
option name
option mode
config domains
EOF
diff -u /tmp/tt15-contract-keys.txt /tmp/tt15-current-keys.txt
```

Expected: no output — the current file's option set equals the contract (5 sections, 22 options, in order; the only `mode` is `routing_profile.mode`; no legacy flat `mode`, `full_exclude_lists`, `lists`, `intercept_dns`, `list_dns`, `list_resolver`, `list_doh_*`, `doh_network`, `domains.bypass`).

**Verification**: the diff is empty; `/tmp/tt15-current-keys.txt` contains 5 `config` lines and 22 `option` lines.

### [ ] Task 2: Re-create the file from the contract

**Files:**

- Rewrite: `packages/luci-app-trusttunnel/root/etc/config/trusttunnel`

- [ ] **Step 1: Write the file composed from the Entities table (the contract), not from the old file**

Compose the UCI text from the section/option table above using the format conventions: `config <type> '<name>'`, `option <key> '<value>'` with one TAB indent, single quotes, blank line between sections, no comments, trailing newline. The resulting file must be exactly:

```uci
config main 'main'
	option enabled '0'
	option log_level 'info'

config endpoint 'endpoint'
	option hostname ''
	option username ''
	option password ''
	option protocol 'http2'
	option anti_dpi '0'
	option post_quantum '1'
	option skip_verification '0'
	option certificate ''
	option has_ipv6 '1'
	option custom_sni ''
	option client_random ''
	option routing_profile 'Default'

config network 'network'
	option mtu '1350'
	option table '880'
	option fwmark '0x9527'
	option blackhole_on_down '1'
	option include_router_traffic '0'
	option lan_devices ''

config routing_profile
	option name 'Default'
	option mode 'vpn'

config domains 'domains'
```

**Comment decision (pinned):** the current file carries a 5-line comment block above `config routing_profile`; comments are not part of the schema contract and cannot be transcribed clean-room, so the re-created file deliberately carries NO comments. The equivalence diff (Task 3 Step 1) strips `#` lines, so the oracle comparison stays valid.

- [ ] **Step 2: Sanity-check the file**

```sh
wc -l packages/luci-app-trusttunnel/root/etc/config/trusttunnel
git show HEAD:packages/luci-app-trusttunnel/root/etc/config/trusttunnel | wc -l
git ls-files -s packages/luci-app-trusttunnel/root/etc/config/trusttunnel
```

Expected: `31` lines for the re-created file (22 options + 5 section headers + 4 blank separators) and `36` for the old file (31 content lines + the 5-line comment block that is deliberately not reproduced); mode still `100644` (if it changed, `chmod 644` it).

**Verification**: 31 lines, TAB indentation, no comments, mode 100644, git status shows only this file modified (plus the plan file).

### [ ] Task 3: Verify — option-set diff vs current (identical) + consistency vs TT-03 and TT-11

**Files:**

- None (diff checks; scratch outputs in `/tmp`)

- [ ] **Step 1: Full-content equivalence against the old file (oracle), comment-normalized**

```sh
git show HEAD:packages/luci-app-trusttunnel/root/etc/config/trusttunnel | sed -E "s/^[[:space:]]+//; /^#/d; s/'//g; /^$/d" > /tmp/tt15-old.txt
sed -E "s/^[[:space:]]+//; /^#/d; s/'//g; /^$/d" packages/luci-app-trusttunnel/root/etc/config/trusttunnel > /tmp/tt15-new.txt
diff -u /tmp/tt15-old.txt /tmp/tt15-new.txt
```

(`/^#/d` strips comment lines: the pinned decision drops the old file's 5-line comment block, so `#` lines are removed from BOTH sides.)

Expected: empty — content identical after normalization (only cosmetic whitespace/quote differences would be allowed; here none, and the comment block is stripped on both sides).

- [ ] **Step 2: Option-set diff vs current**

```sh
awk -F"'" '/^config /{split($1,a," "); print "config " a[2]} /^\toption /{split($1,a," "); print "option " a[2]}' packages/luci-app-trusttunnel/root/etc/config/trusttunnel > /tmp/tt15-new-keys.txt
diff -u /tmp/tt15-current-keys.txt /tmp/tt15-new-keys.txt
```

Expected: empty — option set identical to the current file (5 sections, 22 options).

- [ ] **Step 3: Consistency vs TT-03 export schema (26-key set)**

The TT-03 export key set (schema-keys marker at uci-export line 55 plus the explicit loops) is: `main.enabled`, `main.log_level`; `endpoint.hostname/username/password/protocol/anti_dpi/post_quantum/skip_verification/has_ipv6/custom_sni/client_random/routing_profile`; list keys `endpoint.address`, `endpoint.dns_upstream`; `network.mtu/table/fwmark/blackhole_on_down/include_router_traffic/lan_devices`; `domains.direct`; and the resolved profile keys `routing_profile.name/mode/vpn_rules/bypass_rules`. Every scalar exists in the file; the only file option absent from the export schema is `endpoint.certificate` (deliberate per TT-03); all five list keys are empty lists on defaults, so `uci-export` emits zero list lines; the profile resolution picks the anonymous `routing_profile` section via `endpoint.routing_profile 'Default'` and emits `routing_profile.name` and `routing_profile.mode`.

Expected: check passes — `uci-export` output on these defaults contains exactly the 19 scalars plus `routing_profile.name` + `routing_profile.mode` = 21 records in TT-03 order.

- [ ] **Step 4: Consistency vs TT-11 field list**

The 26 UI-edited fields (`enabled`, `log_level`; `address`, `hostname`, `username`, `password`, `protocol`, `anti_dpi`, `post_quantum`, `custom_sni`, `client_random`, `routing_profile`, `has_ipv6`, `skip_verification`, `certificate`, `dns_upstream`; `name`, `mode`, `vpn_rules`, `bypass_rules`; `mtu`, `lan_devices`, `blackhole_on_down`, `include_router_traffic`, `fwmark`, `table`) each map to a file section/option, and every file option (22) is edited by the UI. The UI's list fields (`address`, `dns_upstream`, `vpn_rules`, `bypass_rules`) are empty defaults; `domains.direct` is the legacy fallback and is not shown in the UI (settings.js comment).

Expected: check passes — sets are identical (every file option has a UI field, and every UI field maps to a file option).

- [ ] **Step 5: Rootfs acceptance (fresh-install `uci export`)**

`uci export trusttunnel` on a fresh install must print the five sections in file order with the same options. This runs in the CI rootfs install gate (opkg/apk; the install flow is TT-14's scope). Locally macOS has no `uci`, so the normalized-content diff (Step 1) plus option-set diff (Step 2) is the local proxy; the CI rootfs gate is the final check.

Expected: CI rootfs gate green after the rewrite; local proxy diffs empty.

- [ ] **Step 6: Clean-room hygiene**

```sh
git status --short
```

Expected: only `packages/luci-app-trusttunnel/root/etc/config/trusttunnel` modified (plus `.sdd/.current/issues/TT-15/plan.md`); no `*.old` copies kept (PRD Implementation Decisions).

**Verification**: all diffs empty; TT-03 and TT-11 consistency checks pass; `git status` shows no stray copies.

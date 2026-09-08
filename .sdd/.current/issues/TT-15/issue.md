# Issue TT-15: default UCI config

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent; may run in parallel)
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/etc/config/trusttunnel`

## Context

The default config file was inherited; the fork deleted the list-related
options in place. It is functional data (a schema instance), not creative
expression — the rewrite is a transcription exercise against the schema
contract.

## Contract to reproduce

- `config main 'main'` — `enabled '0'`, `log_level 'info'`
- `config endpoint 'endpoint'` — `hostname ''`, `username ''`,
  `password ''`, `protocol 'http2'`, `anti_dpi '0'`, `post_quantum '1'`,
  `skip_verification '0'`, `certificate ''`, `has_ipv6 '1'`,
  `custom_sni ''`, `client_random ''`, `routing_profile 'Default'` (no
  `address`/`dns_upstream` defaults — empty lists)
- `config routing_profile` — one anonymous section: `name 'Default'`,
  `mode 'vpn'` (no rule lists — the section is the seed; uci-defaults
  migrates legacy `domains.direct` values into its `bypass_rules`)
- `config network 'network'` — `mtu '1350'`, `table '880'`,
  `fwmark '0x9527'`, `blackhole_on_down '1'`, `include_router_traffic '0'`,
  `lan_devices ''`
- `config domains 'domains'` — no default entries (empty `direct` list;
  the legacy fallback, only used when no profile is assigned)
- NO `mode`, NO `full_exclude_lists`, NO `lists` section, NO
  `intercept_dns`/`list_dns`/`list_resolver`/`list_doh_*`/`doh_network`
  options, NO `domains.bypass`.

## Acceptance criteria

- [ ] The file contains exactly the schema above (compare against the
      current file's option set — same content).
- [ ] `uci export` of a fresh install matches the contract.

## How to verify

1. Diff the new file against the current one: only cosmetic differences
   (whitespace/comments) allowed, option set identical.
2. Install into a rootfs and `uci export trusttunnel`.

## Notes

- This file is re-created from the schema contract; the option set is
  enforced by the TT-03 schema-completeness test and the TT-11 field
  definitions.

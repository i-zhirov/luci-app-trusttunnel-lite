# Issue TT-07: uci-defaults (first-boot firewall setup)

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent of TT-02..TT-06; may run in parallel)
- **Effort**: M
- **Files**: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

## Context

The first-boot script was inherited (zone creation block is inherited
expression; the duplicate-zone dedup and the `tt0`→`tun+` migration are
fork work, comments translated). It runs on every package install and
repairs/creates the firewall zone for the client's tun device.

## Contract to reproduce

- `#!/bin/sh`; loads `/lib/functions.sh`; idempotent (repeated runs
  change nothing).
- Dedup pass FIRST (before creation, so duplicates are not mistaken for a
  missing zone): keep the first firewall zone named `trusttunnel` and the
  first `forwarding` with `dest=trusttunnel`; delete duplicates via
  `uci delete firewall.<section>`; when anything was removed: `uci commit
  firewall`, `/etc/init.d/firewall reload`, log `logger -t trusttunnel
  "removed duplicate firewall zones left by an earlier version"`. (The
  historical bug: an early version read the zone name with an empty
  section argument, so creation fired on every install and piled up
  duplicate zones that broke fw4 with "redefinition of symbol".)
- Zone creation when absent: `uci add firewall zone` with `name='trusttunnel'`,
  `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`, `masq='1'`,
  `mtu_fix='1'`, `add_list device='tun+'` (pattern, NOT a concrete name —
  the client picks its own device name; the side effect of covering
  foreign tun devices is deliberate); forwarding `src='lan'`,
  `dest='trusttunnel'`; `uci commit firewall`; `/etc/init.d/firewall
  reload` (required — without it the status page shows green-on-broken).
- Migration: when the zone exists but its `device` list lacks `tun+`
  (old `tt0` binding): delete the device list, set `tun+`, commit +
  reload + log.
- Cache clear: `mkdir -p /var/cache/trusttunnel`, `rm -f
  /var/cache/trusttunnel/release.json`.
- **Routing profile seed** (added on main 2026-09-09; runs after the
  firewall block, before the cache clear): `config_load trusttunnel`; if
  NO `routing_profile` section exists (`config_foreach` count), create
  one: `uci add trusttunnel routing_profile` with `name='Default'`,
  `mode='vpn'`; migrate the legacy list — every `domains.direct` value via
  `uci -q get` + `while read` pipeline → `uci add_list
  "trusttunnel.$_prof.bypass_rules"="$_d"`; set
  `trusttunnel.endpoint.routing_profile='Default'`; `uci commit
  trusttunnel`; log `logger -t trusttunnel "created the default routing
  profile; the old direct list moved into its bypass rules"`. Idempotent:
  no-op when a profile already exists (fresh installs get the section from
  the shipped config).
- `/etc/init.d/trusttunnel enable` — always registers the rc.d link
  regardless of `main.enabled` (enablement is only checked inside
  start_service).
- LuCI cache clear: `rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*`;
  `exit 0`. Executable bit `100755`.

## Acceptance criteria

- [ ] On a fresh system: one `trusttunnel` zone + one `lan → trusttunnel`
      forwarding, firewall reloaded, rc.d link registered, caches cleared.
- [ ] On a system with duplicates: duplicates collapsed, first kept.
- [ ] On a system with an old `tt0`-bound zone: migrated to `tun+`.
- [ ] Idempotent: second run is a no-op.
- [ ] `shellcheck -s sh` and `sh -n` clean.

## How to verify

1. `shellcheck -s sh`, `sh -n`.
2. Rootfs/container check: run the script against a scratch UCI
   (`/etc/config/firewall` in a chroot), inspect the resulting config for
   the three scenarios (fresh / duplicated / legacy device binding).
3. The release workflow's rootfs install test exercises this script
   implicitly (firewall must come up).

## Notes

- The `_`-prefixed variables instead of `local` are a POSIX/shellcheck
  requirement (SC3043) — keep that convention in the rewrite.
- Independent of the libexec core; can be planned/implemented in parallel
  with TT-02..TT-06.

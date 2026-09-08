# Issue TT-08: hotplug route reattach

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: TT-05 (calls `routing attach`)
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`

## Context

The hotplug script restores the route attachment when the client recreates
its tun device (procd restarts the client → new device → default route in
table 880 disappears with the old interface). It was inherited; comments
translated in place, the guard chain is inherited expression.

## Contract to reproduce

- `#!/bin/sh`; reacts to net `add` events only: `[ "$ACTION" = "add" ] ||
  exit 0`.
- Device name from `dev="${INTERFACE:-$DEVICENAME}"`; empty → exit 0.
- Only tun devices: `/sys/class/net/$dev/tun_flags` must exist.
- Only non-persistent: `flags=$(cat .../tun_flags 2>/dev/null) || exit 0`;
  `[ "$(( flags & 0x800 ))" = "0" ] || exit 0` (IFF_PERSIST bit; excludes
  manual `ip tuntap add` devices and the legacy `tt0`).
- `RECORDS=/var/etc/trusttunnel/settings.tsv`, `OUTDIR=/var/etc/trusttunnel`;
  `[ -f "$RECORDS" ] || exit 0`.
- Service must be running: `/etc/init.d/trusttunnel running >/dev/null
  2>&1 || exit 0`.
- Foreign-device guard: when a device name is already recorded in
  `$OUTDIR/device`, that device still exists in sysfs, and it differs from
  the event device → exit 0 (a foreign event must not switch off a
  working tunnel).
- Otherwise: `/usr/libexec/trusttunnel/routing attach "$RECORDS" "$OUTDIR"
  "$dev"` and log `logger -t trusttunnel "hotplug: reattached routing to
  $dev"`. Executable bit `100755`.

## Acceptance criteria

- [ ] Event pipeline matches the contract (add-only, tun marker, IFF_PERSIST
      check, records/running guards, foreign-device guard, attach + log).
- [ ] `shellcheck -s sh` and `sh -n` clean.
- [ ] Manual test on a device: kill the client → procd respawns it → new
      tun device event → route attached to the new device (status shows
      `device up`, traffic flows).

## How to verify

1. `shellcheck -s sh`, `sh -n`.
2. Device smoke test: restart the client, confirm `routing status` shows
   the new device and the attached route (metric 1).
3. Negative: create a persistent tun device manually → no attach happens.

## Notes

- This script is short; it can be re-expressed together with TT-06 in one
  working session but is tracked as its own issue per the per-file rule.

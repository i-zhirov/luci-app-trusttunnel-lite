# Issue TT-06: init.d service script

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: TT-03, TT-04, TT-05
- **Effort**: L
- **Files**: `packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel`

## Context

The service script is the heart of the package and the largest shell file.
It was inherited and heavily edited in place: `setup_trust_store()`,
`wait_for_time()`, `wait_for_wan()`, `regenerate()`, `start_service()`,
`stop_service()` and the procd scaffolding are inherited expression; the
smart-reload machinery (`apply_settings()`, `changed_keys()`,
`change_class()`, `classify_change()`, `_TT_KEEP_ROUTING`, the `restart()`
override) is fork work. The fork-written tests `tests/test_init_apply.sh`
and `tests/test_init_reload.sh` specify its behavior precisely and remain
the oracle — they are NOT rewritten.

## Contract to reproduce

- `#!/bin/sh /etc/rc.common`, `USE_PROCD=1`, `START=95`, `STOP=10`.
- Constants: `LIBDIR=/usr/libexec/trusttunnel`, `OUTDIR=/var/etc/trusttunnel`,
  `RECORDS=$OUTDIR/settings.tsv`, `CLIENT=/opt/trusttunnel_client/trusttunnel_client`.
- `setup_trust_store()`: no store when `endpoint.skip_verification=1` or
  `endpoint.certificate` non-empty; else `SSL_CERT_FILE` from the first
  existing and non-empty (`-s`) of `/etc/ssl/cert.pem`,
  `/etc/ssl/certs/ca-certificates.crt` (+ `SSL_CERT_DIR=/etc/ssl/certs`
  when that dir exists); log error and return 1 when neither exists.
  When `SSL_CERT_FILE` ends up empty the procd instance gets NO env
  clause at all (empty vs absent matters to BoringSSL).
- `wait_for_time()`: wait up to 30 s (2 s steps) until system clock ≥ mtime
  of `$LIBDIR/gen-config` (fallback floor 1750000000); warn via logger when
  still behind.
- `wait_for_wan()`: wait up to 30 s for a default route (`ip route show
  default` non-empty); warn but always return 0.
- `regenerate()`: `umask 077`; `mkdir -p "$OUTDIR"`; `uci-export >
  "$RECORDS.new"` then `mv` over `$RECORDS` (atomic; failure → remove
  `.new`, return 1); write `endpoint.certificate` from UCI to
  `$OUTDIR/endpoint.pem` (chmod 600, or remove the file when empty); run
  `gen-config "$RECORDS" "$cert" > "$OUTDIR/client.toml"` (chmod 600);
  any failure (incl. `gen-config` non-zero) → return 1.
- `start_service()`: return 0 when `main.enabled` is unset/0 (with log —
  EVERY early exit runs the keep-routing abort cleanup); require `$CLIENT`
  executable; `setup_trust_store`; `regenerate`; `wait_for_wan`;
  `wait_for_time`; `routing up`; snapshot `max_ifindex()` BEFORE the procd
  instance; `procd_open_instance trusttunnel`,
  `procd_set_param command "$CLIENT" -c "$OUTDIR/client.toml"`, env
  `SSL_CERT_FILE` (+`SSL_CERT_DIR` when non-empty), `respawn 3600 5 0`,
  stdout/stderr 1, pidfile `/var/run/trusttunnel.pid`,
  `procd_close_instance`; `attach_client_device` one-shot;
  `abort_restart_cleanup()` resets `_TT_KEEP_ROUTING` and runs
  `routing down` on early-exit paths.
- `stop_service()`: when `_TT_KEEP_ROUTING` unset and `$RECORDS` exists →
  `routing down "$RECORDS"`; always return 0.
- `max_ifindex()` / `new_client_devices <since>` (non-persistent tun
  devices, `tun_flags` marker, IFF_PERSIST 0x800 clear) /
  `attach_client_device <since>` (one-shot attach).
- `restart()`: overrides rc.common with `trap '' TERM`, then `stop; start`.
- `reload_service()` = `apply_settings()` (the Save & Apply path):
  1. missing `$RECORDS` or service not running → plain `restart`.
  2. `umask 077`; `uci-export > "$RECORDS.next"`; failure → remove `.next`,
     log, `restart`.
  3. `classify_change "$RECORDS" "$RECORDS.next"` (via `changed_keys` +
     `change_class` + `class_rank`/`class_max`); additionally compare the
     UCI `endpoint.certificate` value against `$OUTDIR/endpoint.pem`
     contents (cert is not in records) — mismatch bumps the class to at
     least `restart`.
  4. `noop` → move `.next` over `$RECORDS`; `reload` → `regenerate &&
     routing up`, then `routing reattach`; failure → `restart`;
     `restart` → `_TT_KEEP_ROUTING=1` + `restart`; `restart_full` (default)
     → plain `restart`.
- `change_class` key classes (contract — the schema-completeness test in
  `test_init_apply.sh` enforces every exported key except
  `network.table`/`network.fwmark`/`main.enabled` is classified
  explicitly): `domains.direct`→restart (legacy fallback); the resolved
  profile keys `routing_profile.*` (name, mode, vpn_rules, bypass_rules)
  →restart, and `endpoint.routing_profile` itself →restart (the oracle
  asserts it explicitly); `network.lan_devices`,
  `network.blackhole_on_down`, `network.include_router_traffic`→reload;
  `network.table`, `network.fwmark`→restart_full; `main.enabled`→restart_full;
  `main.log_level`, `network.mtu`, `endpoint.*`→restart; unknown→restart_full.
- `service_triggers()`: `procd_add_reload_trigger "trusttunnel"`;
  `procd_add_interface_trigger "interface.*.up" wan /etc/init.d/trusttunnel
  restart`.
- All logging via `logger -t trusttunnel`. The exact log strings are
  externally visible (the oracle tests assert some; users read the rest) —
  enumerate them from the current script and reproduce them.
  Executable bit `100755`.

## Acceptance criteria

- [ ] `tests/test_init_apply.sh` and `tests/test_init_reload.sh` pass
      UNCHANGED (they source the init script; the oracle stays). Note:
      both oracles were EXTENDED on main (2026-09-09) with the
      `routing_profile.*` classification assertions and the profile-change
      reload scenario — the new init script must satisfy those too (26-key
      schema threshold).
- [ ] `sh -n` clean; `shellcheck -s sh` clean.
- [ ] Manual device check: start/stop/restart; reload via UCI change hits
      the right class (lan_devices → reattach, hostname → keep-routing
      restart, table → full restart); hotplug reattaches after client
      restart.
- [ ] All log messages, file paths, procd parameters and the pidfile match
      the contract exactly.

## How to verify

1. `sh tests/run.sh` — `test_init_apply.sh`, `test_init_reload.sh` green.
2. `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel`.
3. Rootfs/device smoke test per the release workflow's install flow:
   enable, start, status, edit settings via UCI, confirm reload behavior.

## Notes

- This issue does NOT rewrite the two oracle tests — they are original
  fork work and stay as the behavioral spec.
- `records.sh` is sourced here (through `routing`/`gen-config`); the
  `tt_get`/`tt_bool` defaulting semantics are the interface.

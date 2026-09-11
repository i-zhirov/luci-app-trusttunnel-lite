# Issue Validation Report: TT-06 — init.d service script

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-06/issue.md`
- **Plan**: `.sdd/.current/issues/TT-06/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 8 | 1 | 0 | 9 |
| Acceptance Criteria | 3 | 1 | 0 | 4 |
| Entities | 3 | 0 | 0 | 3 |
| Contracts | 2 | 0 | 0 | 2 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Baseline — record the oracle state before any change - PASS
  (Baseline green recorded in plan; both oracle tests + `sh -n` verified green
  at validation time; init script `100755` in the index).
- [x] **Task 2**: Chunk 1 — header, constants, abort_restart_cleanup - PASS
  (`#!/bin/sh /etc/rc.common`, `USE_PROCD=1`, `START=95`, `STOP=10`, the four
  constants, guarded cleanup; top level side-effect-free — sourcing works, as
  proven by both oracle tests sourcing the file).
- [x] **Task 3**: Chunk 2 — regenerate - PASS
  (`umask 077`, `mkdir -p`, `.new`+`mv` atomicity, `.new` removed and rc 1 on
  export failure, pem chmod 600 / removed when empty, `gen-config` failure →
  rc 1, `client.toml` chmod 600 — file lines 30–53).
- [x] **Task 4**: Chunk 3 — setup_trust_store, start_service, stop_service -
  PASS (`-s` probe in contract order, `SSL_CERT_DIR` rule, env clause emitted
  ONLY when `SSL_CERT_FILE` non-empty (lines 119–125); every early exit of
  `start_service` runs `abort_restart_cleanup` incl. the enabled=0 return;
  `stop_service` teardown rule with record-exists guard).
- [x] **Task 5**: Chunk 4 — wait_for_time and wait_for_wan - PASS
  (30 s / 2 s / 1 s constants, floor `1750000000` fallback, both warn-only
  loggers, always return 0).
- [x] **Task 6**: Chunk 5 — device helpers - PASS
  (`max_ifindex`, `new_client_devices` with `tun_flags` marker, ifindex
  threshold and IFF_PERSIST 0x800 check, one-shot `attach_client_device`).
- [x] **Task 7**: Chunk 6 — classifier, apply_settings, restart override -
  PASS (ORACLE GOES GREEN: `test_init_apply.sh` 29/0, `test_init_reload.sh`
  21/0, `sh -n` clean; `changed_keys` occurrence-count awk, `change_class`
  incl. `routing_profile.*` → restart, `class_rank`/`class_max`/
  `classify_change`, cert bump, `_TT_KEEP_ROUTING` handshake, `restart()`
  with `trap '' TERM`).
- [x] **Task 8**: Chunk 7 — service_triggers, polish, full gates - PASS
  (reload trigger + wan interface trigger; full suite green; shellcheck
  v0.11.0 `-s sh` clean via docker with the four documented inline disables;
  no stray files).
- [x] **Task 9**: Manual device checklist (router smoke test) - PARTIAL
  (executed as far as possible in the `openwrt/rootfs:x86-64-25.12.0`
  container: 43 bounded lifecycle checks PASS, including procd surface, env
  clause, respawn params, pidfile, teardown semantics and trigger wiring.
  Device-only remainder — real procd `status`/live pidfile/respawn window,
  real `config_load` against `/etc/config/trusttunnel`, real clock/WAN
  waiters, hotplug reattach over a live client — is documented in the plan as
  pending for the caller. Environment limitation, not an implementation
  defect.)

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `tests/test_init_apply.sh` + `tests/test_init_reload.sh` pass UNCHANGED (oracle stays; 26-key schema threshold) | MET | `git diff 44db74c HEAD -- tests/test_init_apply.sh tests/test_init_reload.sh` is empty (byte-identical to the oracle-extending commit). Run: 29 assertions, 0 failed and 21 assertions, 0 failed. The apply oracle's final two assertions passed: "schema parse of uci-export yielded 26 keys" and "every schema key is classified explicitly, none fell into the unknown branch". |
| 2 | `sh -n` clean; `shellcheck -s sh` clean | MET | `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` clean; `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh ...` clean. |
| 3 | Manual device check: start/stop/restart; reload classes (lan_devices → reattach, hostname → keep-routing restart, table → full restart); hotplug reattach | PARTIAL | Classification behavior fully covered by the oracle (reload → reattach, restart → `keep_routing=1`, restart_full → `keep_routing=0`, rollbacks) and the rootfs lifecycle smoke (43 checks, per plan's implementation notes). Real-device verification pending — no router attached to the environment; the plan explicitly defers these items to the caller. |
| 4 | Log messages, file paths, procd parameters and pidfile match the contract exactly | MET | All 11 contract log lines present via `logger -t trusttunnel` and byte-identical (lines 78, 87, 92, 101, 108, 156, 171, 308, 323, 329, 331); constants `LIBDIR`/`OUTDIR`/`RECORDS`/`CLIENT` exact; procd surface exact (instance `trusttunnel`, command `-c client.toml`, env rule, `respawn 3600 5 0`, stdout/stderr 1, pidfile `/var/run/trusttunnel.pid`); mode `100755` in index and on disk. |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| procd instance `trusttunnel` | command + env clause, respawn `3600 5 0`, stdout/stderr 1, pidfile `/var/run/trusttunnel.pid` | `reload_service` → `apply_settings`; triggers (UCI reload + `interface.*.up` wan → restart); started only after routing up + tun snapshot | Rootfs smoke asserted the full parameter set; oracle asserts hook wiring | PASS |
| Records / state files under `$OUTDIR` | `settings.tsv` (+`.new`/`.next`), `endpoint.pem`, `client.toml` | `.new` → atomic `mv` in regenerate; `.next` → mv on noop, rm on all other branches; pem removed when UCI empty | Oracle asserts no `.next` left after export failure; modes 600 verified in smoke | PASS |
| Classifier | noop(0) → reload(1) → restart(2) → restart_full(3); whitelist incl. `routing_profile.*` → restart; unknown → restart_full | `classify_change` = max; cert mismatch bumps ≥ restart; `_TT_KEEP_ROUTING` set only by restart branch, consumed by `stop_service`, reset by `abort_restart_cleanup` | 29 apply assertions + 21 reload assertions, all green | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| Function surface (19 functions: setup_trust_store, wait_for_time, wait_for_wan, regenerate, abort_restart_cleanup, max_ifindex, new_client_devices, attach_client_device, start_service, stop_service, changed_keys, change_class, class_rank, class_max, classify_change, restart, apply_settings, reload_service, service_triggers) | source | PASS | All present with exact names; oracle stubs (`restart`/`regenerate`/`running`/`logger`) bind by name; globals read at call time. |
| Externally visible log lines (11, via `logger -t trusttunnel`) | runtime | PASS | Byte-identical to the plan's Contracts table; oracle asserts several verbatim. |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| (AGENTS.md) | N/A | No AGENTS.md exists in the repo. |

## Issues Found

1. **Device-only manual verification pending (AC3 / Task 9 remainder)**
   - Location: `packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` (verification, not code)
   - Description: The plan's Task 9 checklist was executed via the rootfs container substitution; the real-device items — live procd instance `status`, actual pidfile and the `3600 5 0` respawn window, real `config_load` against `/etc/config/trusttunnel`, the clock/WAN waiters against a router's clock and network, and hotplug reattach over a live client — remain unexecuted. This is documented in the plan's own Task 9 note and is an environment limitation.
   - Impact: Low. The implementation itself matches the contract and the two oracle tests (the core acceptance criterion) pass unchanged; the device smoke is a confirmation step, not a defect signal.
   - Recommendation: Run the Task 9 checklist on a router via the release workflow's install flow (enable/start/status, UCI edits hitting reload vs keep-routing vs full-restart, hotplug reattach) and sign it off.
   - Resolved:
     (pending)

## Recommendations

- Execute the device-only remainder of Task 9 on real hardware (procd lifecycle, real UCI, waiters, hotplug reattach) to fully close AC3.
- No code changes required: all automated gates — both oracle tests unchanged (29 + 21), full suite (315 assertions, 0 failed), `sh -n`, shellcheck v0.11.0, 26-key schema completeness, mode 100755 — pass against the current tree.

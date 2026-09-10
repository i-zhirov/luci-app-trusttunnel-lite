# Issue Validation Report: TT-07 — uci-defaults (first-boot firewall setup)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-07/issue.md`
- **Plan**: `.sdd/.current/issues/TT-07/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 7 | 0 | 0 | 7 |
| Acceptance Criteria | 5 | 0 | 0 | 5 |
| Entities | 4 | 0 | 0 | 4 |
| Contracts | 1 | 0 | 0 | 1 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1: Scenario harness + equivalence baseline** - PASS
  - `tests/test_uci_defaults.sh` exists with the six scenario functions
    (fresh / duplicated / legacy / upgrade / side-effects / idempotent),
    `TT_UCD_SCRIPT` and `TT_UCD_FILTER` selectors, docker-absent skip guard,
    fixture dirs per scenario, stubbed `/etc/init.d/firewall`,
    `/etc/init.d/trusttunnel` and `/bin/logger` recording their calls.
  - Calibration verified empirically: the harness run against the inherited
    file (`git show 31d7f21^`) reports `66 assertions, 0 failed` across all
    six scenarios — the equivalence baseline claim holds.
  - Negative control verified: `TT_UCD_SCRIPT=/nonexistent sh
    tests/test_uci_defaults.sh` → `66 assertions, 50 failed` — the harness
    is not vacuously green.
  - Note (plan-text drift, no behavior impact): plan Task 1's `duplicated`
    description says `RELOADS=1`, but the harness asserts `RELOADS=2` with
    the migration log line and two `device='tun+'` bindings. Calibration
    against the inherited file forced these assertions (the inherited script
    performs a post-dedup device re-bind of the surviving non-first zones);
    the commit message documents this ("Oracle calibration surfaced the
    inherited post-dedup device re-bind — reproduced"). The plan's phase
    list does not mention this repair pass.
- [x] **Task 2: New script skeleton + dedup pass** - PASS
  - Dedup runs first (`config_load firewall`, `config_foreach _dedup_zone
    zone`, `config_foreach _dedup_forwarding forwarding`) before any
    creation logic; first `trusttunnel` zone and first `dest=trusttunnel`
    forwarding kept, later duplicates deleted via `uci delete
    "firewall.$_dz_sec"` / `"firewall.$_df_sec"`; on removal: `uci commit
    firewall`, `/etc/init.d/firewall reload >/dev/null 2>&1`, `logger -t
    trusttunnel "removed duplicate firewall zones left by an earlier
    version"` (exact pinned string). `duplicated` scenario green; verified
    against the inherited file that the first zone/forwarding survive and
    the unrelated `lanzone` zone is not deduped.
- [x] **Task 3: Zone + forwarding creation** - PASS
  - When no trusttunnel zone exists (`-z "$_zone_sec"`, i.e. dedup found
    none): `uci add firewall zone` with `name='trusttunnel'`,
    `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`, `masq='1'`,
    `mtu_fix='1'`, `add_list device='tun+'`; `uci add firewall forwarding`
    with `src='lan'`, `dest='trusttunnel'`; `uci commit firewall` and a
    quieted reload. `fresh` scenario green (13 assertions: exit 0, exactly
    one zone with all seven options, one forwarding, one reload, empty log).
- [x] **Task 4: `tt0` → `tun+` migration** - PASS
  - Only when a zone exists: `config_get _devs "$_zone_sec" device` and
    exact whitespace-delimited token membership (`case " $_devs " in *"
    tun+ "*)`); on absence: `uci -q delete "firewall.$_zone_sec.device"`,
    `uci add_list ... device='tun+'`, then commit + quieted reload + `logger
    -t trusttunnel "firewall zone migrated from tt0 to the tun+ wildcard"`
    (preserved verbatim per plan Discrepancy #1). `legacy` scenario green
    (7 assertions; no forwarding created — matches the contract). The
    post-dedup repair pass (`_rebind_zone`, guarded by `-n "$_removed"`,
    re-loads the firewall config and binds `tun+` on every zone after the
    first) reproduces the inherited behavior surfaced by calibration;
    verified byte-identical final state with the inherited file on the
    `duplicated` fixture (see Issues Found #1).
- [x] **Task 5: Routing profile seed block** - PASS
  - Runs after the firewall block, before the cache clear: `config_load
    trusttunnel`, `config_foreach _count_profiles routing_profile`
    (SC2329-disabled callback sets `_has_profile`); when empty — `uci add
    trusttunnel routing_profile`, `name='Default'`, `mode='vpn'`, the
    `uci -q get trusttunnel.domains.direct 2>/dev/null | while IFS= read -r
    _d` pipeline into `bypass_rules`, `uci set
    trusttunnel.endpoint.routing_profile='Default'`, `uci commit
    trusttunnel`, `logger -t trusttunnel "created the default routing
    profile; the old direct list moved into its bypass rules"` (exact pinned
    string). `upgrade` scenario green (14 assertions: profile seeded with
    name/mode, both `domains.direct` values in `bypass_rules`,
    `endpoint.routing_profile='Default'`, `RELOADS1=0`/`RELOADS2=0`,
    `FW_IDENTICAL`/`TT_IDENTICAL`/`LOG_STABLE`, seed log exactly once, no
    second profile after run 2). `idempotent` scenario additionally proves
    the seed converges the upgrade-shaped fixture and is a no-op on re-run.
- [x] **Task 6: Cache clear, service enable, LuCI cache clear, exit 0** - PASS
  - `mkdir -p /var/cache/trusttunnel`; `rm -f
    /var/cache/trusttunnel/release.json`; `/etc/init.d/trusttunnel enable
    >/dev/null 2>&1` (unconditional); `rm -f /tmp/luci-indexcache
    /tmp/luci-modulecache/* 2>/dev/null`; final `exit 0`. `side-effects`
    scenario green (8 assertions: exit 0, rc.d link
    `S95trusttunnel → ../../etc/init.d/trusttunnel`, `ENABLE=1`, cache dir
    present without `release.json`, both LuCI caches gone, empty log).
- [x] **Task 7: Idempotence, full suite, final gates** - PASS
  - `idempotent` scenario green (10 assertions: `FW_IDENTICAL=yes`,
    `TT_IDENTICAL=yes`, `LOG_STABLE=yes`, `RELOADS1=1`/`RELOADS2=1`, seed
    log once, profile not duplicated).
  - `sh tests/run.sh` → `== all tests passed` (harness runs inside the
    standard runner; 66 assertions, 0 failed).
  - `sh -n packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
    → silent, exit 0.
  - `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s
    sh packages/.../40-luci-trusttunnel` → no output, exit 0.
  - `git ls-files -s` → index mode `100755`.
  - Clean-room check: no file in the tree contains the inherited script's
    text (`git grep` for "green on broken", "redefinition of symbol",
    "zone_exists", "tt0 belongs to no zone" matches only the issue/plan
    docs); the uci-defaults directory holds only the single rewritten file;
    no `*.old`/backup copies. The script uses only `_`-prefixed variables
    (no `local`), per the SC3043 convention.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Fresh system: one `trusttunnel` zone + one `lan → trusttunnel` forwarding, firewall reloaded, rc.d link registered, caches cleared | MET | `scenario_fresh` (13 assertions) + `scenario_side_effects` (8 assertions) in `tests/test_uci_defaults.sh`, both green; raw `uci show firewall` dump shows `@zone[0]` with all seven options and `@forwarding[0]` `src='lan'`/`dest='trusttunnel'`, `RELOADS=1`, rc.d link, caches cleared |
| 2 | Duplicates collapsed, first kept | MET | `scenario_duplicated` (13 assertions) green: 3 zones + 3 forwardings → 1 zone (`marker='first'` kept, `'third'` gone) + 1 forwarding (`marker='a'` kept), unrelated `lanzone` survives, dedup log exactly once |
| 3 | Old `tt0`-bound zone migrated to `tun+` | MET | `scenario_legacy` (7 assertions) green: `device='tun+'` present, `device='tt0'` absent, `RELOADS=1`, migration log exactly once |
| 4 | Idempotent: second run is a no-op | MET | `scenario_idempotent` (10 assertions) green: `FW_IDENTICAL=yes`, `TT_IDENTICAL=yes`, `LOG_STABLE=yes`, reload count stays 1, seeded profile not duplicated, seed log line exactly once |
| 5 | `shellcheck -s sh` and `sh -n` clean | MET | Both run during validation: `sh -n` silent; shellcheck v0.11.0 (pinned image) exit 0 with no findings |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| firewall zone | `name`/`input`/`output`/`forward`/`masq`/`mtu_fix`/`device[]` all set exactly per contract (`REJECT`/`ACCEPT`/`REJECT`/`1`/`1`/`tun+`) | `dest` of the created forwarding; created only when absent, dedup keeps first | `fresh`/`duplicated`/`legacy`/`idempotent` scenarios | PASS |
| firewall forwarding | `src='lan'`, `dest='trusttunnel'` | pairs with the zone; dedup keeps first | `fresh`/`duplicated` scenarios | PASS |
| routing_profile | `name='Default'`, `mode='vpn'`, `bypass_rules[]` = migrated `domains.direct` values | `endpoint.routing_profile='Default'`; seeded only when count is zero | `upgrade`/`idempotent` scenarios | PASS |
| Side-effect artifacts | cache dir/file, rc.d link, LuCI caches, exit 0 | created/removed/registered on every run | `side-effects`/`idempotent` scenarios | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| N/A (no API endpoints) | — | PASS | Behavioral contract verified: three observable log lines — dedup line and seed line exactly as pinned in the issue; migration line (`firewall zone migrated from tt0 to the tun+ wildcard`) preserved verbatim from the inherited file per plan Discrepancy #1. Script structure matches the contract's order: dedup-first, creation, migration, seed (after firewall block, before cache clear), finalize, `exit 0`. |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| N/A — no `AGENTS.md` in the repository | N/A | No project guidelines file to check against |

## Issues Found

1. **Plan text does not describe the post-dedup device re-bind pass (documentation drift)**
   - Location: `.sdd/.current/issues/TT-07/plan.md` Task 1 `duplicated` scenario description (`RELOADS=1`) and the six-phase "Behavior contract" list in Research.
   - Description: the final script contains a seventh behavior — after a dedup removed duplicates, it re-loads the firewall config and binds `tun+` on every zone after the first (`_rebind_zone`, lines 37–51/106–112), and the harness asserts the consequences (`RELOADS=2`, the migration log line, two `device='tun+'` bindings in `duplicated`). The plan describes only dedup → creation → migration of the first zone. This is not an implementation defect: the behavior is inherited (verified empirically — the inherited script produces the identical final state on the `duplicated` fixture, via uci's positional re-resolution of stale anonymous section names), was surfaced by the plan-mandated calibration against the inherited file (Task 1 Step 3), and is documented in commit `31d7f21` and in the code comment.
   - Impact: none on behavior; the equivalence oracle (harness) is green on both files. Future readers of the plan will find the phase list incomplete.
   - Recommendation: update the plan's phase list and the `duplicated` scenario description to include the repair pass (or add a Discrepancy entry like #1–#5). No code change needed.
   - Resolved: (none — validation attempt 1)

2. **Cosmetic stderr difference vs. the inherited file (information only, not a defect)**
   - Location: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel` vs. the inherited blob (`31d7f21^`).
   - Description: on the `duplicated` fixture the inherited script emits one `uci: Invalid argument` stderr line (failed `uci add_list` against stale deleted-section names); the new script emits none because its repair pass re-loads the config and walks only surviving sections. Final UCI state, reloads, logs, rc.d link and cache state are otherwise byte-identical between the two scripts.
   - Impact: none — the issue's contract does not pin stderr noise, and plan Discrepancies #2/#3 treat output-redirect cosmetics as non-contractual.
   - Recommendation: none (keep the cleaner behavior).
   - Resolved: (none — validation attempt 1)

3. **Stray empty untracked file at the repository root**
   - Location: `uc.out` (untracked, 0 bytes, not referenced anywhere).
   - Description: an empty file left in the repo root; not a copy of the uci-defaults script and not a TT-07 artifact, but it will show up in `git status` when the issue branch is finalized.
   - Impact: none on behavior; cosmetic repository hygiene.
   - Recommendation: delete `uc.out` before committing the issue.
   - Resolved: (none — validation attempt 1)

## Recommendations

- Update the plan text (Issue Found #1) so the documented phase list matches the implemented and inherited behavior.
- Delete the stray empty `uc.out` before the branch is finalized.
- Optional hardening (outside this issue's scope, not blocking): the harness's zone-order coverage is limited to the six fixtures; a fixture where a foreign zone precedes the trusttunnel zone(s) would exercise the positional-name quirk corner, but neither the plan nor the issue contract requires it.

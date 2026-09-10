# Issue Validation Report: TT-08 — hotplug route reattach

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-08/issue.md`
- **Plan**: `.sdd/.current/issues/TT-08/plan.md`
- **Overall Status**: Complete
- **Validation attempt**:
  1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 6 | 0 | 0 | 6 |
| Acceptance Criteria | 2 | 1 | 0 | 3 |
| Entities | 4 | 0 | 0 | 4 |
| Contracts | 2 | 0 | 0 | 2 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Baseline — current file is green before any change - PASS
      All three baseline gates re-verified at validation time: `sh -n`
      exits 0 on the hotplug script; pinned shellcheck
      (`koalaman/shellcheck:v0.11.0 -s sh`) exits 0 with no findings; `git
      ls-files -s` shows mode `100755`. Calibration-point check:
      `git log 1fdf82c..HEAD -- <40-trusttunnel>` shows exactly one commit
      (`31d7f21`, the reimplementation itself) — the file was untouched
      between the calibration point and the reimplementation, so the
      inherited file was a valid equivalence oracle.
- [x] **Task 2**: Scenario harness `tests/test_hotplug.sh` + calibration against the inherited file - PASS
      Harness exists with all four groups (filters|guards|attach|invariants,
      default = all) and 16 scenarios / 29 assertions. The sed path-override
      technique, the three stubs (init.d probe, routing recorder, logger),
      the full-state `reset_state()` order-independence contract, and the
      real-file invariant scenarios (I1–I3) all match the plan. **Calibration
      re-verified by the validator**: running the harness against the
      inherited file (`git show 31d7f21^:…/40-trusttunnel`, 47 lines, GPL
      expression) yields 29 assertions, 0 failed — the harness is green
      against the equivalence oracle exactly as the plan requires.
      Integration: `sh tests/run.sh` → `== all tests passed`.
- [x] **Task 3**: Chunk 1 — event filters (ACTION / device name / tun marker / persistence) - PASS
      Script lines 12–28 implement the contract: `[ "$ACTION" = "add" ] ||
      exit 0`; `dev="${INTERFACE:-$DEVICENAME}"` with `[ -n "$dev" ] || exit
      0`; `[ -e "/sys/class/net/$dev/tun_flags" ] || exit 0` (presence = tun
      marker); `flags=$(cat … 2>/dev/null) || exit 0` with
      `[ "$(( flags & 0x800 ))" = "0" ] || exit 0` (IFF_PERSIST, POSIX hex
      arithmetic). All filter scenarios F1–F5 green (including F3,
      INTERFACE-over-DEVICENAME); `sh -n` clean.
- [x] **Task 4**: Chunk 2 — state guards (records / service running / foreign device) - PASS
      Script lines 32–45: `RECORDS=/var/etc/trusttunnel/settings.tsv`,
      `OUTDIR=/var/etc/trusttunnel`, `[ -f "$RECORDS" ] || exit 0` (regular
      file), `/etc/init.d/trusttunnel running >/dev/null 2>&1 || exit 0`
      (output discarded), and the foreign-device guard
      `cur=$(cat "$OUTDIR/device" 2>/dev/null)` with
      `[ -n "$cur" ] && [ -d "/sys/class/net/$cur" ] && [ "$cur" != "$dev" ]`
      (sysfs directory liveness + `!=` comparison). All guard scenarios
      G1–G6 green; `sh -n` clean.
- [x] **Task 5**: Chunk 3 — attach + log - PASS
      Script lines 50–51: `/usr/libexec/trusttunnel/routing attach
      "$RECORDS" "$OUTDIR" "$dev" && logger -t trusttunnel "hotplug:
      reattached routing to $dev"` — log chained to attach success, script
      exit status follows the attach (non-zero on failure, no log), matching
      the behavior pinned by scenario A2 during calibration. A1/A2 green;
      full harness 29/0; full suite green.
- [x] **Task 6**: Final gates + device smoke checklist - PASS
      Static gates all green at validation time: `sh -n` exit 0 on both
      files; shellcheck (docker, `-s sh`) exit 0 with no findings on both
      files; `sh tests/run.sh` → `== all tests passed` (includes
      `tests/test_hotplug.sh`). Executable bit: index mode `100755` for both
      files (`git ls-files -s`). Clean-tree check: `packages/…/hotplug.d/net/`
      contains only `40-trusttunnel` — no `*.old` copy kept; `git status
      --short` shows no TT-08 strays. Device smoke checklist is documented
      (Step 4: client-restart reattach, persistent-tun negative, foreign
      device); it is a manual hardware step — execution on a router cannot
      be confirmed from the repository and is not executable in this
      environment (see Issues Found #2). The persistent-tun negative case is
      covered automatically by scenario F5.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Event pipeline matches the contract (add-only, tun marker, IFF_PERSIST check, records/running guards, foreign-device guard, attach + log) | MET | Line-by-line match with the issue contract (script lines 12–51, see Task 3–5 evidence); harness 16 scenarios / 29 assertions green, including the attach-positive F3/G4–G6/A1/A2 that only pass when the full chain is implemented |
| 2 | `shellcheck -s sh` and `sh -n` clean | MET | `koalaman/shellcheck:v0.11.0 -s sh` exits 0 with no findings on `40-trusttunnel` and `tests/test_hotplug.sh`; `sh -n` exits 0 on both |
| 3 | Manual test on a device: kill the client → procd respawns it → new tun device event → route attached to the new device (status shows `device up`, traffic flows) | PARTIAL | Hardware-only step; not executable in this environment. The checklist with concrete expectations (`routing status` → `device up`, `ip route show table 880` → `default dev <new> metric 1`, `logread` → `hotplug: reattached routing to <new>`, persistent-tun negative) is documented in plan Task 6 Step 4; the machine-verifiable equivalents (F5 persistent-tun negative; A1 happy path; A2 attach-failure) are green |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Hotplug event | OK — `ACTION` (add-only), `INTERFACE` (preferred), `DEVICENAME` (fallback) | OK — one process per event; nothing persists across invocations except `$OUTDIR/device` | OK — empty/absent values exit 0 without crashing; every ignored event exits 0 | PASS |
| Device sysfs marker (`/sys/class/net/<dev>/tun_flags`) | OK — file presence = tun marker; content = hex flags word | OK — keyed by the event's resolved device name | OK — `-e` presence check; `$(( flags & 0x800 ))` IFF_PERSIST mask; read failure → exit 0 | PASS |
| Tunnel records state (`/var/etc/trusttunnel/`) | OK — `settings.tsv` (records), `device` (last attached device) | OK — `RECORDS`/`OUTDIR` bindings feed the attach call; `device` feeds the foreign-device guard | OK — `[ -f "$RECORDS" ]` regular-file check; recorded device live only when its sysfs dir exists (`-d`); foreign live device → exit 0 | PASS |
| Attach call + log | OK — `routing attach <records> <outdir> <dev>`; `logger -t trusttunnel "hotplug: reattached routing to <dev>"` | OK — depends on TT-05 (`routing attach` exists at `routing` line 301: `attach) attach "${4-}"`); called only when every guard passes | OK — log emitted only on attach success (`&&` chain); exit status follows the attach (A2) | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| Event/shell contract (env `ACTION`/`INTERFACE`/`DEVICENAME`, fixed paths, exit 0 for ignored events, non-zero only on attach failure, log-on-success) | hotplug hook | PASS | All guards present in the contract order; log chained to attach success; exit follows attach — matches the inherited behavior pinned by A2 during calibration |
| Call contract: `routing attach "$RECORDS" "$OUTDIR" "$dev"` (TT-05) | CLI | PASS | Dependency present: `routing` script dispatches `attach) attach "${4-}"` (line 301); TT-05 already validated separately; no network API endpoints (N/A) |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| (no AGENTS.md in the repository) | N/A | No project guidelines file exists; nothing to check |

## Issues Found

1. **[Informational — assertion-count vs scenario-count in the brief] Harness covers 16 scenarios, not 14**
   - Location: `tests/test_hotplug.sh`
   - Description: The expected coverage was stated as "14 scenarios, 29 assertions"; the harness actually contains 16 scenarios (filters F1–F5, guards G1–G6, attach A1–A2, invariants I1–I3) and exactly 29 assertions. The assertion count matches; the scenario count is a superset of the stated expectation, and all 29 assertions pass both against the reimplementation and against the inherited file (calibration).
   - Impact: None — coverage is at least as broad as expected; no scenario from the plan's table is missing.
   - Recommendation: None (no change needed). If the brief is reused, expect 16 scenarios / 29 assertions.
   - Resolved: *(to be filled on re-validation if the harness changes)*

2. **[Informational — environment limitation] Manual device smoke test (acceptance criterion 3) not executed**
   - Location: plan Task 6 Step 4; issue "How to verify" §2–3
   - Description: The acceptance criterion is explicitly a manual test on a router (procd respawn → new tun device event → route reattached). This validation ran in a development environment without the device or the hotplug-call stack; the repository contains no evidence that the checklist was executed on hardware. All machine-verifiable prerequisites are green, including the persistent-tun negative (F5) that the issue's "How to verify" §3 asks for.
   - Impact: Criterion 3 remains open until a device smoke run is performed; no code deficiency is indicated.
   - Recommendation: Run the plan's Task 6 Step 4 checklist on a router with the package installed (or a rootfs with hotplug-call) — client restart → expect `routing status` `device up`, `default dev <new> metric 1` in table 880, and the `hotplug: reattached routing to <new>` log line; then the `ip tuntap add` negative.
   - Resolved: *(to be filled on re-validation if the device test is recorded)*

3. **[Informational — known, deliberate scope boundary] ci.yml shellcheck does not cover `tests/test_*.sh`**
   - Location: `.github/workflows/ci.yml` (untouched by this issue)
   - Description: The new harness is kept shellcheck-clean (verified: docker shellcheck exits 0 on it), but ci.yml's shellcheck list does not include test files. This is documented in plan discrepancy #4 with a note for TT-19 (which owns ci.yml); the issue deliberately does not edit ci.yml.
   - Impact: None for this issue — the harness is lint-clean regardless; the TT-19 note (add `tests/test_hotplug.sh` to the shellcheck invocation) is recorded in plan Task 6 Step 5.
   - Recommendation: Ensure TT-19 picks up the note when it rewrites ci.yml.
   - Resolved: *(to be filled on re-validation if TT-19 lands the ci.yml change)*

## Recommendations

- No code changes required: all 6 plan tasks PASS, acceptance criteria 1–2 MET, harness 29/0 (both against the reimplementation and against the inherited file — the calibration oracle), full suite green, `sh -n` and pinned shellcheck clean on both files, mode `100755`, no leftover old file.
- Close the one open item (criterion 3) by executing the plan's Task 6 Step 4 device smoke checklist on hardware and recording the result.
- Verify TT-19 adds `tests/test_hotplug.sh` to ci.yml's shellcheck list when it rewrites ci.yml.

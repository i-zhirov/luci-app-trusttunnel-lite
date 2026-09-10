# Issue Validation Report: Test harness and record fixtures

- **Validated**: 2026-09-10
- **Model**: tokugaurd/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-01/issue.md`
- **Plan**: `.sdd/.current/issues/TT-01/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 6 | 0 | 0 | 6 |
| Acceptance Criteria | 5 | 0 | 0 | 5 |
| Entities | 1 | 0 | 0 | 1 |
| Contracts | 5 | 0 | 0 | 5 |
| Guidelines | 0 | 0 | 0 | 0 (no AGENTS.md — N/A) |

## Task Status

- [x] **Task 1: Capture the current baseline** - PASS
  Baseline captured at `c43e20a` (7 files, 180 assertions); the rewrite commit
  `a982a5a` documents a byte-identical suite transcript vs the pre-rewrite
  baseline. The runner still produces the identical per-test output shape.
- [x] **Task 2: Re-express `tests/lib.sh`** - PASS
  `tests/lib.sh` (107 lines) implements the pinned contract: `TT_TEST_TMP`
  auto-created via `mktemp -d` when unset, counter files `total`/`failed`
  initialized to 0 only when missing, `assert_eq`/`assert_contains`/
  `assert_exit <expected> <message> <command...>` (message before command),
  `_tt_pass`/`_tt_fail` helpers (consumed by `test_deps.sh`,
  `test_init_apply.sh`, `test_routing.sh`, `test_hotplug.sh`), file-based
  read-modify-write counters (subshell survival proven by `test_harness.sh`
  negative check), `tt_test_summary` printing `  N assertions, M failed` and
  exiting non-zero on any failure. `sh -n` clean.
- [x] **Task 3: Re-express `tests/run.sh`** - PASS
  `tests/run.sh` (33 lines): `cd` to repo root, `set -u`, iterates
  `tests/test_*.sh` in glob order, prints `== <path>` per test, fresh
  `mktemp -d` exported as `TT_TEST_TMP`, runs `sh <test> < /dev/null`,
  removes the temp dir, continues after failures, final banner
  `== all tests passed` (exit 0) / `== FAILURES` (exit 1). Failure path
  verified live: a deliberate-failure scratch test produced exit 1,
  `== FAILURES`, its `== ` banner and marker, while every other test still
  ran. Isolation probe verified `TT_TEST_TMP` set/exported to a fresh dir
  and stdin closed (a `read` on stdin fails immediately).
- [x] **Task 4: Re-express `tests/test_harness.sh`** - PASS
  Standalone run: exit 0, exactly `  5 assertions, 0 failed` (4 positive +
  negative check) — identical to the pinned baseline. Structure includes the
  subshell negative check with `failed`-counter guard (else-branch exits 1
  before `tt_test_summary`, per plan).
- [x] **Task 5: Re-create the record fixtures with identical data** - PASS
  Line counts 6/31/14, tab counts 6/28/12, no data line without a tab
  (awk check silent). Rows match the plan's data tables byte-for-byte,
  including the 3+2 comment lines (no tab) and the `full.tsv` password line
  `pa"ss\with<TAB>specials` (quote + backslash + literal second tab).
  Fixtures were never modified during the reimplementation:
  `git diff 44db74c HEAD -- tests/fixtures/records/` is empty (byte-identical
  to the pre-rewrite committed data). `test_records.sh` (31 assertions) and
  `test_gen_config.sh` (57 assertions) pass against them, including the
  "stops at the first tab" semantics.
- [x] **Task 6: Final suite verification and clean-tree check** - PASS
  `sh tests/run.sh`: exit 0, `== all tests passed`, 9 files, 315 assertions,
  0 failed. Deliberate-failure check re-proven during validation. Standalone
  self-test green. `git status --porcelain` clean after validation — no
  scratch files, no `*.old`.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `tests/run.sh` executes every `test_*.sh` in an isolated temp dir and reports per-test failures | MET | `tests/run.sh` per-test `mktemp -d` + `export TT_TEST_TMP` + `< /dev/null`; live probe verified isolation and closed stdin; deliberate-failure scratch test → exit 1, `== FAILURES`, marker reported, suite loop continued |
| 2 | `assert_eq` / `assert_contains` / `assert_exit` / `tt_test_summary` behave as today (positive and negative cases) | MET | `tests/test_harness.sh` standalone: 5 assertions, 0 failed, exit 0; negative path records failures in the counter files (subshell-visible); `assert_exit` order `<expected> <message> <command...>` matches every caller; full suite green |
| 3 | `tests/test_harness.sh` passes (proves the harness itself) | MET | `sh tests/test_harness.sh` → exit 0, `  5 assertions, 0 failed` |
| 4 | Fixture files contain the same records data as today | MET | `git log` shows fixtures last modified at `44db74c` (pre-reimplementation); `git diff 44db74c HEAD -- tests/fixtures/records/` empty → byte-identical; unit tests (`test_records.sh`, `test_gen_config.sh`) pass against them |
| 5 | No text from the inherited test files is copied verbatim; the new files are written from this contract | MET | `git diff ca1795a HEAD` for the three harness files: new variable names (`tt_*` vs `_tt_*`), new helper structure (`tt_init_counters`/`tt_bump_counter`), new comments, reformatted bodies; only the behavioral contract output (`  ok:`/`  FAIL:` prefixes, summary format, runner banners, `_tt_pass`/`_tt_fail` names required by callers) is retained |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| TSV record (`section.option<TAB>value`) | OK — exact keys/values per plan tables in all three fixtures | OK — repeated keys kept as repeated lines (`endpoint.address` ×2, `endpoint.dns_upstream` ×2, `routing_profile.vpn_rules` ×2, `routing_profile.bypass_rules` ×2) | OK — one tab separator per data line, comments carry no tab, parsed value stops at the first tab (password line) | PASS |

## Contract Status

| Contract | Method/Symbol | Status | Notes |
| --- | --- | --- | --- |
| `assert_eq` | `<expected> <actual> <message>` | PASS | ok/FAIL + expected/actual detail lines |
| `assert_contains` | `<haystack> <needle> <message>` | PASS | substring (`case *needle*`) semantics; missing/haystack detail lines |
| `assert_exit` | `<expected> <message> <command...>` | PASS | stdout/stderr discarded; exit-status detail lines; message-before-command order matches all callers |
| `tt_test_summary` | prints `  <total> assertions, <failed> failed`; exit 0 iff `failed == 0` | PASS | two-space indent verified in live output |
| Runner | `sh tests/run.sh`; per-test `mktemp -d` as `TT_TEST_TMP`; stdin closed; exit 0 iff every test exits 0 | PASS | exit 0 on clean suite; exit 1 + `== FAILURES` on failure |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md | N/A | No AGENTS.md in the repo. Clean-room PRD constraint (new expression, no verbatim inherited text, no `*.old`/scratch leftovers) verified via `git diff` review and clean `git status` |

## Issues Found

No blocking issues. Observations recorded for completeness:

1. **Plan letter vs implementation: fixtures were not rewritten (no-op)**
   - Location: `tests/fixtures/records/{minimal,full,bypass}.tsv`; plan Task 5, commit `a982a5a`
   - Description: The plan lists "Rewrite (in place)" for the three fixtures, but the implementer left them untouched because they were already byte-identical to the contract data (documented in the commit message).
   - Impact: None — acceptance criterion 4 (same records data) is satisfied in the strongest form: `git diff 44db74c HEAD` is empty, so the data is the pre-rewrite data itself, and all unit tests pass against it. Fixture rows are functional data, not expression, so the clean-room requirement is unaffected.
   - Recommendation: None required; optionally note in the caller's status update that the fixture task was a verified no-op.
   - Resolved: (omit while validation is in progress)

2. **Baseline assertion totals in the plan (180) no longer match the current suite (315)**
   - Location: plan Task 6 / Research table
   - Description: The plan pinned the baseline at 7 files / 180 assertions. The current suite runs 9 files / 315 assertions because later issues (`TT-02`+ rewrote/expanded `test_records.sh` 12→31, `test_gen_config.sh` 47→57, `test_routing.sh` 40→51 and added `test_hotplug.sh` 29, `test_uci_defaults.sh` 66).
   - Impact: None for TT-01 — the harness contract is unchanged and its own self-test still reports the pinned `5 assertions, 0 failed`; the growth is the expected evolution of the suite.
   - Recommendation: None.
   - Resolved: (omit while validation is in progress)

3. **Cosmetic output-shape difference in `assert_contains` FAIL detail**
   - Location: `tests/lib.sh` `assert_contains`; vs inherited `ca1795a` version
   - Description: The FAIL detail label changed from `    in:      <haystack>` to `    haystack: <haystack>` (missing-needle line unchanged).
   - Impact: None — no test asserts on FAIL detail text (failures only surface on broken harnesses), and the plan's contract ("detail lines showing the missing needle and the haystack") is met.
   - Recommendation: None.
   - Resolved: (omit while validation is in progress)

## Recommendations

- None blocking. If the caller wishes to close the loop on observation 1, the `plan.md`/`issue.md` status flip to Validated can note that the fixture task was verified as a no-op (fixtures were already byte-identical to the contract data).
- Suggested re-verification cadence: re-run `sh tests/run.sh` once more after the remaining issues land, and confirm `tests/test_harness.sh` still reports exactly `5 assertions, 0 failed` — the harness is the load-bearing contract for the whole suite.

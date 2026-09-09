# Plan Review Report: TT-19 — ci.yml workflow

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-19/issue.md`
- **Plan**: `.sdd/.current/issues/TT-19/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 3 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 0 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[medium] correctness — test_deps.sh (already on the tree) omitted from the shellcheck extension**
   - Target: shellcheck step / plan Discrepancy #1
   - Impact: The extension covers three not-yet-existing sibling files but skips the one that has already landed; the plan's own rationale ("lint all project shell, cover them the moment the sibling issues land") applies verbatim to test_deps.sh.
   - Recommendation: Add tests/test_deps.sh unconditionally (it exists now).
   - Status: Resolved
   - Resolved: plan.md now adds `tests/test_deps.sh` to the shellcheck invocation UNCONDITIONALLY — it exists on the current tree (2026-09-09) and is linted nowhere today, so the "lint all project shell" rationale applies to it verbatim. The split is explicit in the Summary, Research Discrepancies #1 (both the Research and closing sections), the Research baseline table (new "Shellcheck (extension: test_deps.sh)" row, verified clean under v0.11.0), the Entities step 5 table ("8 contract files + hotplug script + tests/test_deps.sh (unconditional) + the 3 sibling test files (present-only)"), Task 1 Step 1 (new local verification run for the file), and Task 3 Step 2 (file-list spec). The three not-yet-existing files (`tests/test_hotplug.sh` TT-08, `tests/test_uci_defaults.sh` TT-07, `tests/install-harness.sh` TT-18) stay present-only conditional; Task 6 Step 2's shellcheck negative control now also names test_deps.sh.
2. **[low] correctness — Baseline "40 assertions, 0 failed" is test_routing.sh's count, not the suite's**
   - Target: Summary line 19, Research baseline table, Task 1 Step 1
   - Impact: run.sh prints one summary per file (7 files); the plan's single "40 assertions" contradicts its own baseline date and the 7-test-file tree.
   - Recommendation: Record the per-file baseline (26/47/5/29/21/12/40).
   - Status: Resolved
   - Resolved: plan.md now records the real per-file baseline from a live `sh tests/run.sh` run on 2026-09-09 — 180 assertions, 0 failed, per file: test_deps 26, test_gen_config 47, test_harness 5, test_init_apply 29, test_init_reload 21, test_records 12, test_routing 40. Corrected everywhere "40 assertions" appeared: the Summary ("180 assertions, 0 failed, per file: …"), the Research baseline table, the Entities step 4 row ("180 assertions today: 26/47/5/29/21/12/40 per file"), and Task 1 Step 1's expected result.
3. **[low] correctness — LuCI-requires gate mislabeled "9-module" (the list has 10)**
   - Target: Research row 11, Entities step 10, Task 5 Step 2, Task 7 Step 2
   - Impact: The list itself (ui dom rpc uci form view poll fs network validation) is correct everywhere; only the count is wrong, risking a future checker dropping one module.
   - Recommendation: Fix the count to 10.
   - Status: Resolved
   - Resolved: every "9-module"/"9 modules" reference is corrected to "10-module"/"10 modules" while the module list itself (`ui dom rpc uci form view poll fs network validation`) is unchanged everywhere. Fixed in: the Research baseline table (LuCI module requires row), the Research contract matrix row 11 ("the exact 10-module list"), the Local verification vehicles table, the Entities step 10 table, Task 1 Step 1 ("the 10-module LuCI-requires grep block"), Task 5 Step 2 ("for each of the 10 modules"), and Task 7 Step 2 ("the 10 LuCI modules").

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 3 prior findings verified Resolved (test_deps.sh unconditional in the shellcheck extension, real 7-file/180-assertion baseline, 10-module LuCI-requires gate). No new findings.
- On re-review, this report is updated in place.

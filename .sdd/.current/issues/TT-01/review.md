# Plan Review Report: TT-01 — Test harness and record fixtures

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-01/issue.md`
- **Plan**: `.sdd/.current/issues/TT-01/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 3 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Fixture contract stale and self-contradictory after the rebase**
   - Target: Actualization vs Research fixture facts, Entities, File Structure, Task 5
   - Impact: Following Entities/Task 5 literally produces the wrong fixture (full.tsv is now 31 lines with profile keys and a single `domains.direct` = `legacy.example`; bypass.tsv exists with 14 lines). test_gen_config's profile/legacy-absence/custom_sni assertions would fail.
   - Recommendation: Propagate the actualized fixture data (31-line full.tsv, 14-line bypass.tsv, 6-line minimal.tsv) into Research, Entities, File Structure and Task 5; fix the `wc -l`/tab-count expectations (6/31/14).
   - Status: Open
   - Resolved: Research, Entities, File Structure and Task 5 now carry the actualized fixture set — minimal.tsv 6 rows; full.tsv 31 rows (21 legacy records incl. endpoint.custom_sni/endpoint.client_random + 3 comment lines + 7 routing-profile records with a single domains.direct=legacy.example); bypass.tsv 14 rows (5 records + 2 comment lines + 7 bypass-profile records). Task 5 re-creates all three fixtures with per-fixture `wc -l` (6/31/14) and tab checks (`rg -c $'\t'`: 6/28/12, plus an awk check that no data line lacks a tab).
2. **[medium] correctness — Baseline numbers stale (7 test files, ~180 assertions)**
   - Target: Research baseline table; Task 1 Step 2; Task 6 Step 1
   - Impact: The plan hard-codes "6 test files / 136 assertions"; the current suite is 7 files / 180 assertions (test_deps.sh added on main; gen_config 47, init_apply 29, init_reload 21).
   - Recommendation: Re-run the baseline and update every pinned count.
   - Status: Open
   - Resolved: Baseline re-run at c43e20a (2026-09-09) and pinned throughout: the Research table, Task 1 Step 2 and Task 6 Step 1 now use the 7-file suite with real per-file counts — test_deps 26, test_gen_config 47, test_harness 5, test_init_apply 29, test_init_reload 21, test_records 12, test_routing 40, 180 total.
3. **[low] correctness — Task 4 Step 3's expected summary output is unachievable**
   - Target: Task 4 Step 3
   - Impact: With a sabotaged positive assertion the failed counter is 2 at the negative check; the harness exits before `tt_test_summary` prints "5 assertions, 1 failed".
   - Recommendation: State the exit-code expectation only, or adjust the sabotage scenario.
   - Status: Open
   - Resolved: Task 4 Step 3 now states the exit-code expectation only — `exit=1` with at least one `FAIL:` line (the sabotaged assertion's FAIL line or the negative-check guard's `FAIL: assert_eq did not record a failure`); the summary line is no longer pinned, and the note explains that a sabotaged positive assertion leaves the failed counter at 2 when the guard runs, so the harness exits 1 before `tt_test_summary` prints.
4. **[low] maintainability — Actualization scope misstatement re test_records.sh**
   - Target: Actualization section
   - Impact: The note says the rewritten test_records.sh assertions "must be re-validated" but test_records.sh is untouched by this issue (it stays as oracle).
   - Recommendation: Reword the note to "fixture data must satisfy the existing test_records.sh assertions".
   - Status: Open
   - Resolved: The Actualization bullet now reads "the rewritten fixture data must satisfy the existing test_records.sh assertions"; test_records.sh is explicitly listed as an untouched equivalence oracle in the Summary, File Structure and Task 5 (no re-validation of rewritten test_records.sh text is implied anywhere).

## Dismissed Findings

None.

## Notes

- Review analysis performed by the designated plan-reviewer subagent (one delegation per issue, all six dimensions).
- The harness contract itself (run.sh/lib.sh/test_harness.sh) verified accurate against the code; the failure is stale post-rebase numbers in the task bodies.
- On re-review, this report is updated in place.

# Plan Review Report: TT-02 — records.sh accessor library

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-02/issue.md`
- **Plan**: `.sdd/.current/issues/TT-02/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 2 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | pass | 0 |
| Operational | fail | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — `tt_count domains.direct` assertion wrong for the rebased fixture**
   - Target: plan.md Task 2 test text; tests/fixtures/records/full.tsv
   - Impact: The rewritten test asserts `tt_count domains.direct` == 2, but full.tsv now contains `domains.direct` exactly ONCE (`legacy.example`, line 31). The 28/28-green-against-old-implementation gate cannot pass as written (the repeated-key case is already covered by `endpoint.address` → 2).
   - Recommendation: Change the expected value to 1 (or pin the repeated-key assertion on a profile list key).
   - Status: Open
   - Resolved: Task 2 Step 1 now asserts `tt_count domains.direct` == 1 ("tt_count counts the single domains.direct entry"); the repeated-key case stays pinned by `endpoint.address` → 2 ("tt_count counts repeated keys"). The full 31-assertion set is gated green against the old implementation (Task 2 Step 2) and the new one (Task 4 Step 1).
2. **[medium] maintainability — Baseline assertion counts stale**
   - Target: Task 1 Step 1, Task 6 Step 1
   - Impact: The plan expects 136 total with per-file counts (35/24/20) that no file has; actual is 163 (incl. test_deps.sh 10) or 180 on the full suite — an implementer may suspect collateral damage.
   - Recommendation: Re-run the baseline on the rebased tree and update all counts.
   - Status: Open
   - Resolved: Baseline re-run on the rebased tree: 180 assertions, 0 failed — test_deps.sh 26, test_gen_config.sh 47, test_harness.sh 5, test_init_apply.sh 29, test_init_reload.sh 21, test_records.sh 12, test_routing.sh 40. Task 1 Step 1 records these per-file counts, Task 6 Step 1 expects the same other-file counts with test_records.sh at 31, and Technical Context + Research §2 cite the actualized numbers.
3. **[low] correctness — Whole-field key matching never asserted**
   - Target: Task 2 test text (edge fixture section)
   - Impact: A re-expression using prefix matching would pass every assertion and the golden diff while violating the pinned semantic.
   - Recommendation: Add a prefix-collision fixture pair (e.g. `edge.x` vs `edge.x.y`) and assert whole-field behavior.
   - Status: Open
   - Resolved: Task 2 Step 1 extends the throwaway edge fixture with `edge.x.y⇥2` written BEFORE `edge.x⇥1` and asserts `tt_get edge.x` → 1, `tt_list edge.x` → 1, `tt_count edge.x` → 1 — a prefix-matching re-expression fails all three (get would answer 2, list would emit `2\n1`, count would total 2). Research §1 pins the same behavior in its probe table and edge-case list.
4. **[low] operational — Golden transcript redirect to `$TT_TEST_TMP` outside run.sh context**
   - Target: Task 5 Step 1
   - Impact: Task 5 runs outside run.sh; `TT_TEST_TMP` is unset there and the redirect resolves to `/golden.out` — permission denied on macOS/Linux.
   - Recommendation: Write transcripts next to the Task 1 oracle dir or an explicit `mktemp -d`.
   - Status: Open
   - Resolved: Task 5 Step 1 no longer references `$TT_TEST_TMP` (unset outside run.sh). Task 1 Step 2 creates an explicit temp root `TT02_TMP="$(mktemp -d)"` with the oracle at `$TT02_TMP/oracle`; Task 5 writes `golden.out`/`new.out` and diffs them under `$TT02_TMP`, then Task 5 Step 2 removes `$TT02_TMP` (oracle + transcripts) after the diff passes.

## Dismissed Findings

None.

## Notes

- Guard semantics, first-occurrence/defaulting behavior, quote/backslash handling, assert_exit argument order, caller facts and CI gates all verified accurate.
- On re-review, this report is updated in place.

# Plan Review Report: TT-08 — hotplug route reattach

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-08/issue.md`
- **Plan**: `.sdd/.current/issues/TT-08/plan.md`
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

1. **[medium] correctness — Red/green expectations in Tasks 3-4 contradict the scenario design**
   - Target: plan.md Tasks 3-4 (Steps 1 and 3 of each); scenario table F1-F5/G1-G6
   - Impact: Negative-assertion scenarios (F1, F2, F4, F5, G1, G2, G3) pass trivially against the placeholder (always exit 0), while the attach-positive scenarios (G4-G6) cannot pass until chunk 3. The stated per-chunk red/green states are wrong in both directions and would mislead the implementer (or tempt adding the attach call in chunk 2).
   - Recommendation: Recompute the per-chunk expected states from the scenario semantics (negative scenarios pass from chunk 1; attach scenarios green only at chunk 3).
   - Resolved: The scenario table now carries a "Green from" column (chunk 0 = negative assertion that passes even against the exit-0 placeholder; chunk 3 = positive assertion needing the routing call), with a footnote defining the semantics, and the task expectations are recomputed from it: Task 3 Step 1 now expects F1/F2/F4/F5 to pass trivially and F3 to fail; Task 3 Step 3 and Task 4 Steps 1/3 mark G1–G3 trivially green while F3/G4–G6/A1/A2 stay red until chunk 3, with an explicit "the attach call belongs to chunk 3 — do not add it here" note; Task 4's Verification line and Task 5 Step 1 state the complete pre-chunk-3 red set (F3, G4–G6, A1, A2). Chunk boundaries are kept; only the expectations were corrected.
   - Status: Resolved
2. **[low] correctness — Harness `reset_state()` does not restore state mutated by F5/G1/G4**
   - Target: plan.md Task 2 scaffold: reset_state(), scenario table
   - Impact: Scenarios remove/modify tun_flags, settings.tsv and sysfs entries that reset_state() does not recreate; later scenarios become order-dependent unless each scenario re-establishes its full scratch state.
   - Recommendation: Specify per-scenario full state setup in the harness contract.
   - Resolved: The Task 2 scaffold's reset_state() now restores the FULL default scratch state — re-copies settings.tsv from the fixture, recreates the tun0/tun1 sysfs dirs with non-persistent tun_flags, clears the device record, the stub rc overrides and the recorders — and the harness contract states that every scenario calls reset_state() first and applies its own deltas only afterwards (F5 → 0x1801 tun_flags, G1 → remove settings.tsv, G4 → remove the tun1 sysfs dir, G3/G5 → write device, G2 → init_rc=1, A2 → routing_rc=1), making the scenarios order-independent.
   - Status: Resolved
3. **[low] operational — No step confirms the hotplug script is unchanged since calibration**
   - Target: plan.md Task 2 Step 2 (calibration baseline)
   - Impact: The calibration silently depends on `git log 1fdf82c..HEAD -- 40-trusttunnel` being empty (it is — confirmed in the rebase delta); the plan should state it.
   - Recommendation: Add the git-log check to Task 1.
   - Resolved: Task 1 gains Step 2 — `git log 1fdf82c..HEAD --oneline -- packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` must produce empty output (verified against the repo: the file did not change on main), recorded in the baseline notes; Task 2 Step 2's calibration run now cites this check as the precondition that makes the inherited file a valid equivalence oracle.
   - Status: Resolved

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 3 prior findings verified Resolved ("Green from" classification consistent across the scenario table and task steps, reset_state() full-state contract, git-log baseline check).
- Two non-blocking notes (below the finding threshold): plan line 410 says "default: all five" while the group list is four; Resolved-note 1 overstates that Task 4's Verification line carries the full red set (A1/A2 appear in Task 4 Step 3).
- On re-review, this report is updated in place.

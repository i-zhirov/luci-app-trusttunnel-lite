# Plan Review Report: TT-18 — install.sh

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-18/issue.md`
- **Plan**: `.sdd/.current/issues/TT-18/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 3 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 1 |
| Architecture | pass | 1 |
| Operational | pass | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Task 6 still specifies the old dependency set (no nftables)**
   - Target: Task 6 Steps 1/3; Summary; Research table row 7
   - Impact: The real file (and test_deps.sh) require `kmod-tun ip-full nftables curl ca-bundle`; implementing per the task text drops nftables — behavior diverges and tests/test_deps.sh fails.
   - Recommendation: Propagate the nftables set into Task 6, Summary and Research.
   - Status: Resolved
   - Resolved: `kmod-tun ip-full nftables curl ca-bundle` now appears everywhere the dependency set is spelled out — Task 6 Step 1 (call-log subsequence for both apk and opkg), Task 6 Step 3 (rewrite instruction), Task 6 Verification, Task 8's package-set assert, Summary (install sequence), and Research row 7 (with install.sh lines 186/188).
2. **[high] correctness — The immediate uci-defaults run is absent from every task body**
   - Target: Task 7; Research stub table
   - Impact: No success/failure scenario for the uci-defaults step, no stub, no log assertion; the rpcd restart → uci-defaults → start ordering is unrepresented.
   - Recommendation: Add the uci-defaults scenarios (success + warning fallback) to Task 7 and a stub to the harness table.
   - Status: Resolved
   - Resolved: Chunk 5 (Task 7) now owns the immediate uci-defaults run — SUCCESS/FAILURE/ABSENT scenarios covering the `-x` guard, silenced output (`>/dev/null 2>&1`), the exact warning fallback text "warning: the default routing profile was not created; run /etc/uci-defaults/40-luci-trusttunnel manually", a stdout log assertion, and the enforced call order `rpcd restart` → `/etc/uci-defaults/40-luci-trusttunnel` → `start`; the harness stub table gained the planted uci-defaults stub (records invocation, exits `$STUB_UCI_DEFAULTS_RC`, absent by default); Task 8's golden diff includes the seeded `/etc/config/trusttunnel` and Task 7's rewrite step names the exact warning string.
3. **[medium] correctness — Task 8 golden diff lacks the seeded-profile check and has stale package-set asserts**
   - Target: Task 8 Step 3
   - Impact: The diff path list omits /etc/config/trusttunnel; the package set is "five trusttunnel packages" (there are three) and omits nftables. The final verification cannot detect the two regressions the actualization targets.
   - Recommendation: Add the config diff and fix the package-set assert.
   - Status: Resolved
   - Resolved: Task 8 Step 4's `docker cp`/`diff -r` path list now includes `/etc/config/trusttunnel` (the seeded Default profile) and the package-set assert now reads the three trusttunnel packages (luci-app-trusttunnel, luci-i18n-trusttunnel-ru, trusttunnel-client) + `kmod-tun ip-full nftables curl ca-bundle`; the Research golden-diff methodology section was corrected to match, and the `/etc/config/trusttunnel` entity was added to the Entities section.
4. **[medium] operational — No task runs `sh tests/run.sh` (test_deps.sh never consulted)**
   - Target: Task 8; tests/test_deps.sh
   - Impact: test_deps.sh asserts the rewritten install.sh's dependency lines; the plan's verification matrix omits it, so a CI regression slips through the plan's own gates.
   - Recommendation: Add the suite (or test_deps.sh) to the verification matrix.
   - Status: Resolved
   - Resolved: Task 8 now has an explicit `sh tests/run.sh` gate (new Step 2, echoed in the Task 8 Files list and the final Verification) — `tests/test_deps.sh` asserts both install.sh branches install `kmod-tun ip-full nftables curl ca-bundle`, so a dependency regression fails the plan's own gates.
5. **[medium] maintainability — Research table stale (deps row, uci-defaults row, 263 vs 281 lines)**
   - Target: Research table rows 7/10; Task 1 Step 2; Summary
   - Impact: The baseline inventory the golden-diff strategy rests on is itself wrong.
   - Recommendation: Re-measure on the rebased tree.
   - Status: Resolved
   - Resolved: Research row 7 actualized to `kmod-tun ip-full nftables curl ca-bundle` (lines 186/188) and row 10 actualized to the immediate uci-defaults run (lines 246–257: `-x` guard, silenced output, exact warning fallback, start only when `was_running=1`); the Summary's "263 lines" claim corrected to 281; Summary, Technical Context, Task 1 Step 2 and the golden-diff methodology updated for the nftables set and the seeded `/etc/config/trusttunnel`.

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 5 prior findings verified Resolved (nftables set everywhere, uci-defaults scenarios with the exact warning text and ordering, golden diff incl. /etc/config/trusttunnel + corrected package-set assert, explicit suite gate, actualized research rows). No new findings.
- On re-review, this report is updated in place.

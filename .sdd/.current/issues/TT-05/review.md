# Plan Review Report: TT-05 — routing (nft/ip management)

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-05/issue.md`
- **Plan**: `.sdd/.current/issues/TT-05/plan.md`
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
| Operational | fail | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[medium] correctness — Exact `TT_IP`/`TT_NFT` literals pinned by test_deps.sh are missing from the plan**
   - Target: plan.md Task 3 Step 1 / Task 4 Step 1; tests/test_deps.sh
   - Impact: tests/test_deps.sh (fork-original, added on main) asserts the file contains the exact literals `TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"`; a rephrased default passes the plan's own checks but breaks `sh tests/run.sh`.
    - Recommendation: Pin the two literals in the file contract, like the dump bytes.
    - Status: Open
    - Resolved: Plan Task 3 Step 1 now pins the exact literals
      `TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"` as part of the
      file contract (env/prologue bullet), Task 3 Step 2 adds a byte-exact
      `grep -Fq` gate for both, Task 4 Step 1 notes test_deps.sh re-asserts
      them in the full-suite run, and the Research audit bullet now quotes
      the literals verbatim.
2. **[low] maintainability — "Discrepancies found" section stale and one item misquotes the issue**
   - Target: plan.md Research, "Discrepancies found" section
   - Impact: All six items are already in the updated issue; item 3 misquotes it ("v4+v6, best-effort" vs the issue's "v4 FATAL, v6 best-effort"). The clean-room audit trail is inaccurate.
    - Recommendation: Refresh the section against the actualized issue.
    - Status: Open
    - Resolved: The section is renamed "Contract cross-checks" and refreshed
      against the actualized issue: all six items are now quoted as they
      appear in the issue with the code verified to match each, and item 3
      correctly quotes "(v4 FATAL on failure, v6 best-effort)" instead of
      the previous misquote.
3. **[low] operational — `git status --short` "exactly two entries" expectation fails with untracked .sdd/**
   - Target: Task 4 Step 2
   - Impact: `.sdd/` is not gitignored; the check as worded fails despite a clean outcome.
    - Recommendation: Allow the .sdd plan/issue files in the expectation.
    - Status: Open
    - Resolved: Task 4 Step 2 (and the Summary + File Structure notes) now
      scope the expectation to TRACKED changes: exactly two (routing +
      test_routing.sh), with the untracked `.sdd/` entries and other
      pre-existing untracked dirs (e.g. `docs/`) explicitly allowed and no
      new `??` entries (no `*.old`, goldens, or fixtures).
4. **[low] correctness — Golden-diff expectation "differ exactly by the output-chain block" is wrong**
   - Target: Task 1 Step 4
   - Impact: up.tsv and router.tsv also differ in the `iifname != { ... }` line (br-lan br-guest vs br-lan).
    - Recommendation: State the real difference set.
    - Status: Open
    - Resolved: Task 1 Step 4's verification now states the real difference
      set: (1) the `iifname != { ... }` line — `{ "br-lan", "br-guest" }` in
      up.golden vs `{ "br-lan" }` in router.golden — and (2) the
      output-chain block present only in router.golden.

## Dismissed Findings

None.

## Notes

- Subcommand surface, dump byte shape, up/attach/detach/down/status semantics, exit codes, and the TT-02 dependency claim all verified 1:1 against the code. The routing script and test_routing.sh did NOT change on main (no actualization needed — confirmed via rebase delta).
- On re-review, this report is updated in place.

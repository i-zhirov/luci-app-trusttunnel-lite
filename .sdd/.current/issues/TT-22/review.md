# Plan Review Report: TT-22 — License flip

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-22/issue.md`
- **Plan**: `.sdd/.current/issues/TT-22/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 3 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 1 |
| Architecture | pass | 0 |
| Operational | pass | 2 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[medium] correctness — The Copyright gate is wrong in both directions**
   - Target: Task 1 Step 2, Task 6 Step 1; LICENSE
   - Impact: `git grep -i "opyright"` expecting NO hits can never pass: the tracked LICENSE alone contains 16 Copyright hits, and every candidate license text (Apache-2.0, GPL-3.0, MIT) contains the word. The gate fails immediately and the pass-gate can never pass.
   - Recommendation: Exclude LICENSE from the Copyright grep (or drop the Copyright gate and keep the gpl/NooBiToo/капаров gates, which do work).
   - Status: Resolved
   - Resolved: The Copyright grep is dropped entirely — Task 1 Step 2 and Task 6 Step 1 no longer run `git grep -i "opyright"`, and the revised "Gate design" section in Research documents why (LICENSE alone has 16 hits; every candidate license text contains the word, so no Copyright gate can ever pass). The gpl/NooBiToo/капаров gates stay and, together with the Task 3 LICENSE replacement, carry the AC-4 load.
2. **[medium] maintainability — README "fork" references inventory incomplete**
   - Target: Task 5 Steps 2-4; README.md
   - Impact: ~8 present-tense "this fork" references remain in the body (lines 9, 23, 34, 67, 146, 243-244, 292); the fail-gate grep is never re-run as a pass-gate, undercutting AC-3 (independence statement).
   - Recommendation: Enumerate the lines in the edit list (or decide they are neutral) and add a pass-gate.
   - Status: Resolved
   - Resolved: Task 5 Step 1 now enumerates all 8 present-tense "fork" hits (intro lines 3–5; lines 9, 23, 34, 67, 146; table header 243–244; Acknowledgements bullet 291–292) with a per-line treatment in Step 3, and Step 4 re-runs `grep -n 'fork' README.md` as a pass-gate expecting only the intro history note's single past-tense mention — restoring AC-3 coverage.
3. **[low] correctness — Inventory line numbers stale (README Acknowledgements 289-296 not 251-254; Makefile NooBiToo on line 5 not 4-6; phantom gpl-grep whitelist entry for LICENSE)**
   - Target: inventory items 1, 4, 7; Task 4 Step 2
   - Impact: None break the gates, but the inventory is presented as "verified in the current tree".
   - Recommendation: Re-verify the citations.
   - Status: Resolved
   - Resolved: Inventory citations corrected in the plan: README Acknowledgements now 289–296 with the NooBiToo bullet at 291–292 (inventory item 7, Task 5 Step 1); Makefile NooBiToo text on line 5 within the comment span 4–6 (inventory item 4, Task 4 Steps 1–2); the phantom LICENSE gpl-grep whitelist entry is removed and replaced by a verified note that LICENSE contains no 'gpl' substring (0 hits), so it needs no whitelist entry.
4. **[low] operational — Task 6 Step 5 (push/CI) executes before Task 7 creates the flip commit**
   - Target: Task 6 Step 5 vs Task 7
   - Impact: CI on the flip can only run after the commit exists; the step is unexecutable in order.
   - Recommendation: Reorder (commit first, then push/CI) or mark Step 5 post-commit.
   - Status: Resolved
   - Resolved: Task 6's push/CI step is removed from the pre-commit gate and moved into Task 7 as Step 4 ("Push / CI (post-commit)"), after Step 3 verifies the flip commit exists. Task 6 is now strictly pre-commit verification (grep gate, tests, diff scope, package metadata).
5. **[low] operational — GNU BRE `\|` patterns break on macOS BSD grep**
   - Target: Task 4 Steps 2/4
   - Impact: POSIX BRE has no `\|`; on darwin the pattern matches the literal string and returns nothing — the gate "fails to fail".
   - Recommendation: Use `grep -E` or separate `-e` patterns.
   - Status: Resolved
   - Resolved: Task 4 Steps 2/4 now use separate `-e` patterns instead of BRE `\|` (e.g. `grep -n -e 'GPL-2.0-only' -e 'NooBiToo' packages/luci-app-trusttunnel/Makefile` and `grep -n -e 'SPDX' -e 'PKG_LICENSE' …`), portable to macOS BSD grep; the plan's "Gate design" section states the no-`\|` rule for all gates.
6. **[low] operational — Clean-tree gates ignore the untracked .sdd/ and docs/ dirs**
   - Target: Task 1 Step 2, Task 6 Step 3; .gitignore
   - Impact: `git status --porcelain` shows `?? .sdd/` and `?? docs/`; the gate expectations as written fail.
   - Recommendation: Whitelist the dirs or commit them before the flip.
   - Status: Resolved
   - Resolved: Task 1 Step 2 and Task 6 Step 3 now whitelist the untracked `?? .sdd/` and `?? docs/` entries in the `git status --porcelain` expectations (spec-doc dirs, intentional mentions, invisible to `git grep`); the plan keeps them untracked and outside the three-file flip commit, and Task 7 Step 1 explicitly forbids `git add -A` for that reason.

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 6 prior findings verified Resolved (Copyright gate dropped, full fork-reference inventory + pass-gate, corrected line numbers, commit-before-push ordering, BSD-safe grep patterns, untracked-dir whitelist).
- New on re-review (both non-blocking): (1) Task 7 Step 3's "exactly the three files" expectation was made conditional in the plan by the primary agent — GPL-2.0-only / GPL-2.0-or-later choices leave LICENSE unchanged, so the commit touches only the app Makefile and README; (2) present-tense "the fork" self-references remain in tracked shell scripts (uci-defaults, gen-config, routing, uci-export, install.sh, uninstall.sh) — out of this issue's file scope; flag to the owner whether the independence rewrite should extend there.
- On re-review, this report is updated in place.

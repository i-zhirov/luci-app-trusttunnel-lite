# Plan Review Report: TT-20 — release.yml workflow

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-20/issue.md`
- **Plan**: `.sdd/.current/issues/TT-20/plan.md`
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

1. **[high] correctness — Task 8 still instructs copying the removed static html templates**
   - Target: Task 8 Step 1
   - Impact: `apk-index.html`/`opkg-index.html` no longer exist in repo-site (removed on main; only apk-index.md/opkg-index.md/apk-arch-index.md remain). Task 8 omits the actual steps: `cp -r repo-site/_layouts site/_layouts`, the `__ARCH_LIST__` sed loop, the opkg-index.md copy, and the per-arch `__ARCH__`/`__FILES__` loop. An implementer following Task 8 produces a failing assemble step.
   - Recommendation: Rewrite Task 8 around the markdown templates and sed-substitution loops.
   - Status: Open
   - Resolved: Task 8 Step 1 now describes the actual assemble steps in order — `cp -r repo-site/_layouts site/_layouts`, the `__ARCH_LIST__` sed loop (`sed "/__ARCH_LIST__/{r $arch_list; d}" repo-site/apk-index.md > site/apk/index.md`), the `opkg-index.md` copy, and the per-arch `__ARCH__`/`__FILES__` loop (`sed -e "s/__ARCH__/$arch/g" -e "/__FILES__/{r $files; d}" repo-site/apk-arch-index.md > "$d/index.md"`) — with an explicit instruction that no `apk-index.html`/`opkg-index.html` exists anywhere; Task 8 Steps 2–3, the job-by-job row 14, D10 and the layout contract sections were actualized to match.
2. **[high] maintainability — Binding contract notes (D10, site layout) stale and self-contradictory**
   - Target: plan.md D10, 'Repository/site layout contract', Entities 'Pages site'
   - Impact: D10 still describes the html rename; the layout sections omit _layouts/, per-arch index.md and the placeholders — conflicting authoritative specs for AC1.
   - Recommendation: Actualize D10 and the layout contract sections.
   - Status: Open
   - Resolved: D10 now documents the markdown templates (`_layouts/` recursive copy, `apk-index.md`/`__ARCH_LIST__` → `site/apk/index.md`, `opkg-index.md` → `site/opkg/index.md`, `apk-arch-index.md`/`__ARCH__`+`__FILES__` → `site/apk/<arch>/index.md`, no html rename); the 'Repository/site layout contract' section, job-by-job row 14 and the Entities 'Pages site' section now include `_layouts/`, the per-arch `index.md` pages and the three placeholders.
3. **[medium] correctness — Task 8 Step 3 "exactly five template files" and rename checklist stale**
   - Target: Task 8 Steps 2-3
   - Impact: repo-site now holds 7 entries (3 markdown templates + _config.yml + README.md + _layouts/repo-index.html + favicon.ico).
   - Recommendation: Update the file-set and the destination renames.
   - Status: Open
   - Resolved: Task 8 Step 3 now confirms the 7-entry repo-site set (`apk-index.md`, `apk-arch-index.md`, `opkg-index.md`, `README.md`, `_config.yml`, `favicon.ico`, `_layouts/repo-index.html`) and asserts no `apk-index.html`/`opkg-index.html` remain; the destination list in Task 8 Steps 1–2 was corrected to the markdown destinations (`site/apk/index.md`, `site/opkg/index.md`, `site/apk/<arch>/index.md`, `site/_layouts`).
4. **[low] correctness — Baseline line numbers stale (368/412 vs 403/452; 577 vs 620 lines)**
   - Target: Research 'Baseline state'
   - Impact: Cosmetic (Task 1 re-records the baseline) but the "verified" claim does not match the current file.
   - Recommendation: Re-cite after the baseline capture.
   - Status: Open
   - Resolved: The Research baseline now cites the current state — the file is 620 lines at commit c43e20a, SC2086 around line 403 (apk assemble step, actionlint `run:` key at 368) and SC2016 around line 452 (opkg step, `run:` key at 412) — and states Task 1 re-records the baseline against the working tree before the rewrite, so the exact numbers are re-cited there.
5. **[low] operational — Task 9 site verification checks only "the two index.html pages"**
   - Target: Task 9 Step 3
   - Impact: The actualized site produces per-arch index pages and requires _layouts; a missing per-arch index or layout would go unnoticed.
   - Recommendation: Extend the live checklist to the per-arch pages.
   - Status: Open
   - Resolved: Task 9 Step 3's Site/deploy check now covers the rendered `apk/index.html` (all 20 archs from `__ARCH_LIST__`), every `apk/<arch>/index.html` (`__ARCH__`/`__FILES__` content), `opkg/index.html`, and a spot-check of the `repo-index` layout from `_layouts/`; a missing per-arch index or a broken layout now fails the step.

## Dismissed Findings

None.

## Notes

- Everything outside the site-assembly chunk matches the real workflow byte-for-byte (triggers, matrices, signing, verification containers, Pages actions). The issue contract is correctly actualized; only the plan's task bodies and D-notes are not.
- On re-review, this report is updated in place.

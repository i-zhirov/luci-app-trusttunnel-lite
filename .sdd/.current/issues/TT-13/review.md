# Plan Review Report: TT-13 — Russian translation (.po)

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-13/issue.md`
- **Plan**: `.sdd/.current/issues/TT-13/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 5 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | fail | 1 |
| Operational | fail | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[critical] correctness — Actualization not propagated; all counts stale (216 msgids / 210 keys, not 182/180)**
   - Target: Tasks 1-6, Summary, Research, Entities, Contracts
   - Impact: Task 1 expects exit 0 + "182 translated", Task 2's `len(ids) == 183` raises on the actual 217 entries (216 msgids + header), and the skeleton drops all 34 new msgids. Executable steps fail on the current tree.
   - Recommendation: Re-measure on the rebased tree and update every count (status.js 51, settings.js 79, diagnostics.js 90, union 210, .po 216 msgids).
   - Status: Open
   - Resolved: Plan re-measured on c43e20a and every count updated in the Research table, Summary, Entities, Contracts and Task bodies: .po 217 msgid lines = 216 msgids (215 unique after the Mode dedup); status.js 51, settings.js 79, diagnostics.js 89 unique `_()` keys; union 209; 10 shared; 11 placeholders; target catalog 211 msgids (209 view keys + Status/Settings) = 212 entries incl. header. Task 1's probes print exactly these numbers and the task verifications compare against them, so the executable steps match the current tree. (The diagnostics count is 89 unique keys, not 90: the 90th candidate is the DIAG_TEXT map key `/dev/net/tun present`, which maps to `_('present')` and is not itself a catalog key — the plan documents this.)
2. **[critical] correctness — The "fourth group" for the 34 new strings exists only in the actualization**
   - Target: Actualization vs Tasks 3-5
   - Impact: No task authors the 34 new msgids (Custom SNI, Client Random, Routing profile fields, profile-aware verdicts); the produced catalog would miss keys the UI calls, failing AC1.
   - Recommendation: Add the fourth re-translation group to the task list with the new-string list.
   - Status: Open
   - Resolved: Task 6 added as the fourth re-translation group, authoring all 34 new profile/SNI/random msgids (full msgid list in the task body: 9 status.js strings incl. the shared `Mode`, 26 settings.js strings), with fidelity notes for the Routing profiles tab, the SNI/Client Random validators, the profile selector and the profile-aware status verdicts (incl. the two double-`%s` strings). Statistics gates re-based: Task 6 drives the catalog 177 → 211 translated, and the skeleton now contains all 34 new msgids, so AC1's coverage holds.
3. **[high] correctness — Duplicate `msgid "Mode"` (lines 37 and 607) breaks the msgfmt gate and is unaddressed**
   - Target: po/ru/trusttunnel.po; Task 1 Step 3; Task 2 Step 1; Task 6 Step 1
   - Impact: GNU msgfmt treats duplicate message definitions as fatal; the "baseline gate exit 0" predates the rebase and is false for the current file. The skeleton would inherit the duplicate.
   - Recommendation: Dedup (keep one "Mode" msgid) and define the disposition in the plan.
   - Status: Open
   - Resolved: Disposition defined in Contracts, Actualization and Task 1: keep the single `Mode` entry at the first position (line 37); the line-607 duplicate is dropped by Task 1's first-occurrence dedup, so the skeleton contains one `Mode` and the re-authored catalog is unique. The baseline gate is actualized: Task 1 Step 3 now expects `msgfmt -c` exit 1 with the fatal `duplicate message definition` (607 vs 38) on the current file and `--statistics` printing no count; the first green `msgfmt -c` is the skeleton (Task 2 Step 3), which exists only because the dedup removed the duplicate.
4. **[high] correctness — 4 stale msgids from the removed Exclusions tab remain**
   - Target: po/ru/trusttunnel.po; Task 1 Step 2
   - Impact: 'Do not bypass these', 'Exclusions', 'Everything goes through the tunnel; these entries always go out directly. …', 'Always sent out directly. Accepts a domain, …' have no view/menu consumer; the issue contract requires the msgid set to exactly match the views' keys.
   - Recommendation: Define whether the re-authored catalog drops them (recommended: yes).
   - Status: Open
   - Resolved: Disposition defined: the re-authored catalog drops all 4 stale msgids ('Do not bypass these', 'Exclusions', 'Everything goes through the tunnel; …', 'Always sent out directly. Accepts a domain, …'). Task 1's probe 1a filters them from `/tmp/tt13_msgids.txt`, so the skeleton never contains them; the final catalog's 211 msgids exactly match the views' 209 keys plus the 2 menu titles, and the "po msgids not in views" audit output is empty — satisfying the issue contract.
5. **[medium] correctness — Placeholder contract stale (11 msgids with %s/%d, not 5)**
   - Target: Contracts; Task 5 Step 3
   - Impact: Six new profile strings carry placeholders (two with a double %s); the plan's checks are wrong.
   - Recommendation: Update the placeholder inventory.
   - Status: Open
   - Resolved: Placeholder inventory updated to 11 msgids: the 5 legacy ones plus the 6 new profile strings (two with a double `%s`), listed in full in Contracts and split per task (Task 3 = 4, Task 5 = 1, Task 6 = 6). The generic token-order check in `/tmp/tt13_check.py` covers all 11 automatically, and each task's verification notes its placeholder count.
6. **[medium] maintainability — Authoring guidance describes the pre-rebase UI**
   - Target: Task 4 Step 2; Task 6 Step 3; shared-keys table
   - Impact: "four tabs (General/Server/Exclusions/Network)", "all 4 verdict states", and the shared-key table (missing the now-shared 'Mode') are stale; no fidelity notes for the new profile/SNI/random strings.
   - Recommendation: Actualize the guidance and checklist.
   - Status: Open
   - Resolved: Authoring guidance actualized: the settings page is described as one page with four tabs General / Server / Routing profiles / Network (no Exclusions tab); the shared-keys table now includes all 10 shared keys with ownership, including `Mode` (owned by Task 6); fidelity notes added for the new profile/SNI/random strings (profile semantics, Routing profile selector, Routing profiles tab validators, Custom SNI / Client Random formats and errors, profile-aware verdicts with `%s` tokens); the manual checklist covers the profile states (Mode row, bypass/VPN/legacy verdict variants, Routing profiles tab validator scenarios).
7. **[medium] operational — Final-gate expectations stale (msgfmt statistics ~216, diff-shape checks)**
   - Target: Task 1 Step 3; Tasks 4/5/6 statistics and diff checks
   - Impact: Baseline numbers were measured pre-rebase; Task 6's "zero changed msgid lines" conflicts with the 34-key addition.
   - Recommendation: Re-measure and re-word the gates.
   - Status: Open
   - Resolved: Final-gate expectations re-measured and re-worded: `msgfmt --statistics` is 211 translated messages (42 → 95 → 177 → 211 across Tasks 3–6); the baseline statistics step now records the fatal duplicate-`Mode` failure instead of a pre-rebase count; the diff-shape check (Task 7 Step 2) no longer claims "zero changed msgid lines" — it expects `+211 msgstr`, `-216 msgstr` and exactly 5 removed `msgid` lines (4 stale entries + the duplicate `Mode`), with all other msgid lines unchanged. The baseline gate itself is anchored to the real red state (Task 1 Step 3) and the first green state is the skeleton (Task 2 Step 3).

## Dismissed Findings

None.

## Notes

- Clean-room compliance verified (no inherited msgstr text in the plan). Header/plural-forms contract and the msgfmt tooling notes accurate.
- On re-review, this report is updated in place.

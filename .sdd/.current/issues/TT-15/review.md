# Plan Review Report: TT-15 — default UCI config

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-15/issue.md`
- **Plan**: `.sdd/.current/issues/TT-15/plan.md`
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

1. **[high] correctness — Actualization not propagated; Tasks 1-3 still encode the 4-section/17-option contract**
   - Target: Tasks 1-3, Entities table, File Structure
   - Impact: The actual file has 5 sections / 22 options / 36 lines (incl. custom_sni, client_random, routing_profile, the anonymous routing_profile section with name/mode). Task 1's key list misses them, Task 2 writes the stale 17-option text, `wc -l` expects 24, and Task 3's export/UI cross-checks use the old 16-scalar/20-field sets. Every verification step would fail against the real file.
   - Recommendation: Propagate the actualized option set into Task 1 key list, Task 2 output, Task 3 checks, Entities, File Structure.
   - Status: Open
   - Resolved: Tasks 1–3 now encode the actualized contract (5 sections / 22 options / 36 lines). Task 1's key list adds `custom_sni`, `client_random`, `routing_profile` and the `routing_profile` section (`name`, `mode`); Task 2 writes the full 22-option file (wc -l 31, reconciled against the current file's 36 lines); Task 3's export cross-check uses the 26-key set (incl. the resolved `routing_profile.name/mode/vpn_rules/bypass_rules`) and the UI list gains the 12 endpoint + 4 profile fields; Task 3 Step 5 counts five sections; Entities and File Structure tables actualized (routing_profile row added, 31-line target).
2. **[high] correctness — Internal contradictions (5/20 vs 22 options; "no mode" vs the contract; stale zero-discrepancy claim)**
   - Target: plan.md lines 19, 52-54, 134
   - Impact: The actualization's own count (20) forgets the profile's name+mode; Task 1 says the file has "no `mode`" while the contract and code add `option mode 'vpn'`; the Discrepancy check still claims "same 4 sections, 17 options, zero discrepancies".
   - Recommendation: Fix the counts and the contradiction.
   - Status: Open
   - Resolved: Actualization now says 5 sections / 22 options (the profile's `name` + `mode` included; "20 options" corrected). The "no `mode`" claim is removed — `option mode 'vpn'` is stated as present inside the anonymous `routing_profile` section, with the issue's "NO mode" clause read as the legacy flat option. The Discrepancy section is refreshed to 5 sections / 22 options in the same order/values, and the "zero discrepancies" claim now matches the actualized contract.
3. **[medium] correctness / clean-room — The comment block above `config routing_profile` is unaddressed**
   - Target: lines 48, 146-173, 192-200
   - Impact: The plan says "no comments", but the current file has a 5-line comment block; Task 3's normalization (sed) does not strip `#` lines, so the equivalence diff cannot be empty either way, and no decision is made (keep vs drop, with the clean-room transcription rule).
   - Recommendation: Decide explicitly (recommended: drop, since it is not in the contract; then the oracle diff must strip comment lines).
   - Status: Open
   - Resolved: Decision pinned in the plan (Format conventions + Task 2 Step 1): the re-created file carries NO comments — they are not part of the schema contract and cannot be transcribed clean-room, so the 5-line comment block above `config routing_profile` is deliberately dropped (old file 36 lines vs new file 31 lines, both counts stated in Task 2 Step 2). The normalization rule is pinned in Task 3 Step 1: the sed now strips `#` lines (`/^#/d`) from BOTH sides, so the equivalence diff compares 31 content lines vs 31 content lines and is empty.
4. **[low] maintainability — Makefile citation drift (conffiles at lines 64-66, not 55-57)**
   - Target: plan.md line 32
   - Impact: Cosmetic; substance verified correct.
   - Recommendation: Update the citation.
   - Status: Open
   - Resolved: Makefile citation updated in Technical Context from lines 55–57 to lines 64–66 (the `define Package/luci-app-trusttunnel/conffiles` block with `/etc/config/trusttunnel`).

## Dismissed Findings

None.

## Notes

- Consumer list, the awk extractor behavior, and the schema_keys parse-via-marker mechanics verified accurate. Pure data file; no security/performance/architecture concerns.
- On re-review, this report is updated in place.

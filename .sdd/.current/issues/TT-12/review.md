# Plan Review Report: TT-12 — diagnostics.js view

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-12/issue.md`
- **Plan**: `.sdd/.current/issues/TT-12/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 1 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 0 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[medium] correctness — Actualization's profile checklist item not carried into Task 8**
   - Target: plan.md Actualization vs Task 8 Step 3
   - Impact: The manual checklist lacks the profile-assigned/not-assigned diagnose cases and the 18-entry max check — the one behavior the actualization exists to pin is never verified.
   - Recommendation: Add the two profile states and the 18-count check to the checklist.
   - Status: Open
   - Resolved: Task 8 Step 3 now carries both profile states — new item 8 (profile assigned: extra ok "Routing profile" check with raw label/detail, check count at the 18-entry max, counts include the extra ok) and new item 9 (no profile: warn with raw "none — legacy full-tunnel mode" detail and raw hint, verdict/counts reflect the remark, list still at the 18-entry max); the Step 3 verification count was updated to 9 items.
2. **[low] correctness — Second raw-pass-through string omitted from the actualization's "nothing else changes"**
   - Target: Research §Discrepancies / Actualization
   - Impact: The backend also emits the unmapped hint 'The client is a dependency of the package; reinstall trusttunnel-client.' while the map's 'Run install.sh — the package does not ship the client binary.' is never emitted; both render raw today. Behavior-identical reproduction is already covered by the key-set rule, but the framing is one-directional.
   - Recommendation: Note both unmapped strings; keep the DIAG_TEXT map as-is.
   - Status: Open
   - Resolved: The Actualization section now names both unmapped backend strings — the "Routing profile" check strings AND the "The client is a dependency of the package; reinstall trusttunnel-client." hint — as raw pass-throughs with no new mappings, and states that the map entry "Run install.sh — the package does not ship the client binary." is never emitted by the current backend while the 48-entry DIAG_TEXT map and the 89-key set stay as-is; Task 8 Step 2's key-diff expectation now verifies exactly that set (stale entry retained, no keys added for either unmapped string), and checklist item 3 pins the raw rendering of the reinstall hint.

## Dismissed Findings

1. **[low] operational — git-history claim unverifiable in the read-only review**
   - Target: plan.md Actualization
   - Reason: invalid: corroborated independently (rebase delta shows diagnostics.js unchanged on main; the file matches the plan's 376-line inventory byte-for-byte and contains no profile handling). Not a defect.

## Notes

- The full inventory (89 unique keys, 48-entry DIAG_TEXT, group order, fail/warn-first split, tool flows, RPC envelopes incl. `results` and `avg === null`) verified accurate against the code; the raw-pass-through behavior of the new Routing profile check matches how dtr() works.
- On re-review, this report is updated in place.

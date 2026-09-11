# Plan Review Report: TT-10 — status.js view

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-10/issue.md`
- **Plan**: `.sdd/.current/issues/TT-10/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 5 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 2 |
| Architecture | pass | 1 |
| Operational | pass | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Profile-aware verdict branches absent from Task 3**
   - Target: Task 3 (Step 3/Step 4/Verification), Task 6 Step 1
   - Impact: Task 3 still specifies the pre-rebase 4-state verdict with the legacy success as state 4; the profile-aware success branches (bypass/vpn, checked before the legacy return) are missing, so the implemented view regresses behavior and the Task 7 key diff can never be empty.
   - Recommendation: Add the profile branches to Task 3 with the exact strings from the issue contract.
   - Resolved: Task 3 Step 3 now specifies the two profile-aware success branches — bypass (`routing_profile` + `routing_mode === 'bypass'` → "Tunnel works, profile %s — only the VPN rules go through %s" / "…through the tunnel", detail "Everything else stays direct.") and vpn profile ("Tunnel works, profile %s — everything except the bypass rules goes through %s" / "…through the tunnel", detail "The bypass rules are sent out directly.") — checked BEFORE the legacy return, with the exact issue-contract strings; Task 3 Step 4 and the Task 3 Verification assert the 18 verdict keys including the 6 profile strings and the branch order.
   - Status: Resolved
2. **[high] correctness — Mode row task stale**
   - Target: Task 4 (Step 1, Step 3)
   - Impact: Task 4 mandates the unconditional "Everything through VPN" row and omits the two profile strings; the implemented view loses the profile Mode variants.
   - Recommendation: Add the profile variants to Task 4.
   - Resolved: Task 4 Step 3 now implements the two profile Mode variants — "Profile %s — bypass, only the VPN rules are tunneled" when `st.routing_profile` and `routing_mode === 'bypass'`, "Profile %s — VPN, everything except the bypass rules is tunneled" for a vpn profile, else "Everything through VPN"; Task 4 Step 1's missing-key list, Step 4, and the Task 4 Verification (grep for `routing_profile` in `renderFacts`) all cover the two profile strings.
   - Status: Resolved
3. **[high] correctness — Key count wrong everywhere (51, not 43 or 54)**
   - Target: Actualization, Task 1, Task 3 Step 1, Task 6, Task 7 Step 2; issue.md
   - Impact: The actual view has 51 unique keys / 54 call sites; the delta from 43 is 8 (matching the 8 listed strings), but the plan asserts 43 at every checkpoint and the actualization says "~54 keys" (that is the call-site count).
   - Recommendation: Pin 51 unique keys everywhere.
   - Resolved: the plan pins 51 unique keys / 54 call sites everywhere — the actualization corrects the "~54 keys" wording (54 is the call-site count) and the "grew by 11" shorthand (8 extracted profile strings); Task 1 Step 4 baseline capture (51 keys, `.po` 51/51), Task 3 Step 1/Step 4 (18 verdict keys vs. baseline 51), Task 4 Step 1 (23 facts/versions keys), Task 5 Step 1 (8 button keys), Task 6 Step 1/Step 4 (50 → 51), and Task 7 Step 2 final diff (51, byte-identical, `.po` 51/51). issue.md's "11 new keys" phrase cannot be edited (file is contract, out of scope), but the extraction command is stated as the source of truth.
   - Status: Resolved
4. **[high] architecture — Contracts table not actualized (missing the 3 new status keys)**
   - Target: plan.md Contracts table (line 126), Task 3, Task 4
   - Impact: The frozen status response omits routing_profile/routing_mode/vpn_mode that both the verdict and Mode row depend on.
   - Recommendation: Update the Contracts table to the TT-09 14-key set.
   - Resolved: the Contracts table `status` row now lists the full TT-09 status response set — `enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses[], client_installed, routing_profile, routing_mode, vpn_mode` — with the View-usage column noting the profile keys drive the verdict branches and the Mode row; the Research RPC-shapes section (status shape) is aligned, and Task 3/Task 4 consume `routing_profile`/`routing_mode` exactly as declared.
   - Status: Resolved
5. **[medium] operational — Manual checklist lacks the profile states**
   - Target: Task 7 Step 3, Actualization
   - Impact: The checklist covers only the legacy states; the profile success variants cannot be verified on device, and AC "4 verdict states render exactly as today" is unverifiable as written.
   - Recommendation: Add bypass-profile, vpn-profile and no-profile success states to the checklist.
   - Resolved: Task 7 Step 3's manual checklist now covers the three success states on device — no-profile (legacy "All LAN traffic goes through %s", Mode "Everything through VPN"), bypass-profile (Mode "Profile %s — bypass, only the VPN rules are tunneled"; success head/detail strings diff-verified, since the success banner is intentionally empty), vpn-profile (Mode "Profile %s — VPN, everything except the bypass rules is tunneled") — plus a UCI setup note for driving `routing_profile`/`routing_mode`; items renumbered and the Task 7 Verification maps the ACs to checklist items 1–10.
   - Status: Resolved
6. **[medium] maintainability — Plan internally contradictory (actualization vs task bodies)**
   - Target: plan.md across Tasks 1, 3, 4, 6, 7
   - Impact: Tasks encode the pre-rebase 43-key/4-state spec; the TDD red/green loop cannot close under either reading.
   - Recommendation: Single alignment pass.
   - Resolved: one alignment pass across the whole plan — Actualization, Research (RPC shapes, verdict text specifics, key-list details), Contracts table, and Tasks 1–7 now agree on the profile-aware verdict (18 verdict keys, profile branches before the legacy return), the 51-key count at every checkpoint, and the full TT-09 status response; the TDD red/green loop closes at 51 keys under the actualized spec.
   - Status: Resolved

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 6 prior findings verified Resolved (profile verdict branches, Mode row variants, 51 unique keys everywhere, Contracts table, three profile checklist states, internal consistency).
- New on re-review (label-level, no implementation impact): the status response set is labeled "the full 14-key set" but the enumerated list contains 13 keys (off-by-one label, enumeration correct); the plan attributes an "11 new keys" shorthand to the issue contract while issue.md now says "8 new keys" (stale attribution; the plan's substance is correct).
- On re-review, this report is updated in place.

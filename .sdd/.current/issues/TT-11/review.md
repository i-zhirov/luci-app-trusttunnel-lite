# Plan Review Report: TT-11 — settings.js view

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-11/issue.md`
- **Plan**: `.sdd/.current/issues/TT-11/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 4 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | fail | 1 |
| Operational | fail | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[critical] correctness — Task bodies describe the pre-rebase file (Exclusions tab, 5-field import)**
   - Target: Tasks 2/3/4/5, Summary, Entities
   - Impact: The actual file has form.Section (NOT NamedSection) `routing_profile` with addremove/anonymous/sortable, no domains/Exclusions section, three new Server fields (custom_sni/client_random/routing_profile), a Routing tab with name/mode/vpn_rules/bypass_rules + shared validateRule, and a 12-call guarded import. Implementing the tasks verbatim produces the pre-rebase view.
   - Recommendation: Rewrite Tasks 2-5 (and Summary/Entities) around the actualized contract.
   - Status: Open
   - Resolved: Tasks 2-5 rewritten around the actualized view — Task 2 scaffold declares the `form.Section` `routing_profile` (addremove/anonymous/sortable) as the third tab; Task 3 implements the Server tab with the three new fields (`custom_sni`, `client_random`, `routing_profile` with the deleted-profile fallback); Task 4 implements the Routing tab (`name`/`mode`/`vpn_rules`/`bypass_rules` + shared `validateRule`) replacing the Exclusions tab (no `domains`, no `_('Exclusions')`, no `direct`); Task 5 implements the 12-call guarded import. Summary and Entities actualized to the four tabs and 27 option rows (26 fields + the `_import` button).
2. **[critical] correctness — The equivalence-oracle probe encodes the OLD file and fails on its own baseline**
   - Target: Task 1 Step 3 probe groups
   - Impact: The probe expects a domains NamedSection + `_('Exclusions')`, the old 11-option server group, a `direct` field, and only 5 guarded import sets — it is red against the rebased file and would certify a reimplementation missing all 7 new guarded sets as green.
   - Recommendation: Rewrite the probe from the actualized contract (incl. form.Section, validateRule `*:port`, name uniqueness, routing_profile population).
   - Status: Open
   - Resolved: Task 1 Step 3 probe rewritten from the actualized contract — the scaffold group asserts `form.Section 'routing_profile'` with addremove/anonymous/sortable and the ABSENCE of domains/`_('Exclusions')`/`direct`; the routing group pins `validateRule` (incl. `/^\*:[0-9]+$/` `*:port`, `*.` strip, loose `[0-9a-f:.\[\]/]+`, hostname regex) and the name-uniqueness scan (`secs[i]['.name'] !== section_id`); the server group pins `routing_profile` population from `data.trusttunnel['routing_profile']` + stored-value fallback; the import group pins all 12 guarded `uci.set` calls with their exact guard forms; keys group pinned to 79. Task 1 Step 3/4 prove it green (and able to fail) against the rebased file at c43e20a, and it stays the oracle through Task 5.
3. **[high] correctness — Key count hardcoded to 56 (actual: 77 unique)**
   - Target: Task 1 Step 2, Task 5 Step 3, Task 6 Step 4, Contracts key list
   - Impact: 4 old keys removed, 25 added; the plan's expected results are unreachable and the stale Contracts list would fail its own key-diff.
   - Recommendation: Pin 77 unique keys.
   - Status: Open
   - Resolved: The key count is pinned to the VERIFIED 79 unique keys (56 − 4 removed + 27 added, confirmed by extraction from c43e20a: 80 matches, 79 unique, all present in the .po) in Task 1 Step 2, Task 5 Step 3, Task 6 Step 4, and the Contracts key list, which now carries the full 79-key list. The Task 1 baseline extraction is the authority and the probe's keys group enforces line-for-line equality, so the expected results are reachable. Note: the review's 77 (56 − 4 + 25) under-counted by 2 — the old 56-key list was itself missing "debug and trace write a lot; leave them on only while investigating something."; the plan documents this correction in Risks.
4. **[high] architecture — Clean-room spec of record is pre-rebase**
   - Target: Entities, Contracts, Technical Context, File Structure
   - Impact: Entities still define the domains/Exclusions section and a 3-field-shorter endpoint table; Contracts freeze the 5-key import response instead of TT-09's 12-key set; the trail would certify a non-identical file as equivalent.
   - Recommendation: Actualize all spec-of-record sections from the issue/TT-09 contracts.
   - Status: Open
   - Resolved: Entities actualized — four sections in render order (main/endpoint/routing_profile/network), no domains/Exclusions section, endpoint table now 15 rows incl. `custom_sni`/`client_random`/`routing_profile`, new `routing_profile` section table with addremove/anonymous/sortable and 4 options; Contracts freeze TT-09's 12-key `import_config` response (`hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]`); Technical Context and File Structure describe the actual file (form.Section dependency, storage sections, 26 options).
5. **[high] operational — Manual checklist stale (tabs, import fields, validators, profile UI)**
   - Target: Task 6 Step 3/4
   - Impact: Items list General/Server/Exclusions/Network, verify only 5 import fields, test only direct/fwmark/table validators, and lack profile add/remove/sort and routing_profile assignment.
   - Recommendation: Rewrite the checklist per the actualized contract.
   - Status: Open
   - Resolved: Task 6 Step 3 checklist rewritten — item 1 verifies the four tabs incl. Routing (Routing profiles); item 3 verifies the profile add/remove/sort UI (anonymous addremove, name-required/duplicate-name rejections, drag-sort persisting to `uci show`); item 4 verifies `routing_profile` assignment incl. the deleted-profile fallback and "None — everything through the tunnel"; item 5 verifies the 12-field import (hostname/username/password/certificate/address/custom_sni/client_random/protocol/anti_dpi/has_ipv6/skip_verification/dns_upstream); item 7 tests the actualized validators (custom_sni, client_random, profile name, validateRule incl. `*:443`, fwmark, table).
6. **[medium] maintainability — Two mutually exclusive contract versions with no authority rule**
   - Target: plan.md whole
   - Impact: An implementer cannot reach the stated green state under either reading.
   - Recommendation: State the actualization/issue as authoritative and propagate.
   - Status: Open
   - Resolved: The Actualization section now opens with an explicit authority rule — "The actualized contract below — matching the file at c43e20a and the TT-09 issue — is the authority for this plan. Where any earlier draft conflicts, the actualized text wins and propagates into every section" — and every section (Summary, Technical Context, Entities, Contracts, File Structure, Tasks 1-6, Risks) was rewritten from that single contract version; no pre-rebase text remains.
7. **[low] correctness — Unguarded `data.trusttunnel.endpoint.routing_profile` access not pinned**
   - Target: Actualization bullet 2, probe server group
   - Impact: The population read can throw at render when the config lacks an endpoint section; the plan neither pins the crash nor a guard.
   - Recommendation: Pin the access pattern (guard or reproduce) in the probe.
   - Status: Open
   - Resolved: The unguarded `data.trusttunnel.endpoint.routing_profile` read is pinned in the probe's server group (asserts the exact unguarded expression is present, so the reimplementation reproduces it as-is per the PRD "fix nothing" rule), in the Actualization bullets, in the Entities `routing_profile` row, in Contracts ("Unguarded population read (pinned, reproduce as-is)"), in Task 3 Step 2, and flagged in Risks with the crash-at-render consequence when no `endpoint` section exists.

## Dismissed Findings

None.

## Notes

- The actualization bullets match the file exactly; both CI gate descriptions, the scratch-file naming, the ACL write list and the .po msgid coverage verified correct. No security findings.
- On re-review, this report is updated in place.

# Plan Review Report: TT-21 — README.md

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-21/issue.md`
- **Plan**: `.sdd/.current/issues/TT-21/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 9 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 1 |
| Architecture | pass | 1 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Task 3c dependency facts pre-rebase (no nftables, no immediate uci-defaults seed)**
   - Target: R1 'Dependencies' row; Task 3c Step 1/3
   - Impact: The current install.sh installs `kmod-tun ip-full nftables curl ca-bundle` and runs uci-defaults immediately; the task's grep (`kmod-tun|ip-full|curl|ca-bundle`) cannot catch a README omitting nftables.
   - Recommendation: Propagate both facts and extend the grep.
   - Status: Resolved
   - Resolved: Task 3c Step 1 now lists `kmod-tun ip-full nftables curl ca-bundle` and the immediate `/etc/uci-defaults/40-luci-trusttunnel` run (Default-profile seed, idempotent); Task 3c Step 3's grep set gains `nftables` in the deps pattern and a dedicated `uci-defaults/40-luci-trusttunnel` check; R1's dependency row carries both facts.
2. **[high] correctness — Task 3a omits the routing-profiles framing entirely**
   - Target: Task 3a Step 1
   - Impact: "Full-tunnel only — no domain lists" is the pre-rebase framing; the intro would miss the headline fact (named profiles, VPN/Bypass modes, rule types, assignment, legacy fallback).
   - Recommendation: Rewrite Task 3a around contract bullet 1.
   - Status: Resolved
   - Resolved: Task 3a Step 1 is rewritten around the routing-profiles framing — named profiles with vpn/bypass modes, rule entry types (domain, `*.domain`, IP, `IP:port`, CIDR), assignment via `endpoint.routing_profile`, client-side enforcement, legacy everything-through-tunnel fallback with `domains.direct`; the stale "full-tunnel only" framing is gone; Step 3's greps now cover `routing_profile`/`vpn_rules`/`bypass_rules` in the config defaults.
3. **[high] correctness — Task 3d UCI example pre-rebase (domains.direct instead of the profile block)**
   - Target: Task 3d Step 1/3
   - Impact: The mandated example omits custom_sni/client_random/dns_upstream and the bypass-mode routing_profile block; the verification grep does not cover the new option names.
   - Recommendation: Update the example and the grep.
   - Status: Resolved
   - Resolved: Task 3d Step 1 now mandates `custom_sni`, `client_random`, `dns_upstream` in the headless example plus the bypass-mode `routing_profile` block (`uci add`, `name`, `mode='bypass'`, `vpn_rules[]`, `endpoint.routing_profile`); Step 3's greps cover the new option names (`custom_sni|client_random|dns_upstream|routing_profile|vpn_rules|bypass_rules`) against the config defaults and the new README.
4. **[high] correctness — Task 3f comparison table pre-rebase**
   - Target: Task 3f Step 1
   - Impact: Old Mode row ("selective vs full only"), missing Split tunneling row, missing "Settings that were added" list, stale "do not bypass" row.
   - Recommendation: Actualize the table inventory.
   - Status: Resolved
   - Resolved: Task 3f Step 1's table inventory is actualized — Mode row = profile-driven routing (vpn/bypass, client-side), Split tunneling row added, the stale "do not bypass" exclusions row is removed, and the "Settings that were added" list (`endpoint.custom_sni`, `endpoint.client_random`, `endpoint.routing_profile`, `routing_profile` sections) is added alongside the removed-settings list; Step 3 verifies both lists against the config defaults (negative grep for removed, positive for added).
5. **[medium] correctness — Task 3e behaviour facts pre-rebase**
   - Target: Task 3e Step 1
   - Impact: No routing-profiles behaviour bullet, Status page fact omits the assigned profile, exclusions description covers only the unassigned fallback.
   - Recommendation: Actualize the behaviour facts.
   - Status: Resolved
   - Resolved: Task 3e Step 1 now carries a routing-profiles behaviour bullet (vpn/bypass semantics, SNI matching for domains, destination matching for IPs/CIDRs), the assigned-profile fact for the Status page, and the profile-based exclusions semantics (from `routing_profile.bypass_rules` in vpn mode, from `routing_profile.vpn_rules` in bypass mode, `domains.direct` as the unassigned fallback); Step 3 greps gen-config's three cases and the profile option names.
6. **[medium] correctness — R1 fact table stale/misattributed (UCI options, client.toml, uci-defaults rows)**
   - Target: Research R1
   - Impact: Omits custom_sni/client_random/routing_profile and the profile sections; client.toml row covers only the unassigned case; uci-defaults row omits the profile seed + migration.
   - Recommendation: Re-verify R1 against the rebased code.
   - Status: Resolved
   - Resolved: R1 rows are refreshed against the rebased code — the UCI-options row adds `endpoint.custom_sni`, `endpoint.client_random`, `endpoint.routing_profile` and `routing_profile.{name,mode,vpn_rules[],bypass_rules[]}` (with `domains.direct[]` as the legacy fallback); the client.toml row covers both `vpn_mode` cases (general from `bypass_rules`; selective from `vpn_rules`) plus the unassigned fallback; the uci-defaults row includes the Default-profile seed, the `domains.direct` → bypass-rules migration, and the `tt0 → tun+` zone migration; the dependency row adds `nftables` and the immediate uci-defaults run; all confirmed at commit c43e20a.
7. **[medium] architecture — Actualization not propagated (Task 1/2/4 skeleton and checklist)**
   - Target: Task 1/2/4 vs Actualization
   - Impact: Task 2's skeleton has no profile sections; Task 1's inventory enumeration and Task 4's fact checklist omit the new facts.
   - Recommendation: Propagate the profile facts into the skeleton and checklists.
   - Status: Resolved
   - Resolved: Task 1 Step 2's inventory now enumerates the routing-profile facts, the added options/settings, `nftables`, the immediate uci-defaults seed and the SHA-256 warning; Task 2's skeleton carries the profile facts into Configuration (Server/Routing/General tabs) and Behaviour (assigned profile) and matches the README's heading order; Task 4 Step 1's checklist explicitly maps the profile facts and the SHA-256 warning to README statements backed by code.
8. **[low] maintainability — Clean-room rule violated in the plan itself (inherited phrasing quoted)**
   - Target: Actualization/Summary vs Task 4
   - Impact: The actualization quotes the inherited tagline and tasks paraphrase README sentences, contradicting the plan's own no-phrasing rule (Task 4's sentence diff protects the deliverable).
   - Recommendation: Rephrase the quoted/paraphrased bits in the plan.
   - Status: Resolved
   - Resolved: The plan's own text no longer quotes or paraphrases inherited README phrasing — the Actualization re-expresses the framing in fresh words (no tagline quote), R3's assessments drop the quoted sentence bones, and task bodies use terse fact fragments (option names, values, paths) instead of README-shaped sentences.
9. **[low] architecture — Section-order rationale false**
   - Target: Summary; Task 2 Step 1
   - Impact: The claimed basis ("follows the issue's fact list") contradicts both the issue (behavior before install flows) and Task 2's own skeleton.
   - Recommendation: Fix the stated rationale.
   - Status: Resolved
   - Resolved: The Summary and R4 now state the true basis — the new section order mirrors the current README's heading order (1:1 section mapping so the Task 4 diff can be reviewed section by section) — and Task 2's skeleton is aligned to that order (Requirements, Installation, Configuration, Behaviour, Updating, Uninstalling, Differences, Notes and caveats, Acknowledgements), removing the contradiction with both the issue and the skeleton.
10. **[low] correctness — Manual-download SHA-256 warning fact not covered by any task**
    - Target: Task 3f
    - Impact: A functional fact the plan promises to carry is at risk of being dropped.
   - Recommendation: Add it to a fact list.
   - Status: Resolved
   - Resolved: The manual-download SHA-256 warning is now a fact in Task 3f Step 1's caveats list, named in Task 1 Step 2's inventory expectation, tracked in the R1 signing row, and verified by a `SHA-256` grep over the new README in Task 3f Step 3.
11. **[low] correctness — Issue Context stale (258 vs 296 lines)**
    - Target: issue.md Context
    - Impact: Informational; corroborates the incomplete propagation.
   - Recommendation: Update the line count.
   - Status: Resolved
   - Resolved: The plan's Actualization now uses the corrected count — the README at commit c43e20a is 296 lines — and explicitly states that issue.md itself is not modified by the plan.

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 11 prior findings verified Resolved (nftables + uci-defaults seed, routing-profiles framing, UCI example, comparison table, behaviour facts, R1 rows, propagation, clean-room phrasing, section-order rationale, SHA-256 warning, 296-line count).
- Two new findings from the re-review were FIXED in the plan by the primary agent: (1) the Status-page fact no longer cites status.js for the "client's tun device" clause (the view renders no device row — the device appears only in Diagnostics; the clause is reproduced as the current README's own wording); (2) Task 3d's option verification now checks the example's LIST options (address/dns_upstream/vpn_rules/bypass_rules) against uci-export/settings.js, since the 36-line defaults file carries no list lines.
- On re-review, this report is updated in place.

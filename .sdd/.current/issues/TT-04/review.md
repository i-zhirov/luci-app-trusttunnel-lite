# Plan Review Report: TT-04 — gen-config (client.toml generator)

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-04/issue.md`
- **Plan**: `.sdd/.current/issues/TT-04/plan.md`
- **Verdict**: Approved
- **Review attempt**: 2

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | pass | 4 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | pass | 2 |
| Architecture | pass | 0 |
| Operational | pass | 1 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Task 3's implementation contract is stale (pre-rebase)**
   - Target: plan.md Task 3 Step 1
   - Impact: Task 3 still specifies `vpn_mode` as fixed `"general"` with no profile resolution and omits `custom_sni`/`client_random` from the emission and read lists. Implementing it verbatim produces output missing the new fields and profile semantics — fails the byte-diff and AC1.
   - Recommendation: Rewrite Task 3 Step 1 around the profile resolution matrix (bypass → selective + vpn_rules; vpn → general + bypass_rules; stale/missing → legacy general + domains.direct) and the always-emitted custom_sni/client_random fields.
   - Status: Resolved
   - Resolved: Task 3 Step 1 rewritten — the fixed `vpn_mode = "general"` is removed; the spec now reads `endpoint.custom_sni`/`endpoint.client_random` (no default) and always emits them, TOML-escaped, between `password` and `skip_verification`, and resolves `vpn_mode`/`exclusions` from the profile-resolution matrix (bypass → selective + vpn_rules; vpn → general + bypass_rules; any other mode — empty/stale/unknown non-empty — → legacy general + domains.direct). Output byte-diff and AC1 are now satisfiable.
2. **[high] correctness — Golden case count contradictory (4 vs 6)**
   - Target: Task 1 Step 3/5, Task 4 Step 2, Summary
   - Impact: The actualization mandates 6 cases (three fixtures × with/without PEM); Task 1/4 still capture/diff only 4 (no bypass.tsv cases). AC2 is unsatisfiable as written.
   - Recommendation: Propagate the 6-case scheme into Task 1 and Task 4 (and the Summary).
   - Status: Resolved
   - Resolved: 6-case scheme propagated — Task 1 Steps 3–5 capture/checksum/sanity-diff six goldens (minimal/full/bypass × with/without PEM), Task 4 Step 2 byte-diffs all six, and the Summary, File Structure table, and verification lines all state 6 cases. AC2 is satisfiable as written.
3. **[high] correctness — Rewritten-test assertion list missing the profile matrix**
   - Target: Task 2 Step 1
   - Impact: The task does not cover bypass.tsv (`vpn_mode = "selective"`, `exclusions = ["telegram.org", "1.2.3.0/24"]`, bank.example absent), `legacy.example`-absent checks, custom_sni/client_random assertions, the full `vpn_mode = "general"` case, or the stale-reference fallback.
   - Recommendation: Match the extended tests/test_gen_config.sh assertion set (the actualization lists them).
   - Status: Resolved
   - Resolved: Task 2 Step 1's assertion list now covers the full matrix — minimal (legacy general, `custom_sni = ""`/`client_random = ""`, `exclusions = []`), full (vpn profile → general + bypass_rules exclusions, `legacy.example` absent, populated `custom_sni`/`client_random`), bypass.tsv (selective + vpn_rules exclusions, `bank.example` and `legacy.example` absent), the stale.tsv fallback (→ general + domains.direct), the PEM case, and the missing-credentials exit-1 case — matching the extended `tests/test_gen_config.sh` on main.
4. **[medium] maintainability — Actualization not propagated into the plan body**
   - Target: plan.md entire file (Summary, Technical Context, Tasks 1-4)
   - Impact: Summary still claims 4 golden cases; Technical Context still says "verified on both fixtures"; tasks contradict the actualization. A reader cannot tell which sections are authoritative.
   - Recommendation: Single alignment pass over Summary/Technical Context/Tasks with the actualization.
   - Status: Resolved
   - Resolved: Single alignment pass applied — Summary now states 6 golden cases (three fixtures × with/without PEM), Technical Context says "verified against the current implementation on all three fixtures", the Entities section mentions profile resolution and the always-emitted `custom_sni`/`client_random`, and Tasks 1–4 match the actualization; no contradictory sections remain.
5. **[low] correctness — Unknown profile mode divergence between issue contract and code**
   - Target: plan.md Actualization vs issue.md
   - Impact: issue.md says "vpn (or anything else non-empty) → general + bypass_rules"; the code falls through to the legacy branch for any mode other than bypass/vpn. No fixture pins it; the golden diff would not catch it.
   - Recommendation: Align the issue contract with the code's case-statement semantics.
   - Status: Resolved
   - Resolved: The plan now follows the code's `case` semantics — Research records it as discrepancy 3 (any mode other than exactly `bypass`/`vpn`, including unknown non-empty values, falls through to legacy general + domains.direct), Task 3 Step 1 pins the same "any other value → legacy" rule, and Task 2 Step 1 adds an unknown-mode fixture case (temp TSV with a matching profile whose mode is e.g. `smart` → general + domains.direct) so the golden/test diff would catch a divergence. The issue.md wording ("anything else non-empty") remains unreconciled and is reported for the caller to align.
6. **[low] operational — TOML spot-check covers only 3 of 6 golden outputs**
   - Target: Task 4 Step 3
   - Impact: full-pem and both bypass outputs are never parsed — AC3 only partially exercised.
   - Recommendation: Parse all six outputs.
   - Status: Resolved
   - Resolved: Task 4 Step 3 now parses all six golden outputs (minimal, minimal-pem, full, full-pem, bypass, bypass-pem) with `tomllib`; AC3 is fully exercised, including the full-pem and both bypass outputs that were previously skipped.

## Dismissed Findings

None.

## Notes

- Re-review (attempt 2): all 6 prior findings verified Resolved (profile-matrix Task 3, 6-case goldens, full test matrix, propagation, unknown-mode semantics — issue.md was also aligned to the code's case-statement behavior, the Resolved note's "remains unreconciled" is outdated in the good direction, TOML spot-check on all six outputs).
- New on re-review (informational): issue.md "How to verify" line ~96 still says "capture old output for both fixtures (+ one PEM case)" while AC2 and the plan mandate six cases — a contract-document leftover that does not affect the plan.
- On re-review, this report is updated in place.

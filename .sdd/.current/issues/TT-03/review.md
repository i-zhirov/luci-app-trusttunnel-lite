# Plan Review Report: TT-03 — uci-export

- **Reviewed**: 2026-09-09
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-03/issue.md`
- **Plan**: `.sdd/.current/issues/TT-03/plan.md`
- **Verdict**: Revised
- **Review attempt**: 1

## Per-Dimension Results

| Dimension | Result | Findings |
| --- | --- | --- |
| Correctness | fail | 4 |
| Security | pass | 0 |
| Performance | pass | 0 |
| Maintainability | fail | 1 |
| Architecture | pass | 0 |
| Operational | pass | 0 |

The plan is **Approved** only when all six dimensions pass.
Any `fail` makes the verdict **Rejected**.

## Consolidated Findings

1. **[high] correctness — Golden step demands `cmp full.tsv golden.tsv` which can never hold**
   - Target: Task 1 Step 5
   - Impact: full.tsv is records INPUT data (31 lines incl. 3 comment lines, different order); uci-export output is 26-key TSV without comments. Byte-equality is impossible; the plan's "fix the scaffolding" guidance misdiagnoses it.
   - Recommendation: The golden must be captured as the old script's raw output; the fixture is only a key-set/shape reference.
   - Status: Open
   - Resolved: Task 1 Step 4 now captures the golden as the OLD script's raw output per scratch config (golden-full/empty/stale/minimal.tsv) inside the container; Task 1 Step 5 validates the goldens against the fixtures ONLY as a key-set/shape reference (sorted key-set comparison, coverage checks) and explicitly forbids `cmp` of fixtures vs goldens; the only byte-for-byte `cmp` left is golden-vs-new in Task 3 Step 1. Research §4 documents why full.tsv (31 lines incl. 3 comment lines, network block before the profile block) is not byte-comparable, and the old "fix the scaffolding" misdiagnosis guidance is gone.
2. **[high] correctness — Golden capture misses the `uci` shim and the profile-resolution cases**
   - Target: Task 1 Step 3 / Research §3
   - Impact: The current script calls `uci -q get trusttunnel.endpoint.routing_profile` and `config_foreach find_profile routing_profile`; the alpine container has no `uci`, so the golden silently drops `endpoint.routing_profile` and the whole `routing_profile.*` block — the exact cases the actualization requires.
   - Recommendation: Add a `uci` stub to the scaffold and stale-name scratch configs to Task 1.
   - Status: Open
   - Resolved: Task 1 Step 3 now scaffolds BOTH a `functions.sh` stub (extended with `config_foreach` — four functions) AND a `bin/uci` shim on the container PATH answering `uci -q get trusttunnel.endpoint.routing_profile` (quiet, exit 1 when absent so `|| profile_want=""` is exercised). Task 1 Step 2 adds four scratch configs — full (assigned profile "Default"), empty-profile, stale-name ("Ghost" naming no section), minimal — and Task 1 Step 5 verifies each golden covers the right profile-resolution outcome (profile block present vs absent). Research §1/§3 document the resolution mechanics and shim semantics.
3. **[medium] correctness — Schema key count wrong twice over (26, not 25 or 19)**
   - Target: actualization + Task 2 Steps 1/3, issue.md "Total schema: 25 keys"
   - Impact: The real parse yields 26 keys (2 main + 11 endpoint scalars + address + dns_upstream + 4 marker-line profile keys + 6 network + domains.direct); the plan says "25" and "exactly 19, nothing else" — a direct instruction to drop 7 keys.
   - Recommendation: Pin 26 keys everywhere (including the issue contract).
   - Status: Open
   - Resolved: 26 keys (2 main + 11 endpoint scalars + address + dns_upstream + 4 marker profile keys + 6 network + domains.direct) are pinned in the plan's Actualization, Summary, Research §1/§2, Entities, Contracts, and Task 2 Steps 1/3; all "25" and "exactly 19" references removed. The issue.md "Total schema: 25 keys" typo is explicitly flagged for the caller in the plan (Actualization + Risks) without modifying issue.md; the untouched oracle's ≥15 sanity threshold and its 26-key parse (incl. its own stale "25 keys" comment) are documented in Research §2.
4. **[medium] correctness — SC1091-only suppression contradicts the current file**
   - Target: Task 3 Step 3 vs uci-export lines 58-59
   - Impact: The `config_foreach` callback pattern requires `# shellcheck disable=SC2317,SC2154`; the step expects SC1091 to be the only suppression — the pinned CI shellcheck invocation would fail.
   - Recommendation: Allow the SC2317/SC2154 disables for the callback pattern.
   - Status: Open
   - Resolved: Task 3 Step 3 now expects a clean pinned `koalaman/shellcheck:v0.11.0 -s sh` run with the file's three disable comments allowed — SC1091 (unresolvable `/lib/functions.sh` include) plus SC2317/SC2154 for the `config_foreach` callback pattern (`find_profile` invoked indirectly; `profile_want`/`profile_sec` assigned via `config_get`/callback). Task 2 Step 1 requires those disables in the source; Research §5 documents the CI invocation and the SC2317 history in ci.yml.
5. **[medium] maintainability — Actualization not propagated; stale pre-rebase text remains**
   - Target: Research §2/§4, Task 1 Steps 1-2, Task 3 Step 2
   - Impact: "19 keys", "endpoint (8 options)", "full.tsv 21 lines", "two domains.direct entries", "6 test files / 136 assertions" remain in the task bodies, contradicting the actualization.
   - Recommendation: Single pass aligning Research/Tasks with the actualized contract.
   - Status: Open
   - Resolved: One actualizing pass over Research §1-§5 and Tasks 1-4: 11 endpoint options, the 4-key resolved-profile block with the marker line, full.tsv described as 31 lines (28 data + 3 comment) with a single domains.direct entry, the `uci` shim + `config_foreach` in the scaffold, and baseline numbers no longer pre-pinned ("6 test files / 136 assertions" replaced by re-measuring and recording the live baseline in Task 1 Step 1 — the tree now has 7 test files); no 19-key/21-line/6-file/8-option stale text remains.

## Dismissed Findings

None.

## Notes

- The actualization's description of the profile-resolution export mechanics, the `# schema-keys:` marker and its parser branch, the source-shape coupling analysis, and the no-`set -u` requirement are all verified accurate.
- On re-review, this report is updated in place.

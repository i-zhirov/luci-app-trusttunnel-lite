# Issue Validation Report: uci-export

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash (default thinking)
- **Issue**: `.sdd/.current/issues/TT-03/issue.md`
- **Plan**: `.sdd/.current/issues/TT-03/plan.md`
- **Overall Status**: Revised
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 4 | 0 | 0 | 4 |
| Acceptance Criteria | 3 | 1 | 0 | 4 |
| Entities | 1 | 1 | 0 | 2 |
| Contracts | 0 | 1 | 0 | 1 |
| Guidelines | 0 | 0 | 0 | 0 (N/A — no AGENTS.md) |

## Task Status

- [x] **Task 1: Baseline capture — record the current state and freeze the golden output** - PASS
  - Golden hashes reproduced independently: I rebuilt the scratch harness from the plan's
    description (stub `functions.sh` + `bin/uci` shim, docker alpine, four scratch configs
    mirroring `full.tsv` values) and re-ran the pre-rewrite blob (`8ec241f` =
    blob `585b58c`). The recorded hashes match my reproductions byte-for-byte:
    `golden-full` `a0f634e2…` ✓, `golden-empty` `4507c045…` ✓, `golden-stale`
    `1b7fdb29…` ✓, with byte sizes 833/620/651 as recorded. (`golden-minimal` 144 B not
    hash-comparable: the plan does not record the exact `minimal.uci` values; my variant
    produced 136 B with correct real-UCI semantics. Old==new holds on it regardless.)
  - Suite baseline for the era (199 assertions, 7 files) is recorded in the plan's notes.
- [x] **Task 2: Implement the new uci-export from the contract** - PASS
  - File rewritten; schema parse yields exactly the 26 contract keys (verified by running
    `schema_keys()`' awk program standalone and via the test itself); `sh -n` clean;
    `grep 'set -u'` finds only the two header-comment mentions, no directive.
- [x] **Task 3: Golden byte-diff and all gates** - PASS
  - Old vs new byte-identical on all four plan configs (833/833, 620/620, 651/651,
    167/167 B, both rc=0) and on the missing-config parity case (both rc=0, empty output).
    `koalaman/shellcheck:v0.11.0 -s sh` clean (rc 0) with only the three allowed disables
    (SC1091 above `. /lib/functions.sh`; SC2317+SC2154 above `find_profile`). Index mode
    `100755` (`git ls-files -s`). One behavioral divergence found outside the captured
    cases — see Issues Found #1 (Task 3's own verification criteria were met).
- [x] **Task 4: Cleanup and final state** - PASS
  - No scratch/`*.old`/backup remains; `git status` shows no tracked changes from this
    issue (only pre-existing untracked `.sdd/`). Oracle tests and fixtures untouched
    (`git diff 8ec241f HEAD -- tests/test_init_apply.sh tests/test_init_reload.sh
    tests/fixtures/records/` empty). Live-router sanity not performed — documented and
    acceptable per plan (container golden diff is the equivalence proof).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Against the default `/etc/config/trusttunnel` values the output contains exactly the schema above, in order | MET | Reproduced `golden-full` byte-for-byte (hash `a0f634e2…` matches the plan's record): 26 keys in exact contract order, `routing_profile.*` block resolved by name, repeated list lines, password pass-through with quote/backslash/embedded TAB, no `endpoint.certificate`, no `network.lan_devices` (absent → skipped), no foreign keys |
| 2 | Golden byte-diff: old vs new produce identical output for the same UCI input | PARTIAL | Identical on all captured configs (full/empty/stale/minimal/missing) and 3/4 recorded golden hashes reproduce exactly; but a hand-edited config — `endpoint.routing_profile` empty/absent plus a `routing_profile` section with no `name` option — makes the NEW script emit `routing_profile.mode/vpn_rules/bypass_rules` while the OLD script emits nothing (see Issues Found #1) |
| 3 | The schema-completeness test in `tests/test_init_apply.sh` still passes | MET | `sh tests/test_init_apply.sh`: 29 assertions, 0 failed, incl. "schema parse of uci-export yielded 26 keys" and "every schema key is classified explicitly" |
| 4 | No `set -u`, executable bit set | MET | No `set -u` directive (only comment mentions); index mode `100755 c3ea8d4…` |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Records TSV (26-key schema) | OK — all 26 keys, fixed order, lists one line per value, empty scalars skipped, `0` values emitted, values pass through raw | OK — `config_load trusttunnel`, resolved profile via `uci -q get` + `config_foreach` | PARTIAL — profile resolution matches an empty `name` against an empty assignment (unnamed section), violating "nothing is exported when `endpoint.routing_profile` is empty" | PARTIAL |
| uci-export source shape (parser contract) | OK — `# schema-keys:` marker before loops; one-line `for o in …; do scalar …` for main; two-TAB continuation loops for endpoint/network; line-start `listopt`; profile loops scalar-free; disables in place; no `set -u` | OK — parse yields exactly the 26 keys, all explicitly classified | OK | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| Issue TT-03 contract section (exact schema + ordering + exclusions) | stdout TSV | PARTIAL | Schema/order/exclusions correct on all captured inputs; "Nothing is exported when `endpoint.routing_profile` is empty" violated in the unnamed-section edge case |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md | N/A | No AGENTS.md exists in the repo |

## Issues Found

1. **Spurious `routing_profile.*` records when the assignment is empty and an unnamed profile section exists**
   - Location: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export` lines 50–63
     (`find_profile` + unconditional `config_foreach find_profile routing_profile`).
   - Description: The old script guarded profile resolution with `if [ -n "$profile_want" ]; then
     config_foreach find_profile routing_profile; fi`. The new script runs `config_foreach` always,
     and `find_profile` matches `config_get _name "$_sec" name` (empty for a section without a
     `name` option) against `profile_want=""` — the comparison `[ "" = "" ]` succeeds, so
     `profile_sec` gets set and the block at lines 77–87 emits `routing_profile.mode`,
     `routing_profile.vpn_rules`, `routing_profile.bypass_rules`. Reproduced in a docker-alpine
     harness with a faithful `/lib/functions.sh` stub + `uci` shim: config with
     `option routing_profile ''` (or absent) + `config routing_profile` (no `name`) →
     old 137 B (no profile lines), new 243 B (+3 profile lines). This contradicts the issue's
     contract "Nothing is exported when `endpoint.routing_profile` is empty or names no existing
     section" and breaks old-vs-new byte identity on that input (PRD SC-003).
   - Impact: On a device whose config contains a `routing_profile` section without a `name`
     option (hand-edited config; the UI/uci-defaults always create named profiles), records gain
     profile lines with no profile assigned. `gen-config` ignores them (it requires
     `endpoint.routing_profile` non-empty and equal to `routing_profile.name`), but the records
     TSV violates the closed-schema semantics and `changed_keys` would classify edits of those
     lines as client restarts.
   - Recommendation: Restore the old guard — wrap the resolution in
     `if [ -n "$profile_want" ]; then config_foreach find_profile routing_profile; fi` (or make
     `find_profile` require a non-empty `_name` before matching). Add this case as a fifth golden
     config (`unnamed.uci`) to the scratch harness before re-running the byte-diff.
   - Resolved: (not yet — validation in progress)

## Recommendations

- Fix the profile-resolution edge case (Issue #1) and re-verify with the added golden case.
- Optional: re-run `sh tests/run.sh`, `sh -n`, and the pinned shellcheck after the fix; the
  schema-parse gate and the index mode are unaffected by the change.

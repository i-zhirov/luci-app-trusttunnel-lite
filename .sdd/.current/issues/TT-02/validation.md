# Issue Validation Report: TT-02 records.sh accessor library reimplementation

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-02/issue.md`
- **Plan**: `.sdd/.current/issues/TT-02/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 6 | 0 | 0 | 6 |
| Acceptance Criteria | 4 | 0 | 0 | 4 |
| Entities | 2 | 0 | 0 | 2 |
| Contracts | 1 | 0 | 0 | 1 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Baseline capture and oracle snapshot - PASS
  - Baseline (180 assertions, records 12) recorded in the plan and the commit
    message; oracle procedure verified by reproduction: the rewritten test
    passes 31/0 against the OLD inherited library (`git show 4c30fc1^:…/records.sh`
    run from a temp root outside the tree), and the old-vs-new accessor matrix
    is byte-identical (Task 5). No oracle artifacts remain in the tree
    (`git status` clean; no `*.old`, no temp files).
- [x] **Task 2**: Rewrite `tests/test_records.sh` from the contract - PASS
  - New text (messages/commentary re-expressed vs the inherited 12-assertion
    test); 31 assertions covering scalar/list fixtures, defaults, empty
    default, stored-0-beats-default, quote/backslash verbatim values with
    first-tab truncation, empty-first-value-as-absent, whole-field key match
    (prefix collision), and the guard (source-time OK, unset + empty
    `TT_RECORDS` error, non-zero exit only). Verified: `31 assertions, 0
    failed` against the OLD library (contract capture) and against the NEW
    library (31/0, exit 0).
- [x] **Task 3**: Write the new `records.sh` from the contract - PASS
  - `sh -n` silent; shellcheck `koalaman/shellcheck:v0.11.0 -s sh` clean
    (verified locally, same pinned version as CI). Guard
    `${TT_RECORDS:?TT_RECORDS is not set}` fires inside each accessor on
    unset OR empty variable; sourcing succeeds without it (verified: probe
    prints `source-ok`, accessor fails with message body `TT_RECORDS is not
    set`, non-zero exit). Semantics verified by test + golden diff:
    whole-field key match, first-occurrence `tt_get` (empty first value →
    default), verbatim values truncated at first tab, `tt_bool` true only for
    exactly `1` with default `0` (stored `0` beats default `1`), `tt_count`
    numeric `0` for absent. File mode `100644` in index and working tree
    (Makefile `chmod 0644` and the CI executable-bits list, which excludes
    `records.sh`, both consistent); no mode change in commit 4c30fc1; path
    preserved. Clean-room spot-check: function structure and comments differ
    from the inherited file (inline guard in the awk filename argument,
    awk-level `found`/`fallback` logic, `tt_key`/`-v key=` naming, entirely new
    header and per-function comments); only the contract-mandated message body
    `TT_RECORDS is not set` and standard awk idioms are shared.
- [x] **Task 4**: Prove the rewritten test against the NEW implementation - PASS
  - `sh tests/test_records.sh`: `31 assertions, 0 failed`, exit 0.
- [x] **Task 5**: Golden byte-diff of old vs new accessor outputs - PASS
  - Independently reproduced with the plan's 23-call matrix on both fixtures
    (old library from `4c30fc1^`, new library from the tree): `diff -u` exits
    0, transcripts byte-identical. Oracle/temp root deleted afterwards; tree
    clean.
- [x] **Task 6**: Full suite, CI gates, and clean-tree check - PASS
  - `sh tests/run.sh`: `== all tests passed`, exit 0; `test_records.sh` at 31
    (was 12), all other files green at their current counts (deps 26,
    gen_config 57, harness 5, init_apply 29, init_reload 21, routing 51,
    hotplug 29, uci_defaults 66 — gen_config/routing grew only via later
    issues, not TT-02). `sh -n` clean on both files; shellcheck clean;
    executable-bits CI list unchanged; `git status` clean at branch tip
    ad2b309 with no stray artifacts.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All four accessors behave identically on the fixtures (scalar vs list, defaults, `0` beats default, quote/backslash values) | MET | `tests/test_records.sh` 31/0 green; independent old-vs-new matrix byte-identical on `minimal.tsv` + `full.tsv`; edge cases (empty value, prefix collision) pass on both implementations |
| 2 | `tests/test_records.sh` rewritten from this contract (assertions kept as behavioral facts, text re-expressed) and passes | MET | Assertions preserved as behavioral facts in new wording (messages differ from the inherited 12-assertion file); 31/0 green against both libraries |
| 3 | Missing `TT_RECORDS` produces the same clear error as today | MET | Guard message body `TT_RECORDS is not set` asserted via `assert_contains` for unset and empty `TT_RECORDS`; exit asserted non-zero only (shell-dependent: 1 bash/zsh, 2 dash); sourcing without the variable succeeds |
| 4 | Callers (`uci-export`, `gen-config`, `routing`) keep working unchanged against the new library | MET | Commit 4c30fc1 touches only `records.sh`, `tests/test_records.sh` and issue/plan status marks — the three caller scripts are untouched; suite green through them (`test_gen_config.sh` 57, `test_routing.sh` 51, `test_init_apply.sh` 29, `test_init_reload.sh` 21) |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Records TSV (`/var/etc/trusttunnel/settings.tsv`) | OK — lines `section.option⇥value`, repeated keys for lists, values with quotes/backslashes, value ends at first tab (full.tsv password line with embedded tab verified) | OK — produced by `uci-export`, consumed by the four accessors feeding `gen-config`/`routing` | OK — whole-field key match, occurrence counting; verified by tests + golden diff | PASS |
| Accessor interface (`tt_list`/`tt_get`/`tt_bool`/`tt_count`) | OK — exact names, signatures, output formats | OK — all four used by callers via sourced library | OK — guard on unset/empty `TT_RECORDS` inside each accessor; first-occurrence, 0-beats-default, `true`/`false` rendering, numeric count | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| Accessor interface: `tt_list <key>`, `tt_get <key> [default]`, `tt_bool <key> [default]`, `tt_count <key>` | shell functions | PASS | Signatures and observable behavior match the issue contract and plan Research §1 exactly; no API endpoints exist for this issue |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| (no `AGENTS.md` in the repository) | N/A | No project guideline file exists; PRD-level clean-room requirement (new expression, no inherited text, no `*.old` artifacts) verified as compliant |

## Issues Found

None. The implementation fully satisfies the issue contract and plan.

Observations (non-blocking, no action required):

1. `tests/test_records.sh` is mode `100755`, matching every other `tests/test_*.sh` and the pre-change mode of the file; the issue's non-executable requirement applies only to `records.sh` (`100644`), which holds.
2. The plan's Task 6 baseline cites `test_gen_config.sh` 47 and `test_routing.sh` 40; today they report 57 and 51 — those grew in later issues (TT-03/TT-04 era) and were not touched by commit 4c30fc1, so this is not a TT-02 deviation.

## Recommendations

- None required. If re-validating later, re-run `sh tests/run.sh` and the guard/edge-case assertions in `tests/test_records.sh`; the golden-diff procedure can be reproduced from `git show 4c30fc1^:…/records.sh` since the oracle copy was correctly discarded.
- Per instruction, the issue and plan statuses were left untouched by this validation.

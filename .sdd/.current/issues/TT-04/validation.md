# Issue Validation Report: TT-04 — gen-config (client.toml generator)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-04/issue.md`
- **Plan**: `.sdd/.current/issues/TT-04/plan.md`
- **Overall Status**: Complete
- **Validation attempt**:
  1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 4 | 0 | 0 | 4 |
| Acceptance Criteria | 3 | 0 | 0 | 3 |
| Entities | 2 | 0 | 0 | 2 |
| Contracts | 0 | 0 | 0 | 0 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Capture golden outputs from the current implementation - PASS
  - The plan's scratch dir `/tmp/tt04-genconfig-goldens/` was deleted after the
    transition (as the plan's Task 4 Step 6 required), so its transient record
    is gone by design. The byte-equivalence oracle was independently
    re-derived: the pre-rewrite `gen-config` was recovered from git
    (`ad9e3e6^`), `records.sh`, `tests/fixtures/records/`, `tests/lib.sh` and
    `tests/run.sh` were confirmed byte-identical between the TT-04 commit and
    HEAD, and all six goldens (minimal/full/bypass × with/without PEM) were
    re-generated old-vs-new — 6/6 byte-identical (SHA-256 recorded for the new
    side).
- [x] **Task 2**: Rewrite `tests/test_gen_config.sh` - PASS
  - Rewritten in new text; follows the harness conventions (`lib.sh`,
    `TT_TEST_TMP`, `assert_eq`/`assert_contains`/`assert_exit`,
    `tt_test_summary` last, stdin never read). Runs green: **57 assertions,
    0 failed** (matches the issue's stated 57).
- [x] **Task 3**: Implement the new `gen-config` from the contract - PASS
  - Present at the same path, `#!/bin/sh` + `set -u`, `sh -n` silent, mode
    `100755` (git index `100755`, `stat` 755). Contract behaviors verified by
    reading and by execution (see Acceptance Criteria).
- [x] **Task 4**: Verify — tests, golden diff, lint, exec bit, suite, git
  state - PASS
  - `tests/test_gen_config.sh` green (57/0); six golden diffs empty; all six
    outputs parse with Python `tomllib`; `sh -n` silent on both files;
    `sh tests/run.sh` → `== all tests passed`; `git ls-files -s` shows
    `100755`; working tree clean, only the two intended files in commit
    `ad9e3e6`.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Rewritten test green: fixed fields present, invented keys absent, field mapping (incl. escaping of `pa"ss\with`, `custom_sni`/`client_random` emission), PEM literal emission, missing credentials → exit 1; profile mode matrix (bypass → selective + vpn_rules; vpn → general + bypass_rules; legacy ignored while assigned); stale reference → general + domains.direct | MET | `tests/test_gen_config.sh` — 57 assertions, 0 failed; covers every listed case incl. the unknown-mode fixture (`smart` → legacy general + domains.direct) and `assert_exit 1` with stderr `gen-config: endpoint.hostname is not set` |
| 2 | Golden byte-diff: old vs new `gen-config` produce identical `client.toml` for all three fixtures, with and without a PEM file | MET | Independently reproduced: old binary recovered from git `ad9e3e6^` (fixtures/records.sh/harness identical to HEAD) vs current — all six cases `diff`-empty: minimal OK, minimal-pem OK, full OK, full-pem OK, bypass OK, bypass-pem OK |
| 3 | The output parses as valid TOML | MET | Python 3 `tomllib` parses all six new outputs; parsed values confirm semantics (minimal/full: `vpn_mode general`, exclusions `[]`/`['bank.example', '*.local.example']`; bypass: `selective`, `['telegram.org', '1.2.3.0/24']`) |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| `gen-config` (shell script) | OK — usage `gen-config <records-file> [pem-file]`, `TT_LIBDIR` default to script dir, sources `records.sh` before `TT_RECORDS` | OK — consumes the TT-02 `tt_get`/`tt_list`/`tt_bool`/`tt_count` interface, unchanged since TT-04 | OK — exit 1 + `gen-config: <key> is not set` for the four mandatory checks in order; mode 100755 | PASS |
| Generated `client.toml` | OK — exact key set/order (top-level + `exclusions`, `[endpoint]`, `[listener.tun]`), two blank separator lines, single trailing newline; booleans lowercase, `mtu_size` bare, `certificate = ""` fallback | OK — consumed by the client binary; `[listener.tun]` schema per `setup_wizard` reference (no `device_name`/`use_existing`, empty route lists) | OK — 6/6 byte-identical to the old output; all six parse as TOML | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| n/a | n/a | PASS | No API endpoints involved (out-of-scope per plan §Contracts) |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| n/a | N/A | No `AGENTS.md` in the repository |

## Issues Found

No blocking issues found. Observations:

1. **Transient golden record is not directly inspectable**
   - Location: `/tmp/tt04-genconfig-goldens/` (plan Task 1/Task 4 evidence)
   - Description: The plan's own scratch directory and its `checksums.sha256`
     were deleted after the transition, as Task 4 Step 6 explicitly required,
     so the plan's written record ("six OK", "all six parse") cannot be
     re-inspected from that directory.
   - Impact: None — the acceptance criterion was re-verified end-to-end from
     git history (old binary at `ad9e3e6^`, identical fixtures/harness):
     6/6 byte-identical and 6/6 `tomllib`-parseable, with SHA-256 recorded.
   - Recommendation: None required. For future issues, keeping the transient
     evidence until after validation would make the plan's record auditable,
     but deleting it is per-plan and the git history preserves the oracle.

2. **Shellcheck not run locally**
   - Location: `gen-config`, `tests/test_gen_config.sh`
   - Description: `shellcheck` is not installed in this environment; the plan
     anticipates this and falls back to `sh -n` (silent on both files). The
     CI workflow runs the real gate (`koalaman/shellcheck:v0.11.0 -s sh
     --severity=error` in `.github/workflows/ci.yml`).
   - Impact: Low — syntax is verified; expression-level lint remains a CI
     gate.
   - Recommendation: Confirm green on the next CI run; nothing to fix
     pre-emptively.

3. **Transient untracked file observed during validation (environment noise,
   not part of the issue)**
   - Location: `tests/test_zz_scratch.sh` (untracked)
   - Description: A scratch probe file (`set -u; echo "marker:
     zz-scratch-failure"; exit 1`) appeared in the working tree mid-validation
     and vanished before re-check; it was never committed (clean tree, commit
     `ad9e3e6` touches only the two intended files) and both full-suite runs
     printed `== all tests passed`.
   - Impact: None on TT-04.
   - Recommendation: None; concurrent-session noise in the shared worktree.
     Note that `tests/run.sh` globs `tests/test_*.sh`, so any such probe left
     in place would fail the suite — worth remembering for other sessions.

## Recommendations

- Run the CI shellcheck gate (`docker run ... koalaman/shellcheck:v0.11.0
  -s sh --severity=error`) once to close the local lint gap; `sh -n` is
  clean on both files.
- Clean-room spot-check passed: the emission code is structurally new
  expression (per-line `printf` vs the inherited single heredoc template;
  inline `tt_get` fetch vs pre-fetched variables; streaming awk
  `BEGIN/END` array builder vs collected-items awk; inline certificate
  branch with hex-escaped `\x27` delimiters vs the inherited
  `emit_certificate()` function; `tt_`-prefixed naming, new comments). The
  literal TOML key/value text is identical because it is the byte-level
  external contract, not copied expression.

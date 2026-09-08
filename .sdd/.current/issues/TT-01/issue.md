# Issue TT-01: Test harness and record fixtures

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: none
- **Effort**: S
- **Files**: `tests/run.sh`, `tests/lib.sh`, `tests/test_harness.sh`,
  `tests/fixtures/records/minimal.tsv`, `tests/fixtures/records/full.tsv`

## Context

The shared test infrastructure was inherited from the upstream project and
modified in place (4/4 and 2/2 line diffs — text still derived). The records
fixtures were inherited too (0/2 and 0/11 — only list-related records
deleted). Every other test issue depends on this harness, so it is
reimplemented first. The harness's behavior is the contract every test uses.

## Contract to reproduce

- `tests/run.sh`: for each `tests/test_*.sh`, run it in its own
  `mktemp -d` directory exported as `TT_TEST_TMP`, stdin closed
  (`< /dev/null`); the suite fails (exit non-zero) if any test exits
  non-zero.
- `tests/lib.sh` (sourced by tests): assertion counters stored in files
  under `$TT_TEST_TMP` (`total`, `failed`); functions `assert_eq <expected>
  <actual> <message>`, `assert_contains <haystack> <needle> <message>`,
  `assert_exit <expected-code> <message> <command...>` (note: message comes
  BEFORE the command — the order the existing callers use); `tt_test_summary`
  prints "N assertions, M failed" and exits 1 when anything failed.
- `tests/test_harness.sh`: self-test of the harness — a positive assertion
  that passes and a negative one that fails, both wired to make the
  self-test exit 0 only when the harness behaves.
- Fixtures (data, functional facts):
  - `fixtures/records/minimal.tsv` — 6 records incl. scalar and list keys.
  - `fixtures/records/full.tsv` — 31 records incl. repeated list keys, a
    password value with quotes/backslashes and tab-like content, and the
    routing-profile records (`endpoint.routing_profile` Default,
    `routing_profile.name/mode/vpn_rules/bypass_rules`, plus a differing
    legacy `domains.direct` value on purpose).
  - `fixtures/records/bypass.tsv` — 14 records: a bypass-mode profile
    (`routing_profile.mode bypass`, vpn_rules, bypass_rules) with a legacy
    `domains.direct` that must NOT become exclusions.
  - Exact key/value content is dictated by what the unit tests assert; keep
    the same keys as today so the rewritten tests can assert the same
    semantics.

Note (rebase on main 2026-09-09): `tests/test_deps.sh` was ADDED on main —
it is original fork work (guards the Makefiles' dependency declarations and
install.sh parity) and is NOT rewritten here; `tests/run.sh` picks it up
automatically. The harness contract above is unchanged by it.

## Acceptance criteria

- [ ] `tests/run.sh` executes every `test_*.sh` in an isolated temp dir and
      reports per-test failures.
- [ ] `assert_eq` / `assert_contains` / `assert_exit` / `tt_test_summary`
      behave as today (positive and negative cases).
- [ ] `tests/test_harness.sh` passes (proves the harness itself).
- [ ] Fixture files contain the same records data as today (verify by
      running the current unit tests against them — they must pass when the
      test files still exist).
- [ ] No text from the inherited test files is copied verbatim; the new
      files are written from this contract.

## How to verify

1. `sh tests/run.sh` — all tests green (existing tests still pass against
   the new harness before their own rewrites land).
2. Run `tests/test_harness.sh` alone: exits 0.
3. Introduce a deliberate failure in a scratch test file and confirm
   `tests/run.sh` exits non-zero and reports it.
4. `git diff` the old vs new harness files and confirm the text is new
   expression (the contract is behavioral, not textual).

## Dependencies for later issues

- TT-02 (records.sh + test_records.sh) — needs the harness
- TT-04 (gen-config + test_gen_config.sh) — needs the harness + fixtures
- TT-05 (routing + test_routing.sh) — needs the harness + fixtures

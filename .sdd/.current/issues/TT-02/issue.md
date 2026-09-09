# Issue TT-02: records.sh accessor library

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: TT-01
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh`,
  `tests/test_records.sh`

## Context

`records.sh` is a sourced shell library from the upstream project; the fork
translated the comments (RU→EN) but left the accessor bodies in place — the
awk parsing and function structure are inherited expression. It is the
foundation for `uci-export`, `gen-config`, `routing`, the init script, and
the ucode backend's `records()` helper, so it must be re-expressed first and
its behavior pinned by the rewritten unit test.

## Contract to reproduce

- Sourced via `. "$TT_LIBDIR/records.sh"`; requires the environment
  variable `TT_RECORDS` pointing at the TSV file; the
  `${TT_RECORDS:?...}` guard fires inside each function (not at source
  time — callers source the file before assigning the variable).
- File format: lines `section.option<TAB>value`; the same key may repeat
  (list values); values may contain quotes and backslashes but not tabs.
- Functions (names are the interface used by all callers):
  - `tt_list <key>` — prints every value for the key, one per line.
  - `tt_get <key> [default]` — prints the first value, or the default.
  - `tt_bool <key> [default]` — prints `true`/`false`; a stored value of
    `1` maps to `true`, everything else (incl. `0`) to `false`, unless a
    default is given and the key is absent.
  - `tt_count <key>` — prints the number of occurrences.
- Implementation notes for the rewrite: the current implementation parses
  with a single awk pass per call; the new implementation may use any
  approach as long as the observable behavior (incl. quoting edge cases)
  is identical. `set -u` is fine here.

## Acceptance criteria

- [ ] All four accessors behave identically on the fixtures (scalar vs
      list, defaults, `0` beats default, quote/backslash values).
- [ ] `tests/test_records.sh` is rewritten from this contract (assertions
      kept as behavioral facts, text re-expressed) and passes.
- [ ] Missing `TT_RECORDS` produces the same clear error as today.
- [ ] Callers (`uci-export`, `gen-config`, `routing`) keep working
      unchanged against the new library.

## How to verify

1. `sh tests/run.sh` — `test_records.sh` green.
2. `test_init_apply.sh`/`test_init_reload.sh` (fork-written oracles) still
   pass — they source the init script which sources this library.
3. Golden check: `TT_RECORDS=tests/fixtures/records/full.tsv` and run the
   accessor calls from the old and new libraries — outputs identical.

## Notes

- Do NOT open the inherited file while writing the replacement; work from
  this contract and the fixtures.
- The `${TT_RECORDS:?}` guard's exit code is shell-dependent (1 on
  macOS bash, 2 on dash/busybox ash) — tests must assert non-zero only.
- The file must stay non-executable (`100644`): the Makefile's
  `Build/Compile` chmod set and the CI executable-bits check expect it
  sourced, not executed.
- The init script does NOT source this library directly; it reaches it
  through `gen-config`/`routing` subprocesses.
- The ucode backend's own `records()` parser (TT-09) is a separate
  expression and not covered by this issue.

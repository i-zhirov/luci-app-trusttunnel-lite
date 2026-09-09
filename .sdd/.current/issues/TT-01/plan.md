# Implementation Plan: TT-01 — Test harness and record fixtures

- **Created**: 2026-09-08
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-01/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation — no text copied from the inherited files; identical behavior; fixtures carry the same data"

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (now at `c43e20a`), which
added the routing-profiles feature. Impact on this plan:

- **New fixture `tests/fixtures/records/bypass.tsv`** (14 records,
  bypass-mode profile) and **extended `tests/fixtures/records/full.tsv`**
  (31 records: 21 legacy records incl. `endpoint.custom_sni`,
  `endpoint.client_random`, plus 3 comment lines and 7 routing-profile
  records with a differing legacy `domains.direct` on purpose). Task 5
  (fixtures) must re-create THREE fixtures with these exact data sets —
  the tab-byte and key-count checks apply to all three. (The issue's
  `Files` header predates the rebase and lists only `minimal.tsv` /
  `full.tsv`, but the issue's contract section and the current tree both
  include `bypass.tsv`; this plan rewrites all three.)
- **New original test `tests/test_deps.sh`** added on main — it is fork
  work (dependency-declaration guards), NOT part of this issue's rewrite;
  `tests/run.sh` picks it up automatically. The baseline task must
  record the CURRENT suite including `test_deps.sh` (7 test files now).
- Harness contract (`run.sh`/`lib.sh`/`test_harness.sh`) is unchanged.
- The rewritten fixture data must satisfy the existing
  `test_records.sh` assertions (`test_records.sh` is untouched by this
  issue and stays the equivalence oracle), and the fixture-data checks
  in the other tasks must be validated against the actualized
  `full.tsv` / `bypass.tsv` content (the password line and its tab
  handling are unchanged).

## Summary

Re-express the three inherited harness files (`tests/run.sh`,
`tests/lib.sh`, `tests/test_harness.sh`) and the three inherited record
fixtures (`tests/fixtures/records/minimal.tsv`, `full.tsv`,
`bypass.tsv`) as new expression written from the behavioral contract in
the issue, without changing any externally visible behavior. The six
untouched `tests/test_*.sh` files (`test_deps.sh`,
`test_gen_config.sh`, `test_init_apply.sh`, `test_init_reload.sh`,
`test_records.sh`, `test_routing.sh`) are NOT touched in this issue and
are the equivalence oracle: they must keep passing unchanged against
the new harness. Work is ordered so the current behavior is captured as
a baseline first, each file is then rewritten against a behavioral
probe written before the implementation (probe → implement → verify →
negative control), the fixtures are re-created from the data contract,
and a final verification pass proves the whole suite plus the failure
paths behave identically to the baseline.

## Technical Context

- **Language/Version**: POSIX shell (`sh`), no bashisms. Runs on macOS
  `/bin/sh` (bash 3.2 in POSIX mode) in dev and busybox ash on OpenWrt —
  the CI gate runs the suite via `sh tests/run.sh` (`.github/workflows/ci.yml`).
- **Primary Dependencies**: none. Only core POSIX utilities: `mktemp -d`,
  `cat`, `echo`/`printf`, `rm -rf`, `sh`, `dirname`.
- **Storage**: assertion counters are plain files (`total`, `failed`) under
  `$TT_TEST_TMP`. This is a functional requirement: counters must remain
  visible to the parent shell when an assertion runs inside a subshell or
  command substitution (the harness self-test and several tests rely on it).
- **Testing**: the harness is the test framework — `tests/run.sh` runs every
  `tests/test_*.sh`; `tests/lib.sh` provides `assert_eq` / `assert_contains` /
  `assert_exit` / `tt_test_summary`; `tests/test_harness.sh` self-tests the
  harness. No external framework.
- **Target Platform**: developer machine (macOS) + OpenWrt CI (busybox ash);
  everything must be POSIX-portable and `set -u`-safe.

## Research

### Current harness behavior (observed by running the current suite)

Baseline captured on 2026-09-09 at `c43e20a`: `sh tests/run.sh` exits **0**
with the banner `== all tests passed`; 7 tests, 180 assertions total, all
green:

| Test file | Assertions |
| --- | --- |
| `tests/test_deps.sh` | 26 |
| `tests/test_gen_config.sh` | 47 |
| `tests/test_harness.sh` | 5 |
| `tests/test_init_apply.sh` | 29 |
| `tests/test_init_reload.sh` | 21 |
| `tests/test_records.sh` | 12 |
| `tests/test_routing.sh` | 40 |

(These per-file counts are the real numbers from running the current
suite at `c43e20a`; they are the pinned baseline for Tasks 1 and 6.)

Behavioral facts the rewrite must preserve (each is part of the observable
contract):

- **`tests/run.sh`**: `cd`s to the repo root; `set -u`; iterates the glob
  `tests/test_*.sh` in shell glob order; prints `== <test-path>` before each
  test; for each test creates a fresh directory with `mktemp -d`, exports it
  as `TT_TEST_TMP`, runs `sh <test> < /dev/null` (stdin closed), then removes
  the temp directory; a non-zero test exit sets the suite exit code to 1 but
  the loop continues (all tests still run); final banner is
  `== all tests passed` (exit 0) or `== FAILURES` (exit 1).
- **`tests/lib.sh`** (sourced as `. "$(dirname "$0")/lib.sh"`): if
  `TT_TEST_TMP` is unset, creates its own fresh dir via `mktemp -d` and
  exports it (this is the standalone-test path — `sh tests/test_records.sh`
  works without the runner); initializes counter files `total` and `failed`
  to `0` only if they do not already exist (re-sourcing must not reset);
  counters are incremented by writing the file back (`$(( $(cat file) + 1 ))`
  style) so subshell increments survive.
  - `assert_eq <expected> <actual> <message>`: on match prints an ok line for
    the message; on mismatch prints a FAIL line for the message plus detail
    lines showing expected and actual values.
  - `assert_contains <haystack> <needle> <message>`: substring match (glob
    `*needle*` semantics); on mismatch prints a FAIL line plus detail lines
    showing the missing needle and the haystack.
  - `assert_exit <expected> <message> <command...>`: runs the command with
    stdout/stderr discarded, compares its exit status; on mismatch prints a
    FAIL line plus a detail line showing expected vs actual exit status.
    **NOTE — signature discrepancy in the issue**: the issue contract lists
    `assert_exit <code> <command...> <message>`, but every current caller
    (`test_records.sh`, `test_gen_config.sh`, `test_routing.sh`,
    `test_init_apply.sh`) uses `<expected> <message> <command...>`, and the
    acceptance criteria say "behave as today". This plan pins the ACTUAL
    signature `<expected> <message> <command...>`; the existing callers must
    keep working unchanged.
  - Every ok/FAIL output line goes to stdout (the runner passes it through).
  - `tt_test_summary`: prints `  <total> assertions, <failed> failed`
    (two-space indent) and exits 0 only when `failed` is 0, non-zero
    otherwise — this is how a test's failure propagates to the runner.
- **`tests/test_harness.sh`**: sources `lib.sh`; runs four positive
  assertions (equal strings, substring, exit 0 on success, exit 1 on
  failure); then a negative check: runs an intentionally failing assertion
  inside a subshell with output discarded, verifies the `failed` counter is
  exactly 1 (proving failures are recorded), prints an ok line, and resets
  the counter to 0; ends with `tt_test_summary`. Passing run: exactly
  **5 assertions, 0 failed** and exit 0. NOTE: when a positive assertion is
  sabotaged to fail, the `failed` counter is 2 at the negative check, the
  guard's `else` branch prints `FAIL: assert_eq did not record a failure`
  and exits 1 — `tt_test_summary` never runs in that path.
- **Standalone behavior**: each test can run alone (`sh tests/test_harness.sh`
  etc.) because `lib.sh` creates `TT_TEST_TMP` when unset.

### Fixture data facts (the data contract — data, not expression)

- `tests/fixtures/records/minimal.tsv` — exactly **6 lines**, keys present:
  `main.enabled`, `endpoint.hostname`, `endpoint.address` (list key, single
  value), `endpoint.username`, `endpoint.password`, `network.mtu`.
- `tests/fixtures/records/full.tsv` — exactly **31 lines**: 21 legacy
  records (incl. repeated list keys `endpoint.address` ×2,
  `endpoint.dns_upstream` ×2, `endpoint.custom_sni`,
  `endpoint.client_random`, and a password value containing a quote and a
  backslash followed by tab-separated trailing content — the "value stops at
  the first tab" semantics asserted by `test_records.sh`), 3 comment lines
  (start with `#`, contain no tab), and 7 routing-profile records
  (`endpoint.routing_profile Default`,
  `routing_profile.name/mode/vpn_rules/bypass_rules` ×2, and a SINGLE
  `domains.direct legacy.example` that differs from the legacy direct list
  on purpose — it must NOT become an exclusion while a profile is assigned).
- `tests/fixtures/records/bypass.tsv` — exactly **14 lines**: 5 records
  (incl. `endpoint.routing_profile Games`), 2 comment lines (no tab), and
  7 bypass-profile records (`routing_profile.name Games`,
  `routing_profile.mode bypass`, `routing_profile.vpn_rules` ×2,
  `routing_profile.bypass_rules bank.example`, and a legacy
  `domains.direct legacy.example` that must NOT become exclusions).
- Line format: `section.option<TAB>value`. Values may contain
  quotes/backslashes but the parsed value never contains a tab (parsing
  stops at the first tab; trailing tab-and-content is inert data). Comment
  lines carry no tab at all.
- The exact rows are dictated by what the existing unit tests assert:
  `test_records.sh` reads `minimal.tsv` + `full.tsv`; `test_gen_config.sh`
  reads `minimal.tsv` + `full.tsv` + `bypass.tsv`. See Entities for the full
  row table. The implementer writes the rows from this data contract, not by
  transforming the old file.

### Clean-room constraints

- Do not transform the inherited text: write each file from the contract
  above with new expression. The plan's probes are new test text written
  behaviorally.
- Fixture rows are functional data (identical rows required by the issue);
  the data table in this plan is the source of truth.
- Keep the same file paths and the same sourcing pattern
  (`. "$(dirname "$0")/lib.sh"`) so the untouched test files keep working.
- Per PRD: no `*.old` backups left behind; end with a `git status` check.

## Entities

### TSV record (`section.option<TAB>value`)

- **Fields**: key `section.option` (string), value (string; may contain
  quotes/backslashes, never a tab in the parsed value; trailing
  tab-and-content beyond the first tab is inert data).
- **Relationships**: repeated key = list value (e.g. `endpoint.address`);
  consumed by `records.sh` accessors and `gen-config` (later issues).
- **Validation**: tab separates key from value; parser stops at first tab.

### Fixture: `minimal.tsv` (6 rows — must reproduce exactly)

| key | value |
| --- | --- |
| `main.enabled` | `1` |
| `endpoint.hostname` | `vpn.example.com` |
| `endpoint.address` | `1.2.3.4:443` |
| `endpoint.username` | `alice` |
| `endpoint.password` | `s3cret` |
| `network.mtu` | `1350` |

### Fixture: `full.tsv` (31 rows — must reproduce exactly)

| key | value |
| --- | --- |
| `main.enabled` | `1` |
| `main.log_level` | `debug` |
| `endpoint.hostname` | `vpn.example.com` |
| `endpoint.address` | `1.2.3.4:443` |
| `endpoint.address` | `[2001:db8::1]:443` |
| `endpoint.username` | `alice` |
| `endpoint.password` | `pa"ss\with` + `<TAB>` + `specials` (literal tab after the backslash value) |
| `endpoint.protocol` | `http3` |
| `endpoint.anti_dpi` | `1` |
| `endpoint.post_quantum` | `0` |
| `endpoint.skip_verification` | `1` |
| `endpoint.has_ipv6` | `0` |
| `endpoint.custom_sni` | `vpn.example.com` |
| `endpoint.client_random` | `0a0b0c/0f0f0f` |
| `endpoint.dns_upstream` | `tls://1.1.1.1` |
| `endpoint.dns_upstream` | `quic://dns.adguard.com:8853` |
| `network.mtu` | `1400` |
| `network.table` | `880` |
| `network.fwmark` | `0x9527` |
| `network.blackhole_on_down` | `1` |
| `network.include_router_traffic` | `1` |
| (comment, no tab) | `# The assigned profile is resolved by name; its bypass rules become the` |
| (comment, no tab) | `# exclusions in vpn mode. domains.direct is the legacy fallback and must be` |
| (comment, no tab) | `# IGNORED while a profile is assigned (the value differs on purpose).` |
| `endpoint.routing_profile` | `Default` |
| `routing_profile.name` | `Default` |
| `routing_profile.mode` | `vpn` |
| `routing_profile.vpn_rules` | `telegram.org` |
| `routing_profile.bypass_rules` | `bank.example` |
| `routing_profile.bypass_rules` | `*.local.example` |
| `domains.direct` | `legacy.example` |

### Fixture: `bypass.tsv` (14 rows — must reproduce exactly)

| key | value |
| --- | --- |
| `main.enabled` | `1` |
| `endpoint.hostname` | `vpn.example.com` |
| `endpoint.address` | `1.2.3.4:443` |
| `endpoint.username` | `alice` |
| `endpoint.password` | `s3cret` |
| (comment, no tab) | `# A bypass-mode profile: only the VPN rules go through the tunnel. The` |
| (comment, no tab) | `# bypass rules and the legacy direct list must NOT become exclusions here.` |
| `endpoint.routing_profile` | `Games` |
| `routing_profile.name` | `Games` |
| `routing_profile.mode` | `bypass` |
| `routing_profile.vpn_rules` | `telegram.org` |
| `routing_profile.vpn_rules` | `1.2.3.0/24` |
| `routing_profile.bypass_rules` | `bank.example` |
| `domains.direct` | `legacy.example` |

## Contracts

N/A — no API endpoints. The shell interface contract is the harness API
pinned in Research:

- `assert_eq <expected> <actual> <message>` — pass/fail + detail output
- `assert_contains <haystack> <needle> <message>` — substring semantics
- `assert_exit <expected> <message> <command...>` — exit-status comparison
- `tt_test_summary` — prints `  <total> assertions, <failed> failed`, exits
  0 iff `failed == 0`
- `TT_TEST_TMP` — per-test temp dir (exported by the runner, or created by
  `lib.sh` when unset); counter files `$TT_TEST_TMP/total`,
  `$TT_TEST_TMP/failed`
- Runner: `sh tests/run.sh` — exit 0 iff every `tests/test_*.sh` exits 0

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `tests/lib.sh` | Rewrite (in place) | Assert helpers + file-based counters + summary; same interface, new expression |
| `tests/run.sh` | Rewrite (in place) | Suite runner: per-test fresh `mktemp -d` as `TT_TEST_TMP`, stdin closed, failure aggregation, banners |
| `tests/test_harness.sh` | Rewrite (in place) | Harness self-test: positive asserts + subshell negative check; exits 0 only when the harness behaves |
| `tests/fixtures/records/minimal.tsv` | Rewrite (in place) | 6-row fixture data (identical rows) |
| `tests/fixtures/records/full.tsv` | Rewrite (in place) | 31-row fixture data (identical rows) |
| `tests/fixtures/records/bypass.tsv` | Rewrite (in place) | 14-row fixture data (identical rows) |
| `tests/test_deps.sh`, `tests/test_records.sh`, `tests/test_gen_config.sh`, `tests/test_routing.sh`, `tests/test_init_apply.sh`, `tests/test_init_reload.sh` | Keep (untouched) | Equivalence oracle for this issue; rewritten in later issues |

Scratch files used during tasks (behavioral probes, negative-control test
files) are created and deleted within their task; none survive the issue.

## Tasks

### [x] Task 1: Capture the current baseline

**Files:**

- Read-only: `tests/run.sh`, `tests/lib.sh`, `tests/test_harness.sh`, `tests/fixtures/records/*.tsv`, all `tests/test_*.sh`

- [x] **Step 1: Run the current suite and record the result**

Run: `sh tests/run.sh > /tmp/tt-baseline.txt 2>&1; echo "exit=$?"`

Expected: `exit=0`, last line of the capture is `== all tests passed`.

- [x] **Step 2: Record per-test results and stdout shapes**

From the capture, note the 7 test banners (`== tests/test_*.sh`), each
test's final `  N assertions, M failed` line, and the total (180 assertions,
0 failed, per the table in Research — test_deps 26, test_gen_config 47,
test_harness 5, test_init_apply 29, test_init_reload 21, test_records 12,
test_routing 40). Also note the output shapes: ok lines start with
`  ok:`, failures start with `  FAIL:`, and the runner banner precedes
each test.

- [x] **Step 3: Confirm the standalone path works**

Run: `sh tests/test_records.sh; echo "exit=$?"`

Expected: `exit=0`, summary line `  12 assertions, 0 failed` (lib.sh creates
its own temp dir when `TT_TEST_TMP` is unset — this must keep working).

**Verification**: `/tmp/tt-baseline.txt` exists and shows the 7 tests green.
The baseline is the comparison target for every later task.

### [x] Task 2: Re-express `tests/lib.sh`

**Files:**

- Create: `tests/zz_probe_lib.sh` (scratch behavioral probe — name does NOT
  match `tests/test_*.sh`, so the runner never picks it up; deleted in Step 5)
- Rewrite: `tests/lib.sh`

- [x] **Step 1: Write the behavioral probe first (new test text)**

Write `tests/zz_probe_lib.sh` from the contract (do not copy the inherited
file; express the checks in your own words). It must source `lib.sh` the
same way tests do (`. "$(dirname "$0")/lib.sh"`) with `TT_TEST_TMP` exported
to a fresh `mktemp -d`, then verify, printing `ok:`/`FAIL:` and exiting
non-zero on any failed check:

1. after sourcing, `total` and `failed` counter files exist and contain `0`;
2. `assert_eq a a` prints an ok line containing the message; `assert_eq a b`
   prints a FAIL line plus expected/actual detail lines, and increments
   `total` and `failed`;
3. `assert_contains` matches a real substring (ok line) and reports
   missing/in detail lines on a miss;
4. `assert_exit` with `true`/`false` and matching expectations passes;
   `assert_exit 1 <msg> true` fails and prints a detail line mentioning the
   expected and the actual exit status;
5. counter increments survive a subshell: run one failing assertion inside
   `( ... )` and check the `failed` file from the parent shell — this is
   what makes file-based counters a requirement;
6. `tt_test_summary` prints exactly `  N assertions, M failed` (two-space
   indent) and exits 0 when `failed` is 0, non-zero otherwise;
7. with `TT_TEST_TMP` unset, sourcing `lib.sh` creates and exports its own
   temp dir (run this check in a fresh shell: `env -u TT_TEST_TMP sh -c '. ./tests/lib.sh; ...'`).

- [x] **Step 2: Run the probe against the current (inherited) lib.sh**

Run: `sh tests/zz_probe_lib.sh; echo "exit=$?"`

Expected: `exit=0`, all probe checks ok. This proves the probe encodes the
real contract of today's `lib.sh`.

- [x] **Step 3: Rewrite `tests/lib.sh` with new expression**

Replace the file content with your own expression implementing the pinned
contract: `TT_TEST_TMP` default via `mktemp -d` when unset; `total`/`failed`
files initialized to 0 only when missing; the four functions with the exact
argument order, output shapes, and detail lines from Research; counters
updated via file read-modify-write so subshell increments survive; `set -u`
- and POSIX-safe. Keep the file at `tests/lib.sh` and the sourcing pattern —
the seven suite tests source it unchanged.

- [x] **Step 4: Verify — probe, then the whole suite**

Run: `sh tests/zz_probe_lib.sh; echo "exit=$?"`

Expected: `exit=0` (all contract checks pass against the new expression).

Run: `sh tests/run.sh > /tmp/tt-after-lib.txt 2>&1; echo "exit=$?"`

Expected: `exit=0`; same 7 tests, same assertion counts and same summary
lines as `/tmp/tt-baseline.txt` (diff the two files: only file paths may
differ if a test's output text changed — none should, since the test files
are untouched).

- [x] **Step 5: Negative control — prove the probe can fail**

Temporarily sabotage the new `lib.sh` (e.g. make `assert_eq` always print a
FAIL line). Run `sh tests/zz_probe_lib.sh` — expected: non-zero exit, probe
FAIL lines. Restore the correct implementation and re-run the probe —
expected: `exit=0`. Then delete `tests/zz_probe_lib.sh`.

**Verification**: full suite green against the new `lib.sh` with identical
counts to baseline; probe (now deleted) demonstrated red under sabotage;
`git diff tests/lib.sh` shows new expression, no verbatim inherited text.

### [x] Task 3: Re-express `tests/run.sh`

**Files:**

- Create (scratch, deleted in Step 4): `tests/test_zz_probe_pass.sh`, `tests/test_zz_probe_fail.sh`
- Rewrite: `tests/run.sh`

- [x] **Step 1: Write the runner probes first**

`tests/test_zz_probe_pass.sh` (must match the `tests/test_*.sh` glob to be
picked up): write, in new expression, checks that `TT_TEST_TMP` is set and
exported, is an empty directory created for this test (e.g. create a file in
it and verify it persists), that stdin is closed (a `read` on stdin returns
non-zero immediately — nothing may block), and that the test's own file in
`$TT_TEST_TMP` is not the same directory another probe would use (fresh dir
per test); print ok lines; exit 0. `tests/test_zz_probe_fail.sh`: prints a
distinct marker line and exits 1.

- [x] **Step 2: Run the probes against the current runner**

Run: `sh tests/run.sh; echo "exit=$?"`

Expected: `exit=1`, banner `== FAILURES`, both probe tests listed with their
own `== ` banners, the failing probe's marker visible. This documents the
failure path of the current runner and proves the probes are picked up.

- [x] **Step 3: Rewrite `tests/run.sh` with new expression**

Replace the file content with your own expression implementing the pinned
contract: `cd` to repo root; `set -u`; iterate `tests/test_*.sh`; print
`== <test-path>` per test; fresh `mktemp -d` exported as `TT_TEST_TMP` per
test; run `sh <test> < /dev/null`; remove the temp dir after each test
(even on failure); continue the loop after failures; final banner
`== all tests passed` (exit 0) or `== FAILURES` (exit 1).

- [x] **Step 4: Verify the failure path, then the clean path**

Run: `sh tests/run.sh; echo "exit=$?"` — Expected: `exit=1`, `== FAILURES`,
both probes listed, failing probe reported (proves the NEW runner reports
per-test failures).

Delete `tests/test_zz_probe_pass.sh` and `tests/test_zz_probe_fail.sh`.

Run: `sh tests/run.sh > /tmp/tt-after-run.txt 2>&1; echo "exit=$?"` —
Expected: `exit=0`, `== all tests passed`, same 7 tests and counts as the
baseline (diff against `/tmp/tt-baseline.txt`).

**Verification**: new runner produces the baseline suite result, and the
deliberate-failure probe proved the failure path (acceptance criterion 1
and issue verification step 3). `git diff tests/run.sh` shows new
expression.

### [x] Task 4: Re-express `tests/test_harness.sh`

**Files:**

- Rewrite: `tests/test_harness.sh`

- [x] **Step 1: Write the new self-test from the contract**

Replace the file content with your own expression: source `lib.sh`; run four
positive assertions — an `assert_eq` on equal strings, an `assert_contains`
on a real substring, an `assert_exit 0` on a success command, an
`assert_exit 1` on a failure command; then the negative check: inside a
subshell, run an intentionally failing assertion with its output discarded,
verify from the parent shell that the `failed` counter is exactly 1, print
an ok line for the check, and reset the counter file to 0; end with
`tt_test_summary`. The self-test must exit 0 only when the harness behaves.
Do not copy the inherited file's text.

- [x] **Step 2: Run it alone**

Run: `sh tests/test_harness.sh; echo "exit=$?"`

Expected: `exit=0`, exactly `  5 assertions, 0 failed` (4 positive + 1
negative-check ok line — identical to the baseline).

- [x] **Step 3: Negative control — the self-test must catch a broken harness**

Temporarily make one positive assertion fail (e.g. compare unequal strings).
Run: `sh tests/test_harness.sh; echo "exit=$?"` — Expected: `exit=1` and at
least one `FAIL:` line visible (either the sabotaged assertion's FAIL line
or the negative-check guard's `FAIL: assert_eq did not record a failure`).
Do NOT pin a summary line here: with a sabotaged positive assertion the
`failed` counter is 2 when the negative-check guard runs, so the guard's
else branch exits 1 before `tt_test_summary` prints. Restore the correct
assertion and re-run — Expected: `exit=0`, `  5 assertions, 0 failed`.

- [x] **Step 4: Full-suite check**

Run: `sh tests/run.sh; echo "exit=$?"` — Expected: `exit=0`, harness test
still reports `  5 assertions, 0 failed`.

**Verification**: self-test passes standalone (issue verification step 2)
and its summary line matches the baseline; the sabotage run proved it exits
non-zero when the harness misbehaves (acceptance criterion 3).
`git diff tests/test_harness.sh` shows new expression.

### [x] Task 5: Re-create the record fixtures with identical data

**Files:**

- Rewrite: `tests/fixtures/records/minimal.tsv`, `tests/fixtures/records/full.tsv`, `tests/fixtures/records/bypass.tsv`

- [x] **Step 1: Write the fixtures from the data contract**

Replace all three files with rows written from the Entities tables above (6,
31 and 14 rows): `section.option<TAB>value`, exact keys and values, repeated
keys kept as repeated lines, the comment lines reproduced byte-for-byte
(they carry NO tab), and the `endpoint.password` line of `full.tsv`
reproduced byte-for-byte (value `pa"ss\with`, then a LITERAL tab, then
`specials`). Mind the tabs: write the separator with a real tab character,
not spaces.

- [x] **Step 2: Verify with the existing unit tests (red first, then green)**

Run: `sh tests/test_records.sh; echo "exit=$?"` — Expected: `exit=0`, all 12
assertions pass (this test reads `minimal.tsv` + `full.tsv` and asserts the
exact fixture values, incl. the password "stops at the first tab"
semantics).

Run: `sh tests/test_gen_config.sh; echo "exit=$?"` — Expected: `exit=0`,
all 47 assertions pass (this test reads `minimal.tsv` + `full.tsv` +
`bypass.tsv` and asserts fixture-derived TOML values incl. both
`endpoint.address` rows, `endpoint.custom_sni`, `endpoint.client_random`,
the profile records, the single legacy `domains.direct` absence while a
profile is assigned, and the bypass-mode profile semantics).

If a fixture row is wrong, the corresponding assertion fails — that failure
is the red signal; fix the row from the data contract and re-run until
green.

- [x] **Step 3: Verify structural facts**

Run: `wc -l tests/fixtures/records/minimal.tsv tests/fixtures/records/full.tsv tests/fixtures/records/bypass.tsv`
— Expected: `6`, `31`, `14` (one line per row, comments included).

Run: `rg -c $'\t' tests/fixtures/records/*.tsv` — Expected: `6` (minimal),
`28` (full — 31 lines minus the 3 comment lines), `12` (bypass — 14 lines
minus the 2 comment lines): every data line carries a tab separator, no
comment line does. Every data line must have EXACTLY one tab as the
separator (the password line's second, literal tab is beyond the separator
and is the only such line — proven by the "stops at the first tab"
assertion in Step 2); check no data line lacks a tab with:
`awk '!/^#/ && index($0,"\t")==0 {print FILENAME": "FNR}' tests/fixtures/records/*.tsv`
— Expected: no output.

Review `git diff --word-diff` on the fixtures: only the expected data rows
may differ, nothing else (incl. the comment text).

**Verification**: current unit tests pass against the re-created fixtures
(acceptance criterion 4 — the fixture content is proven identical by the
tests that assert it; `test_records.sh` and `test_gen_config.sh` together
cover all three fixtures).

### [x] Task 6: Final suite verification and clean-tree check

**Files:**

- Read-only: all rewritten files; scratch `tests/test_zz_scratch.sh` (created and deleted inside this task)

- [x] **Step 1: Full suite vs baseline**

Run: `sh tests/run.sh > /tmp/tt-final.txt 2>&1; echo "exit=$?"`

Expected: `exit=0`, `== all tests passed`. Diff the per-test banner list and
every `  N assertions, M failed` line against `/tmp/tt-baseline.txt`:
identical tests, identical counts (180 assertions total).

- [x] **Step 2: Deliberate-failure check (acceptance criterion 1)**

Create `tests/test_zz_scratch.sh` that prints a marker and exits 1. Run:
`sh tests/run.sh; echo "exit=$?"` — Expected: `exit=1`, banner
`== FAILURES`, the scratch test listed with its `== ` banner and marker.
Delete `tests/test_zz_scratch.sh`, re-run — Expected: `exit=0`.

- [x] **Step 3: Standalone self-test (acceptance criterion 3)**

Run: `sh tests/test_harness.sh; echo "exit=$?"` — Expected: `exit=0`,
`  5 assertions, 0 failed`.

- [x] **Step 4: Clean-tree and clean-room check**

Run: `git status --porcelain` — Expected: only the six planned files show
as modified, plus `.sdd/.current/` plan/issue files; NO `*.old` files, NO
scratch files (`tests/zz_*`, `tests/test_zz_*`) left behind. Run:
`git diff --stat` to confirm the change set. Then review `git diff` for
each rewritten file and confirm the text is new expression: spot-check that
no comment or logic line is copied verbatim from the inherited versions
(acceptance criterion 5; the issue allows `git diff` old-vs-new as the
review mechanism).

**Verification**: suite green and byte-equivalent in results to baseline;
failure path proven; standalone self-test green; tree contains only the
intended files, all with new expression.

## Risks and Open Items

- **`assert_exit` argument order in the issue text**: the issue contract
  writes `<code> <command...> <message>` but all current callers and the
  "behave as today" acceptance criteria use `<expected> <message>
  <command...>`. This plan pins the ACTUAL order; if a reviewer prefers the
  issue text over reality, the existing test callers would need changing —
  out of scope here (they must pass unchanged).
- **Fixture byte-exactness**: the fixtures contain comment lines (3 in
  `full.tsv`, 2 in `bypass.tsv`) that no assertion checks, and the
  `full.tsv` password line contains a quote, a backslash, and a literal tab
  mid-line; a text editor could silently convert tabs to spaces or reflow
  comments. Mitigated by the per-fixture `wc -l` (6/31/14) and
  `rg -c $'\t'` (6/28/12) structural checks, the awk check for data lines
  without a tab, the `test_records.sh` "stops at the first tab" assertion,
  and the `git diff --word-diff` review in Task 5.
- **Glob pollution**: scratch probes in Tasks 3 and 6 live under
  `tests/test_*` and are part of the suite while they exist; each task
  deletes them before finishing, and Task 6 Step 4 verifies none remain.
- **Counter-file semantics**: file-based counters are load-bearing (subshell
  visibility). A rewrite using shell variables would silently break
  `test_harness.sh` and tests that assert inside `$(...)`; the Task 2 probe
  explicitly checks subshell visibility.

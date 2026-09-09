# Implementation Plan: TT-02 records.sh accessor library

- **Created**: 2026-09-08
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-02/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation: plan contains behavior/contract targets only, no inherited text; test rewritten as new text; contract-first TDD (rewritten test must pass against the OLD implementation before the rewrite)"

## Summary

Re-express the inherited `records.sh` shell library (four accessors `tt_list` /
`tt_get` / `tt_bool` / `tt_count` over a TSV file at `$TT_RECORDS`) as
functionally identical, independently written POSIX sh, and rewrite the
inherited `tests/test_records.sh` in new text. The contract in the issue is
the spec; the fixtures and the currently green test suite are the equivalence
oracle. Sequence (contract-first TDD): capture the baseline + an old-library
oracle copy outside the tree → rewrite the test from the contract and prove it
passes against the OLD implementation → write the new library from the
contract → prove the rewritten test passes → byte-diff old-vs-new accessor
outputs on the fixtures → run the full suite and the CI gates.

## Technical Context

- **Language/Version**: POSIX sh (`/bin/sh`); must run identically on busybox
  ash (OpenWrt target), dash (CI), and bash-in-posix-mode (macOS `sh` for
  local runs). No bashisms. `set -u` is allowed.
- **Primary Dependencies**: none beyond `awk` (busybox awk on the target).
  The file is a sourced library, **not** executable: git mode must stay
  `100644`; the Makefile chmods it to 0644 and CI's executable-bits check
  deliberately excludes it.
- **Storage**: the TSV file at `$TT_RECORDS` (`/var/etc/trusttunnel/settings.tsv`
  on a router), produced by `uci-export`; regenerated atomically by the init
  script.
- **Testing**: `tests/run.sh` runs each `tests/test_*.sh` in a fresh
  `$TT_TEST_TMP` (mktemp -d), with stdin closed, from the repo root;
  `tests/lib.sh` provides `assert_eq`, `assert_contains`, `assert_exit`,
  `tt_test_summary`. Fixtures: `tests/fixtures/records/minimal.tsv` and
`full.tsv`. Full-suite baseline recorded in Task 1 (180 assertions, 0
failed, of which `test_records.sh` contributes 12; per-file breakdown in
Task 1).
- **Target Platform**: OpenWrt (busybox ash/awk) for the package; macOS
  `sh`/CI dash for tests.
- **CI gates that touch this issue** (`.github/workflows/ci.yml`): unit tests
  (`sh tests/run.sh`), shellcheck pinned `koalaman/shellcheck:v0.11.0 -s sh`
  on `records.sh` (among others), `sh -n` on the init script, executable-bits
  check (records.sh not in the list).

## Research

### 1. Pinned observable behavior of the accessors (empirically verified against the current implementation)

Calling patterns and outputs — the contract targets the rewrite must hit
exactly (verified by direct probing on this machine; values are quoted as
`[…]` where whitespace matters):

| Call (on full.tsv unless noted) | Output | Semantics pinned |
| --- | --- | --- |
| `tt_get main.enabled` | `1` | prints the stored value |
| `tt_get main.nosuch` | (empty line) | absent key → empty output |
| `tt_get main.nosuch fallback` | `fallback` | absent key → default |
| `tt_get main.nosuch ""` | (empty line) | explicit empty default → empty output |
| `tt_get endpoint.address` | `1.2.3.4:443` | repeated key → FIRST occurrence only |
| `tt_get endpoint.password` | `pa"ss\with` | value is verbatim (quotes/backslashes literal) and **stops at the first tab** (the fixture line is `endpoint.password⇥pa"ss\with⇥specials`) |
| `tt_get edge.x` | `1` (throwaway edge.tsv: an `edge.x.y⇥2` line sits BEFORE `edge.x⇥1`) | key match is on the WHOLE field, no prefix matching — a prefix-matcher would answer `2`; pinned in the rewritten test |
| `tt_list endpoint.address` | `1.2.3.4:443` then `[2001:db8::1]:443` | every occurrence, one per line, file order |
| `tt_list main.nosuch` | (zero bytes) | absent key → nothing at all |
| `tt_bool main.enabled` | `true` | stored `1` → `true` |
| `tt_bool main.nosuch` | `false` | absent, no default → `false` |
| `tt_bool main.nosuch 1` | `true` | absent + default `1` → `true` |
| `tt_bool main.nosuch banana` | `false` | absent + non-`1` default → `false` |
| `tt_bool endpoint.post_quantum 1` | `false` | stored `0` BEATS default `1` |
| `tt_bool main.log_level` | `false` | stored non-`1` value (e.g. `debug`) → `false` |
| `tt_count endpoint.address` | `2` | occurrence count, repeated keys counted |
| `tt_count main.nosuch` | `0` | absent → `0` (numeric zero, not empty) |

Edge cases verified with throwaway fixtures (NOT in the shipped fixtures — pin
them in the rewritten test via a temp file):

- A line `key⇥` (empty value): `tt_get` treats it as absent → default;
  `tt_bool` falls to its default (`1` → `true`); `tt_count` still counts the
  occurrence. First-occurrence rule applies: an empty first occurrence means
  the default is used even if a later occurrence has a value.
- Prefix collision: an `edge.x.y⇥2` line written BEFORE `edge.x⇥1` —
  `tt_get`/`tt_list`/`tt_count edge.x` must see only the exact key
  (whole-field match, no prefix matching); pinned in the rewritten test via
  the temp fixture (table row above).
- Guard semantics: the `${TT_RECORDS:?…}` guard fires on BOTH unset and empty
  `TT_RECORDS`, inside each accessor (not at source time — sourcing the
  library without the variable succeeds). On failure the shell prints
  `…: TT_RECORDS is not set` to stderr (the filename/line prefix is the
  shell's own, and is **localized** — observed `строка 21` under a Russian
  locale; only the message body `TT_RECORDS is not set` is ours to pin).
  The exit code is shell-dependent (1 under macOS `sh`=bash, 2 under
  dash/busybox ash) — the test must assert non-zero, not a specific code.
- Values never contain newlines (multi-line PEM bypasses records entirely;
  `endpoint.certificate` is deliberately not exported).

### 2. Callers and how they use the library

- `gen-config` sources `. "$TT_LIBDIR/records.sh"` BEFORE assigning
  `TT_RECORDS` from `$1` — this is exactly why the guard lives inside the
  functions. Uses: `tt_get endpoint.hostname/username/password`,
  `tt_get network.mtu 1350`, `tt_get main.log_level info`,
  `tt_get endpoint.protocol http2`, `tt_count endpoint.address` (guard for
  missing credentials), `tt_list endpoint.address | endpoint.dns_upstream |
  domains.direct`, `tt_bool endpoint.post_quantum 1`, `tt_bool
  endpoint.has_ipv6 1`, `tt_bool endpoint.skip_verification 0`, `tt_bool
  endpoint.anti_dpi 0`.
- `routing` sources `. "$TT_LIBDIR/records.sh"`, then assigns
  `TT_RECORDS="${2:-}"` and rejects it as empty. Uses: `tt_get network.table
  880`, `tt_get network.fwmark 0x9527`, `tt_get network.mtu 1350`,
  `tt_get network.lan_devices` (no default), `tt_bool
  network.include_router_traffic 0`, `tt_bool network.blackhole_on_down 1`,
  `tt_list endpoint.address` (streamed with `while IFS= read -r`).
- `uci-export` does NOT source the library — it is the PRODUCER of the TSV
  (`section.option⇥value`, repeated keys for lists). Its output format is the
  accessors' input contract; it keeps working unchanged (its behavior is
  gated by `test_gen_config.sh`/`test_init_*.sh` through the other scripts).
- The init script and the hotplug script call `uci-export`/`gen-config`/
  `routing` as subprocesses and never source `records.sh` themselves
  (verified by grep over `root/etc/`). Correction to the issue's wording: the
  fork-written init tests therefore exercise this library only INDIRECTLY
  (via `test_gen_config.sh` with 47 assertions and `test_routing.sh` with 40
  assertions, which DO load `records.sh` through the callers). They are still
  mandatory gates via `sh tests/run.sh`.
- The ucode backend's own `records()` parser (`luci.trusttunnel`) is a
  separate expression owned by TT-09 — out of scope here.

### 3. Test harness conventions the rewritten test must follow

- `. "$(dirname "$0")/lib.sh"` first; counters live in `$TT_TEST_TMP`;
  finish with `tt_test_summary` (its exit status is the test's verdict).
- `run.sh` executes each test from the repo root with stdin closed — a
  missing-`TT_RECORDS` accessor that silently fell back to stdin would HANG
  the suite (this is why the guard is part of the contract).
- Assertion style: `assert_eq "<expected>" "$(tt_get …)" "<message>"`;
  multi-line expected values are literal strings with embedded newlines;
  `assert_contains` for substrings (stderr capture); `assert_exit` for
  expected exit codes of whole `sh -c` invocations.
- Relative paths like `tests/fixtures/records/minimal.tsv` are valid because
  `run.sh` cd's to the repo root.

### 4. Clean-room procedure specific to this issue

1. Task 1 copies the CURRENT `records.sh` to a temp root OUTSIDE the tree
   (`$TT02_TMP`, created with `mktemp -d` — `$TT_TEST_TMP` only exists inside
   run.sh and is NOT available to Tasks 1/5) and records the baseline suite
   result. After that, the inherited file is the enemy:
2. The implementer writes the new test and the new library from the issue
   contract + this plan's pinned-behavior table ONLY. Do NOT open the
   inherited `records.sh` (or the oracle copy) while writing the replacement.
3. The oracle copy exists solely to run the old accessors for the golden
   byte-diff (verification step 3 of the issue) and is deleted afterwards —
   never committed, never diffed into the tree.
4. The rewritten test must pass against BOTH implementations: against the old
   one it proves the contract is captured (TDD "test encodes the spec"), then
   against the new one it proves the re-expression.
5. Task 6 ends with the PRD-mandated `git status` check: only
   `records.sh` and `test_records.sh` modified; no `*.old`, no temp copies
   left in the tree.

### 5. Risks and gaps

- **Exit-code variance of the guard**: bash exits 1, dash/ash exit 2 on
  `${VAR:?}` failure. The rewritten test must assert "non-zero + stderr
  contains `TT_RECORDS is not set`", never a hard-coded code.
- **Localized shell diagnostics**: the prefix (`file: line N:`) is
  locale-dependent; only the message body is asserted.
- **The full.tsv password line contains an embedded tab** (defensive
  fixture). The rewrite must preserve "value = up to the first tab".
- **Empty-value lines** are absent from the shipped fixtures; the behavior is
  pinned in the rewritten test with a temp fixture so the equivalence claim
  covers it.
- **`sh` differences local-vs-CI**: macOS `sh` is bash in posix mode; CI is
  dash. Keep strictly POSIX, verify with `sh -n` and the pinned shellcheck.
- **Sourcing order**: the library must stay source-safe without
  `TT_RECORDS` (callers set it after sourcing); a top-level guard would break
  `gen-config`/`routing`.
- **Mode drift**: the new file must remain non-executable (`100644`) or CI's
  executable-bits gate and the package build (Makefile chmod 0644) still
  pass, but the diff would silently carry a mode change — keep 0644.
- **Temp-root discipline**: `$TT_TEST_TMP` exists only inside run.sh; the
  oracle and the golden transcripts live in the Task 1 `$TT02_TMP` root
  (`mktemp -d`), so Tasks 1 and 5 never depend on run.sh state.

## Entities

### Records TSV (`/var/etc/trusttunnel/settings.tsv`)

- **Fields**: lines `section.option⇥value`; same key may repeat (list
  values); values may contain quotes and backslashes but not tabs (a tab
  inside a line terminates the value defensively — see full.tsv password);
  no newlines in values (PEM bypasses records as a separate file).
- **Relationships**: produced by `uci-export` (TT-01-family schema:
  `main.*`, `endpoint.*` minus `certificate`, `network.*`, `domains.direct`
  lists), consumed by the four accessors, which feed `gen-config`,
  `routing`, and the init script's apply/reload logic.
- **Validation**: the accessors match keys on the whole field (no prefix
  matching); repeated keys are occurrence-counted.
- **States**: regenerated atomically via `.new` + `mv` by the init script's
  `regenerate()`; the applied-state copy is compared by `changed_keys`.

### Accessor interface (the library's public contract)

- `tt_list <key>` — every value for the key, one per line, file order;
  nothing for an absent key.
- `tt_get <key> [default]` — first value only; absent key or empty first
  value → default; no default → empty line.
- `tt_bool <key> [default]` — `true` iff the effective value is exactly `1`;
  effective value = stored first value if non-empty, else default
  (default itself defaults to `0`); so stored `0` beats default `1`, and any
  non-`1` value or default maps to `false`.
- `tt_count <key>` — number of occurrences as a decimal number (`0` for
  absent).
- Guard: `${TT_RECORDS:?…}` with the message body `TT_RECORDS is not set`,
  fired inside each accessor on unset OR empty `TT_RECORDS`; sourcing the
  library itself never fails.

## Contracts

- Issue contract: `.sdd/.current/issues/TT-02/issue.md` (Contract to
  reproduce, Acceptance criteria, How to verify).
- Producer contract: `uci-export` output format (section.option⇥value) is the
  input contract of the accessors.
- No API endpoints; the four function signatures above are the interface.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh` | Rewrite | Four accessors re-expressed from the contract; identical observable behavior; POSIX sh + awk; shellcheck-clean; mode stays 0644 |
| `tests/test_records.sh` | Rewrite | Behavioral assertions from the contract in new text; passes against old AND new implementation |
| temp root outside the tree (`$(mktemp -d)`, `$TT02_TMP`) | Create (ephemeral) | Oracle copy of the old library + golden outputs for the old-vs-new byte-diff; deleted in Task 5 |

## Tasks

### [ ] Task 1: Baseline capture and oracle snapshot

**Files:**

- Run (no file changes): `tests/run.sh`, `tests/test_records.sh`
- Create (ephemeral, outside the tree): oracle copy of the current
  `records.sh`

- [ ] **Step 1: Record the pre-change baseline**

Run: `sh tests/run.sh`

Expected: `== all tests passed`, exit 0. Baseline for this issue: 180
assertions, 0 failed. Record the per-file counts — the other files must keep
their exact counts after the rewrite: `test_deps.sh` 26,
`test_gen_config.sh` 47, `test_harness.sh` 5, `test_init_apply.sh` 29,
`test_init_reload.sh` 21, `test_records.sh` 12, `test_routing.sh` 40
(26+47+5+29+21+12+40 = 180).

- [ ] **Step 2: Snapshot the old library as the golden oracle**

```sh
TT02_TMP="$(mktemp -d)"
ORACLE="$TT02_TMP/oracle"
mkdir -p "$ORACLE"
cp packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh "$ORACLE/records.sh"
```

Verify: `sh -n "$ORACLE/records.sh"` succeeds; record `$TT02_TMP` and
`$ORACLE` paths for Task 5. This copy is the ONLY old-implementation
artifact the rewrite tasks may execute (never read). `$TT02_TMP` is the
ephemeral temp root OUTSIDE the tree — it also holds the Task 5 golden
transcripts and is deleted in Task 5 Step 2.

**Verification**: baseline recorded in the task notes; oracle copy exists
outside the tree; `git status` is clean (no tracked changes yet).

### [ ] Task 2: Rewrite `tests/test_records.sh` from the contract

**Files:**

- Modify: `tests/test_records.sh`

- [ ] **Step 1: Write the new test text**

The file below is new expression written from the issue contract and the
pinned behaviors in Research §1 (31 assertions; message strings are new
text — every line must be fresh wording, no inherited phrasing):

```sh
#!/bin/sh
# Records accessors, pinned from the TT-02 contract.
#
# The four accessors read the TSV file at $TT_RECORDS: a line is
# "section.option<TAB>value", a key may repeat for list values, and a
# value ends at the first tab — quotes and backslashes inside a value
# are literal characters, not syntax. The TT_RECORDS guard lives inside
# the accessors: callers source the library before they know the file
# path, so sourcing must succeed without the variable.
. "$(dirname "$0")/lib.sh"

. packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh

# --- scalar fixture -------------------------------------------------------------

TT_RECORDS=tests/fixtures/records/minimal.tsv

assert_eq "1" "$(tt_get main.enabled)" "tt_get prints the stored value"
assert_eq "" "$(tt_get main.nosuch)" "tt_get prints nothing for an absent key"
assert_eq "fallback" "$(tt_get main.nosuch fallback)" "tt_get falls back to the given default"
assert_eq "" "$(tt_get main.nosuch "")" "tt_get prints nothing for an empty default"
assert_eq "true" "$(tt_bool main.enabled)" "tt_bool maps a stored 1 to true"
assert_eq "false" "$(tt_bool main.nosuch)" "tt_bool prints false for an absent key"
assert_eq "true" "$(tt_bool main.nosuch 1)" "tt_bool honours a true default"
assert_eq "false" "$(tt_bool main.nosuch banana)" "tt_bool maps a non-1 default to false"
assert_eq "1.2.3.4:443" "$(tt_list endpoint.address)" "tt_list prints the single value"
assert_eq "1" "$(tt_count endpoint.address)" "tt_count counts one occurrence"
assert_eq "0" "$(tt_count main.nosuch)" "tt_count prints 0 for an absent key"

# --- list fixture: repeated keys, quotes, backslashes, stored zeroes ------------

TT_RECORDS=tests/fixtures/records/full.tsv

assert_eq "1.2.3.4:443
[2001:db8::1]:443" "$(tt_list endpoint.address)" "tt_list prints every value in file order"
assert_eq "1.2.3.4:443" "$(tt_get endpoint.address)" "tt_get prints only the first value"
assert_eq "" "$(tt_list main.nosuch)" "tt_list prints nothing for an absent key"
assert_eq "2" "$(tt_count endpoint.address)" "tt_count counts repeated keys"
assert_eq "1" "$(tt_count domains.direct)" "tt_count counts the single domains.direct entry"
assert_eq 'pa"ss\with' "$(tt_get endpoint.password)" "a value keeps quotes and backslashes and stops at the first tab"
assert_eq 'pa"ss\with' "$(tt_list endpoint.password)" "tt_list takes the same first-tab slice"
assert_eq "false" "$(tt_bool endpoint.post_quantum 1)" "a stored 0 beats a true default"
assert_eq "false" "$(tt_bool main.log_level)" "a stored non-1 value maps to false"

# --- empty stored value, pinned via a throwaway fixture --------------------------

edge="$TT_TEST_TMP/edge.tsv"
printf 'edge.empty\t\nedge.empty\tvalue\nedge.bool\t\n' > "$edge"
TT_RECORDS="$edge"

assert_eq "" "$(tt_get edge.empty)" "an empty first value is treated as absent"
assert_eq "fallback" "$(tt_get edge.empty fallback)" "an empty first value falls back to the default"
assert_eq "true" "$(tt_bool edge.bool 1)" "an empty stored value honours the default"
assert_eq "2" "$(tt_count edge.empty)" "empty values still count as occurrences"

# --- prefix collision: keys match the whole field, not a prefix ------------------
# edge.x.y sits BEFORE edge.x in the fixture; a prefix-matching
# implementation would answer edge.x with the longer key's data.

printf 'edge.x.y\t2\nedge.x\t1\n' >> "$edge"

assert_eq "1" "$(tt_get edge.x)" "tt_get matches the whole key, not a prefix"
assert_eq "1" "$(tt_list edge.x)" "tt_list emits only the exact key's values"
assert_eq "1" "$(tt_count edge.x)" "tt_count counts only the exact key"

# --- the TT_RECORDS guard ---------------------------------------------------------

assert_exit 0 "sourcing the library needs no TT_RECORDS" sh -c '. packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh'

_guard_err=$(unset TT_RECORDS; tt_get main.enabled 2>&1)
assert_contains "$_guard_err" "TT_RECORDS is not set" "an accessor without TT_RECORDS names the variable"
(unset TT_RECORDS; tt_get main.enabled >/dev/null 2>&1) && _guard_ok=0 || _guard_ok=1
assert_eq "1" "$_guard_ok" "an accessor without TT_RECORDS fails"

_guard_err=$(TT_RECORDS=; tt_get main.enabled 2>&1)
assert_contains "$_guard_err" "TT_RECORDS is not set" "an accessor with an empty TT_RECORDS names the variable"

tt_test_summary
```

Note: do not assert a concrete exit code for the guard (bash exits 1, dash /
busybox ash exit 2 — Research §1); the `_guard_ok` pattern above only asserts
non-zero. Do not assert the shell's `file: line:` prefix (localized).

- [ ] **Step 2: Run the rewritten test against the OLD implementation**

Run: `sh tests/test_records.sh`

Expected: PASS — all 31 assertions green, `0 failed`. This proves the
rewritten test encodes exactly today's observable behavior (contract
captured) before any implementation changes. If an assertion fails here,
the test over- or under-specifies the contract — fix the test, not the
implementation.

**Verification**: 31/31 green against the untouched inherited library.

### [ ] Task 3: Write the new `records.sh` from the contract

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh`

- [ ] **Step 1: Write the replacement from the contract only**

CLEAN-ROOM: do NOT open the current `records.sh` or the Task 1 oracle copy
while writing. Work from the issue's Contract section and the pinned
behavior table in Research §1. The file must:

- define the four accessors with the exact names, signatures, output
  formats, defaulting and first-occurrence semantics of Research §1
  (any implementation approach is allowed — single awk pass per call is
  the known-cost baseline, but the expression must be original);
- match keys on the WHOLE field (no prefix matching), slice values at the
  first tab, print values verbatim (quotes/backslashes never interpreted),
  print occurrence counts as decimal numbers with `0` for absent;
- fire the `${TT_RECORDS:?...}` guard with message body `TT_RECORDS is not
  set` inside each accessor (unset OR empty), never at source time;
- be POSIX sh + busybox-awk compatible, `set -u` safe, no bashisms;
- carry a short original header comment (file format + guard rationale +
  sourcing contract) — new wording only;
- preserve the file mode 0644 (not executable) and the path.

- [ ] **Step 2: Syntax and lint gates on the new file**

```sh
sh -n packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh
docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh \
  packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh
```

Expected: `sh -n` silent; shellcheck reports zero findings (same pinned
version as CI, per ci.yml).

**Verification**: new file parses, is shellcheck-clean under the pinned
version, mode is `100644` (`git status` shows no mode change), and no line
of the new file matches the inherited implementation (self-check: the file
was written from the contract, not by transformation).

### [ ] Task 4: Prove the rewritten test against the NEW implementation

**Files:**

- Run: `tests/test_records.sh`

- [ ] **Step 1: Run the rewritten test**

Run: `sh tests/test_records.sh`

Expected: PASS — the same 31 assertions green, `0 failed`.

**Verification**: the identical assertion set passes on both old (Task 2)
and new (Task 4) implementations — behavioral equivalence on the
contract-covered surface.

### [ ] Task 5: Golden byte-diff of old vs new accessor outputs

**Files:**

- Run (ephemeral, outside the tree): accessor matrix over both fixtures
  against the Task 1 oracle copy and the new library

- [ ] **Step 1: Generate and compare outputs**

Run the same deterministic accessor matrix against both libraries (new
script, written for this task; `$ORACLE` and `$TT02_TMP` are the Task 1
paths — transcripts go under `$TT02_TMP`, NOT `$TT_TEST_TMP`, which only
exists inside run.sh):

```sh
# usage: sh matrix.sh <records.sh> ; prints a stable transcript
. "$1"
for f in minimal full; do
	TT_RECORDS="tests/fixtures/records/$f.tsv"
	for call in \
		"get main.enabled" "get main.nosuch" "get main.nosuch fallback" \
		"get endpoint.address" "get endpoint.password" "get main.log_level info" \
		"get network.mtu 1350" "get endpoint.protocol http2" \
		"list endpoint.address" "list endpoint.dns_upstream" "list domains.direct" \
		"list main.nosuch" \
		"bool main.enabled" "bool endpoint.post_quantum 1" \
		"bool endpoint.skip_verification 0" "bool endpoint.has_ipv6 1" \
		"bool main.nosuch" "bool main.nosuch 1" "bool main.nosuch 0" \
		"bool main.nosuch banana" \
		"count endpoint.address" "count domains.direct" "count main.nosuch"; do
		set -- $call
		echo "## $f $1 $2 ${3-}"
		case "$1" in
			get) tt_get "$2" "${3-}" ;;
			list) tt_list "$2" ;;
			bool) tt_bool "$2" "${3-}" ;;
			count) tt_count "$2" ;;
		esac
	done
done
```

```sh
sh matrix.sh "$ORACLE/records.sh" > "$TT02_TMP/golden.out"
sh matrix.sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh > "$TT02_TMP/new.out"
diff -u "$TT02_TMP/golden.out" "$TT02_TMP/new.out"
```

Expected: `diff` exits 0, no output — byte-identical transcripts on both
fixtures (this is the issue's verification step 3).

- [ ] **Step 2: Discard the oracle**

Remove the whole Task 1 temp root after the diff passes (oracle copy plus
the golden/new transcripts): `rm -rf "$TT02_TMP"`.

**Verification**: empty diff; oracle deleted; `git status` shows only the
two intended modified files.

### [ ] Task 6: Full suite, CI gates, and clean-tree check

**Files:**

- Run: `tests/run.sh`; CI-equivalent local gates; `git status`

- [ ] **Step 1: Full suite**

Run: `sh tests/run.sh`

Expected: `== all tests passed`, exit 0, with the OTHER test files keeping
their exact baseline counts (deps 26, gen_config 47, harness 5, init_apply
29, init_reload 21, routing 40) and `test_records.sh` now at 31. The
fork-written init tests pass unchanged (they exercise
`uci-export`/`gen-config`/`routing` subprocesses, which load the new
library).

- [ ] **Step 2: CI-equivalent gates**

```sh
sh -n packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh
docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh \
  packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh
git diff --stat   # only the two files, no mode changes
```

Expected: syntax and shellcheck clean; `records.sh` mode `100644`
(executable-bits CI list must stay untouched — the file is sourced, not
executed).

- [ ] **Step 3: Clean-tree check (PRD requirement)**

Run: `git status` and `git diff --name-only`

Expected: exactly `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh`
and `tests/test_records.sh` modified; no `*.old`, no oracle/temp copies, no
stray fixtures inside the tree; nothing else staged.

**Verification**: full suite green with unchanged other-file counts; all CI
gates pass locally; tree clean of oracle artifacts.

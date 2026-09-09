# Implementation Plan: TT-04 — gen-config (client.toml generator)

- **Created**: 2026-09-08
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-04/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "None"

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`gen-config` changed — the issue contract was updated; adjust this plan:

- **`vpn_mode` is no longer fixed**: profile resolution — `routing_profile`
  assigned and `routing_profile.name` matches → mode `bypass` emits
  `vpn_mode = "selective"` with `exclusions` = `vpn_rules`; mode `vpn`
  emits `"general"` with `exclusions` = `bypass_rules`; ANY other mode
  (empty — stale/missing reference — or unknown non-empty) → legacy
  `"general"` with `domains.direct` (matches the code's `case`
  semantics). `domains.direct` must NOT leak while a profile is assigned.
- **New fields always emitted**: `custom_sni = "…"`, `client_random =
  "…"` (TOML-escaped, empty when unset).
- **Golden capture (Task 1) is now 6 cases**: the three fixtures
  (`minimal.tsv`, `full.tsv` with the vpn Default profile,
  `bypass.tsv`) × with/without PEM.
- **Rewritten test (Task 2)** must cover: the profile mode matrix
  (bypass → selective + vpn_rules exclusions; vpn profile → general +
  bypass_rules exclusions; `legacy.example` absent from both), the
  stale-reference fallback (temp `stale.tsv` → general + domains.direct),
  the unknown-mode fallback (temp fixture case with a matching profile
  whose mode is neither `bypass` nor `vpn` → legacy general +
  domains.direct), `custom_sni`/`client_random` emission (empty and
  populated), plus the previously pinned assertions — matching the
  extended `tests/test_gen_config.sh` on main.
- The `[listener.tun]`/escaping/PEM contracts are unchanged.

## Summary

Reimplement the inherited `gen-config` shell script (GPL-2.0 expression) as a
clean-room POSIX sh + awk implementation that is **byte-identical** in output
to today's version: the `client.toml` it generates is consumed by the
Apache-2.0 TrustTunnel client binary, so the field set, values, order and
formatting are a hard external contract (issue TT-04, "Contract to
reproduce"). The inherited `tests/test_gen_config.sh` is rewritten in new
text with the same behavioral assertions. The equivalence oracle is a set of
transient golden outputs (6 cases: the three fixtures `minimal.tsv`,
`full.tsv` and `bypass.tsv` × with/without a PEM file) captured from the
current implementation into a scratch directory under
`/tmp` — never committed as fixtures — plus the rewritten unit test and the
existing suite (`sh tests/run.sh`). The old implementation is only ever
*executed* for byte-diffing; its text is not consulted while writing the
replacement.

Blocked by TT-02 (records.sh reimplementation): the new `gen-config` consumes
the `tt_get` / `tt_list` / `tt_bool` / `tt_count` interface, which is already
pinned by the rewritten `tests/test_records.sh` and `tests/fixtures/records/`
fixtures.

## Technical Context

- **Language/Version**: POSIX shell (`/bin/sh` — dash/busybox ash on the
  target), single implementation file, no build step.
- **Primary Dependencies**:
  - `records.sh` (sourced via `TT_LIBDIR`, defaulting to the script's own
    directory): `tt_get <key> [default]`, `tt_list <key>`, `tt_bool <key>
    [default]`, `tt_count <key>` — reimplemented in TT-02; interface pinned
    by `tests/test_records.sh`.
  - `awk` (POSIX/busybox) for field extraction via the records library and
    for the multi-line PEM normalization (`awk 1` prints every line and adds
    a trailing newline if the file lacks one).
- **Output**: `client.toml` on stdout. Byte-level structure (verified against
  the current implementation on all three fixtures):
  - header comment line; then the top-level scalars and `exclusions` array;
    one blank line; `[endpoint]` block; one blank line; `[listener.tun]`
    block; the last line ends with a single newline (no trailing blank
    line).
  - Booleans are emitted as lowercase `true`/`false` (via `tt_bool`), not
    `0`/`1`.
  - Scalar strings are TOML basic strings: backslash first, then double
    quote, escaped to `\\` and `\"`. Array items get the same per-item
    escaping and are joined with `", "` inside square brackets; empty arrays
    are `[]`.
  - The PEM, when a non-empty file is given, is emitted as a TOML
    multi-line literal string: `certificate = '''` on its own line, the file
    content normalized through `awk 1` (trailing newline guaranteed, so the
    closing delimiter sits on its own line), then `'''` immediately followed
    by a newline and the next key. With no file (or an empty one): the exact
    text `certificate = ""`.
  - `mtu_size` is a bare (unquoted) number.
- **Testing**: `tests/run.sh` runs every `tests/test_*.sh` from the repo root
  in a fresh `TT_TEST_TMP` with stdin closed; `tests/lib.sh` provides
  `assert_eq`, `assert_contains`, `assert_exit`, `tt_test_summary`.
- **Target Platform**: OpenWrt routers (busybox ash/awk); development on
  macOS (BSD tools) and Linux CI.

## Research

### Behavior of the current implementation (observed by execution only)

Ran the current `gen-config` against
`tests/fixtures/records/{minimal,full,bypass}.tsv` with and without a PEM
file, plus temp TSV cases for the stale reference and an unknown profile
mode, and with a missing-credentials records file.
Facts pinned (these are the byte-level targets for the golden diff):

- Emission order and blank-line layout confirmed as described above; key
  set exactly as listed in the issue contract.
- Defaults: `main.log_level` → `info`, `network.mtu` → `1350`,
  `endpoint.protocol` → `http2`, `endpoint.post_quantum` → `1`,
  `endpoint.has_ipv6` → `1`, `endpoint.skip_verification` → `0`,
  `endpoint.anti_dpi` → `0`. All boolean-sourced keys render `true`/`false`.
- Profile resolution (observed): `rprofile=$(tt_get endpoint.routing_profile)`;
  the profile mode is read only when `rprofile` is non-empty AND
  `routing_profile.name` equals it; the `case` on the mode: `bypass` →
  `vpn_mode = "selective"` with `exclusions` from `routing_profile.vpn_rules`;
  `vpn` → `"general"` with `exclusions` from `routing_profile.bypass_rules`;
  **any other value** — empty (no assignment or stale reference) or an
  unknown non-empty mode — → legacy `"general"` with `exclusions` from
  `domains.direct`. `domains.direct` never leaks while a profile matches.
- `custom_sni` and `client_random` are **always** emitted, between
  `password` and `skip_verification`, TOML-escaped, as `custom_sni = ""` /
  `client_random = ""` when unset.
- Escaping: password `pa"ss\with` (full fixture) renders as
  `password = "pa\"ss\\with"`. The fixture line actually contains a third
  tab-separated token after the password; the records accessors print only
  field 2, so that token is ignored — `gen-config`'s password is exactly
  `pa"ss\with`.
- PEM normalization: a PEM file with and without a trailing newline produces
  **identical** output (the trailing newline is added when absent), i.e. the
  closing `'''` always lands on its own line before the next key.
- Empty/absent PEM → literal `certificate = ""`.
- Missing credentials: stderr `gen-config: <message>`, exit 1, checked in
  this order: `endpoint.hostname`, `endpoint.username`, `endpoint.password`,
  then `endpoint.address` (count must be ≥ 1). Messages end with
  `is not set`.
- A missing first argument fails via the shell's `:?` guard (diagnostic + a
  non-1 exit) — outside the issue's exit-1 contract; the same guard style
  preserves identical behavior.
- Executable bit of the script is `100755`; the script runs under `set -u`.

### Contract discrepancies found (issue text vs. actual code)

1. **Boolean notation**: the issue writes `has_ipv6 = <0|1>`,
   `skip_verification = <0|1>`, `anti_dpi = <0|1>` and
   `post_quantum_group_enabled = <endpoint.post_quantum|1>`. The actual
   output (and the inherited test's assertions) is lowercase `true`/`false`
   — the `<0|1>` shorthand really means "the `tt_bool` result with this
   default". The byte contract is `true`/`false`; the plan and the golden
   diff use `true`/`false`.
2. **Empty certificate**: the issue says "empty string `''` when no file";
   the actual literal emitted is `certificate = ""` (double-quoted empty
   basic string). The byte contract is `certificate = ""`.
3. **Unknown profile mode**: the issue says `routing_profile.mode` == `vpn`
   "(or anything else non-empty)" → general + bypass_rules. The actual
   code's `case` falls through to the legacy branch for **any** mode other
   than exactly `bypass`/`vpn` — an unknown non-empty mode yields
   `general` + `domains.direct`. The plan, goldens, and rewritten test
   follow the code (byte-identical output is the contract); the issue
   contract divergence is reported for the caller to align `issue.md`.

No other discrepancies: key set, order, defaults, escaping rules, PEM
emission, diagnostics and exit codes match the issue contract as written.

### TOML validity of the generated output

The output uses only basic strings (`""`), multi-line literal strings
(`'''…'''`), bare booleans/numbers, and one-element-or-empty arrays — all
plain TOML 1.0 constructs. A local spot-check is possible with Python
`tomllib` (available in this environment, Python 3.11+); on the router the
client's `setup_wizard --settings` path is the ultimate oracle.

### Clean-room method

- The replacement is written from the issue's contract section plus the
  observed behavior facts above. The inherited file's text is **not**
  opened/consulted while writing the new implementation (mirrors the TT-02
  rule).
- The preserved copy of the old script under `/tmp` is used only as an
  executable for byte-diffing, never as a text source.
- The plan deliberately does not reproduce the current TOML template text.

### Tooling

- `sh -n` for syntax; `shellcheck -s sh` is a CI gate (not installed in the
  local environment; run it wherever available, fall back to `sh -n` +
  CI for the local check).
- `diff` for golden comparisons; `shasum -a 256` for checksum evidence.
- Python 3.11+ `tomllib` available locally for the TOML parse spot-check.

## Entities

### `gen-config` (shell script, `/usr/libexec/trusttunnel/gen-config`)

- **Input**: records TSV path (`$1`), optional PEM path (`$2`); sourced
  `records.sh` via `TT_LIBDIR` (default: script's directory).
- **Behavior**: validates the four mandatory records (die + exit 1 with
  `gen-config: <message>` on stderr); otherwise resolves the routing
  profile for `vpn_mode`/`exclusions` (matrix in Task 3), always emits
  `custom_sni`/`client_random`, and emits the `client.toml`
  byte contract on stdout (see issue contract + Research).
- **Validation**: field set/order/format byte-identical to today; output
  parses as TOML.
- **States**: n/a (stateless generator).

### Generated `client.toml`

- **Fields**: exactly the key set and order listed in the issue's
  "Contract to reproduce" (top-level scalars + `exclusions`, `[endpoint]`,
  `[listener.tun]`), including the two blank separator lines and the final
  newline.
- **Relationships**: consumed by the Apache-2.0 TrustTunnel client binary;
  the `[listener.tun]` schema matches `setup_wizard`'s reference config
  (no `device_name`, no `use_existing`, empty route lists — routing is owned
  by the package).
- **Validation**: must parse by the client; TOML-escaped scalars; `true`/
  `false` booleans; bare `mtu_size`.

## Contracts

- Normative spec: `issue.md` § "Contract to reproduce" plus the
  clarifications in Research (booleans render `true`/`false`; empty
  certificate is `certificate = ""`; profile modes other than
  `bypass`/`vpn` fall through to the legacy branch).
- Dependency interface: `records.sh` accessors per TT-02
  (`tt_get`/`tt_list`/`tt_bool`/`tt_count`), pinned by `test_records.sh`.
- No API endpoints involved.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config` | Rewrite | Clean-room reimplementation; same path, same behavior, mode `100755` |
| `tests/test_gen_config.sh` | Rewrite | New test text, same behavioral assertions (contract fields, escaping, PEM, exit codes) |
| `/tmp/tt04-genconfig-goldens/` | Create (transient, outside the repo) | Copy of the old binary + 6 golden `client.toml` outputs + dummy PEM + checksums; **never committed**; deleted before issue closure |

## Tasks

### [ ] Task 1: Capture golden outputs from the current implementation

Transient evidence for the byte-equivalence oracle. Everything lives in a
scratch directory outside the repo; nothing is committed.

**Precondition**: TT-02 landed — `tests/test_records.sh` green,
`sh tests/run.sh` green before this task.

**Files:**

- Create (scratch, outside repo): `/tmp/tt04-genconfig-goldens/`

- [ ] **Step 1: Create the scratch area and preserve the old binary**

```sh
G=/tmp/tt04-genconfig-goldens
mkdir -p "$G/old" "$G/new"
cp packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config "$G/old/gen-config"
```

Expected: `$G/old/gen-config` exists and is executable. This preserved copy
is what the final byte-diff runs against — the repo file gets replaced in
Task 3.

- [ ] **Step 2: Create the fixed PEM fixture**

```sh
G=/tmp/tt04-genconfig-goldens
printf -- '-----BEGIN CERTIFICATE-----\nMIIBdummy\n-----END CERTIFICATE-----\n' > "$G/cert.pem"
```

Expected: 3-line dummy PEM **with** trailing newline (the exact content the
rewritten test will use, so goldens and tests cover the same PEM path).

- [ ] **Step 3: Capture the six golden outputs**

```sh
G=/tmp/tt04-genconfig-goldens
GEN=packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config
sh "$GEN" tests/fixtures/records/minimal.tsv              > "$G/minimal.toml"
sh "$GEN" tests/fixtures/records/minimal.tsv "$G/cert.pem"  > "$G/minimal-pem.toml"
sh "$GEN" tests/fixtures/records/full.tsv                 > "$G/full.toml"
sh "$GEN" tests/fixtures/records/full.tsv  "$G/cert.pem"     > "$G/full-pem.toml"
sh "$GEN" tests/fixtures/records/bypass.tsv               > "$G/bypass.toml"
sh "$GEN" tests/fixtures/records/bypass.tsv "$G/cert.pem"   > "$G/bypass-pem.toml"
```

Expected: all six files non-empty; each starts with the header comment and
ends with `change_system_dns = false` and a single trailing newline.

- [ ] **Step 4: Record checksums**

```sh
G=/tmp/tt04-genconfig-goldens
shasum -a 256 "$G"/*.toml > "$G/checksums.sha256"
```

Expected: `checksums.sha256` lists all six goldens.

- [ ] **Step 5: Sanity-diff the goldens against the preserved old binary**

```sh
G=/tmp/tt04-genconfig-goldens
diff "$G/minimal.toml"        <(sh "$G/old/gen-config" tests/fixtures/records/minimal.tsv)             && echo OK
diff "$G/minimal-pem.toml"    <(sh "$G/old/gen-config" tests/fixtures/records/minimal.tsv "$G/cert.pem") && echo OK
diff "$G/full.toml"           <(sh "$G/old/gen-config" tests/fixtures/records/full.tsv)                && echo OK
diff "$G/full-pem.toml"       <(sh "$G/old/gen-config" tests/fixtures/records/full.tsv  "$G/cert.pem")  && echo OK
diff "$G/bypass.toml"         <(sh "$G/old/gen-config" tests/fixtures/records/bypass.tsv)               && echo OK
diff "$G/bypass-pem.toml"     <(sh "$G/old/gen-config" tests/fixtures/records/bypass.tsv "$G/cert.pem") && echo OK
```

Expected: six `OK` — the goldens are reproducible from the old binary.

**Verification**: six `$G/*.toml` files + `checksums.sha256` exist; the
sanity diffs are empty. The goldens remain in `/tmp` for the transition and
are never staged or committed.

### [ ] Task 2: Rewrite `tests/test_gen_config.sh`

New test text (clean-room — no text copied from the inherited test), same
behavioral facts. Must pass against the **old** implementation, proving it
captures today's behavior.

**Files:**

- Rewrite: `tests/test_gen_config.sh`

- [ ] **Step 1: Write the rewritten test**

Keep the harness conventions (`#!/bin/sh`; `. "$(dirname "$0")/lib.sh"`;
repo-root-relative paths; per-test `TT_TEST_TMP` for the temp TSV fixture
cases, the dummy PEM and the bare records file; `assert_eq` /
`assert_contains` / `assert_exit`; `tt_test_summary` last; never read
stdin). Assertions to keep (from the contract and the observed behavior):

- header comment line present;
- fixed fields: `killswitch_enabled = false`,
  `exclusions_tcp_early_ack_enabled = true`,
  `exclusions_preresolve_enabled = true`, `change_system_dns = false`,
  `included_routes = []`, `excluded_routes = []`;
- invented keys absent: zero occurrences of `device_name` and
  `use_existing` in the minimal output;
- minimal fixture (no profile assigned — legacy): `vpn_mode = "general"`,
  `loglevel = "info"`, `mtu_size = 1350` (bare number),
  `hostname = "vpn.example.com"`, `addresses = ["1.2.3.4:443"]`,
  `username = "alice"`, `password = "s3cret"`, `custom_sni = ""` and
  `client_random = ""` (always emitted, empty when unset),
  `exclusions = []`, `upstream_protocol = "http2"`, `anti_dpi = false`,
  `post_quantum_group_enabled = true`, `has_ipv6 = true`,
  `skip_verification = false`, `dns_upstreams = []`,
  `certificate = ""`;
- full fixture (vpn-mode profile assigned): `vpn_mode = "general"` (kept
  by the vpn profile), `loglevel = "debug"`, `mtu_size = 1400`,
  `addresses = ["1.2.3.4:443", "[2001:db8::1]:443"]`,
  `password = "pa\"ss\\with"` (quote+backslash escaping),
  `custom_sni = "vpn.example.com"`, `client_random = "0a0b0c/0f0f0f"`
  (populated emission), `exclusions = ["bank.example", "*.local.example"]`
  (the profile's bypass_rules), zero occurrences of `legacy.example`
  (domains.direct must not leak while a profile is assigned),
  `upstream_protocol = "http3"`, `anti_dpi = true`,
  `post_quantum_group_enabled = false`, `skip_verification = true`,
  `has_ipv6 = false`,
  `dns_upstreams = ["tls://1.1.1.1", "quic://dns.adguard.com:8853"]`;
- bypass fixture (bypass-mode profile assigned): `vpn_mode = "selective"`,
  `exclusions = ["telegram.org", "1.2.3.0/24"]` (the profile's vpn_rules),
  zero occurrences of `bank.example` (bypass_rules are not exclusions in
  bypass mode) and zero occurrences of `legacy.example`;
- stale-reference fallback (temp `stale.tsv` in `TT_TEST_TMP` naming a
  profile that does not exist, e.g. `endpoint.routing_profile` = `Ghost`
  with no matching `routing_profile.name`): `vpn_mode = "general"` and
  `exclusions = ["bank.example"]` from `domains.direct`;
- unknown-mode fallback (temp TSV in `TT_TEST_TMP` with a matching
  `routing_profile.name` whose `routing_profile.mode` is neither `bypass`
  nor `vpn`, e.g. `smart`): falls through to the legacy branch —
  `vpn_mode = "general"` with `exclusions` from `domains.direct` (pins
  the code's case semantics; see Research discrepancy 3);
- PEM case (dummy cert written into `TT_TEST_TMP`, passed as `$2`):
  `certificate = '''` present, the PEM body (`-----END CERTIFICATE-----`)
  present verbatim; `certificate = ""` in the minimal output without a
  PEM;
- missing credentials (records file with only `main.enabled`): `assert_exit
  1`, and the stderr captured from a direct run contains `gen-config:` and
  `endpoint.hostname is not set`.

- [ ] **Step 2: Run the rewritten test against the OLD implementation**

```sh
TT_TEST_TMP=$(mktemp -d) sh tests/test_gen_config.sh < /dev/null
```

Expected: PASS — summary line reports 0 failed (the repo still holds the
old `gen-config`, so this run exercises it).

- [ ] **Step 3: Run the whole suite for regression**

```sh
sh tests/run.sh
```

Expected: `== all tests passed`.

**Verification**: rewritten test green against the old implementation;
full suite green.

### [ ] Task 3: Implement the new `gen-config` from the contract

Clean-room: write from the issue contract, the Research facts, and the
fixtures. Do **not** open the inherited file's text while writing; the old
binary copy under `/tmp` is for execution only. The plan intentionally does
not contain the old template text — the implementer works from the key
set/order and formatting facts in the issue and in Research.

**Files:**

- Rewrite: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config`

- [ ] **Step 1: Write the new implementation**

Behavior contract to implement (new expression, any structure that satisfies
it):

- `#!/bin/sh` shebang, `set -u`;
- usage: `gen-config <records-file> [pem-file]`; first argument required
  (fail with a clear diagnostic), second optional;
- source `records.sh` from `TT_LIBDIR` (default: the script's own
  directory) before setting `TT_RECORDS` from the first argument;
- validate in order — `endpoint.hostname`, `endpoint.username`,
  `endpoint.password` non-empty, and at least one `endpoint.address` (via
  the records count); on failure print `gen-config: <key> is not set` to
  stderr and exit 1;
- read the remaining values with their defaults: `main.log_level` → `info`,
  `network.mtu` → `1350`, `endpoint.protocol` → `http2`,
  `endpoint.post_quantum` → `1`, `endpoint.has_ipv6` → `1`,
  `endpoint.skip_verification` → `0`, `endpoint.anti_dpi` → `0`; booleans
  render lowercase `true`/`false` (consume `tt_bool`'s output directly);
  `endpoint.custom_sni` and `endpoint.client_random` are read with no
  default and **always** emitted;
- routing-profile resolution (drives `vpn_mode` and `exclusions`; mirrors
  the code's `case` semantics exactly):
  - `rprofile=$(tt_get endpoint.routing_profile)`; read
    `routing_profile.mode` only when `rprofile` is non-empty AND
    `routing_profile.name` equals it (no assignment or stale reference
    leaves the mode empty);
  - `case` on the mode: `bypass` → `vpn_mode = "selective"`, `exclusions` =
    all `routing_profile.vpn_rules` values; `vpn` → `vpn_mode = "general"`,
    `exclusions` = all `routing_profile.bypass_rules` values; **any other
    value** (empty, or an unknown non-empty mode) → legacy: `vpn_mode =
    "general"`, `exclusions` = all `domains.direct` values;
  - `domains.direct` must never leak while a profile matches (only the
    legacy branch reads it);
- emit on stdout, in this order and with exactly one blank line between the
  top-level block and `[endpoint]`, and between `[endpoint]` and
  `[listener.tun]`:
  1. the header comment;
  2. `loglevel`, `vpn_mode` (from the resolution above), `killswitch_enabled`
     (`false` fixed), `post_quantum_group_enabled`, 
     `exclusions_tcp_early_ack_enabled` (`true` fixed),
     `exclusions_preresolve_enabled` (`true` fixed), `exclusions` (from the
     resolution above);
  3. `[endpoint]`: `hostname`, `addresses`, `has_ipv6`, `username`,
     `password`, `custom_sni`, `client_random`, `skip_verification`,
     `certificate`, `upstream_protocol`, `anti_dpi`, `dns_upstreams`;
  4. `[listener.tun]`: `included_routes = []`, `excluded_routes = []`,
     `mtu_size` (bare number), `change_system_dns` (`false` fixed);
- TOML escaping: for every scalar string (loglevel, hostname, username,
  password, custom_sni, client_random, protocol) escape backslash first
  then double quote; build each array (`exclusions`, `addresses`,
  `dns_upstreams`) from the full list of records values, escaping every
  item identically and joining with `", "` inside square brackets; empty
  lists render `[]`;
- certificate: if a PEM path was given and the file is non-empty, print
  `certificate = '''`, the file content normalized through `awk 1` (so the
  closing delimiter always starts on its own line), then `'''` followed by a
  newline; otherwise print exactly `certificate = ""`;
- end the output with a single newline after the last line; no other
  keys, no extra blank lines;
- the script must be executable (`100755`).

- [ ] **Step 2: Syntax-check and set the mode**

```sh
sh -n packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config
chmod 755 packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config
```

Expected: `sh -n` silent; `stat` shows `755`.

**Verification**: implementation exists at the same path, is executable,
syntax-checks clean. (Byte-equivalence and tests are Task 4.)

### [ ] Task 4: Verify — tests, golden diff, lint, exec bit, suite, git state

**Files:**

- Run/check: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config`,
  `tests/test_gen_config.sh`, `/tmp/tt04-genconfig-goldens/`

- [ ] **Step 1: Run the rewritten test against the NEW implementation**

```sh
TT_TEST_TMP=$(mktemp -d) sh tests/test_gen_config.sh < /dev/null
```

Expected: PASS, 0 failed.

- [ ] **Step 2: Golden byte-diff — old vs new, all six cases**

```sh
G=/tmp/tt04-genconfig-goldens
GEN=packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config
sh "$GEN" tests/fixtures/records/minimal.tsv              > "$G/new/minimal.toml"
sh "$GEN" tests/fixtures/records/minimal.tsv "$G/cert.pem"  > "$G/new/minimal-pem.toml"
sh "$GEN" tests/fixtures/records/full.tsv                 > "$G/new/full.toml"
sh "$GEN" tests/fixtures/records/full.tsv  "$G/cert.pem"     > "$G/new/full-pem.toml"
sh "$GEN" tests/fixtures/records/bypass.tsv               > "$G/new/bypass.toml"
sh "$GEN" tests/fixtures/records/bypass.tsv "$G/cert.pem"   > "$G/new/bypass-pem.toml"
diff "$G/minimal.toml"     "$G/new/minimal.toml"     && echo "minimal OK"
diff "$G/minimal-pem.toml" "$G/new/minimal-pem.toml" && echo "minimal-pem OK"
diff "$G/full.toml"        "$G/new/full.toml"        && echo "full OK"
diff "$G/full-pem.toml"    "$G/new/full-pem.toml"    && echo "full-pem OK"
diff "$G/bypass.toml"      "$G/new/bypass.toml"      && echo "bypass OK"
diff "$G/bypass-pem.toml"  "$G/new/bypass-pem.toml"  && echo "bypass-pem OK"
```

Expected: six `OK` — byte-identical on all six cases (acceptance
criterion: golden byte-diff empty).

- [ ] **Step 3: TOML parse spot-check**

```sh
python3 - <<'EOF'
import tomllib
for f in ["/tmp/tt04-genconfig-goldens/new/minimal.toml",
          "/tmp/tt04-genconfig-goldens/new/minimal-pem.toml",
          "/tmp/tt04-genconfig-goldens/new/full.toml",
          "/tmp/tt04-genconfig-goldens/new/full-pem.toml",
          "/tmp/tt04-genconfig-goldens/new/bypass.toml",
          "/tmp/tt04-genconfig-goldens/new/bypass-pem.toml"]:
    with open(f, "rb") as fh:
        tomllib.load(fh)
    print("parses:", f)
EOF
```

Expected: all six parse. (On the router: the client's
`setup_wizard --settings` path is the ultimate oracle.)

- [ ] **Step 4: Lint**

```sh
shellcheck -s sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config tests/test_gen_config.sh
```

Expected: clean. `shellcheck` is a CI gate; if it is not installed locally,
run `sh -n` on both files (must be silent) and note that the CI workflow
covers the real check.

- [ ] **Step 5: Executable bit and full suite**

```sh
sh tests/run.sh
git ls-files -s packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config
```

Expected: `== all tests passed`; mode `100755` for `gen-config`.

- [ ] **Step 6: Git state — no stray files, no goldens committed**

```sh
git status --short
```

Expected: only the two intended files modified
(`packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config`,
`tests/test_gen_config.sh`); no `*.old`, no backup copies, nothing from
`/tmp/tt04-genconfig-goldens/` staged. Commit the two files with a
single-issue message (e.g. `gen-config: independent reimplementation`),
then delete the scratch area (`rm -rf /tmp/tt04-genconfig-goldens`) — the
goldens were transient transition evidence and must not outlive the issue.

**Verification**: rewritten test green; six golden diffs empty; TOML
spot-check passes; shellcheck clean; exec bit `100755`; full suite green;
`git status` shows exactly the two files; scratch area removed.

## Out of Scope

- Any change to `client.toml` fields, order, or formatting (byte-identical
  output is the requirement — no "improvements", including the
  `[listener.tun]` schema).
- Changing `records.sh` (TT-02) or any other libexec script.
- Fixing unrelated bugs found along the way — note them, do not fix (per
  PRD "Out of Scope").
- Committing the golden outputs or any copy of the old implementation.

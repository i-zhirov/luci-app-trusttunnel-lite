# Implementation Plan: uci-export

- **Created**: 2026-09-08
- **Revised**: 2026-09-09 (revision addressing all review findings)
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-03/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation: behavior/contract targets only, no code from the inherited file may appear in the plan; TDD-ordered tasks; baseline capture first; golden byte-diff; `test_init_apply.sh` schema parse must keep working; no `set -u`; executable bit 100755."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`uci-export` changed — the contract in the issue was updated accordingly;
this plan is actualized to the rebased file:

- **11 endpoint scalars** join the scalar loop: the pre-rebase 8
  (`hostname`, `username`, `password`, `protocol`, `anti_dpi`,
  `post_quantum`, `skip_verification`, `has_ipv6`) plus `custom_sni`,
  `client_random`, `routing_profile`.
- **Resolved-profile export block** after the endpoint lists: the assigned
  profile NAME is read with `uci -q get trusttunnel.endpoint.routing_profile`
  (silent, exit 1 when absent → empty), then `config_foreach find_profile
  routing_profile` matches it against the `routing_profile` sections' `name`
  option. When a section matches, emit `routing_profile.name` (only when
  non-empty), `routing_profile.mode`, and the list keys
  `routing_profile.vpn_rules` / `routing_profile.bypass_rules` (one line per
  value, via the `_emit_one` helper with a `_KEY` prefix variable). Nothing
  is exported when `endpoint.routing_profile` is empty or names no existing
  section.
- **Marker line**: the source must carry the comment `# schema-keys:
  routing_profile.name routing_profile.mode routing_profile.vpn_rules
  routing_profile.bypass_rules` before the emission loops
  (`schema_keys()` in `test_init_apply.sh` parses it); the profile loops
  themselves must NOT use the `scalar` keyword (see Research §2), so the
  marker line is the only parse source for these 4 keys — keep it in sync
  with the emitted options.
- **Schema size is now 26 keys** — 2 main + 11 endpoint scalars +
  `endpoint.address` + `endpoint.dns_upstream` + 4 marker profile keys +
  6 network + `domains.direct` (issue.md's contract text agrees: "Total
  schema: 26 keys"). This plan pins **26** everywhere.
- Task 2's tripwire step: the schema parse must yield 26 keys, and the
  golden capture must include the profile-resolution cases (assigned
  profile, empty `routing_profile`, stale name) — the scratch scaffold
  therefore needs a `uci` shim plus `config_foreach` support (Task 1).
- The golden diff (Task 3) compares old-vs-new against the CURRENT
  (rebased) implementation.

## Summary

Replace the inherited GPL-2.0 `uci-export` script with a functionally
identical, independently written POSIX shell script that reads the
`trusttunnel` UCI config via OpenWrt's `/lib/functions.sh`
(`config_load trusttunnel`) and prints the records TSV on stdout:
`section.option<TAB>value`, one line per value, repeated lines for list
options. The emitted key set and order are fixed by the issue contract
(26 keys) and are the canonical schema for the init script's
change-classifier. The replacement must keep a source shape that
`tests/test_init_apply.sh`'s `schema_keys()` awk parser can still parse
(it learns the schema from this file's text: the `# schema-keys:` marker
line, the `for o in` loops with the `scalar` keyword, line-start `listopt`
lines, two-TAB continuations), must not use `set -u`, and must keep the
`100755` mode in the git index. Equivalence is proven by a byte-diff of
the OLD vs NEW script's output on identical UCI input, captured before the
rewrite in a scratch container; the fixture files are only a key-set/shape
reference, never a byte-comparison target.

## Technical Context

- **Language/Version**: POSIX shell (`/bin/sh`); no bashisms; runs under
  OpenWrt's BusyBox ash and macOS `/bin/sh`.
- **Primary Dependencies**: `/lib/functions.sh` (OpenWrt) — `config_load
  trusttunnel`, `config_get`, `config_list_foreach`, `config_foreach`. The
  current file additionally calls the `uci` binary directly
  (`uci -q get trusttunnel.endpoint.routing_profile`), so the golden
  scaffold must shim `uci` as well. Absent on the macOS dev host, which is
  why the golden capture needs a stub/container (see Research §3).
- **Storage**: none — the script is a pure stdout producer; the init script
  redirects its output to `$RECORDS.new` and `mv`s it over `settings.tsv`.
- **Testing**: `sh tests/run.sh` (suite harness with `assert_*` in
  `tests/lib.sh`); the schema-completeness check lives inside
  `tests/test_init_apply.sh` (fork-written, kept as-is, is the oracle);
  pinned shellcheck `koalaman/shellcheck:v0.11.0 -s sh`; CI executable-bit
  gate (`git ls-files -s` must show `100755`); `sh -n` syntax check.
- **Target Platform**: OpenWrt routers (apk/opkg); dev host macOS.

## Research

### 1. Observed behavior of the current uci-export (the behavioral contract)

Facts established by reading the current file's output contract and the
init script's call site (`regenerate()` in
`root/etc/init.d/trusttunnel`):

- **Call contract**: executed directly (`"$LIBDIR/uci-export" >
  "$RECORDS.new"`); must exit non-zero when config loading fails so
  `regenerate()` aborts and removes `.new`; exits 0 on success.
- **Emission order** (must match byte-for-byte):
  1. `main.enabled`, `main.log_level` (scalars)
  2. `endpoint.hostname`, `endpoint.username`, `endpoint.password`,
     `endpoint.protocol`, `endpoint.anti_dpi`, `endpoint.post_quantum`,
     `endpoint.skip_verification`, `endpoint.has_ipv6`,
     `endpoint.custom_sni`, `endpoint.client_random`,
     `endpoint.routing_profile` (11 scalars)
  3. `endpoint.address`, `endpoint.dns_upstream` (lists — one line per
     value)
  4. **Resolved-profile block** (only when `endpoint.routing_profile`
     names an existing `routing_profile` section, resolved via
     `config_foreach`): `routing_profile.name` (only when non-empty),
     `routing_profile.mode`, `routing_profile.vpn_rules` (list),
     `routing_profile.bypass_rules` (list). Empty `routing_profile` or a
     stale name → no `routing_profile.*` lines at all.
  5. `network.mtu`, `network.table`, `network.fwmark`,
     `network.blackhole_on_down`, `network.include_router_traffic`,
     `network.lan_devices` (6 scalars)
  6. `domains.direct` (list — one line per value; the legacy fallback,
     still exported for the no-profile case)
- **Empty scalars are skipped**: a `scalar` value that is empty or absent
  produces no line. Evidence: the default config has `option lan_devices ''`
  and `tests/fixtures/records/full.tsv` has no `network.lan_devices` line;
  `endpoint.hostname ''` is likewise absent from output until set. A value
  of `0` IS emitted (`-n "0"` is true) — `main.enabled 0` is present in the
  default config and `full.tsv` carries `network.blackhole_on_down 1`,
  `main.enabled 1`, `endpoint.post_quantum 0`, `endpoint.has_ipv6 0`.
- **List options**: each configured value gets its own line; an absent list
  emits nothing (no line at all, no empty-value line).
- **`endpoint.certificate` is deliberately excluded** (multi-line PEM cannot
  be a record value); it is handled separately by the init script as
  `endpoint.pem`. No other key may ever be emitted — foreign sections/options
  in the UCI config must not leak into records.
- **Values pass through unescaped**: quotes, backslashes, and even an
  embedded TAB in a value stay verbatim (see `endpoint.password` in
  `full.tsv`); only the key/value separator is a TAB, values cannot contain
  a newline.
- **No `set -u`**: `/lib/functions.sh` reads uninitialized variables
  (`IPKG_INSTROOT` at source time, `CONFIG_LIST_STATE` inside
  `config_load`); under `set -u` the script dies before printing anything.
  This is a behavioral requirement. The `set -u` used by `tests/run.sh` is
  fine — it applies to the harness, not to sourced/executed package code.
- **Exit status of helper calls**: emission helpers always return success so
  a missing option is not an error.
- **Profile resolution mechanics**: the assigned profile name is read by the
  `uci` binary (`uci -q get trusttunnel.endpoint.routing_profile
  2>/dev/null || profile_want=""`) — NOT via `/lib/functions.sh`; the
  match against `routing_profile` sections uses `config_foreach find_profile
  routing_profile`, where `find_profile` compares the section's `name`
  option to `profile_want` and records the section id. This is a hard
  dependency of the golden scaffold (Research §3).

### 2. The schema parser in `tests/test_init_apply.sh` — source-shape constraints

`schema_keys()` in `test_init_apply.sh` (fork-written, kept as the oracle)
extracts the key set by awk-parsing uci-export's SOURCE text, not by running
it. The parser has branches with literal token patterns, so the rewrite must
keep the following source shape (structural requirement, not a style
preference — violating it silently drops keys from the parsed schema):

- **Marker line**: a line starting with the literal comment
  `# schema-keys: ` followed by the 4 profile keys
  (`routing_profile.name routing_profile.mode routing_profile.vpn_rules
  routing_profile.bypass_rules`). The parser's marker branch prints each
  word on that line verbatim; it must sit in the source before the
  `for o in` loops, and its keys must stay in sync with the emitted
  options.
- **Loop token**: lines must start with the literal text `for o in`
  (the loop variable name is pinned to `o` by the parser regexes).
- **One-line loops**: a line `for o in <opts...>; do scalar <section> "$o"; done`
  (the word `scalar` must appear on the same line; the section name is taken
  as the word right after `scalar`; options are the words before the `;`).
  The `main` group (2 options) uses this shape.
- **Multi-line loops**: a line starting with `for o in` that does NOT contain
  `scalar` (options accumulate until `;`/`do`); continuation lines must start
  with exactly two TABs (the parser matches `/^\t\t/` and strips `\`
  continuations); the body line must contain the word `scalar` followed by
  the section name. The current endpoint (11 options) and network (6 options)
  groups use this shape.
- **The profile loops are deliberately `scalar`-FREE**: the current file
  emits the profile block with `for o in name mode` + `config_get`/`printf`
  and `for o in vpn_rules bypass_rules` + `config_list_foreach`/`_emit_one`
  — no `scalar` word, so the parser's loop branches never see them (their
  option words are overwritten by the later network loop before any
  `/scalar/` line). The 4 profile keys enter the parse ONLY via the marker
  line. The new file must keep this shape: profile keys must not be written
  with the `scalar` keyword (that would emit section-id-keyed keys) and the
  marker line must stay the sole carrier.
- **List options**: a line starting with `listopt <section> <option>` emits
  exactly one key (`$2.$3`); the three lists (`endpoint.address`,
  `endpoint.dns_upstream`, `domains.direct`) need such lines.
- **Key set**: the parse must yield exactly the same **26 keys** as today
  (2 main + 11 endpoint scalars + address + dns_upstream + 4 marker profile
  keys + 6 network + domains.direct). The sanity gate requires ≥15 keys; the
  completeness gate then requires every parsed key to be explicitly
  classified by the (untouched) `change_class` — any extra or missing key
  fails `test_init_apply.sh`, since unknown keys map to `restart_full` and
  are counted as "missing". The classifier already covers all 26 (including
  `routing_profile.name`/`mode`/`vpn_rules`/`bypass_rules` and
  `endpoint.routing_profile` → `restart`); the new file must not add or drop
  any.
- `endpoint.certificate` must stay OUT of the parse (it is not emitted via
  these constructs) — it is classified separately by the init script.
- Note: the oracle's own comment at `test_init_apply.sh` line ~231 still says
  "25 keys", but the parse of the current file yields 26 and the threshold is
  deliberately lower (≥15); the test is the untouched oracle and is NOT
  modified by this plan.

Note: the function bodies behind the `scalar`/`listopt` call sites are free
expression; only the call-site tokens above are pinned.

### 3. Running uci-export on the dev host (golden capture mechanics)

`uci-export` sources `/lib/functions.sh` by absolute path AND calls the
`uci` binary directly; macOS has neither. Two ways to capture the golden
output:

- **Scratch stubs + container (primary, reproducible)**: write fresh
  scaffolding in a scratch dir (NEW test scaffolding written from OpenWrt's
  documented API, not derived from the inherited file; lives only in the
  scratch dir and is deleted at the end):
  - `functions.sh` stub implementing the FOUR functions the script calls —
    `config_load <name>`, `config_get <var> <section> <option>`,
    `config_list_foreach <section> <option> <func>`, `config_foreach <func>
    <type>` — by parsing a scratch UCI config file given in `uci export`
    syntax (`config <type> '<name>'`, `option <key> '<value>'`,
    `list <key> '<value>'`).
  - `uci` shim executable on PATH (e.g. `$TMPDIR/tt03-scratch/bin/uci`)
    answering exactly the call the script makes: `uci -q get
    trusttunnel.endpoint.routing_profile` — prints the `routing_profile`
    option of the `endpoint` section from the same scratch config; `-q`
    means no stderr; exit 1 (no output) when the option is absent so the
    script's `|| profile_want=""` fallback is exercised.
  - Run: `docker run --rm -e PATH=/scratch/bin:/usr/sbin:/usr/bin:/sbin:/bin
    -v "$PWD:/src" -v "$TMPDIR/tt03-scratch:/scratch" -w /src alpine sh -c
    'mkdir -p /lib && cp /scratch/functions.sh /lib/functions.sh && sh
    /src/packages/.../uci-export'` (root in the container may write `/lib`;
    busybox ash is POSIX). If docker is unavailable, the same stubs can be
    dropped into `/lib` and `/usr/bin` on a real OpenWrt router or the check
    can run against the real config there.
- **Live router (per the issue)**: `uci export trusttunnel` into a scratch
  config and byte-compare old vs new output.

The golden file is the OLD script's RAW OUTPUT — a fact, not expression;
using it as the equivalence oracle is the PRD's own methodology (SC-003).

### 4. Fixtures as the shape reference (NOT byte-comparison targets)

- `tests/fixtures/records/full.tsv` — 31 lines (28 data lines + 3 comment
  lines); its data-line key set is the 25 keys present in the file
  (`network.lan_devices` is absent): repeated lines for `endpoint.address`
  (2), `endpoint.dns_upstream` (2), `routing_profile.bypass_rules` (2);
  the password value contains a double quote, a backslash, and an embedded
  TAB (proves pass-through); no `network.lan_devices`, no
  `endpoint.certificate`; the assigned profile is present
  (`endpoint.routing_profile Default` + `routing_profile.*` block with
  `mode vpn`). It is records INPUT data and is NOT byte-comparable with
  uci-export output: it contains comment lines and its line order differs
  (the network block precedes the profile block, while the script emits
  the profile block before the network block). Use it only as the
  key-set/shape reference for the full config (which values must be
  exercised, which keys must appear, list repetition, pass-through) —
  the coverage check is "the 25 keys present in full.tsv appear, no
  foreign keys, the profile block is present", NOT equality with the
  full 26-key schema (the golden-full.tsv raw output covers all 26).
- `tests/fixtures/records/minimal.tsv` — 6 lines; used for the "only set
  keys are emitted" check.
- `tests/fixtures/records/bypass.tsv` — bypass-mode profile shape
  (`routing_profile.mode bypass`, `vpn_rules` repeated); reference for the
  profile block's list repetition.
- The fixtures are kept as-is; no new committed test file is added for
  uci-export (per the issue: schema is tested via `test_init_apply.sh` +
  golden byte-diff). **Never** `cmp` a fixture against golden/new output
  byte-for-byte.

### 5. CI gates relevant to this file

- Executable bits (ci.yml): `git ls-files -s -- <file>` must be `100755`
  in the index — so `chmod 755` before `git add` (or `git update-index
  --chmod=+x` after).
- Shellcheck (ci.yml): pinned `koalaman/shellcheck:v0.11.0 -s sh` with the
  file listed explicitly. The file's disable convention must be kept:
  `# shellcheck disable=SC1091` on the line directly above
  `. /lib/functions.sh` (unresolvable include), and
  `# shellcheck disable=SC2317,SC2154` directly above the `find_profile`
  callback (SC2317: invoked indirectly by `config_foreach`, invisible to the
  linter; SC2154: `profile_want`/`profile_sec` assigned by `config_get` and
  inside the callback). ci.yml's own comment cites SC2317 as the reason the
  shellcheck version is pinned.
- Unit tests: `sh tests/run.sh`.
- `test_init_reload.sh` stubs uci-export in its sandbox (`UCI_EXPORT_RC`),
  so it never executes the real file — no dependency there.

## Entities

### Records TSV (output of uci-export)

- **Fields** (emission order = contract order, 26 keys):
  - `main.enabled`, `main.log_level` — scalars.
  - `endpoint.hostname`, `endpoint.username`, `endpoint.password`,
    `endpoint.protocol`, `endpoint.anti_dpi`, `endpoint.post_quantum`,
    `endpoint.skip_verification`, `endpoint.has_ipv6`,
    `endpoint.custom_sni`, `endpoint.client_random`,
    `endpoint.routing_profile` — scalars (11).
  - `endpoint.address`, `endpoint.dns_upstream` — lists, one line per value.
  - `routing_profile.name` (only when non-empty), `routing_profile.mode`,
    `routing_profile.vpn_rules`, `routing_profile.bypass_rules` — the
    resolved-profile block, emitted only when `endpoint.routing_profile`
    names an existing `routing_profile` section; lists one line per value.
  - `network.mtu`, `network.table`, `network.fwmark`,
    `network.blackhole_on_down`, `network.include_router_traffic`,
    `network.lan_devices` — scalars (6).
  - `domains.direct` — list, one line per value (legacy fallback).
  - `endpoint.certificate` — deliberately NOT exported (multi-line PEM;
    init script writes it to `endpoint.pem`).
- **Relationships**: read from the `trusttunnel` UCI config (sections
  `main`/`endpoint`/`network`/`domains` + `routing_profile` sections
  referenced by name); consumed by `records.sh`
  (`tt_list`/`tt_get`/`tt_bool`/`tt_count`), `gen-config`, `routing`, and
  the init script's `changed_keys` classifier.
- **Validation**: key set is closed (26 keys) — no foreign keys ever; empty
  scalar values produce no line; list values each produce one line; values
  pass through unescaped (quotes/backslashes/tabs allowed, newlines not).
- **States**: n/a (pure stdout stream; init script persists it atomically).

### uci-export source shape (parser contract)

- **Fields**: the marker comment `# schema-keys: routing_profile.name
  routing_profile.mode routing_profile.vpn_rules routing_profile.bypass_rules`
  before the loops; literal tokens `for o in`, `scalar <section> "$o"`,
  `listopt <section> <option>` at the positions the `schema_keys()` awk
  parser expects (one-line loops, two-TAB continuation lines, line-start
  `listopt`); the profile loops free of the `scalar` keyword; no `set -u`;
  `# shellcheck disable=SC1091` before `. /lib/functions.sh` and
  `# shellcheck disable=SC2317,SC2154` before the `config_foreach` callback.
- **Relationships**: this file is the canonical schema source for
  `test_init_apply.sh`; the init script's `change_class` classifies exactly
  its 26 keys.
- **Validation**: parse yields ≥15 keys (sanity), exactly the 26 known keys,
  and every key is explicitly classified (completeness).
- **States**: n/a.

## Contracts

- Issue TT-03 contract section (exact schema + ordering + exclusions) —
  the spec to implement from: `.sdd/.current/issues/TT-03/issue.md`
  (note: the issue's "Total schema: 25 keys" is a typo; the pinned count is
  26 — flagged for the caller).
- Shape reference: `tests/fixtures/records/full.tsv`,
  `tests/fixtures/records/minimal.tsv`, `tests/fixtures/records/bypass.tsv`
  (key-set/shape only, never byte-compared).
- Oracle: `tests/test_init_apply.sh` (fork-written, NOT modified).
- N/A — no API endpoints.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export` | Rewrite | New expression implementing the contract: `config_load trusttunnel`, fixed-order 26-key TSV emission, resolved-profile block (`uci -q get` + `config_foreach`), empty-scalar skip, `endpoint.certificate` excluded, no `set -u`, SC1091/SC2317/SC2154 disables, source-shape tokens + marker line for `schema_keys()`, mode `100755` |
| `tests/test_init_apply.sh` | Keep (untouched) | Oracle: schema parse + classification completeness must stay green |
| `tests/fixtures/records/*.tsv` | Keep (untouched) | Key-set/shape reference for the golden capture (never `cmp`-compared) |
| `tests/run.sh`, `tests/lib.sh` | Keep (untouched) | Harness conventions |
| scratch dir (e.g. `$TMPDIR/tt03-scratch/`, not committed) | Create, then Delete | Stub `functions.sh` (config_load/get/list_foreach/foreach), `bin/uci` shim, scratch UCI configs (full / empty-profile / stale-name / minimal), `golden-*.tsv`, `new-*.tsv` — the old-vs-new byte-diff oracle; removed in the final task |

## Tasks

### [x] Task 1: Baseline capture — record the current state and freeze the golden output

**Files:**

- Create (scratch, not committed): `$TMPDIR/tt03-scratch/functions.sh`,
  `$TMPDIR/tt03-scratch/bin/uci`, `$TMPDIR/tt03-scratch/full.uci`,
  `$TMPDIR/tt03-scratch/empty-profile.uci`,
  `$TMPDIR/tt03-scratch/stale-name.uci`,
  `$TMPDIR/tt03-scratch/minimal.uci`, `$TMPDIR/tt03-scratch/golden-*.tsv`

- [x] **Step 1: Record the pre-change suite result**

Run: `sh tests/run.sh` Expected: all green. Record the current test-file
count and assertion totals (including `test_init_apply.sh`'s own count) in
the issue's implementation notes — these are the baseline the final task
must reproduce. Do not assume pre-rebase numbers; re-measure now.
Baseline recorded (tree state `8ec241f`, 2026-09-09): 7 test files, 199
assertions, 0 failed; per file: test_deps 26, test_gen_config 47,
test_harness 5, test_init_apply 29, test_init_reload 21, test_records 31,
test_routing 40. See "Implementation notes" below.

- [x] **Step 2: Build the scratch UCI configs**

Write four configs in `uci export` syntax (`config <type> '<name>'`,
`option <key> '<value>'`, `list <key> '<value>'`):

1. `full.uci` — mirror the VALUES of `tests/fixtures/records/full.tsv`:
   `main.enabled 1`, `main.log_level debug`, `endpoint.hostname
   vpn.example.com`, the password value containing a double quote, a
   backslash, and a TAB, `endpoint.protocol http3`, anti_dpi/post_quantum/
   skip_verification/has_ipv6/custom_sni/client_random per `full.tsv`, two
   `endpoint.address` entries, two `dns_upstream` entries, `network.mtu
   1400`, `table 880`, `fwmark 0x9527`, `blackhole_on_down 1`,
   `include_router_traffic 1`, `lan_devices` ABSENT so it stays empty, one
   `domains.direct` entry (`legacy.example`), AND the assigned-profile case:
   `endpoint.routing_profile Default` plus a `config routing_profile 'p1'`
   section (`name Default`, `mode vpn`, `list vpn_rules telegram.org`, two
   `bypass_rules` entries `bank.example`, `*.local.example`). Also set
   `endpoint.certificate` to a multi-line-ish value to prove it is never
   emitted.
2. `empty-profile.uci` — same base, but NO `endpoint.routing_profile`
   option (and no profile sections): the no-profile case.
3. `stale-name.uci` — same base, `endpoint.routing_profile Ghost` with NO
   `routing_profile` section named `Ghost`: the stale-name case.
4. `minimal.uci` — only the `minimal.tsv` keys
   (`main.enabled`, `endpoint.hostname`, `endpoint.address`,
   `endpoint.username`, `endpoint.password`, `network.mtu`).

- [x] **Step 3: Write the scaffold — `functions.sh` stub + `uci` shim**

Fresh scaffolding (new expression, not derived from the inherited file),
written from OpenWrt's documented API:

- `functions.sh`: `config_load <name>` parses the scratch UCI file and
  returns 0; `config_get <var> <section> <option>` sets `<var>` to the
  option value (raw, preserving quotes/backslashes/tabs) or empty;
  `config_list_foreach <section> <option> <func>` calls `<func>` once per
  list value; `config_foreach <func> <type>` calls `<func> <section-id>`
  for every section of the given type (needed by the profile resolution).
- `bin/uci`: an executable shim answering `uci -q get
  trusttunnel.endpoint.routing_profile` from the same scratch config —
  print the value, exit 0; when absent, print nothing, exit 1 (`-q` =
  quiet, no stderr). The container PATH must include the shim's directory.

The config path may be wired via a fixed relative location or an
environment variable.

- [x] **Step 4: Capture the golden output from the OLD script**

Run the old `uci-export` with the stub installed as `/lib/functions.sh`
and the shim on PATH (docker alpine: `docker run --rm -e
PATH=/scratch/bin:/usr/sbin:/usr/bin:/sbin:/bin -v "$PWD:/src" -v
"$TMPDIR/tt03-scratch:/scratch" -w /src alpine sh -c 'mkdir -p /lib && cp
/scratch/functions.sh /lib/functions.sh && sh
/src/packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export'`;
or the same stubs on a live router). Run it against EACH of the four
configs and save the RAW output as `golden-full.tsv`, `golden-empty.tsv`,
`golden-stale.tsv`, `golden-minimal.tsv`. Record
`shasum -a 256 golden-*.tsv`. The goldens are the old script's raw
output — nothing is synthesized or reordered by hand.

- [x] **Step 5: Prove the goldens cover the required cases (fixtures as
  reference only)**

The fixtures are records INPUT data with comment lines and a different
line order — they are NEVER `cmp`-compared byte-for-byte with the goldens.
Use them only as a key-set/shape reference (e.g. compare sorted key sets
via `awk -F'\t' '{print $1}' | sort -u`):

- `golden-full.tsv` must contain exactly the 26-key schema (the raw
  output of the old script on the full scratch config), the
  `routing_profile.*` block present, and no `endpoint.certificate` lines;
  `full.tsv`'s data-line key set is a 25-key SUBSET of it (its
  `network.lan_devices` is absent) — the fixture comparison checks that
  the 25 fixture keys appear in the golden with no foreign keys, not
  set-equality with the full 26;
  repeated list keys (address, dns_upstream, bypass_rules) and the
  pass-through password value must be visible in the shape.
- `golden-empty.tsv` and `golden-stale.tsv` must contain the 22
  non-profile keys and NO `routing_profile.*` lines.
- `golden-minimal.tsv` must contain exactly the 6 `minimal.tsv` keys.

If a golden deviates, the scaffold or scratch config is wrong — fix the
scaffolding, not the script (the fixtures are not the oracle for output
bytes; the old script's raw output is).

**Verification**: suite baseline recorded (Step 1); four goldens captured
with recorded hashes; Step 5 coverage checks pass. The goldens are now the
frozen old-vs-new oracle for the rewrite.

### [x] Task 2: Implement the new uci-export from the contract

**Files:**

- Rewrite: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`

- [x] **Step 1: Write the replacement (clean-room)**

Write the new file WITHOUT opening the inherited file; work only from the
issue contract, this plan, the fixtures, and the observed behavior in
Research §1. Requirements:

- `#!/bin/sh` shebang; a short header comment in new prose describing the
  purpose and the two hard constraints (no `set -u` because of
  `/lib/functions.sh`; `endpoint.certificate` excluded because PEM is
  multi-line).
- `# shellcheck disable=SC1091` directly above `. /lib/functions.sh`, then
  `config_load trusttunnel`.
- Emit the 26-key schema in the exact contract order: `main` (2 scalars),
  11 endpoint scalars, `endpoint.address` + `endpoint.dns_upstream` lists,
  the resolved-profile block, 6 network scalars, `domains.direct` list.
  Scalar emission only for non-empty values; list emission one line per
  value; values pass through raw (`printf '%s\t%s\n'`-style output).
- Profile block: `uci -q get trusttunnel.endpoint.routing_profile
  2>/dev/null || profile_want=""`, then `config_foreach find_profile
  routing_profile` where `find_profile` matches the section `name` against
  `profile_want`; when a section matches, emit `routing_profile.name`
  (only if non-empty) and `routing_profile.mode` via `config_get` +
  `printf`, and `routing_profile.vpn_rules` / `routing_profile.bypass_rules`
  one line per list value via `config_list_foreach` + the `_emit_one`
  helper with `_KEY="routing_profile.$o"`. Nothing when unassigned or stale.
  The marker comment `# schema-keys: routing_profile.name routing_profile.mode
  routing_profile.vpn_rules routing_profile.bypass_rules` must be present
  BEFORE the emission loops.
- Exit 0 on success; propagate failure (non-zero) when config loading
  fails so `regenerate()` aborts.
- Source-shape tokens per Research §2: `for o in` loops (variable literally
  `o`) with `scalar <section> "$o"` bodies — one-line form for `main` (2
  options), two-TAB-indented multi-line continuation form for `endpoint`
  (11) and `network` (6); line-start `listopt <section> <option>` for
  `endpoint.address`, `endpoint.dns_upstream`, `domains.direct`; the
  profile loops WITHOUT the `scalar` keyword (keys come from the marker
  line only). Exactly 26 keys, nothing else.
- Do NOT use `set -u`; do NOT emit `endpoint.certificate` or any
  not-contracted key.

- [x] **Step 2: Set the mode**

Run: `chmod 755 packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`

- [x] **Step 3: Verify the schema parse survives**

Run: `sh tests/test_init_apply.sh` Expected: PASS — the parser yields the
26 keys (marker line + loops + listopts), the ≥15 sanity gate passes, and
the completeness assertion finds no unclassified key (0 missing). If keys
are dropped, the source shape violates the parser's token expectations or
the marker line is out of sync (see Research §2).

**Verification**: `test_init_apply.sh` green; `sh -n` on the file clean;
`grep -n 'set -u' <file>` finds nothing.

### [x] Task 3: Golden byte-diff and all gates

**Files:**

- Test (scratch): `$TMPDIR/tt03-scratch/new-*.tsv` (diff against
  `golden-*.tsv`)

- [x] **Step 1: Byte-diff old vs new output**

Run the NEW script with the same scaffold (stub + `uci` shim) and the same
four scratch configs used for the goldens: `sh packages/.../uci-export >
new-<case>.tsv` (inside the same docker stub setup), then `cmp
golden-<case>.tsv new-<case>.tsv` for each of `full`, `empty-profile`,
`stale-name`, `minimal`. Expected: no output, exit 0 for all four. Any
difference means the new expression diverges from the old behavior — fix
the implementation, then re-verify. (The fixtures are NOT part of this
comparison; the goldens captured in Task 1 are the oracle.)

- [x] **Step 2: Full suite**

Run: `sh tests/run.sh` Expected: all test files green; assertion totals
unchanged from the Task 1 Step 1 baseline (recorded in the issue notes).

- [x] **Step 3: Shellcheck**

Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0
-s sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`
Expected: clean — the ONLY suppressions are the disable comments in the
file: SC1091 (unresolvable `/lib/functions.sh` include), SC2317 and
SC2154 (the `config_foreach` callback pattern: `find_profile` is invoked
indirectly; `profile_want`/`profile_sec` are assigned via `config_get` and
inside the callback). No other check may be suppressed; any other warning
is a finding against the implementation.

- [x] **Step 4: Executable bit in the index**

Run: `git add packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export
&& git ls-files -s -- packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`
Expected: mode `100755` in the index (if `git add` did not preserve it,
`git update-index --chmod=+x` on the path).

**Verification**: golden diff empty for all four configs; full suite green
with baseline totals; shellcheck clean with only the three allowed
disables; index mode `100755`.

### [x] Task 4: Cleanup and final state

**Files:**

- Delete (scratch): `$TMPDIR/tt03-scratch/` (stub, shim, configs, goldens)

- [x] **Step 1: Remove the scratch scaffolding**

Run: `rm -rf "$TMPDIR/tt03-scratch"` — nothing from the golden harness may
be committed; the equivalence proof is recorded as the verification result.

- [x] **Step 2: Confirm the tree delta**

Run: `git status --short` Expected: the only tracked-file change is
`packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`
(pre-existing untracked `.sdd/` and `docs/` are not part of this issue).
Check there is no `*.old`, no backup of the inherited file, no leftover
scratch under the repo tree (per PRD: the old file must not be kept
alongside the new one).

- [x] **Step 3: Final suite run**

Run: `sh tests/run.sh` Expected: all green; record the final assertion
counts next to the baseline in the issue notes (must be identical to
Task 1 Step 1).

- [ ] **Step 4 (optional, per the issue): live-router sanity**

If a router is reachable: `uci export trusttunnel` into a scratch config,
run the new script against it, and compare byte-for-byte with the golden
captured from the old script before the rewrite (or re-capture from git
history: `git show HEAD:packages/.../uci-export`).
NOT PERFORMED: no router reachable from the dev host; the container golden
byte-diff (Task 3) is the equivalence proof, with goldens captured from
the exact pre-rewrite blob (`585b58c`, verified equal to both `8ec241f` and
`818a276` versions of the file).

**Verification**: scratch gone; `git status` shows only the intended file;
suite green; no inherited expression remains in the tree.

## Implementation notes (2026-09-09, executed by sdd-coder)

- **Baseline (Task 1 Step 1, tree `8ec241f`)**: `sh tests/run.sh` green,
  exit 0 — 7 test files, 199 assertions, 0 failed. Per file: test_deps 26,
  test_gen_config 47, test_harness 5, test_init_apply 29, test_init_reload
  21, test_records 31, test_routing 40.
- **Golden hashes (Task 1 Step 4, old script's raw output)**:
  - `golden-full.tsv`    a0f634e25cc0222c18d73d9dc2185dcb2910f5f701d4dbb8bc1e069dfa9ad796
  - `golden-empty.tsv`   4507c045aee3f7a6ff4ec886ef3f2928db304e5771888f2128b6d336fc18372c
  - `golden-stale.tsv`   1b7fdb298f73aa63dda4803efffb1513276da5aa7f5aadffec5b0a75378e1784
  - `golden-minimal.tsv` 1650fc3eccb5e1f41f7a3ca0e9786de0d8803c8c2898f0de47fd080c937ab885
  - Coverage: golden-full emits the 25-key data set (fixture `full.tsv`'s
    keys, all present, no foreign keys, no `endpoint.certificate`;
    `network.lan_devices` absent — matches the fixture's 25-key subset),
    the resolved `routing_profile.*` block present, list keys repeated,
    `endpoint.password` pass-through with quote/backslash/embedded TAB.
    golden-empty and golden-stale contain no `routing_profile.*` lines
    (stale keeps the `endpoint.routing_profile Ghost` scalar). golden-minimal
    emits exactly the 6 `minimal.tsv` keys. All four `rc=0`.
  - Golden capture environment: docker alpine (`busybox ash`), scratch
    `functions.sh` stub (config_load/config_get/config_list_foreach/
    config_foreach per OpenWrt's documented API, raw-value preservation
    verified against the password/backslash/TAB case) + `bin/uci` shim
    (`-q get` semantics: value + exit 0; absent → silent, exit 1),
    installed as `/lib/functions.sh` and on PATH in the container.
- **Task 3 Step 1 byte-diff**: `cmp golden-<case>.tsv new-<case>.tsv` —
  identical for full (833 B), empty-profile (620 B), stale-name (651 B),
  minimal (144 B). Also verified: missing-config parity (old and new both
  exit 0 with empty output).
- **Task 2 Step 3 tripwire**: `tests/test_init_apply.sh` green —
  "schema parse of uci-export yielded 26 keys", "every schema key is
  classified explicitly", 29 assertions, 0 failed (count unchanged).
- **Task 3 Step 3 shellcheck**: `koalaman/shellcheck:v0.11.0 -s sh` clean
  (rc 0) with only the three in-file disables: SC1091 (above
  `. /lib/functions.sh`), SC2317+SC2154 (above the `find_profile` callback).
- **Task 3 Step 4**: index mode `100755` (`git ls-files -s` shows
  `100755 c3ea8d4…`).
- **Final suite (Task 4 Step 3)**: green, exit 0. NOTE: the worktree was
  being worked in concurrently during this task — commits `ad9e3e6`
  (gen-config reimplementation) and `818a276` (TT-04 docs) landed and
  uncommitted TT-05 edits (`packages/.../routing`, `tests/test_routing.sh`,
  `.sdd/.current/issues/TT-05/plan.md`) appeared mid-session. The suite
  totals therefore differ from the 8ec241f baseline (gen_config 47→57 from
  the TT-04 landing; routing 40→51 from the TT-05 in-tree edits). All
  uci-export-relevant counts are unchanged: test_init_apply 29 (incl. the
  26-key schema parse), test_init_reload 21, test_records 31, test_deps 26,
  test_harness 5. `uci-export` itself is untouched by the concurrent work
  (blob `585b58c` at both `8ec241f` and `818a276`), so the goldens remain
  the old script's raw output.
- **Deviations from this plan (with reasons)**:
  1. *Scratch location*: Docker Desktop on macOS does not mount
     `/var/folders` (and `/tmp` proved unreliable), so the scratch dir was
     placed at a sibling of the repo under `/Users` (still outside the
     repo; removed in Task 4).
  2. *No `|| exit 1` after `config_load`*: the plan's Research §1 claimed
     the old script exits non-zero when config loading fails; measured
     behavior of the old script (missing-config case in the same harness)
     is exit 0 with empty output — the old script ignores `config_load`'s
     status. The new script matches the measured behavior
     (`config_load trusttunnel` without status propagation), and the
     missing-config outputs are byte-identical.
  3. *No trailing `exit 0`*: shellcheck v0.11.0 fires SC2329 on the pure
     callback functions (`find_profile`, `_emit_one`) when the script ends
     with `exit 0`; without it the file is clean with exactly the three
     allowed disables and still exits 0 (status of the final `listopt`
     call, whose helper always succeeds).
  4. *Task 4 Step 4 not performed* (no router reachable) — see above.
- **Clean-room confirmation**: the inherited file's source was never read
  during this task; goldens were captured by executing the old script
  (blob `585b58c`) in the container. The new file was written only from
  the issue contract, this plan (Research §1 behavior, §2 parser shape,
  §3 scaffold), the fixture shape reference, and the measured goldens. No
  spec-internal IDs appear in the shipped file. `git status` shows the new
  `uci-export` staged (100755) and no `*.old`/backup of the inherited file
  anywhere in the tree; the scratch harness was deleted in Task 4.

## Risks / Open Questions

- **Source-shape coupling is the main risk**: `schema_keys()` in
  `test_init_apply.sh` pins literal tokens (`for o in`, `scalar`, `listopt`
  at line start, two-TAB continuations) AND the `# schema-keys:` marker
  line. A "freer" re-expression that renames helpers or the loop variable,
  or a marker line out of sync with the emitted profile options, will
  silently drop keys; the ≥15 sanity gate only catches total breakage,
  while partial key loss fails the completeness assertion. Task 2 Step 3 is
  the tripwire.
- **Profile-loop shape**: the profile block must stay free of the `scalar`
  keyword (the 4 keys are carried by the marker line alone); adding
  `scalar` there would change the parsed key source and risk section-id
  leakage. Research §2 pins this.
- **The schema key count**: the real parse yields 26 keys; issue.md's
  contract agrees ("Total schema: 26 keys"); this plan pins 26 everywhere.
- **macOS has no `/lib/functions.sh` and no `uci`**: the golden capture
  depends on docker (alpine image) or a live router. If neither is
  available, Tasks 1 and 3 degrade to fixture-shape coverage only — still
  meaningful, but not a true old-vs-new byte-diff; the live-router check in
  Task 4 then becomes mandatory.
- **Scaffold fidelity**: the scratch stub must preserve values raw
  (quotes, backslashes, embedded TAB), implement `config_foreach`, and the
  `uci` shim must match the real `-q`/exit-status semantics (silent on
  missing option, exit 1 → `profile_want=""`) or the golden will be a false
  positive/negative (the `endpoint.password` value in `full.tsv` and the
  stale-name case are the traps). Validate the scaffold by the Task 1
  Step 5 coverage checks before trusting it.
- **Empty-value semantics**: only empty/absent scalars are skipped — `0`
  values are emitted. Getting this backwards yields a byte-diff failure on
  the default config.
- **Out-of-scope discipline**: per the PRD, behavioral bugs discovered
  during the work (e.g., a golden mismatch that is not an implementation
  error) must be noted, not fixed.
- **No dedicated test file** is added (per the issue): regression coverage
  rests on `test_init_apply.sh` (schema parse + classification) and the
  one-off old-vs-new golden byte-diff; if future changes touch uci-export,
  the same scratch-golden recipe must be re-run.

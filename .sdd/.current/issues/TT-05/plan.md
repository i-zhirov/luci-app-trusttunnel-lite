# Implementation Plan: TT-05 routing (nft/ip management)

- **Created**: 2026-09-08
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-05/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation of `packages/.../trusttunnel/routing` and `tests/test_routing.sh`; goldens captured under /tmp from the old implementation; no inherited code text may appear in the plan or in the final files."

## Summary

Rewrite `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`
(the nft ruleset + ip/nft command management script) and its test
`tests/test_routing.sh` as an independent reimplementation with byte-identical
kernel behavior. The contract is the issue's "Contract to reproduce" section;
the equivalence oracle is (1) golden byte-diffs of `routing dump` on two record
fixtures, captured from the OLD implementation before it is replaced, and
(2) a rewritten `test_routing.sh` that must pass against BOTH the old
implementation (oracle validation) and the new one.

Order of work (TDD): (a) snapshot the old implementation under `/tmp/tt05/`
and capture the dump goldens; (b) rewrite `tests/test_routing.sh` from the
contract (stubbed ip/nft argv-logging technique) and prove it green against the
old implementation; (c) write the new `routing` script from the contract and
prove it green + byte-identical; (d) run the full verification: suite, goldens,
shellcheck, executable bit, and a device/rootfs smoke checklist.

Cross-cutting clean-room rule: nothing may be copied from the inherited files
into the new text — no printf sequences, no awk programs, no comment wording.
The new scripts are written from the contract below; the goldens and the
rewritten test are the verification that the new expression is behaviorally
equivalent. No old file may be kept alongside the new one (`git status` must
show only the two intended files as tracked changes — the untracked `.sdd/`
plan/issue record and other pre-existing untracked dirs are expected; all
oracle material lives under `/tmp/tt05/` and is never committed).

## Technical Context

- **Language/Version**: POSIX `sh` (busybox ash on OpenWrt targets; `/bin/sh`
  on the macOS/Linux test host). No bashisms, no `set -e` — the inherited
  script uses `set -u` only; explicit `|| return 1` on the few fatal steps.
- **Primary Dependencies** (runtime): `nft` (nftables ≥ 1.0; the `oifname
  "tun*"` pattern was verified against nftables 1.1.6), `ip` (iproute2 /
  busybox), `awk` + `grep` + `sed` + `tr` (POSIX/busybox), `nslookup`
  (busybox), `uci` (optional, LAN fallback), `logger` (busybox). At test time
  none of `ip`/`nft`/`nslookup` are invoked — they are stubbed or
  short-circuited by literal addresses.
- **Storage**: reads the records TSV (via the `records.sh` accessor library,
  TT-02's file — interface `tt_get`/`tt_bool`/`tt_list` is stable and already
  pinned by `test_records.sh`); writes the device-name file `$OUT_DIR/device`
  (default `$OUT_DIR=/var/etc/trusttunnel`).
- **Testing**: `sh tests/run.sh` (fresh `mktemp -d` per test, stdin closed) +
  `tests/lib.sh` (`assert_eq`, `assert_contains`, `assert_exit`,
  `tt_test_summary`). Golden byte-diff (old vs new) for `routing dump`.
- **Target Platform**: OpenWrt routers (apk 25.12, opkg 22.03–24.10), kernel
  nftables; the script must also run on the test host under plain `sh`.

## Research

### Contract vs. current code — verification results

Verified the issue's contract against the current script (read-only analysis;
no text reused):

- Subcommand surface `dump|up|attach|reattach|detach|down|status`, argv layout
  (`$1` cmd, `$2` records, `$3` out-dir default `/var/etc/trusttunnel`, `$4`
  device for attach), env overrides `TT_IP`/`TT_NFT` written as the EXACT
  literals `TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"`
  (tests/test_deps.sh asserts them byte-for-byte), `TT_LIBDIR` (default
  `dirname $0`), sourcing `records.sh` — all present.
- Records reads with the issue's defaults: `network.table` 880, `network.fwmark`
  0x9527, `network.include_router_traffic` 0, `network.blackhole_on_down` 1,
  `network.mtu` 1350 with numeric coercion (junk → 1350), `network.lan_devices`
  with fallback chain.
- Constants: priority 30820, the exact private v4/v6 CIDR sets, device file
  `$OUT_DIR/device`.
- `dump`: idempotent head (empty `table inet trusttunnel { }` then
  `delete table inet trusttunnel`), sets `tt_endpoint4`/`tt_endpoint6`
  (`ipv4_addr`/`ipv6_addr`, `flags interval`), prerouting chain
  (`type filter hook prerouting priority mangle; policy accept;`), `iifname
  != <set> return` first, endpoint returns, private-range returns,
  `meta mark set <fwmark>`; optional output chain (`type route hook output
  priority mangle; policy accept;`) with `oifname "tun*" return` first; no
  `tt_bypass`, no dstnat. Assembly is successive `printf` calls — no heredoc
  with `$(...)` (command substitution strips trailing newlines, gluing the
  last `return` to the next statement; nft rejects the file). Every statement
  ends its own line; closing braces sit alone.
- `up`: blackhole first (`ip route replace blackhole default table <T>
  metric 1000`, v4+v6) when enabled; fwmark rule add guarded by
  `ip rule show | grep -E "lookup <T>([^0-9]|$)"` (substring-proof against a
  foreign table 8800), `ip rule add fwmark <M> table <T> priority 30820`
  v4+v6; endpoint resolution into a `mktemp` file (EXIT/INT/TERM trap) BEFORE
  the ruleset load (otherwise the router's own marked nslookup would blackhole
  itself); single `nft -f -` transaction (failure → `logger` + return 1); then
  `nft add element inet trusttunnel tt_endpoint{4,6}` per address, v6 by
  colon; no device creation, no route attach.
- `attach`: device validation via `ip link show dev` (failure → `logger` +
  return 1), then `ip route replace default dev <dev> table <T> metric 1`
  v4+v6, `mkdir -p $OUT_DIR`, write device name to `$OUT_DIR/device`, log.
- `reattach`: attach by the recorded device name (validated live), no-op when
  the file is absent or the device is gone.
- `detach`: `ip route del default table <T> metric 1` v4+v6 best-effort,
  `rm -f $OUT_DIR/device`; blackhole and nft stay.
- `down`: `nft delete table inet trusttunnel`; `ip rule del fwmark <M> table
  <T> priority 30820` v4+v6; `ip route flush table <T>` v4+v6; remove device
  file; NO `link del` of the client device.
- `status`: `device up` iff the recorded device's `/sys/class/net/<dev>/carrier`
  is `1`, else `device down`; `client device <name>` when the recorded device
  is live; `rule present|absent` (grep with the `([^0-9]|$)` anchor on
  `ip rule show`); `table present|absent` (non-empty `ip route show table`);
  `nft present|absent` (`nft list table inet trusttunnel` exit status).
- Unknown subcommand → `routing: unknown subcommand '<cmd>'` on stderr, exit 1.
- Missing records file → `routing: missing records file` on stderr, exit 1.
- Executable bit 100755 (current `git ls-files -s` mode; CI's "Executable
  bits" gate checks it).

### Contract cross-checks (issue text vs. current code)

The issue has been actualized against the current code (post-fork-merge), so
these six points are no longer discrepancies — each is already stated in the
issue's contract, and the code matches the issue on every one. They stay
listed as the clean-room audit trail: the plan reproduces each, and the
goldens + rewritten test pin them.

1. **`lan_set` skips the uci fallback for `dump`**: the issue's note says in
   dump mode an empty `network.lan_devices` goes straight to the `br-lan`
   default; the code consults `uci -q get network.lan.device` only when the
   subcommand is NOT `dump`. Reproduced (golden diff is the oracle).
2. **`iifname != … return` is effectively unconditional**: the issue says the
   `br-lan` fallback makes it so; `lan_set` always yields at least `br-lan`,
   so the line always appears. Reproduced.
3. **attach's v4 route replace is FATAL, v6 best-effort**: the issue says
   "(v4 FATAL on failure, v6 best-effort)"; the code does `ip route replace
   default dev <dev> table <T> metric 1 || return 1` for v4 (aborts attach,
   no device file written) and only the v6 variant is `2>/dev/null || true`.
   Reproduced.
4. **`status`'s `client device <name>` line is conditional**: the issue says
   the line prints only when the recorded device exists and is live per
   `ip link show`. Reproduced.
5. **`network.mtu` is read + coerced but never consumed**: the issue says the
   read is vestigial parity and must be kept; no command in `routing` uses
   MTU (the real consumption is `gen-config`'s `mtu_size`). Reproduced — the
   read + coercion stays, used nowhere.
6. **attach has an extra empty-name guard**: the issue says an empty device
   name → stderr message + exit 1; `routing attach <rec> <dir> ""` (or
   missing `$4`) prints `routing: attach requires a device name` to stderr
   and returns 1 before touching `ip`. Reproduced.

None of these change the acceptance criteria — the goldens and the rewritten
test pin the real behavior, which the plan targets.

### Test-stub technique (kept in the rewrite)

`TT_IP`/`TT_NFT` are the test seams. The rewritten test keeps the technique:
stub `ip`/`nft` scripts log their argv to `$TT_CMD_LOG`; the nft stub reads
stdin ONLY for `-f -` (captured into `$TT_NFT_STDIN`; an unconditional `cat`
would hang the suite because `run.sh` closes stdin); `ip link show dev` must
succeed (attach/`client_device` depend on it). Endpoint addresses in the
test fixtures are literals (`1.2.3.4:443`, `[2001:db8::1]:443`) so
`resolve_host` short-circuits and no real `nslookup` runs.

### Verification tooling

- `sh tests/run.sh` — full suite; `tests/run.sh` and `lib.sh` are original
  fork files, untouched.
- Shellcheck gate (CI, pinned): `docker run --rm -v "$PWD:/src" -w /src
  koalaman/shellcheck:v0.11.0 -s sh <files>`; the issue additionally requires
  the rewritten `test_routing.sh` to be clean (it is not in CI's list — run it
  locally, do not edit ci.yml).
- Executable bit: `git ls-files -s -- packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing` must read `100755`
  (CI gate).
- Golden diff: `diff <old-golden> <(sh routing dump <fixture>)` empty on both
  fixtures.

## Entities

### Kernel routing state (the script's contract surface)

- **Fields**:
    - `nft table inet trusttunnel` — sets `tt_endpoint4` (ipv4_addr,
      interval), `tt_endpoint6` (ipv6_addr, interval); chains `prerouting`
      (filter/prerouting/mangle) and, optionally, `output`
      (route/output/mangle) — verdicts: endpoint returns, private-range
      returns, `meta mark set`.
    - `fwmark rule` — `fwmark <0x9527> table <880> priority <30820>`, v4+v6.
    - `routing table <880>` — blackhole route (metric 1000) vs. attached
      default route (metric 1).
    - `$OUT_DIR/device` — the client-created device name (written at attach,
      read by status/reattach/detach).
- **Relationships**: `routing up` installs table rule + nft + blackhole;
  `attach` wins over the blackhole by metric 1; `detach` removes only the
  attached route; `down` removes rule, table contents, nft, device file — but
  never the client's device.
- **Validation**: all ip/nft commands use contract constants; device names
  validated live via `ip link show dev`; ruleset bytes pinned by goldens.
- **States**: up → attach → detach → down; reattach is idempotent.

### Records TSV (read-only input, via `records.sh`)

- **Fields**: `network.table`, `network.fwmark`, `network.include_router_traffic`,
  `network.blackhole_on_down`, `network.mtu`, `network.lan_devices`,
  `endpoint.address` (list).
- **Relationships**: consumed with the defaults listed in the issue.
- **Validation**: MTU coerced to 1350 unless purely numeric; booleans via
  `tt_bool` ("1" → true); `lan_devices` fallback chain.

## Contracts

N/A — no API endpoints. The external contract is the kernel/nft surface
described in the issue's "Contract to reproduce" and pinned by the golden
byte-diffs; the CLI surface is the subcommand/argv layout in the issue's
Usage line.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing` | Rewrite | New-expression implementation of the full contract; must produce byte-identical `dump` output and identical ip/nft command sequences; mode 100755 |
| `tests/test_routing.sh` | Rewrite | Contract test with the stubbed ip/nft argv-logging technique; must pass against old AND new implementations |
| `/tmp/tt05/routing.old` | Create (throwaway) | Oracle snapshot of the current implementation for goldens + test validation |
| `/tmp/tt05/test_routing.old.sh` | Create (throwaway) | Reference copy of the inherited test (assertion inventory) |
| `/tmp/tt05/{up,router}.tsv` | Create (throwaway) | The two record fixtures (dump modes: router off / on) |
| `/tmp/tt05/{up,router}.golden` | Create (throwaway) | Old-implementation `routing dump` byte outputs |

Nothing under `/tmp/tt05/` is committed; the tree must end with exactly two
changed (tracked) files — routing + test; the untracked `.sdd/` plan/issue
record and other pre-existing untracked dirs are expected and never staged
here.

## Tasks

### [x] Task 1: Snapshot the oracle and capture `routing dump` goldens

**Files:**

- Create: `/tmp/tt05/` (routing.old, test_routing.old.sh, up.tsv, router.tsv, up.golden, router.golden)

- [x] **Step 1: Snapshot the old implementation**

```sh
mkdir -p /tmp/tt05
cp packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing /tmp/tt05/routing.old
cp tests/test_routing.sh /tmp/tt05/test_routing.old.sh
```

- [x] **Step 2: Write the two record fixtures (data, from the contract)**

`/tmp/tt05/up.tsv` (router traffic off; no `blackhole_on_down` key → default 1):
`network.fwmark⇥0x9527`, `network.lan_devices⇥br-lan br-guest`,
`network.include_router_traffic⇥0` (⇥ = TAB).

`/tmp/tt05/router.tsv` (router traffic on):
`network.fwmark⇥0x9527`, `network.lan_devices⇥br-lan`,
`network.include_router_traffic⇥1`.

- [x] **Step 3: Capture the goldens from the OLD implementation**

```sh
sh /tmp/tt05/routing.old dump /tmp/tt05/up.tsv > /tmp/tt05/up.golden
sh /tmp/tt05/routing.old dump /tmp/tt05/router.tsv > /tmp/tt05/router.golden
```

- [x] **Step 4: Validate the goldens + record the suite baseline**

```sh
test -s /tmp/tt05/up.golden && test -s /tmp/tt05/router.golden
grep -c 'hook output' /tmp/tt05/up.golden      # expected 0 (no output chain)
grep -c 'hook output' /tmp/tt05/router.golden  # expected 1 (output chain present)
shasum -a 256 /tmp/tt05/up.golden /tmp/tt05/router.golden  # record the hashes
sh tests/run.sh   # expected: all green (old routing + old test, pre-change baseline)
```

**Verification**: both goldens non-empty; their difference set is exactly
(1) the `iifname != { ... }` line — `{ "br-lan", "br-guest" }` in up.golden
vs `{ "br-lan" }` in router.golden (the fixtures differ in
`network.lan_devices`) — and (2) the output-chain block present only in
router.golden (blank line + `chain output { ... }` through its closing
brace). Hashes recorded, full suite green before any change.

### [x] Task 2: Rewrite `tests/test_routing.sh` from the contract

**Files:**

- Modify: `tests/test_routing.sh` (complete rewrite, new text)

- [x] **Step 1: Write the rewritten test**

New text, keeping the harness conventions (`lib.sh` asserts, `TT_TEST_TMP`)
and the stubbed `ip`/`nft` argv-logging technique (log to `$TT_CMD_LOG`; nft
stub reads stdin ONLY for `-f -` into `$TT_NFT_STDIN`; `ip link show dev`
always succeeds). Add an env override for the script under test:
`R="${TT_ROUTING:-packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing}"`
so the same test runs against the old and the new implementation.

In-test fixtures: `up.tsv` (router off, `br-lan br-guest`), `router.tsv`
(router on, `br-lan`), `nobh.tsv` (`blackhole_on_down 0`), and `eps.tsv`
(= `up.tsv` + `endpoint.address⇥1.2.3.4:443` + `endpoint.address⇥[2001:db8::1]:443`).

Assertions (contract coverage; the old test's assertions kept, phrased anew):

- `dump` (up.tsv): table declared + `delete table` idempotent head; sets
  `tt_endpoint4`/`tt_endpoint6` with `ipv4_addr`/`ipv6_addr` + `flags
  interval`; prerouting header `type filter hook prerouting priority mangle`;
  `iifname != { "br-lan", "br-guest" } return`; `ip daddr @tt_endpoint4
  return` and `ip6 daddr @tt_endpoint6 return`; private v4 (spot-check
  `192.168.0.0/16`) and v6 (`fc00::/7`) present; `meta mark set 0x9527`; zero
  `tt_bypass` occurrences; zero `hook output` in the default dump; `router.tsv`
  dump has the output chain (`type route hook output priority mangle`) and
  `oifname "tun*" return`; zero `dstnat` occurrences; unknown subcommand
  `bogus` → exit 1.
- Line-break hygiene (what substring asserts cannot see): no line matches
  `return[[:space:]]\+[a-z]` (a statement glued after a `return` verdict) and
  no `mark set.*}` line (closing brace on its own line) — both on the dump
  output.
- `up` via stubs (up.tsv): zero `tuntap add`, zero `link set dev`, zero
  `route replace default` (nothing attached yet); blackhole present v4+v6:
  `ip route replace blackhole default table 880 metric 1000` and `ip -6 …`
  same; fwmark rule add v4+v6: `ip rule add fwmark 0x9527 table 880 priority
  30820` and `ip -6 …`; a single `nft -f -` transaction whose stdin
  (`$TT_NFT_STDIN`) contains `table inet trusttunnel {` and `meta mark set
  0x9527`.
- `up` endpoint elements (eps.tsv): log contains `nft add element inet
  trusttunnel tt_endpoint4 { 1.2.3.4 }` and `nft add element inet trusttunnel
  tt_endpoint6 { 2001:db8::1 }` (v6 classified by colon).
- `attach`: `ip route replace default dev tun7 table 880 metric 1` + the
  `-6` variant; `$TT_TEST_TMP/device` contains `tun7`; metric-1-over-blackhole
  phrasing asserted (`table 880 metric 1`).
- `detach`: `ip route del default table 880 metric 1` (+ `-6`); no
  `blackhole` in the log; device file removed.
- `down`: `nft delete table inet trusttunnel`; `ip rule del fwmark 0x9527
  table 880 priority 30820` (+ `-6`); `ip route flush table 880` (+ `-6`);
  zero `link del`; teardown order asserted (nft delete before route flush,
  via an awk/line-number scan of the log).
- `nobh.tsv` `up`: zero `blackhole` occurrences in the log.

End with `tt_test_summary`.

- [x] **Step 2: Run the rewritten test against the OLD implementation (oracle)**

Run: `TT_ROUTING=/tmp/tt05/routing.old sh tests/test_routing.sh`
Expected: PASS, 0 failed. Any failure here means the test text diverges from
the real behavior — fix the test (not the implementation) until green against
the oracle.

- [x] **Step 3: Run the full suite with the old implementation still in place**

Run: `sh tests/run.sh` Expected: all tests green (the rewritten test included).

**Verification**: rewritten test green against `/tmp/tt05/routing.old`; full
suite green; `test_routing.sh` is invoked via `sh` (no mode change needed —
`run.sh` always shells it).

### [x] Task 3: Implement the new `routing` script from the contract

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing` (complete rewrite, new expression)

- [x] **Step 1: Write the new script**

Structure (contractual, written fresh):

- Header comment stating the 7 subcommands and their args; `set -u`.
- Env/prologue: `TT_LIBDIR` (default `dirname "$0"`), source `records.sh`
  (with a static-linter guard comment). The `TT_IP`/`TT_NFT` override
  defaults are part of the FILE CONTRACT and must be the exact literals
  `TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"` — tests/test_deps.sh
  (fork-original) asserts these byte-for-byte; any rephrasing (e.g.
  `TT_IP=${TT_IP:-ip}`) passes our own checks but breaks `sh tests/run.sh`.
- Arg parsing: cmd from `$1`; `TT_RECORDS` from `$2`, required — otherwise
  `routing: missing records file` to stderr, exit 1; `OUT_DIR` from `$3`,
  default `/var/etc/trusttunnel`.
- Records reads with the issue's defaults: `network.table` → 880,
  `network.fwmark` → 0x9527, `network.include_router_traffic` → 0 via
  boolean mapping, `network.blackhole_on_down` → 1, `network.mtu` → 1350 with
  numeric coercion (empty or non-numeric → 1350; parity-only read, never used
  in a command).
- Constants: rule priority 30820; private v4 ranges 10/8, 127/8, 169.254/16,
  172.16/12, 192.168/16, 224/4, 240/4; private v6 ::1/128, fc00::/7, fe80::/10,
  ff00::/8; device file `$OUT_DIR/device`.
- LAN set builder: read `network.lan_devices`; when empty, fall back to
  `uci -q get network.lan.device` — but ONLY outside `dump` mode (cross-check
  #1) — then to `br-lan`; format the space-split names as a quoted nft set
  literal (`{ "a", "b" }`).
- Ruleset assembly (`dump`): emit, in this exact order and byte shape: the
  idempotence head (empty table declaration, `delete table`, blank line), the
  table opener, the two set declarations (`ipv4_addr`/`ipv6_addr`, `flags
  interval`), blank line, the prerouting chain (header `type filter hook
  prerouting priority mangle; policy accept;`, then `iifname != <lan set>
  return`, then the endpoint return for ipv4, the endpoint return for ipv6,
  the private-v4 return, the private-v6 return, then `meta mark set <fwmark>`,
  then the chain's closing brace); when router traffic is enabled, a blank
  line and the output chain (header `type route hook output priority mangle;
  policy accept;`, `oifname "tun*" return` FIRST, then the same four returns
  and the mark rule, closing brace); the table's closing brace. One statement
  per line, tab indentation (one tab per nesting level), a `return` verdict
  always ends its line, closing braces on their own line. Assembly uses
  successive per-line writes — NO heredoc containing command substitution
  anywhere in the assembly path (the trailing-newline stripping glues
  statements and nft rejects the file). No `tt_bypass` sets, no dstnat.
- Endpoint resolution: `host_of` strips `[v6]:port` / `host:port` forms; a
  literal IPv6 (contains `:`) or a purely dotted-numeric IPv4 is echoed as-is;
  otherwise `nslookup <host>` output is parsed with the busybox answer format
  (`Address: <ip>` — the `Name:` line gates the answer section, an optional
  `Address N:` prefix is stripped, a trailing tail after the address is cut —
  but NOT a port after an IPv6 address); results printed one per line.
- `up`: when blackhole enabled, `ip route replace blackhole default table
  <T> metric 1000` then the `-6` variant; then the rule guard: v4 and v6
  `ip rule show | grep -E "lookup <T>([^0-9]|$)"` — add `ip rule add fwmark
  <M> table <T> priority 30820` (v4+v6) only when the anchor is absent; then
  resolve `endpoint.address` into a `mktemp` file guarded by an EXIT/INT/TERM
  cleanup trap; then load the ruleset via ONE `nft -f -` transaction piped
  from the assembly (on failure: `logger` the nft stderr and return 1); then
  add one nft element per resolved address — `tt_endpoint6` if the address
  contains a colon, else `tt_endpoint4`, stderr suppressed. No device
  creation, no route attach.
- `attach <dev>`: empty-name guard (`routing: attach requires a device name`,
  stderr, return 1); validate with `ip link show dev <dev>` (failure →
  `logger` + return 1); v4 `ip route replace default dev <dev> table <T>
  metric 1` — failure is FATAL (return 1, cross-check #3); `-6` variant
  best-effort; `mkdir -p $OUT_DIR`; write the device name (newline-terminated)
  to `$OUT_DIR/device`; `logger` the attachment.
- `reattach`: read the recorded device via the same live validation as
  status; when absent or dead → no-op success; otherwise run attach with the
  recorded name.
- `detach`: v4+v6 `ip route del default table <T> metric 1`, best-effort;
  remove the device file; blackhole and nft stay.
- `down`: `nft delete table inet trusttunnel` best-effort; v4+v6 `ip rule del
  fwmark <M> table <T> priority 30820` best-effort; v4+v6 `ip route flush
  table <T>` best-effort; remove the device file; NO `link del` of the client
  device.
- `status`: resolve the recorded device (file + live `ip link show`); print
  `device up` when `/sys/class/net/<dev>/carrier` is `1`, else `device down`;
  print `client device <name>` only when the recorded device is live
  (cross-check #4); `rule present|absent` via the anchored grep on
  `ip rule show`; `table present|absent` via non-empty
  `ip route show table <T>`; `nft present|absent` via the exit status of
  `nft list table inet trusttunnel`.
- Dispatch: the 7 subcommands; anything else → `routing: unknown subcommand
  '<cmd>'` to stderr, exit 1.

Then ensure the file mode stays executable (the rewrite must not clear it).

- [x] **Step 2: Syntax + lint gates**

Run: `sh -n packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`
(clean) and the pinned shellcheck:
`docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh
packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`
Expected: no findings (SC1091-style source-path directives are the sanctioned
pattern).

Then confirm the two override-default literals are byte-exact (re-asserted by
test_deps.sh in Task 4 Step 1):

```sh
grep -Fq 'TT_IP="${TT_IP:-ip}"' packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing
grep -Fq 'TT_NFT="${TT_NFT:-nft}"' packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing
```

Expected: both exit 0.

- [x] **Step 3: Run the rewritten test against the NEW implementation**

Run: `sh tests/test_routing.sh` Expected: PASS, 0 failed. Any failure is a
behavioral gap in the new script — fix the implementation, never the test
(the test is contract-pinned and oracle-validated).

- [x] **Step 4: Byte-diff the goldens**

Run:
`diff /tmp/tt05/up.golden <(sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing dump /tmp/tt05/up.tsv)`
and the same with `router.golden` / `router.tsv`.
Expected: both empty. Iterate on the assembly until byte-identical
(whitespace, blank lines, ordering — everything).

**Verification**: rewritten test green against the new script; both golden
diffs empty; `sh -n` and shellcheck clean; mode 100755.

### [x] Task 4: End-to-end verification and smoke checklist

**Files:** none (verification only)

- [x] **Step 1: Full suite**

Run: `sh tests/run.sh` Expected: `== all tests passed`, 0 failed. This run
includes test_deps.sh, which asserts the exact literals
`TT_IP="${TT_IP:-ip}"` and `TT_NFT="${TT_NFT:-nft}"` in `routing` — a
rephrased default would fail here (Task 3 Step 1 pins them).

- [x] **Step 2: Final golden cmp + lint + mode**

Run:
`cmp /tmp/tt05/up.golden <(sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing dump /tmp/tt05/up.tsv) &&
cmp /tmp/tt05/router.golden <(sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing dump /tmp/tt05/router.tsv)` —
clean; then the pinned shellcheck on BOTH new files (`routing` and
`tests/test_routing.sh`, `-s sh`); then
`git ls-files -s -- packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`
→ `100755`; then
`git status --short` → exactly two TRACKED changes: the routing script and
`tests/test_routing.sh`. The untracked `.sdd/` entries (this plan/issue
record) and other pre-existing untracked dirs (e.g. `docs/`) are expected
and allowed — what must NOT appear: `*.old` files, golden files, fixtures,
or any other new `??` entry.

- [x] **Step 3: Device/rootfs smoke checklist** (OpenWrt with busybox
  `ip`/`nft`, real records file)

1. `routing up <records> <outdir>` → exit 0; `routing status` shows `rule
   present`, `table present`, `nft present`; `ip rule` shows `fwmark 0x9527
   lookup 880 priority 30820`; `ip route show table 880` shows the blackhole
   `metric 1000` (both address families).
2. `routing attach <records> <outdir> <dev>` (device created by the client,
   or `ip tuntap add dev tunX mode tun` for the test) → `ip route show table
   880` shows `default dev <dev> metric 1`; `cat <outdir>/device` = `<dev>`.
3. `routing reattach <records> <outdir>` → exit 0, route still in place
   (idempotent); repeat with the device file removed → exit 0, no-op.
4. `routing detach <records> <outdir>` → `ip route show table 880` shows only
   the blackhole (metric 1000); device file gone.
5. `routing down <records>` → `status` shows `rule absent`, `table absent`,
   `nft absent`; `nft list table inet trusttunnel` fails; the client device
   still exists; device file gone.
6. `routing bogus <records>` → exit 1 with the unknown-subcommand message.
7. With `include_router_traffic=1`: `nft list ruleset` shows the output chain
   with `oifname "tun*"`.

**Verification**: suite green, goldens byte-identical, shellcheck clean, mode
100755, tree contains only the two intended changes, and every smoke item
passes on the device/rootfs.

## Notes

- TT-05 is blocked by TT-02 (records.sh), which is still Draft. This plan
  only relies on TT-02's stable public interface (`tt_get`/`tt_bool`/
  `tt_list` — already pinned by `test_records.sh`), so the dependency does
  not block this plan's tasks; the suite run in Task 4 implicitly re-verifies
  the pair once TT-02 lands.
- `tests/run.sh` closes stdin for every test — the rewritten stubs must only
  read stdin for `nft -f -` (as the inherited technique does).
- MTU is intentionally read and coerced but not used in any command
  (cross-check #5) — removing the read would change the records-read side
  effect contract and risk a silent divergence from the issue's contract.
- The old implementation and its test remain on disk only under
  `/tmp/tt05/`; after Task 4 the working tree must contain no trace of the
  inherited text beyond the git history.

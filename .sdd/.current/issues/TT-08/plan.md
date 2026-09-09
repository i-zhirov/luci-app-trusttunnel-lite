# Implementation Plan: TT-08 — hotplug route reattach

- **Created**: 2026-09-08
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-08/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM constraints: no code copied from the inherited file into the plan; verify via a scenario harness that handles the hardcoded RECORDS/OUTDIR (chroot or path-override technique); baseline → 2–3 implementation chunks → device smoke checklist → final gates."

## Summary

Reimplement `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
(the net-hotplug route-reattach script, 47 lines, currently inherited GPL-2.0
expression) from the behavioral contract in the issue. The script is a linear
guard chain that reacts to net `add` events for the client's tun device,
filters out persistent/foreign devices, and re-attaches the default route via
`routing attach` when the client recreates its tun.

Approach:

1. Baseline the current file's gates (`sh -n`, shellcheck) so the starting
   point is green.
2. Write a scenario harness `tests/test_hotplug.sh` that runs a
   path-override test copy of the script (the script hardcodes its absolute
   paths, so the harness `sed`-substitutes the four fixed prefixes into a
   scratch tree with stubbed init.d probe, stubbed `routing` recorder, and
   stubbed `logger`), plus invariant asserts on the real file. Calibrate the
   harness against the *inherited* file: every scenario must pass against it —
   the inherited behavior is the equivalence oracle.
3. Implement from the issue contract in three chunks (event filters → state
   guards → attach+log), each chunk verified by its harness scenario group
   (negative scenarios are green from the placeholder baseline; the
   attach-positive ones — F3, G4–G6, A1, A2 — only from chunk 3).
4. Final gates: full suite, `sh -n`, shellcheck, executable bit, `git status`
   cleanliness (no old file kept alongside), and a device smoke checklist.

Clean-room note: implementation steps below describe *behavior* and point at
the issue's contract section; they contain no expression from the inherited
file. The harness text is new, original test expression written from the
contract.

## Technical Context

- **Language/Version**: POSIX sh (`#!/bin/sh`). On the router: busybox ash
  (OpenWrt 22.03–25.12). Tests also run under macOS `/bin/sh` (bash in POSIX
  mode) and CI — the script and the test must stay POSIX-clean.
- **Primary Dependencies**:
  - `/usr/libexec/trusttunnel/routing attach <records> <outdir> <device>`
    (TT-05 — this issue is blocked by TT-05).
  - `/etc/init.d/trusttunnel running` — procd-provided probe (TT-06 keeps
    the procd service; the probe contract is unaffected).
  - `logger` (busybox) for the log line.
- **Storage**: `/var/etc/trusttunnel/settings.tsv` (records TSV),
  `/var/etc/trusttunnel/device` (last attached device name). Both are
  hardcoded absolute paths inside the script — no env overrides exist by
  contract.
- **Testing**: `tests/run.sh` (runs every `tests/test_*.sh` in a fresh
  `TT_TEST_TMP`, stdin closed) + `tests/lib.sh` asserts
  (`assert_eq`, `assert_contains`, `assert_exit`, `tt_test_summary`);
  `tests/fixtures/records/minimal.tsv` reused as the records fixture.
  Gates: shellcheck (docker, as ci.yml runs it) and `sh -n`.
- **Target Platform**: OpenWrt router; the script lives in
  `/etc/hotplug.d/net/` and is executed by `/sbin/hotplug-call` on net
  events (one-shot process per event; exit 0 = handled/no-op).

## Research

### OpenWrt net hotplug environment

`/etc/hotplug.d/net/*` scripts run once per net event with the event
environment exported: `ACTION` (`add`/`remove`/…), `INTERFACE`, `DEVICENAME`,
plus others (MACADDR, SEQNUM, …). The contract pins exactly the variables the
script consumes: `ACTION`, `INTERFACE` (preferred), `DEVICENAME` (fallback).
The script must exit 0 for every event it does not act on — hotplug scripts
have no return-value meaning beyond success. Nothing in the script persists
state across invocations except the `$OUTDIR/device` file and the side
effects of `routing attach`; every guard must therefore be re-evaluated per
event. The fork-written init tests (`test_init_apply.sh`) source the init
script to test it; that technique does not transfer here — the hotplug script
is top-level imperative code with `exit` statements, so the harness runs it
as a child process instead.

### sysfs `tun_flags` and the IFF_PERSIST bit

For tun/tap devices the tun driver exposes `/sys/class/net/<dev>/tun_flags`;
regular net devices (ethernet/wireless/bridge) do not — its *presence* is the
tun marker. The value is a hex flags word in which the `IFF_PERSIST` bit is
`0x800`: set on devices created manually (`ip tuntap add dev … mode tun`) and
on the legacy `tt0` left by old package versions; not set on devices created
by the client itself. POSIX shell arithmetic (`$(( … ))`) accepts hexadecimal
literals, so the bit test is a plain arithmetic mask, not a character
positional parse. Fake `tun_flags` values used by the harness:
`0x1001` (non-persistent tun → attach proceeds) and `0x1801` (persistent →
filtered out); `0x1801 & 0x800 = 2048 ≠ 0`, `0x1001 & 0x800 = 0`.

### Testability of the hardcoded absolute paths (chroot vs path-override)

The script hardcodes `RECORDS`, `OUTDIR`, the init.d probe path, the routing
helper path, and the `/sys/class/net` prefix, so a scenario harness needs a
fake root. Two techniques were considered:

- **chroot**: build a scratch root with fake sysfs (plain directories/files —
  no mounts needed), stub init.d/routing/logger, and `chroot` into it.
  Problem: chroot requires root, a working `/bin/sh` plus dynamic libraries
  inside the scratch root (busybox static or a lib copy), and does not exist
  on the macOS dev machine. This is how the *device* smoke test works in
  practice (real router rootfs), but it is not a portable unit-test
  technique.
- **path-override (chosen)**: generate a test copy of the script with
  `sed`, substituting the four fixed absolute prefixes with scratch paths,
  and run it under a stubbed `PATH` (logger stub prepended). Works
  non-root, on macOS and Linux CI, with zero host-side side effects.
  Weakness: it tests a transformed copy. Mitigations: (a) invariant
  scenarios assert the real file still contains the exact contract paths
  and shebang; (b) `sh -n`/shellcheck run on the real file; (c) the
  release.yml rootfs-install tests and the manual device checklist exercise
  the real file end-to-end. The PRD's golden-diff idea applies here as the
  calibration step: the harness must pass against the inherited file before
  the reimplementation starts.

### Repo test conventions for stubbing

`tests/test_routing.sh` stubs external commands via env overrides
(`TT_IP`/`TT_NFT`); the hotplug script has no env overrides by contract, so
the harness stubs differently: PATH-prepended `logger` and scratch-root
versions of `/etc/init.d/trusttunnel` and `/usr/libexec/trusttunnel/routing`
written by the test itself (exit-code state files + an invocation recorder).
`tests/run.sh` picks up the new test file automatically (glob
`tests/test_*.sh`). Note: ci.yml's shellcheck list does not currently include
`tests/test_*.sh` files; ci.yml is TT-19's file, so this issue does not edit
ci.yml — the harness is kept shellcheck-clean anyway.

## Entities

### Hotplug event

- **Fields**: `ACTION` (string; `add` is the only acting value),
  `INTERFACE` (string, preferred device source), `DEVICENAME` (string,
  fallback device source).
- **Relationships**: produced by `/sbin/hotplug-call` for net events; one
  process per event; no persistent state.
- **Validation**: none (environment strings); empty/absent values must not
  crash the script.
- **States**: event → filtered-out (exit 0) | acted-on (attach+log).

### Device sysfs marker (`/sys/class/net/<dev>/tun_flags`)

- **Fields**: file presence = tun/tap device; content = hex flags word.
- **Relationships**: keyed by the event's resolved device name.
- **Validation**: `IFF_PERSIST` bit `0x800` set → device is manual/legacy →
  ignore; absent file → not a tun → ignore.
- **States**: present non-persistent (act) | present persistent (ignore) |
  absent (ignore).

### Tunnel records state (`/var/etc/trusttunnel/`)

- **Fields**: `settings.tsv` (records file; existence = service configured),
  `device` (last attached device name; may be absent).
- **Relationships**: `settings.tsv` is the first argument to
  `routing attach`; `device` feeds the foreign-device guard.
- **Validation**: recorded device counts as live only when its sysfs dir
  exists.
- **States**: no records → ignore; no recorded device → attach;
  recorded live foreign device → ignore; recorded dead/equal device →
  attach.

### Attach call + log

- **Fields**: command `/usr/libexec/trusttunnel/routing attach <records>
  <outdir> <dev>`; log line via `logger -t trusttunnel
  "hotplug: reattached routing to <dev>"`.
- **Relationships**: blocked by TT-05 (`routing attach` must exist); the
  call happens only when every guard passes.
- **Validation**: log emitted only on attach success; script exit status
  follows the attach's outcome (pinned by calibration — see Discrepancies).
- **States**: idle → attached (route metric 1 in table 880, device name
  recorded by routing).

## Contracts

- **Authoritative spec**: `.sdd/.current/issues/TT-08/issue.md` — "Contract
  to reproduce" (guard chain, exact paths, executable bit `100755`) and
  "Acceptance criteria".
- **Event/shell contract** (what the script must honor):
  - Env: `ACTION`, `INTERFACE`, `DEVICENAME`; paths
    `/var/etc/trusttunnel/settings.tsv`, `/var/etc/trusttunnel`,
    `/etc/init.d/trusttunnel running`, `/usr/libexec/trusttunnel/routing`,
    `/sys/class/net/<dev>/tun_flags`.
  - Exit 0 for every ignored event; non-zero only when the attach command
    itself fails (behavioral fact — see Research/discrepancies).
  - `logger -t trusttunnel "hotplug: reattached routing to $dev"` only when
    attach succeeds.
- **Call contract**: `routing attach "$RECORDS" "$OUTDIR" "$dev"` — TT-05's
  contract (issue TT-05): empty device → error exit 1; validates the device
  via `ip link show dev`; `ip route replace default dev <dev> table 880
  metric 1`; writes `$OUTDIR/device`.
- N/A — no network API endpoints.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` | Reimplement | Replace the inherited guard chain with original expression written from the contract; mode `100755`; replaces the file in place (no `*.old` copy left) |
| `tests/test_hotplug.sh` | Create | Scenario harness: sed path-override test copy, stubbed init.d/routing/logger, invariant asserts on the real file, scenario groups `filters|guards|attach|invariants` (default: all) |

Reused as-is: `tests/fixtures/records/minimal.tsv` (records fixture for the
scratch tree), `tests/run.sh`, `tests/lib.sh`. No other files change; ci.yml
stays untouched (TT-19 owns it).

## Tasks

### [x] Task 1: Baseline — current file is green before any change

**Files:**

- None (read-only checks)

- [x] **Step 1: Confirm the inherited file passes the existing gates**

Run:

```sh
sh -n packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel
docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh \
  packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel
git ls-files -s packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel
```

Expected: `sh -n` exits 0; shellcheck reports no findings; the git index
shows mode `100755`.

- [x] **Step 2: Confirm the file is unchanged since the calibration point**

Run:

```sh
git log 1fdf82c..HEAD --oneline -- \
  packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel
```

Expected: **empty output** — no commit between `1fdf82c` and `HEAD` touched
the hotplug script, i.e. the file did not change on main. This is the
precondition that makes the Task 2 calibration meaningful: the inherited
file used as the equivalence oracle is byte-identical to the one the harness
is written against.

- [x] **Step 3: Confirm the suite is green as a whole**

Run: `sh tests/run.sh` Expected: `== all tests passed`

**Verification**: A green starting point, so any later failure is attributable
to the reimplementation, not to a pre-existing state. Record the baseline
(the gates output plus the empty `git log` result) in the task completion
notes.

---

### [x] Task 2: Scenario harness `tests/test_hotplug.sh` + calibration against the inherited file

**Files:**

- Create: `tests/test_hotplug.sh`

- [x] **Step 1: Write the harness (test code — original expression)**

The harness generates a path-override test copy of the script, builds the
scratch fake root, stubs the three external commands, and exposes scenario
groups. Scaffold:

```sh
#!/bin/sh
# Scenario harness for the net hotplug route-reattach script.
#
# The script hardcodes its fixed paths, so scenarios run a sed-generated
# test copy with those prefixes redirected into a scratch tree; stubs take
# the place of /etc/init.d/trusttunnel, the routing helper and logger.
# Invariant scenarios assert the REAL file still carries the contract paths.
# Usage: sh tests/test_hotplug.sh [filters|guards|attach|invariants]
. "$(dirname "$0")/lib.sh"

HOTPLUG="packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel"

scratch="$TT_TEST_TMP/root"
export SCRATCH="$scratch"
mkdir -p "$scratch/var/etc/trusttunnel" "$scratch/etc/init.d" \
         "$scratch/usr/libexec/trusttunnel" "$scratch/bin" \
         "$scratch/sys/class/net/tun0" "$scratch/sys/class/net/tun1"
cp tests/fixtures/records/minimal.tsv "$scratch/var/etc/trusttunnel/settings.tsv"
printf '0x1001\n' > "$scratch/sys/class/net/tun0/tun_flags"
printf '0x1001\n' > "$scratch/sys/class/net/tun1/tun_flags"

# Stub of the procd "running" probe: exit code from a state file (default 0).
cat > "$scratch/etc/init.d/trusttunnel" <<'STUB'
#!/bin/sh
exit "$(cat "$SCRATCH/init_rc" 2>/dev/null || printf 0)"
STUB
chmod +x "$scratch/etc/init.d/trusttunnel"

# Recorder stub of the routing helper: appends its arguments, honors a state
# file for the exit code (default 0).
cat > "$scratch/usr/libexec/trusttunnel/routing" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$SCRATCH/routing_calls"
exit "$(cat "$SCRATCH/routing_rc" 2>/dev/null || printf 0)"
STUB
chmod +x "$scratch/usr/libexec/trusttunnel/routing"

# logger stub: records the tag + message.
cat > "$scratch/bin/logger" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$SCRATCH/log_lines"
STUB
chmod +x "$scratch/bin/logger"

# Test copy: substitute the four fixed absolute prefixes with scratch paths.
# '|' as the sed delimiter avoids escaping the path slashes.
sed -e "s|/var/etc/trusttunnel|$scratch/var/etc/trusttunnel|g" \
    -e "s|/etc/init.d/trusttunnel|$scratch/etc/init.d/trusttunnel|g" \
    -e "s|/usr/libexec/trusttunnel/routing|$scratch/usr/libexec/trusttunnel/routing|g" \
    -e "s|/sys/class/net|$scratch/sys/class/net|g" \
    "$HOTPLUG" > "$scratch/40-trusttunnel.test"
chmod +x "$scratch/40-trusttunnel.test"

# Reset per-scenario state: restore the FULL default scratch state, so every
# scenario starts identical no matter what earlier scenarios mutated (F5
# rewrites tun0/tun_flags, G1 deletes settings.tsv, G4 deletes the tun1
# sysfs dir — none of that may leak into a later scenario). Recorders and
# stub rc overrides are cleared, the device record is removed, settings.tsv
# is re-copied from the fixture, and the tun0/tun1 sysfs dirs are recreated
# with non-persistent flags. Scenario deltas are applied AFTER this call.
reset_state() {
	rm -f "$scratch/routing_calls" "$scratch/log_lines" \
	      "$scratch/var/etc/trusttunnel/device" "$scratch/init_rc" \
	      "$scratch/routing_rc"
	cp tests/fixtures/records/minimal.tsv \
	   "$scratch/var/etc/trusttunnel/settings.tsv"
	mkdir -p "$scratch/sys/class/net/tun0" "$scratch/sys/class/net/tun1"
	printf '0x1001\n' > "$scratch/sys/class/net/tun0/tun_flags"
	printf '0x1001\n' > "$scratch/sys/class/net/tun1/tun_flags"
}

run_hotplug() {
	PATH="$scratch/bin:$PATH" ACTION="$ACT" INTERFACE="$IFACE" \
	DEVICENAME="$DEVNAME" sh "$scratch/40-trusttunnel.test"
}

calls() { cat "$scratch/routing_calls" 2>/dev/null || printf '<none>'; }
logs()  { cat "$scratch/log_lines" 2>/dev/null || printf '<none>'; }
```

Scenario coverage (each is a small function registered under a group; the
example shows the first one — write the rest from the table):

```sh
scn_filters() {
	# F1: a non-add event is ignored before anything else.
	# Pattern: reset_state FIRST (full default state), then scenario deltas.
	ACT=remove IFACE=tun0 DEVNAME=; reset_state
	run_hotplug
	assert_eq "0" "$?" "non-add event exits 0"
	assert_eq "<none>" "$(calls)" "non-add event never reaches routing"
	# Deltas are applied after reset_state, scoped to the scenario — e.g. F5:
	#   printf '0x1801\n' > "$scratch/sys/class/net/tun0/tun_flags"
	# ... F2-F5 per the table below
}
```

Harness contract (order-independence):
- `reset_state()` restores the FULL default state above, and every scenario
  calls it first; scenario deltas are applied only afterwards: F5 rewrites
  `tun0/tun_flags` to `0x1801`, G1 removes `settings.tsv`, G4 removes the
  `tun1` sysfs dir and records `device`=tun1, G3/G5 write
  `device`=tun1/tun0, G2 sets `init_rc`=1, A2 sets `routing_rc`=1. No
  scenario ever relies on state left behind by a previous scenario.
- Scenario kinds decide the red/green timeline (see the "Green from"
  column): negative scenarios assert "exit 0, no routing call" — they pass
  against any script that never calls routing, including the exit-0
  placeholder; positive scenarios assert the routing call or the
  attach-failure exit — they pass only once chunk 3 implements the attach.

| # | Group | Scenario | Scratch state | Env | Expected | Green from |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | filters | non-add ACTION | default | `ACTION=remove`, `INTERFACE=tun0` | exit 0, no routing call | chunk 0 |
| F2 | filters | no device name | default | `ACTION=add`, both empty | exit 0, no routing call | chunk 0 |
| F3 | filters | INTERFACE wins over DEVICENAME | default | `INTERFACE=tun0`, `DEVICENAME=tun1` | routing called with `tun0` | chunk 3 |
| F4 | filters | not a tun device | `sys/class/net/tun99` absent | `INTERFACE=tun99` | exit 0, no routing call | chunk 0 |
| F5 | filters | persistent tun filtered | `tun0/tun_flags` = `0x1801` | `INTERFACE=tun0` | exit 0, no routing call | chunk 0 |
| G1 | guards | records file missing | remove `settings.tsv` | `INTERFACE=tun0` | exit 0, no routing call | chunk 0 |
| G2 | guards | service not running | `init_rc` = 1 | `INTERFACE=tun0` | exit 0, no routing call | chunk 0 |
| G3 | guards | foreign live device | `device`=tun1, `sys/class/net/tun1` exists | `INTERFACE=tun0` | exit 0, no routing call | chunk 0 |
| G4 | guards | recorded device gone | `device`=tun1, remove `sys/class/net/tun1` | `INTERFACE=tun0` | routing called with `tun0` | chunk 3 |
| G5 | guards | recorded device is the event device | `device`=tun0 | `INTERFACE=tun0` | routing called with `tun0` | chunk 3 |
| G6 | guards | no recorded device | `device` absent | `INTERFACE=tun0` | routing called with `tun0` | chunk 3 |
| A1 | attach | happy path: attach + log | default | `INTERFACE=tun0` | routing called with exactly `attach <records> <outdir> tun0`; log contains `-t trusttunnel hotplug: reattached routing to tun0`; exit 0 | chunk 3 |
| A2 | attach | attach failure → no log | `routing_rc` = 1 | `INTERFACE=tun0` | exit non-zero, no log line | chunk 3 |
| I1 | invariants | real file: shebang | — | — | first line of the real file is `#!/bin/sh` | chunk 0 |
| I2 | invariants | real file: contract paths | — | — | real file contains `RECORDS=/var/etc/trusttunnel/settings.tsv`, `OUTDIR=/var/etc/trusttunnel`, `/etc/init.d/trusttunnel running`, `/usr/libexec/trusttunnel/routing attach` | chunk 0 / 3 |
| I3 | invariants | real file: executable | — | — | `test -x` on the real file | chunk 0 |

"Green from": `chunk 0` = the scenario passes against ANY script that never
calls routing — including the exit-0 placeholder used as the red baseline in
Task 3 Step 1. These are negative assertions: they can only catch
over-reach, so the guard itself must still be implemented per the contract.
`chunk 3` = the scenario asserts the routing call (or the attach-failure
exit) and passes only once chunk 3 implements the attach call. I2 asserts
the real file's final contract paths: green at chunk 0 (inherited file),
red during chunks 1–2, green again from chunk 3; the invariant group is
exercised only by full-harness runs.

Main dispatcher: run the requested group(s) (default: all five), then
`tt_test_summary` and exit with its status.

- [x] **Step 2: Run the harness against the INHERITED file — calibration**

Run: `sh tests/test_hotplug.sh` Expected: **ALL scenarios pass**
(the inherited file is the equivalence oracle; any failure here means the
harness misreads the contract — fix the harness, not the file). The oracle
is valid because Task 1 Step 2 confirmed
`git log 1fdf82c..HEAD -- packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
is empty: the file is unchanged since the calibration point.

- [x] **Step 3: Run the full suite to confirm the harness integrates**

Run: `sh tests/run.sh` Expected: `== all tests passed`

**Verification**: The harness is the executable spec for this issue. It must
be green against the inherited implementation before any reimplementation
starts, so that the same harness later proves equivalence of the new file.

---

### [x] Task 3: Chunk 1 — event filters (ACTION / device name / tun marker / persistence)

**Files:**

- Reimplement: `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` (in place, replacing the inherited file)

- [x] **Step 1: Confirm the chunk's scenarios fail against an empty script**

Replace the file content with a minimal POSIX placeholder (`#!/bin/sh` +
`exit 0`), then run: `sh tests/test_hotplug.sh filters`
Expected: F1, F2, F4, F5 PASS trivially — they are negative assertions
(exit 0, no routing call) and the placeholder satisfies them by doing
nothing. F3 FAILS — it asserts the routing call, which no placeholder can
produce. This is the chunk-1 red baseline: only F3 (and, later, the other
positive scenarios) can prove the new code does the work.

- [x] **Step 2: Implement chunk 1 from the issue contract (behavioral spec — write original expression, do not open the inherited file)**

Per the issue "Contract to reproduce":
- Ignore every event whose `ACTION` is not `add`.
- Resolve the device name from `INTERFACE`, falling back to `DEVICENAME`;
  ignore the event when both are empty.
- Ignore the event when `/sys/class/net/<dev>/tun_flags` does not exist
  (not a tun device).
- Read the flags; on any read failure ignore the event. Keep the event only
  when the arithmetic mask `flags & 0x800` (IFF_PERSIST) is zero — hex
  literals work in POSIX `$(( ))`, including busybox ash.

- [x] **Step 3: Run the chunk's scenarios**

Run: `sh tests/test_hotplug.sh filters` Expected: F1, F2, F4, F5 PASS; F3
still FAIL (no routing call exists yet — it is green only from chunk 3).
`sh tests/test_hotplug.sh` Expected, per group: guards — G1–G3 PASS
trivially (negative assertions), G4–G6 FAIL (positive; the recorder stays
empty); attach — A1, A2 FAIL; invariants — I1, I3 PASS, I2 FAIL (the
chunk-1 file does not yet carry the full contract paths).

- [x] **Step 4: Syntax gate**

Run: `sh -n packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
Expected: exit 0.

**Verification**: F1, F2, F4, F5 green on the new expression (F3 red until
chunk 3); red-green transition demonstrated against the placeholder;
`sh -n` clean.

---

### [x] Task 4: Chunk 2 — state guards (records / service running / foreign device)

**Files:**

- Reimplement: `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` (extend the chunk-1 file)

- [x] **Step 1: Confirm the chunk's scenarios are red**

Run: `sh tests/test_hotplug.sh guards` Expected: G1–G3 PASS trivially
(negative assertions — the chunk-1 file exits 0 without calling routing,
which is exactly what they assert). G4–G6 FAIL: no routing call exists, so
the "routing called with `tun0`" assertions see an empty recorder — the
failure is "call missing", not "call shape".

- [x] **Step 2: Implement chunk 2 from the issue contract (behavioral spec)**

- Bind the two fixed constants: records file
  `/var/etc/trusttunnel/settings.tsv`, output dir `/var/etc/trusttunnel`.
- Ignore the event when the records file is not a regular file.
- Ignore the event when the service probe
  `/etc/init.d/trusttunnel running` reports failure (its output is
  discarded).
- Foreign-device guard: read the recorded device name from
  `$OUTDIR/device`; when a name is recorded, the corresponding sysfs
  directory `/sys/class/net/<recorded>` still exists, and the recorded name
  differs from the event device → ignore the event (a foreign event must
  not tear off a working tunnel). Recorded name missing, dead, or equal →
  continue.

- [x] **Step 3: Run the chunk's scenarios**

Run: `sh tests/test_hotplug.sh guards` Expected: G1–G3 PASS; G4–G6 still
FAIL — the chunk-2 file implements the guards but not the attach call, and
the positive scenarios can only pass from chunk 3. This is deliberate: the
attach call belongs to chunk 3 — do not add it here.
`sh tests/test_hotplug.sh attach` Expected: A1/A2 still FAIL (no attach
call yet).

- [x] **Step 4: Syntax gate**

Run: `sh -n packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
Expected: exit 0.

**Verification**: G1–G3 green on the new expression (G4–G6 green only from
chunk 3); the filters group keeps its chunk-3-red expectation (F1, F2, F4,
F5 green; F3 red until chunk 3) — nothing regressed.

---

### [x] Task 5: Chunk 3 — attach + log

**Files:**

- Reimplement: `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` (complete the file)

- [x] **Step 1: Confirm the chunk's scenarios are red**

Run: `sh tests/test_hotplug.sh attach` Expected: A1, A2 FAIL (no routing
call, no log) — and the same for the other positive scenarios F3, G4–G6.
The complete pre-chunk-3 red set is exactly F3, G4–G6, A1, A2; after this
chunk every one of them must be green.

- [x] **Step 2: Implement chunk 3 from the issue contract (behavioral spec)**

- When every guard has passed, invoke the routing helper with exactly three
  arguments — records file, output dir, event device:
  `/usr/libexec/trusttunnel/routing attach "$RECORDS" "$OUTDIR" "$dev"`.
- Only when that invocation succeeds, emit the log line via `logger` with
  tag `trusttunnel` and message `hotplug: reattached routing to <dev>`.
- The script's exit status must follow the attach outcome (success → 0;
  attach failure → non-zero, no log line) — the inherited behavior pinned by
  scenario A2 during calibration.

- [x] **Step 3: Run the complete harness**

Run: `sh tests/test_hotplug.sh` Expected: ALL scenarios PASS (F1–F5, G1–G6,
A1, A2, I1–I3).

- [x] **Step 4: Full suite**

Run: `sh tests/run.sh` Expected: `== all tests passed`

**Verification**: Full harness green on the reimplemented file — the same
scenarios that were calibrated against the inherited file — plus the whole
suite.

---

### [x] Task 6: Final gates + device smoke checklist

**Files:**

- Verify: `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`, `tests/test_hotplug.sh`

- [x] **Step 1: Static gates**

Run:

```sh
sh -n packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel
docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh \
  packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel \
  tests/test_hotplug.sh
sh tests/run.sh
```

Expected: `sh -n` exit 0; shellcheck no findings; `== all tests passed`.

- [x] **Step 2: Executable bit**

Run: `chmod 755 packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel && git ls-files -s packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
Expected: index mode `100755` (matches the ci.yml "Executable bits" gate and
the issue's contract).

- [x] **Step 3: Clean-tree check (PRD "Implementation Decisions")**

Run: `git status --short`
Expected: exactly two changes — the reimplemented hotplug script (mode
`100755` retained) and the new `tests/test_hotplug.sh`; no `*.old` copy of
the hotplug script, no diff of old-vs-new kept alongside.

- [x] **Step 4: Device smoke checklist (manual; the issue's acceptance gate)**

1. **Client restart → reattach**: on a router with the package installed,
   restart the client (`/etc/init.d/trusttunnel restart` or kill the client
   process so procd respawns it). Expect: a new tun device event fires;
   `routing status` shows `device up` and `client device <new>`; `ip route
   show table 880` contains `default dev <new> metric 1`; marked traffic
   flows (tunnel works after the restart, not the blackhole); `logread |
   grep trusttunnel` shows `hotplug: reattached routing to <new>`.
2. **Negative — persistent tun**: `ip tuntap add dev tthook mode tun` (or
   reuse the legacy `tt0` if present). Expect: no attach — no new
   metric-1 route for `tthook` in table 880 and no
   `hotplug: reattached routing to tthook` log line (the IFF_PERSIST
   filter). Clean up with `ip tuntap del dev tthook mode tun`.
3. **Foreign device**: while the tunnel is attached and working, produce a
   net `add` event for a different, non-persistent tun device; expect the
   working tunnel stays attached (recorded-device guard; covered
   automatically by scenario G3, manual confirmation optional).

- [x] **Step 5: Note for TT-19 (no edit here)**

ci.yml's shellcheck list does not cover `tests/test_*.sh`; when TT-19
rewrites ci.yml, add `tests/test_hotplug.sh` to the shellcheck invocation.
Leave ci.yml untouched in this issue.

**Verification**: All static gates, the full harness, the index mode, a clean
`git status`, and the device smoke checklist — the issue's acceptance
criteria in full.

## Discrepancies found (vs. the issue contract)

1. **Log-on-success semantics unspecified**: the contract says "Otherwise:
   … attach … and log", which reads as unconditional; the inherited file
   chains the log to attach success (`attach && logger`) and the script's
   exit status follows the attach. Scenario A2 pins the inherited behavior
   (attach failure → non-zero exit, no log line). No change to the issue is
   required, but the ambiguity is recorded here.
2. **`logger` resolved via PATH**: the contract names the command
   `logger -t trusttunnel …`; the script relies on PATH lookup (no absolute
   path). The harness stubs it via PATH prepend; a chroot/device smoke run
   would see the real busybox logger.
3. **Recorded-device liveness check is a directory test**: the contract says
   the recorded device "still exists in sysfs"; the inherited guard checks
   the sysfs *directory* (`-d`), not the file. The harness fakes sysfs as
   directories so both readings agree; no behavioral difference.
4. **ci.yml does not lint test files**: the new harness is not in ci.yml's
   shellcheck list; TT-19 owns ci.yml (its issue states it is "the gate for
   every other issue"), so this issue adds a note instead of an edit.
5. **No dedicated test file existed**: the issue's Files list names only the
   script; `tests/test_hotplug.sh` is added per the PRD's per-component
   testing decisions (module design: "Service lifecycle … Tested: yes").
6. Everything else in the contract matched the inherited file exactly
   (guard order, `INTERFACE`-over-`DEVICENAME`, `0x800` arithmetic check,
   fixed paths, mode `100755`).

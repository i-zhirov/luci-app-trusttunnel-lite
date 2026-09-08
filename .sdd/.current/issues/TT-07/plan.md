# Implementation Plan: TT-07 — uci-defaults (first-boot firewall setup)

- **Created**: 2026-09-08
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-07/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation. packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel is inherited GPL-2.0 code (zone creation block inherited; dedup + migration fork work). No dedicated test file — verification is shellcheck, sh -n, and scenario testing in a chroot/container."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`uci-defaults` gained a block; the issue contract is updated:

- **NEW profile-seed block** (after the firewall block, before the cache
  clear): when NO `routing_profile` section exists — create one
  (`name='Default'`, `mode='vpn'`), migrate every `domains.direct` value
  into its `bypass_rules` (via `uci -q get` + `while read` pipeline),
  set `trusttunnel.endpoint.routing_profile='Default'`, `uci commit
  trusttunnel`, log "created the default routing profile; the old direct
  list moved into its bypass rules". Idempotent (fresh installs already
  carry the seeded section from the shipped config).
- Task 1's scenario harness gets a FOURTH scenario: **upgrade** — no
  `routing_profile` section, populated `domains.direct` → after the run a
  Default profile exists with the migrated rules and
  `endpoint.routing_profile='Default'`; re-run → no-op.
- The seed block gets its own task body (Task 5): it is implemented and
  asserted (name/mode/bypass_rules migration/commit/log) against the
  `upgrade` scenario in a red/green cycle, exactly like the other phases.
- Every scenario fixture ships a scratch `/etc/config/trusttunnel` in the
  shipped-config shape (a Default `routing_profile` section), so the seed
  block is a no-op in the baseline scenarios — the stock rootfs image has
  no trusttunnel config, which would otherwise fire the seed (and its log
  line) on every scenario. Only the `upgrade` and `idempotent` fixtures
  use the upgrade shape (no profile, populated `domains.direct`).
- Task 7's idempotence check dumps BOTH `uci show firewall` and
  `uci show trusttunnel` after each run, so the seed block's no-op on the
  second run is actually asserted, not just the firewall state.

## Summary

Replace the inherited GPL-2.0 first-boot script `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel` with a functionally identical clean-room reimplementation written against the issue's contract (no text copied from the inherited file — the plan below describes behavior, never expression). The script runs on every package install and repairs/creates the `trusttunnel` firewall zone for the client's tun device, and seeds the default routing profile for upgraded installs. The new implementation is written phase by phase in TDD order (dedup → creation → migration → profile seed → finalize), each phase verified by a new docker-based scenario harness (`tests/test_uci_defaults.sh`) that executes the script inside an OpenWrt rootfs container against scratch `/etc/config/firewall` and `/etc/config/trusttunnel` and asserts the resulting UCI state for fresh / duplicated / legacy-`tt0` / upgrade / side-effects / idempotent scenarios. Final gates: `shellcheck -s sh` (pinned `koalaman/shellcheck:v0.11.0` via docker), `sh -n`, executable bit `100755`.

## Technical Context

- **Language/Version**: POSIX sh (busybox ash on OpenWrt 22.03–25.12). No `local` (SC3043): all helper state in `_`-prefixed variables, per the repo convention.
- **Primary Dependencies**: `/lib/functions.sh` (`config_load`, `config_foreach`, `config_get` — OpenWrt shell lib, absent on the lint machine → SC1091 disable needed); `uci` CLI (`add`, `set`, `add_list`, `delete`, `commit`); `/etc/init.d/firewall reload`; `/etc/init.d/trusttunnel enable`; busybox `logger`, `mkdir`, `rm`.
- **Storage**: UCI configs `/etc/config/firewall` (fw4) and `/etc/config/trusttunnel` (routing profiles; the seed block may create the file on upgraded installs that lack it); cache file `/var/cache/trusttunnel/release.json`; LuCI caches `/tmp/luci-indexcache`, `/tmp/luci-modulecache/*`; rc.d links under `/etc/rc.d/`.
- **Testing**: repo harness `tests/run.sh` (runs every `tests/test_*.sh` in a fresh `mktemp -d`, stdin closed, `assert_eq`/`assert_contains`/`assert_exit`/`tt_test_summary` from `tests/lib.sh`); new docker scenario harness `tests/test_uci_defaults.sh` (this issue); shellcheck pinned `koalaman/shellcheck:v0.11.0 -s sh` via docker (already a CI gate for this file); `sh -n`.
- **Target Platform**: OpenWrt routers (apk 25.12 / opkg 22.03–24.10); executed by the uci-defaults machinery on every package install and first boot, and immediately by `install.sh` after the package install (its "Seeding the default routing profile" step). Container equivalent used for testing: `openwrt/rootfs:x86-64-25.12.0` (already used by release.yml).

## Research

### Behavior contract (issue §"Contract to reproduce" + docs/reimplementation-file-review.md §6)

The script is a straight-line six-phase program, always ending `exit 0`:

1. **Presence scan**: load `/etc/config/firewall`; set a flag when any `zone` section is named `trusttunnel`.
2. **Dedup pass (must run before creation)**: keep the first `zone` named `trusttunnel` and the first `forwarding` with `dest=trusttunnel`; delete every later duplicate via `uci delete firewall.<section>`. If anything was removed: `uci commit firewall`, `/etc/init.d/firewall reload`, `logger -t trusttunnel "removed duplicate firewall zones left by an earlier version"` (message pinned in the issue). Rationale (historical bug): an early version read the zone name with an empty section argument, so creation fired on every install and piled up zones that break fw4 with "redefinition of symbol".
3. **Creation (only when no `trusttunnel` zone exists)**: `uci add firewall zone` with `name='trusttunnel'`, `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`, `masq='1'`, `mtu_fix='1'`, `add_list device='tun+'` (a pattern, not a concrete device name — the client picks its own name; covering foreign tun devices is deliberate); plus `uci add firewall forwarding` with `src='lan'`, `dest='trusttunnel'`; then `uci commit firewall` and `/etc/init.d/firewall reload` (required — without it the status page shows green-on-broken).
4. **Migration (only when a zone exists)**: when the zone's `device` list lacks the exact token `tun+` (old `tt0` binding): delete the whole device list, set `add_list device='tun+'`, then `uci commit firewall`, reload, and log. The log line text is observable behavior but is NOT pinned in the issue — see Discrepancies.
5. **Profile seed (only when no `routing_profile` section exists in `/etc/config/trusttunnel`)**: `config_load trusttunnel`; count `routing_profile` sections via `config_foreach`; when the count is zero — `uci add trusttunnel routing_profile` with `name='Default'`, `mode='vpn'`; migrate the legacy list — every `domains.direct` value (via `uci -q get` + `while read` pipeline) → `uci add_list "trusttunnel.$_prof.bypass_rules"="$_d"`; set `trusttunnel.endpoint.routing_profile='Default'`; `uci commit trusttunnel`; `logger -t trusttunnel "created the default routing profile; the old direct list moved into its bypass rules"` (message pinned in the issue). Idempotent: fresh installs already carry the section from the shipped config, so the block is a no-op there. The block runs after the firewall block (dedup/creation/migration) and before the cache clear.
6. **Finalize**: `mkdir -p /var/cache/trusttunnel`; `rm -f /var/cache/trusttunnel/release.json`; `/etc/init.d/trusttunnel enable` (unconditionally — enablement is only checked inside `start_service`; without the rc.d link the tunnel does not come up after reboot); `rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*`; `exit 0`.

Idempotence: phases 2/3/4/5 mutate nothing on a second run (dedup finds no duplicates, creation is skipped, migration finds `tun+` already present, the seed finds a profile already present); phase 6 re-runs harmless idempotent operations. `_`-prefixed variables instead of `local` are a POSIX/shellcheck requirement (SC3043) — keep the convention.

### CI gates that already cover this file (ci.yml)

- "Executable bits" gate expects git index mode `100755` for exactly this path.
- "Shellcheck" gate runs `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh ... packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel` — version pinned on purpose (SC2317 etc. appear in newer releases). The file is already in the list.
- `sh -n` in CI currently covers only the init script; extending it to this file belongs to the packaging/CI issue that reimplements `ci.yml` (TT-07 does not modify `ci.yml` — see File Structure). Locally the plan's gates run `sh -n` on this file.
- Makefile `Build/Compile` chmods the file 0755 at build time (defense in depth for the executable bit).

### Test harness design (new, original text)

The script sources `/lib/functions.sh` by absolute path and uses the real `uci` CLI, so scenario testing needs a real OpenWrt rootfs: the repo already uses `openwrt/rootfs:x86-64-25.12.0` in release.yml and docker for shellcheck. The harness therefore runs the script inside that image with scratch `/etc/config/firewall` and `/etc/config/trusttunnel` and stub `/etc/init.d/firewall` (records `reload` calls), stub `/etc/init.d/trusttunnel` (creates the rc.d link, records the call), stub `/bin/logger` (records messages) — all placed in a fresh `$TT_TEST_TMP/<scenario>/` fixture dir and copied in by the container setup. The real `uci` and `/lib/functions.sh` from the image do the actual work, so the assertions exercise the true toolchain. Conventions followed: `tests/test_*.sh` naming (auto-picked by `tests/run.sh`), `lib.sh` asserts, `TT_TEST_TMP`, `set -u`-safe, docker guard (skip with a visible message and exit 0 when `docker` is absent, so the local suite stays runnable; CI always has docker).

The stock rootfs image has NO `/etc/config/trusttunnel`, so on a bare image the seed block would fire on every scenario and write its log line everywhere. Every scenario fixture therefore ships a scratch `trusttunnel` config: the default fixture shape is the shipped-config shape (a `routing_profile` section with `name='Default'`, `mode='vpn'` — the seed is a no-op), and only the `upgrade` and `idempotent` fixtures override it with the upgrade shape (NO `routing_profile` section, populated `domains.direct` — the seed fires there, and its log line is asserted).

Scenario filter for chunked red/green work: `TT_UCD_FILTER=fresh|duplicated|legacy|upgrade|side-effects|idempotent` runs only the matching scenario functions; default (unset) runs all six. `TT_UCD_SCRIPT` overrides the script path under test (default: the package path) — used to validate the harness against the inherited file (Task 1) and to point at the new file as it develops.

### Contract vs inherited code — discrepancies found

1. **Migration log message not pinned**: the issue contract says "commit + reload + log" but does not give the message text; the inherited code logs `firewall zone migrated from tt0 to the tun+ wildcard`. The message is externally observable (syslog), so the reimplementation preserves it verbatim for functional identity. Recommend pinning it in the issue.
2. **`rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*`**: the issue omits the `2>/dev/null` stderr suppression present in the inherited code. Behaviorally equivalent (the `rm -f` semantics are the contract); the new code may keep the suppression.
3. **`/etc/init.d/trusttunnel enable` and firewall reload stderr suppression**: same class as #2 — output redirects are cosmetic, not contractual.
4. **Verification vehicle**: the issue says "chroot"; the repo's existing container-based checks (release.yml rootfs installs, shellcheck) use docker. The plan uses `openwrt/rootfs:x86-64-25.12.0` as the chroot equivalent; `sh tests/run.sh` stays the local entry point.
5. **Presence scan before dedup**: the inherited code scans for the zone before the dedup pass. Order between scan and dedup is not observable (both are reads before any write); the contract's hard rule — dedup before creation — is preserved.

## Entities

### firewall zone (UCI section type `zone`)

- **Fields**: `name` = `trusttunnel`; `input` = `REJECT`; `output` = `ACCEPT`; `forward` = `REJECT`; `masq` = `1`; `mtu_fix` = `1`; `device`[] = `tun+` (list).
- **Relationships**: referenced by the forwarding rule's `dest`; matches the client's tun device via the `tun+` wildcard (deliberately also foreign tun devices).
- **Validation**: presence flag from the scan; dedup keeps the first section only.
- **States**: absent → created; duplicated → deduped (first kept); legacy (`tt0` binding) → migrated to `tun+`; correct → untouched.

### firewall forwarding (UCI section type `forwarding`)

- **Fields**: `src` = `lan`; `dest` = `trusttunnel`.
- **Relationships**: pairs with the zone; duplicates deduped to the first with `dest=trusttunnel`.
- **States**: absent → created (with the zone); duplicated → deduped.

### routing_profile (UCI section type `routing_profile` in `/etc/config/trusttunnel`)

- **Fields**: `name` = `Default`; `mode` = `vpn`; `bypass_rules`[] = the migrated `domains.direct` values (list, one entry per legacy value).
- **Relationships**: referenced by `trusttunnel.endpoint.routing_profile` (set to `Default` when the profile is seeded); the seed block also writes `uci commit trusttunnel`, so on upgraded installs without the config file the seed materializes `/etc/config/trusttunnel`.
- **Validation**: existence counted via `config_foreach count_profile routing_profile` after `config_load trusttunnel`; seeding happens only when the count is zero.
- **States**: absent → seeded (with `domains.direct` migration + `endpoint.routing_profile`); present → untouched (no-op).

### Side-effect artifacts

- `/var/cache/trusttunnel/release.json` — created dir, removed file on every run.
- `/etc/rc.d/S95trusttunnel` — link registered by `/etc/init.d/trusttunnel enable` on every run.
- `/tmp/luci-indexcache`, `/tmp/luci-modulecache/*` — removed on every run.
- `/etc/config/trusttunnel` — created/extended only when the seed block fires (no `routing_profile` section existed); committed and logged.
- Exit status: always 0.

## Contracts

N/A — no API endpoints. The behavioral contract is the issue's "Contract to reproduce" plus the three observable log messages (two pinned in the issue — the dedup line and the seed line — and one preserved from observation — see Discrepancies #1).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel` | Rewrite (same path, keep mode `100755`) | New-expression implementation of the six phases; replaces the inherited GPL-2.0 text |
| `tests/test_uci_defaults.sh` | Create | Docker scenario harness: fresh / duplicated / legacy / upgrade / side-effects / idempotent, with `TT_UCD_FILTER` and `TT_UCD_SCRIPT` selectors and a docker-absent skip guard |

Deliberately NOT touched: `.github/workflows/ci.yml` (its Shellcheck + Executable bits gates already cover this file; the file itself is reimplemented by the packaging/CI issue), the Makefile (already chmods 0755), `/etc/config/trusttunnel` (schema data, own issue — the harness's `trusttunnel` fixtures are scratch copies inside the container, never repo files).

## Tasks

### [ ] Task 1: Scenario harness + equivalence baseline

**Files:**

- Create: `tests/test_uci_defaults.sh`

- [ ] **Step 1: Write the failing test — the harness itself**

Write `tests/test_uci_defaults.sh` (new, original text; conventions from `tests/lib.sh`):

- Header `#!/bin/sh`, source `. "$(dirname "$0")/lib.sh"`, default `TT_UCD_SCRIPT=packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`, `TT_UCD_FILTER` unset = all scenarios. Guard: if `command -v docker` fails, print `SKIP: docker unavailable — scenario tests not run` and exit 0.
- Fixture dir per scenario under `$TT_TEST_TMP/<name>/` containing: `firewall` (scratch UCI config), `trusttunnel` (scratch UCI config — DEFAULT fixture shape: a `routing_profile` section with `name='Default'` and `mode='vpn'`, i.e. the shipped-config shape, so the seed block is a no-op in the baseline scenarios; the `upgrade` and `idempotent` scenarios override it with the upgrade shape: NO `routing_profile` section, populated `domains.direct`), `firewall-stub` (`#!/bin/sh` → `echo reload >> /tmp/tt_reloads; exit 0`), `trusttunnel-stub` (`#!/bin/sh` → `mkdir -p /etc/rc.d; ln -sf ../../etc/init.d/trusttunnel /etc/rc.d/S95trusttunnel; echo enable >> /tmp/tt_enable_log`), `logger-stub` (`#!/bin/sh` → `echo "$*" >> /tmp/tt_log`).
- Runner: `docker run --rm -v "$PWD/packages/luci-app-trusttunnel/root/etc/uci-defaults:/script:ro" -v "$TT_TEST_TMP/$name:/fixture:ro" openwrt/rootfs:x86-64-25.12.0 sh -c 'cp /fixture/firewall /etc/config/firewall; cp /fixture/trusttunnel /etc/config/trusttunnel; cp /fixture/firewall-stub /etc/init.d/firewall; cp /fixture/trusttunnel-stub /etc/init.d/trusttunnel; cp /fixture/logger-stub /bin/logger; chmod +x /etc/init.d/firewall /etc/init.d/trusttunnel /bin/logger; sh /script/40-luci-trusttunnel; echo "SCRIPT_EXIT=$?"; uci show firewall; uci show trusttunnel; echo "RELOADS=$(wc -l < /tmp/tt_reloads)"; cat /tmp/tt_log; readlink /etc/rc.d/S95trusttunnel; ls /var/cache/trusttunnel 2>/dev/null; ls /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null' < /dev/null` — capture stdout+stderr into `$TT_TEST_TMP/$name/out`. The `upgrade` and `idempotent` scenarios use a double-run runner variant: it runs the script a second time, snapshots the log after run 1 (`cp /tmp/tt_log /tmp/tt_log1`), and dumps `uci show firewall` and `uci show trusttunnel` after EACH run into `/tmp/fw1`/`/tmp/fw2` and `/tmp/tt1`/`/tmp/tt2` (per-run `RELOADS` included), so the assertions can diff per-run state and prove no-op behavior.
- Scenario functions (each runs the runner, then asserts on `out` with `assert_eq`/`assert_contains`, using `case`/`grep -c` for negative checks). Zone counts are SCOPED to trusttunnel zones via `printf '%s\n' "$out" | grep -c "name='trusttunnel'"` — an unrelated zone in a fixture must not disturb the count; total `@zone[` counts are asserted only where the fixture's zone inventory matters:
  1. `fresh` — fixture: minimal `config defaults` block; trusttunnel config in the DEFAULT shape (profile present → seed is a no-op). Assert: `SCRIPT_EXIT=0`; `TT_ZONE_COUNT=1` (via `grep -c "name='trusttunnel'"`); `name='trusttunnel'`, `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`, `masq='1'`, `mtu_fix='1'`, `device='tun+'` present; `@forwarding[0]` with `src='lan'` `dest='trusttunnel'` present and `FWD_COUNT=1` (via `grep -c "dest='trusttunnel'"`); `RELOADS=1`; log empty (the seed was a no-op — no "created the default routing profile..." line).
  2. `duplicated` — fixture: three `config zone` sections all `name=trusttunnel` with distinct markers (`option marker 'first'/'second'/'third'`), three `config forwarding` with `dest=trusttunnel` and markers `a/b/c`, plus one unrelated zone (`name='lanzone'`); trusttunnel config in the DEFAULT shape. Assert: `TT_ZONE_COUNT=1` (scoped: `grep -c "name='trusttunnel'"` = 1), `marker='first'` present, `marker='third'` absent (`grep -c` = 0), TOTAL zone count is 2 (`grep -c "@zone["` = 2 — the unrelated `lanzone` survives dedup alongside the one remaining trusttunnel zone), `FWD_COUNT=1`, `marker='a'` present, `marker='c'` absent, `name='lanzone'` still present, `RELOADS=1`, log contains `removed duplicate firewall zones left by an earlier version`.
  3. `legacy` — fixture: one `config zone` `name=trusttunnel` with `list device 'tt0'`; trusttunnel config in the DEFAULT shape. Assert: `TT_ZONE_COUNT=1`, `device='tun+'` present, `device='tt0'` absent, `RELOADS=1`, log contains `firewall zone migrated from tt0 to the tun+ wildcard`, `FWD_COUNT=0` (via `grep -c "dest='trusttunnel'"` — the fixture has no forwarding, creation did NOT fire because the zone existed, and the migration phase never creates forwarding).
  4. `upgrade` — fixture: one converged `trusttunnel` zone WITH `device='tun+'` + one forwarding (`src='lan'`, `dest='trusttunnel'`) — the firewall part is a full no-op; trusttunnel config in the UPGRADE shape: an `endpoint` section (`option host 'vpn.example.com'`), a `domains` section with `list direct 'example.com'` and `list direct 'api.example.net'`, and NO `routing_profile` section. Runner: the double-run variant (dumps `uci show trusttunnel` after each run). Assert after run 1: `SCRIPT_EXIT=0`; a `routing_profile` section exists (`grep -c "@routing_profile["` = 1) with `name='Default'` and `mode='vpn'`; `bypass_rules='example.com'` and `bypass_rules='api.example.net'` both present (every `domains.direct` value migrated, one list entry each); `routing_profile='Default'` present on the `endpoint` section; log contains exactly `created the default routing profile; the old direct list moved into its bypass rules`; `RELOADS=0` (the firewall block was untouched). Assert after run 2: the `uci show trusttunnel` dump is unchanged (`@routing_profile[` count still 1 — no second profile), and no new log lines.
  5. `side-effects` — fixture: minimal `config defaults`; trusttunnel config in the DEFAULT shape (profile present → seed no-op, so the log stays EMPTY); the in-container setup additionally pre-creates `/var/cache/trusttunnel/release.json`, `/tmp/luci-indexcache`, `/tmp/luci-modulecache/x` before running the script (extra setup line appended to the runner for this scenario). Assert: `SCRIPT_EXIT=0`; `/etc/rc.d/S95trusttunnel` → `../../etc/init.d/trusttunnel`; `enable` recorded once; `/var/cache/trusttunnel` exists and contains no `release.json`; `/tmp/luci-indexcache` absent; `/tmp/luci-modulecache` empty; log empty (including NO "created the default routing profile..." line).
  6. `idempotent` — fixture: minimal `config defaults` (zone creation fires on run 1) + trusttunnel config in the UPGRADE shape (NO profile, populated `domains.direct` — the seed fires on run 1). Runner: the double-run variant (dumps `uci show firewall` AND `uci show trusttunnel` after each run). Assert: `fw1 == fw2` (no diff), `tt1 == tt2` (no diff — the seeded profile is not duplicated on run 2), `RELOADS` stays 1, the log contains exactly the run-1 seed line and NO new lines after run 2.
- Self-check (harness must not be vacuously green): run `TT_UCD_SCRIPT=/nonexistent sh tests/test_uci_defaults.sh` — every scenario must FAIL.

- [ ] **Step 2: Run test to verify it fails**

Run: `TT_UCD_SCRIPT=/nonexistent sh tests/test_uci_defaults.sh`
Expected: FAIL — every scenario reports failed assertions (proves the harness detects a missing/broken script).

- [ ] **Step 3: Validate the harness against the known-good inherited behavior**

Run: `sh tests/test_uci_defaults.sh`
Expected: PASS — all SIX scenarios green against the inherited file (the equivalence baseline: the inherited file already carries the seed block, so the upgrade + idempotent scenarios exercise it; the rewrite must keep every scenario green).

- [ ] **Step 4: Record the static baseline**

Run:
`sh -n packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
`docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
`git ls-files -s -- packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
Expected: all clean; index mode `100755`.

**Verification**: `sh tests/test_uci_defaults.sh` green on the inherited file; `/nonexistent` run red; `sh -n`, shellcheck v0.11.0, and `100755` all confirmed.

### [ ] Task 2: New script skeleton + dedup pass

**Files:**

- Rewrite: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

- [ ] **Step 1: Establish the failing state**

Replace the inherited content with a fresh skeleton (shebang, one-line purpose comment, `# shellcheck disable=SC1091` above `. /lib/functions.sh`, `exit 0` at the end — nothing else). This is the red state for this chunk.

Run: `TT_UCD_FILTER=duplicated sh tests/test_uci_defaults.sh`
Expected: FAIL — the three duplicate zones survive (`name='trusttunnel'` count = 3, no dedup log).

- [ ] **Step 2: Implement the dedup pass (contractual)**

New original expression implementing: load the firewall config; two `config_foreach` passes over `zone` and `forwarding` sections using `_`-prefixed state variables (first-seen flags, "removed anything" flag); for every section after the first matching `name=trusttunnel` (zones) or `dest=trusttunnel` (forwardings), issue `uci delete firewall.<section>`; when the "removed anything" flag is set: `uci commit firewall`, `/etc/init.d/firewall reload` (stderr/stdout to `/dev/null`), `logger -t trusttunnel "removed duplicate firewall zones left by an earlier version"`. The pass runs before any creation logic. Keep `exit 0` as the script's final statement. Where shellcheck flags `config_foreach` callbacks as unreachable/never-invoked and `config_get`-assigned variables (SC2317/SC2329/SC2154), add targeted disables with a brief comment — verify against the pinned shellcheck before committing to each disable.

- [ ] **Step 3: Run test to verify it passes**

Run: `TT_UCD_FILTER=duplicated sh tests/test_uci_defaults.sh` then `sh -n packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
Expected: PASS — duplicates collapsed to the first zone + first forwarding, unrelated zone untouched, reload once, exact dedup log line; `sh -n` clean.

**Verification**: duplicated scenario green on the new file. `fresh` is still expected to FAIL here (creation not implemented yet — next task).

### [ ] Task 3: Zone + forwarding creation

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

- [ ] **Step 1: Confirm the failing state**

Run: `TT_UCD_FILTER=fresh sh tests/test_uci_defaults.sh`
Expected: FAIL — no zone created (`name='trusttunnel'` count = 0, no `RELOADS`).

- [ ] **Step 2: Implement the creation phase (contractual)**

New original expression implementing: when the presence scan found no zone named `trusttunnel`: `uci add firewall zone`, then `uci set` each of `name='trusttunnel'`, `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`, `masq='1'`, `mtu_fix='1'`, and `uci add_list ... device='tun+'`; `uci add firewall forwarding` with `src='lan'` and `dest='trusttunnel'`; then `uci commit firewall` and `/etc/init.d/firewall reload` (quieted). No creation when the zone exists.

- [ ] **Step 3: Run test to verify it passes**

Run: `TT_UCD_FILTER=fresh sh tests/test_uci_defaults.sh`
Expected: PASS — exactly one zone with all seven options, one forwarding `lan → trusttunnel`, one reload.

- [ ] **Step 4: Regression check on the previous chunk**

Run: `TT_UCD_FILTER=duplicated sh tests/test_uci_defaults.sh`
Expected: PASS — unchanged.

**Verification**: fresh + duplicated scenarios green. `legacy` and `side-effects` still expected to FAIL (next tasks).

### [ ] Task 4: `tt0` → `tun+` migration

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

- [ ] **Step 1: Confirm the failing state**

Run: `TT_UCD_FILTER=legacy sh tests/test_uci_defaults.sh`
Expected: FAIL — the zone still binds `tt0` (`device='tt0'` present, no migration log).

- [ ] **Step 2: Implement the migration phase (contractual)**

New original expression implementing: when the presence scan found a zone named `trusttunnel`, for that zone check whether its `device` list contains the exact token `tun+` (whitespace-delimited list membership, so `tun+` inside a longer token does not count); when it does not: delete the entire device list, `uci add_list ... device='tun+'`, set a "migrated" flag; when the flag is set: `uci commit firewall`, reload (quieted), and `logger -t trusttunnel` with the message `firewall zone migrated from tt0 to the tun+ wildcard` (observable behavior preserved verbatim — see Discrepancies #1).

- [ ] **Step 3: Run test to verify it passes**

Run: `TT_UCD_FILTER=legacy sh tests/test_uci_defaults.sh`
Expected: PASS — one zone with `device='tun+'` and no `tt0`, exactly one reload, exact migration log line, no forwarding at all (`FWD_COUNT=0` — the fixture has none, creation only fires when no zone exists, and migration never creates forwarding).

- [ ] **Step 4: Regression check on the previous chunks**

Run: `TT_UCD_FILTER=fresh sh tests/test_uci_defaults.sh && TT_UCD_FILTER=duplicated sh tests/test_uci_defaults.sh`
Expected: PASS — both still green.

**Verification**: fresh, duplicated, legacy all green. `upgrade` and `side-effects` still expected to FAIL (seed + finalize not implemented yet — next tasks).

### [ ] Task 5: Routing profile seed block

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

- [ ] **Step 1: Confirm the failing state**

Run: `TT_UCD_FILTER=upgrade sh tests/test_uci_defaults.sh`
Expected: FAIL — no profile created (`@routing_profile[` count = 0 in the `uci show trusttunnel` dump), no `endpoint.routing_profile`, no seed log line.

- [ ] **Step 2: Implement the profile-seed phase (contractual)**

New original expression implementing, positioned AFTER the firewall block (dedup/creation/migration) and BEFORE the cache clear, matching the contract and the inherited placement: `config_load trusttunnel`; `_has_profile=""`; `count_profile() { _has_profile=1; }` — a `config_foreach` callback with a targeted `# shellcheck disable=SC2329,SC2317` + one-line comment (the OpenWrt-library callback pattern, same as the other callbacks in this script); `config_foreach count_profile routing_profile`. When `_has_profile` is empty (an upgraded install without the section): `_prof=$(uci add trusttunnel routing_profile)`; `uci set "trusttunnel.$_prof.name"='Default'`; `uci set "trusttunnel.$_prof.mode"='vpn'`; migrate the legacy list — `uci -q get trusttunnel.domains.direct 2>/dev/null | while IFS= read -r _d; do [ -n "$_d" ] && uci add_list "trusttunnel.$_prof.bypass_rules"="$_d"; done` (a pipeline, NOT `for _d in $(...)`: the loop form needs an unquoted expansion, which shellcheck flags and which also trips on empty input); `uci set trusttunnel.endpoint.routing_profile='Default'`; `uci commit trusttunnel`; `logger -t trusttunnel "created the default routing profile; the old direct list moved into its bypass rules"` (exact string, pinned in the issue). No-op when a profile exists (fresh installs carry it from the shipped config).

- [ ] **Step 3: Run test to verify it passes**

Run: `TT_UCD_FILTER=upgrade sh tests/test_uci_defaults.sh`
Expected: PASS — one `routing_profile` with `name='Default'` and `mode='vpn'`, every `domains.direct` value present in `bypass_rules`, `endpoint.routing_profile='Default'`, the exact seed log line, `RELOADS=0` (firewall untouched); on the second run the trusttunnel state is unchanged and no new log lines appear.

- [ ] **Step 4: Regression check on the previous chunks**

Run: `TT_UCD_FILTER=fresh sh tests/test_uci_defaults.sh && TT_UCD_FILTER=duplicated sh tests/test_uci_defaults.sh && TT_UCD_FILTER=legacy sh tests/test_uci_defaults.sh && TT_UCD_FILTER=idempotent sh tests/test_uci_defaults.sh`
Expected: PASS — fresh/duplicated/legacy unchanged; `idempotent` now passes because the seed block converges the upgrade-shaped fixture (creation + seed fire on run 1, both no-ops on run 2, both `uci show` dumps identical). `side-effects` still expected to FAIL (finalize not implemented yet — next task).

**Verification**: fresh, duplicated, legacy, upgrade, idempotent green. `side-effects` remains red until Task 6.

### [ ] Task 6: Cache clear, service enable, LuCI cache clear, exit 0

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`

- [ ] **Step 1: Confirm the failing state**

Run: `TT_UCD_FILTER=side-effects sh tests/test_uci_defaults.sh`
Expected: FAIL — `release.json` still present, `/tmp/luci-indexcache` still present, no rc.d link.

- [ ] **Step 2: Implement the finalize phase (contractual)**

New original expression implementing, unconditionally on every run: `mkdir -p /var/cache/trusttunnel`; `rm -f /var/cache/trusttunnel/release.json`; `/etc/init.d/trusttunnel enable` (quieted; always, regardless of `main.enabled` — the rc.d link is what auto-starts the service, the UCI flag is only checked inside `start_service`); `rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*` (stderr suppression optional); final `exit 0`.

- [ ] **Step 3: Run test to verify it passes**

Run: `TT_UCD_FILTER=side-effects sh tests/test_uci_defaults.sh`
Expected: PASS — exit 0, rc.d link `S95trusttunnel` → `../../etc/init.d/trusttunnel`, cache dir present without `release.json`, both LuCI caches gone, no log lines (the fixture ships a profile, so the seed block is a no-op and writes nothing).

- [ ] **Step 4: Regression check on all previous chunks**

Run: `sh tests/test_uci_defaults.sh`
Expected: PASS — all SIX scenarios green on the new file.

**Verification**: full harness green on the new file.

### [ ] Task 7: Idempotence, full suite, final gates

**Files:**

- None new — verification only: `packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`, `tests/test_uci_defaults.sh`

- [ ] **Step 1: Verify idempotence explicitly**

Run: `TT_UCD_FILTER=idempotent sh tests/test_uci_defaults.sh`
Expected: PASS — `uci show firewall` identical after run 2, `uci show trusttunnel` identical after run 2 (the seeded profile is not duplicated and `endpoint.routing_profile` is not rewritten), reload count stays 1, the seed log line appears exactly once (run 1) with no new lines after run 2. If it FAILs, fix the offending phase in the script (dedup/creation/migration/seed must be no-ops on a converged config) and re-run.

- [ ] **Step 2: Run the full test suite**

Run: `sh tests/run.sh`
Expected: PASS — `== all tests passed`; the new `test_uci_defaults.sh` runs within the standard harness (fresh `$TT_TEST_TMP`, closed stdin; docker-present CI runs it, docker-absent machines get the visible SKIP).

- [ ] **Step 3: Run the static gates on the new file**

Run:
`sh -n packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
`docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
`git ls-files -s -- packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
Expected: `sh -n` silent; shellcheck clean (no output, exit 0); index mode `100755`. If the mode regressed: `chmod 755` and re-add.

- [ ] **Step 4: Clean-room completeness check (PRD requirement)**

Run: `git status --porcelain` and `ls packages/luci-app-trusttunnel/root/etc/uci-defaults/`
Expected: the only artifact for this issue is the rewritten `40-luci-trusttunnel` (+ new `tests/test_uci_defaults.sh`); no `*.old`, no backup copies, no other file containing the inherited script's text anywhere in the tree.

**Verification**: idempotent scenario green; `sh tests/run.sh` green; shellcheck v0.11.0 + `sh -n` clean; mode `100755`; no stray copies of the old file.

## Notes for the implementer

- Clean-room rule: write the script from the contract in this plan and in issue TT-07; do not open the inherited file while writing the new text (a `git show` of the old blob is only needed to validate observable details like the migration log message — already recorded here).
- The profile-seed block is part of the contract (issue TT-07, "Routing profile seed" paragraph) and runs immediately on install via `install.sh`'s "Seeding the default routing profile" step — implement it in Task 5 exactly as specified: position (after the firewall block, before the cache clear), `config_load trusttunnel`, the `config_foreach` count, `name='Default'`/`mode='vpn'`, the `uci -q get | while read` migration pipeline, `endpoint.routing_profile='Default'`, `uci commit trusttunnel`, and the exact log string. The harness asserts every one of these.
- If any shellcheck disable beyond SC1091 appears necessary, confirm it against the pinned v0.11.0 image and add a one-line comment explaining the OpenWrt-library callback pattern — same convention as the other `config_foreach`-using scripts in the repo.
- The rootfs container runs as root, so writes to `/etc`, `/tmp`, `/var` in the harness are unprivileged there.
- CI implication: no workflow change needed — ci.yml already shellchecks this file and enforces `100755`; `sh -n` coverage of this file in CI is left to the packaging/CI reimplementation issue (ci.yml is that issue's file).

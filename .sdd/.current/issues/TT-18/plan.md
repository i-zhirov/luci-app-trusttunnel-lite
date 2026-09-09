# Implementation Plan: install.sh

- **Created**: 2026-09-08
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-18/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "Clean-room reimplementation of install.sh; must stay consistent with uninstall.sh and the release.yml verify steps; TDD with a stub dry-run harness and rootfs golden diff against the current script's behavior"

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`install.sh` changed; the issue contract was updated:

- **Dependency install includes `nftables`** (both branches:
  `apk add kmod-tun ip-full nftables curl ca-bundle` /
  `opkg install kmod-tun ip-full nftables curl ca-bundle` — install.sh
  lines 186/188). The harness stub expectations and the rootfs state diffs
  must include the new package.
- **NEW uci-defaults step** after `rpcd restart`: run
  `/etc/uci-defaults/40-luci-trusttunnel` immediately (guarded by `-x`,
  output silenced, warning fallback message when it fails) — seeds the
  Default routing profile and migrates `domains.direct`. Chunk 5 covers
  it: stub the uci-defaults execution (success + failure paths, the `-x`
  guard, silenced output, the exact warning fallback message, stdout log
  assertion, ordering `rpcd restart` → uci-defaults → `start`) and extend
  the rootfs golden diff to check the seeded profile in
  `/etc/config/trusttunnel`.
- Everything else unchanged.

## Summary

Reimplement `install.sh` (281 lines, inherited GPL-2.0 skeleton) from the
TT-18 contract as one POSIX-sh installer over both OpenWrt package-manager
generations: environment checks (`TT_REPO_URL`, `/etc/openwrt_release`), PM
detection with version floors (apk ≥ 25, opkg ≥ 22), CPU allowlist via
`uname -m`, per-PM repository setup (apk: key + per-arch `packages.adb`
entry; opkg: idempotent `src/gz trusttunnel` feed line + usign-fingerprint
key), update/install sequence (`kmod-tun ip-full nftables curl ca-bundle` →
`luci-app-trusttunnel` → optional `luci-i18n-trusttunnel-ru` → tripwire),
`was_running` remember/stop/restore around `rpcd restart`, and the
immediate uci-defaults run between the `rpcd restart` and the restore
(`-x`-guarded, silenced, warning fallback; seeds `/etc/config/trusttunnel`).

The plan is TDD-ordered: baseline first (shellcheck state + behavior
inventory + preserved oracle copy), then a docker-based stub dry-run harness
(`tests/install-harness.sh`, new code, not picked up by `tests/run.sh`),
then five implementation chunks each verified by shellcheck and the harness
against the preserved current script, then full verification: shellcheck
v0.11.0 (exact pinned CI invocation), `sh -n`, executable bit `100755`, the
repo unit suite (`sh tests/run.sh` — `test_deps.sh` guards the nftables
dependency lines), and golden rootfs tests on `openwrt/rootfs` images (apk
25.12.0; opkg 22.03.7/23.05.6/24.10.8) byte-diffing the resulting `/etc/apk`,
`/etc/opkg` and `/etc/config/trusttunnel` state against the current script's
behavior, plus the negative CPU test. The install/uninstall/release.yml
consistency contract (URLs, key file names, feed line) is preserved;
`uninstall.sh` and both workflows stay untouched (ci.yml is TT-19, release.yml
is TT-20 and is blocked by this issue's parity). Zero text is copied from the
inherited file into the new one; each chunk is written fresh from the
contract and replaces the inherited slice.

## Technical Context

- **Language/Version**: POSIX sh (`#!/bin/sh`, `set -e`; dash/busybox ash on OpenWrt)
- **Primary Dependencies**: busybox `wget` (key fetches), `apk` (apk-tools v3, OpenWrt 25.12+), `opkg` + `usign` (OpenWrt 22.03–24.10), `uname -m`, `/etc/openwrt_release`, `/etc/init.d/trusttunnel`, `/etc/init.d/rpcd`, `/etc/uci-defaults/40-luci-trusttunnel` (immediate seed run)
- **Storage**: `/etc/apk/keys/trusttunnel.pub`, `/etc/apk/repositories.d/trusttunnel.list`, `/etc/opkg/customfeeds.conf`, `/etc/opkg/keys/trusttunnel.pub` + `/etc/opkg/keys/<fingerprint>`, `/etc/config/trusttunnel` (seeded Default profile)
- **Testing**: shellcheck v0.11.0 via `koalaman/shellcheck:v0.11.0 -s sh` (exact CI invocation from `.github/workflows/ci.yml`), `sh -n`, `tests/run.sh` (existing repo unit suite — `test_deps.sh` asserts the dependency lines), `tests/install-harness.sh` (new docker stub harness), golden rootfs tests on `openwrt/rootfs:x86-64-{25.12.0,22.03.7,23.05.6,24.10.8}`, `git ls-files -s` mode check
- **Target Platform**: OpenWrt routers — 22.03–24.10 (opkg) and 25.12+ (apk)

## Research

### Baseline state of the inherited file (verified 2026-09-08)

- `git ls-files -s install.sh` → mode `100755` in the index (CI gate expects exactly this).
- `sh -n install.sh` → OK.
- CI shellcheck invocation (`docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh`) → clean. Baseline linter state: GREEN; the reimplementation must stay green under the same pinned invocation.
- The release.yml verify steps ("Verify the apk installs on 25.12", "Verify the ipk installs on 23.05/24.10") execute exactly this script's flow (key install, arch-specific repo entry, feed line, fingerprint key) — they are the end-to-end oracle and TT-20 is blocked on this issue's parity, so the contracts they mirror must not drift.

### Contract vs current behavior — step-by-step verification

| # | Issue contract item | Current behavior | Verdict |
|---|---|---|---|
| 1 | `#!/bin/sh`; `set -e`; `say()`/`die()` helpers | present | matches |
| 2 | `TT_REPO_URL` (default `https://i-zhirov.github.io/trusttunnel-openwrt`); key URLs `<url>/apk/key-build.pub`, `<url>/opkg/opkg-key.pub` | present, derived from `REPO_URL` | matches |
| 3 | `/etc/openwrt_release` must exist (sourced) | present; die "this script is for OpenWrt only" when missing | matches |
| 4 | PM detection: apk (major ≥ 25) else opkg (major ≥ 22); neither → die | present; floors checked against `DISTRIB_RELEASE` major; non-numeric major → warning and continue (see D1) | matches + D1 |
| 5 | CPU check via `uname -m` ∈ {x86_64/x86-64/x64/amd64, aarch64/arm64, armv7l/armv8l, mips, mipsel}; else die BEFORE any changes | present with exactly the 10 names; runs after env/PM checks, before any write | matches |
| 6a | apk repo setup: wget `<url>/apk/key-build.pub` → `/etc/apk/keys/trusttunnel.pub`; `apk --print-arch`; write `<url>/apk/<arch>/packages.adb` into `/etc/apk/repositories.d/trusttunnel.list` | present, in that order (key before index: apk refuses untrusted indexes) | matches |
| 6b | opkg repo setup: idempotent append `src/gz trusttunnel <url>/opkg` to `/etc/opkg/customfeeds.conf`; fetch key → `/etc/opkg/keys/trusttunnel.pub`; usign fingerprint → copy to `/etc/opkg/keys/<fingerprint>` | present; idempotence via anchored line match; `usign -F -p`; stable-name copy kept alongside (see D2) | matches + D2 |
| 7 | `apk update` / `opkg update`; install `kmod-tun ip-full nftables curl ca-bundle` | present (install.sh lines 186/188), in that order | matches |
| 8 | Remember `was_running` (`/etc/init.d/trusttunnel running`); stop the service if installed | present; guard is executable-init-script existence; probe `running`; stop with non-fatal rc | matches |
| 9 | Install `luci-app-trusttunnel`, then optional `luci-i18n-trusttunnel-ru` (warning, not fatal); tripwire `trusttunnel-client` installed | present; i18n failure → warning, continue; tripwire: `apk info -e` / `opkg list-installed` grep | matches |
| 10 | `rpcd restart`; run `/etc/uci-defaults/40-luci-trusttunnel` IMMEDIATELY (if `-x`, output silenced, warning fallback "warning: the default routing profile was not created; run /etc/uci-defaults/40-luci-trusttunnel manually" on failure); then if `was_running=1` start service back up | present (install.sh lines 246–257); rpcd restart quieted and non-fatal; uci-defaults `-x`-guarded, silenced, non-fatal; start only when `was_running=1` | matches |
| 11 | Service stays disabled on first install; repo entry persists for future `apk upgrade`/`opkg upgrade` | present (no start on first install; closing banner states the repo stays configured) | matches |
| 12 | Executable bit `100755`; shellcheck-clean (`-s sh`) | verified: `100755`, shellcheck v0.11.0 clean, `sh -n` OK | matches |

**Discrepancies found (all observed-behavior notes, none contract-breaking):**

- **D1** — Unparseable `DISTRIB_RELEASE` (non-numeric major): the current script prints a warning and continues instead of dying. Not mentioned in the issue contract. Preserve: it is deliberate behavior and the acceptance criteria compare state "exactly as today".
- **D2** — The opkg branch keeps a stable-name copy `/etc/opkg/keys/trusttunnel.pub` alongside the fingerprint-named copy. The issue text mentions only the fingerprint copy, but the stable name is `uninstall.sh`'s handle for removing the key, and the release.yml opkg verify creates both files. Preserve.
- **D3** — Version floors are OpenWrt release majors (`DISTRIB_RELEASE`), not the PM binaries' own versions. The die messages say "OpenWrt 25.12 or newer" / "22.03 or newer" — the issue's "major version" means the OpenWrt release major. Implement the same way.
- **D4** — stdout text: the acceptance diff targets `/etc` state files, not stdout. Keep `say`/`die` messages semantically equivalent (die messages are user-facing contract), wording need not be byte-identical. Exception: the uci-defaults warning fallback text IS an exact-match contract (the issue quotes it verbatim).

### Install/uninstall/release.yml consistency contract (must hold after the rewrite)

The three artifacts agree on every layout detail; the rewrite must keep all of them:

- Repo base URL: `https://i-zhirov.github.io/trusttunnel-openwrt` (default, `TT_REPO_URL`-overridable).
- apk: key fetched from `<url>/apk/key-build.pub` into `/etc/apk/keys/trusttunnel.pub`; repo entry is exactly `<url>/apk/<arch>/packages.adb` (index file named explicitly; `<arch>` = `apk --print-arch`); file `/etc/apk/repositories.d/trusttunnel.list`.
- opkg: feed line `src/gz trusttunnel <url>/opkg` (URL must NOT name the index; opkg appends `/Packages.gz`); removal pattern in uninstall.sh is `^src\/gz trusttunnel `; key fetched from `<url>/opkg/opkg-key.pub` into `/etc/opkg/keys/trusttunnel.pub`, fingerprint via `usign -F -p`, fingerprint-named copy next to it.
- uninstall.sh removes exactly: `/etc/apk/repositories.d/trusttunnel.list`, `/etc/apk/keys/trusttunnel.pub`, the feed line, `/etc/opkg/keys/trusttunnel.pub` and the fingerprint copy.
- release.yml verify steps mirror the same arrangement (key in `/etc/apk/keys/trusttunnel.pub`, arch-specific `packages.adb` entry, `src/gz trusttunnel` line, both key files in `/etc/opkg/keys`).

### Stub dry-run harness design (`tests/install-harness.sh`)

Why docker: the script writes absolute paths under `/etc`, so a dry run must happen in a disposable root. The harness runs each scenario inside a fresh `openwrt/rootfs` container (the image doubles as the "scratch /etc"), with the real package-manager and system tools neutralized and recording stubs first in `PATH`.

- **Neutralization**: the image's real `apk`/`opkg`/`uname`/`usign`/`wget` are renamed aside (located via `command -v`), so only stubs respond and canned outputs are authoritative — required for the "neither PM" and crafted-output scenarios.
- **Stubs** (each appends `$0` + argv + relevant env to a per-scenario call log; behavior driven by env):

| Stub | Canned behavior |
|---|---|
| `uname` | `-m` prints `$STUB_UNAME_M` (default: the image's real value) |
| `apk` | `--print-arch` prints `$STUB_APK_ARCH` (default `x86_64`); `update` exits `$STUB_APK_UPDATE_RC` (0); `add` exits `$STUB_APK_ADD_RC` (0); `info -e <pkg>` exits `$STUB_APK_INFO_RC` (0) |
| `opkg` | `update` exits `$STUB_OPKG_UPDATE_RC` (0); `install <pkgs>` exits 0, or 1 if `$STUB_OPKG_FAIL_PKG` is among the args (i18n-warning scenario); `list-installed` prints `$STUB_OPKG_LIST` (canned line list incl. `trusttunnel-client`) |
| `wget` | records `-O <path>` and URL; creates the target file with `$STUB_WGET_BODY` (default `stub pubkey`); exits `$STUB_WGET_RC` (0) |
| `usign` | `-F -p <file>` prints `$STUB_USIGN_FP` (default 64-hex fake); exits `$STUB_USIGN_RC` (0) |
| fake `/etc/init.d/trusttunnel` | `running` exits `$STUB_TT_RUNNING_RC`; `stop`/`start` recorded, exit 0 |
| fake `/etc/init.d/rpcd` (optional) | records `restart` |
| fake `/etc/uci-defaults/40-luci-trusttunnel` (planted) | records invocation in the call log; exits `$STUB_UCI_DEFAULTS_RC` (0); absent by default, so the script's `-x` guard skips the step entirely |

- **Scenario shape**: (image, prep, env overrides, expected exit code, expected call-log subsequence, expected file contents/existence, expected absences). Prep mirrors release.yml (`mkdir -p /var/lock /etc/apk/keys /etc/apk/repositories.d /etc/opkg/keys`) and may additionally craft `/etc/openwrt_release` (e.g., a 21.x value) or hide it (`mv` aside) for the env-check scenarios, or plant the fake `/etc/uci-defaults/40-luci-trusttunnel` (executable, recording, env-driven rc) for the chunk-5 scenarios. Each scenario runs `sh /src/install.sh` with a throwaway `TT_REPO_URL` and asserts.
- **Negative controls**: one deliberately wrong expectation per harness milestone must FAIL the harness — proves the harness detects drift (mirrors the repo's "control on the check itself" convention from ci.yml).
- The harness is a dev tool: it requires docker, is named `install-harness.sh` (NOT `test_*.sh`, so `tests/run.sh` never picks it up and the CI unit-test step stays docker-free), and exits 0 with a skip note when docker is unavailable. `ci.yml` is not modified in this issue (TT-19 owns it).
- The preserved current script is mounted read-only into a scenario container (env `TT_BASELINE_INSTALL`), so every harness scenario can be run against the oracle and the new file interchangeably.

### Golden-diff methodology (rootfs, real tools, live repo)

Per image `openwrt/rootfs:x86-64-{25.12.0,22.03.7,23.05.6,24.10.8}`: run the current script in one fresh container and the new script in another (identical prep mirroring release.yml, `TT_REPO_URL` default = live Pages repo), then `docker cp` the state paths out and `diff -r`. Assert byte-identical `/etc/apk/keys`, `/etc/apk/repositories.d`, `/etc/opkg/customfeeds.conf`, `/etc/opkg/keys`, `/etc/config/trusttunnel` (the seeded Default profile); identical installed package set (the three trusttunnel packages — luci-app-trusttunnel, luci-i18n-trusttunnel-ru, trusttunnel-client — + `kmod-tun ip-full nftables curl ca-bundle`); service installed but not started on first install (no rc.d start link). The baseline copy of the current script lives in the OS temp dir (never in the repo) and is deleted at the end (PRD convention: no `*.old`, no old-vs-new diffs committed).

## Entities

### `/etc/apk/keys/trusttunnel.pub`

- **Fields**: file — content = apk signing public key fetched from `<repo-url>/apk/key-build.pub` via wget
- **Relationships**: created before the first `apk update` (apk refuses untrusted indexes); consumed by apk; removed by uninstall.sh
- **Validation**: fetched with wget; fetch failure → die before any repo entry exists
- **States**: absent → present (repo configured); persists after install

### `/etc/apk/repositories.d/trusttunnel.list`

- **Fields**: single line `<repo-url>/apk/<arch>/packages.adb`, `<arch>` = `apk --print-arch` output
- **Relationships**: the URL must name `packages.adb` explicitly (bare directory URL would make apk look for Alpine-style `APKINDEX.tar.gz`)
- **Validation**: `apk --print-arch` failure → die
- **States**: absent → present (per-arch entry); persists after install (upgrade path)

### `/etc/opkg/customfeeds.conf`

- **Fields**: appended line `src/gz trusttunnel <repo-url>/opkg`; URL must NOT name the index
- **Relationships**: removal pattern in uninstall.sh is `^src\/gz trusttunnel `; opkg verifies `Packages.sig` against the key below
- **Validation**: append idempotent (anchored existence check; re-run adds no duplicate); file created if absent
- **States**: absent → present; persists after install

### `/etc/opkg/keys/trusttunnel.pub` + `/etc/opkg/keys/<fingerprint>`

- **Fields**: two files, same content = usign public key fetched from `<repo-url>/opkg/opkg-key.pub`; fingerprint = `usign -F -p` output
- **Relationships**: the fingerprint-named copy is what opkg-key matches (`usign -P` matches files named by fingerprint); the stable-name copy is uninstall.sh's removal handle
- **Validation**: wget failure → die; `usign` missing or fingerprint read failure → die
- **States**: absent → both present; both removed by uninstall.sh

### `/etc/config/trusttunnel` (seeded Default profile)

- **Fields**: UCI config file produced by `/etc/uci-defaults/40-luci-trusttunnel` — the Default routing profile plus the `domains.direct` migration
- **Relationships**: created by the immediate uci-defaults run after `rpcd restart`; on first install it is produced by THIS install, not the next boot
- **Validation**: byte-identical between baseline and new script (golden diff path); when the uci-defaults script is missing or fails, no file is created and the exact warning fallback is printed
- **States**: absent → present (first install, uci-defaults succeeds); unchanged on failure (warning fallback, install still exits 0)

### TrustTunnel service state (was_running contract)

- **Fields**: `was_running` ∈ {0, 1}, probed via `/etc/init.d/trusttunnel running` when the init script exists
- **States**: first install (no init script) → stays disabled; reinstall with stopped service → stop called, stays stopped; reinstall with running service → stop before install, start after `rpcd restart` + the uci-defaults run

## Contracts

The contract is the issue's "Contract to reproduce" section, plus the cross-file consistency contract documented in Research (install.sh ↔ uninstall.sh ↔ release.yml: repo URLs, key file names, feed line shape, fingerprint naming, stable-name key copy). No API endpoints. `uninstall.sh`, `ci.yml`, `release.yml` are untouched.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `install.sh` | Re-create (modify in place) | Rewritten from the TT-18 contract in five chunks; identical external behavior; mode `100755`; shellcheck-clean; zero inherited expression |
| `tests/install-harness.sh` | Create | Docker stub dry-run harness (dev tool; deliberately NOT `test_*.sh`, so `tests/run.sh` ignores it; skips without docker) — runs scenarios against the new script and the preserved baseline copy |
| `tests/run.sh` (+ `tests/test_deps.sh`) | Test (unchanged) | Existing repo unit suite — the verification gate for the dependency lines: `test_deps.sh` asserts both install.sh branches install `kmod-tun ip-full nftables curl ca-bundle` and all Makefile-declared deps |

## Tasks

### [x] Task 1: Baseline — shellcheck state, behavior inventory, preserve oracle copy

**Files:**

- Read: `install.sh`
- Read: `.github/workflows/release.yml` (verify steps, lines 461–518)
- Read: `.github/workflows/ci.yml` (shellcheck gate, lines 88–98; executable-bit gate, lines 33–51)
- Read: `uninstall.sh` (consistency contract)

- [x] **Step 1: Record the linter and mode baseline**

Run: `git ls-files -s install.sh` Expected: mode `100755`
Run: `sh -n install.sh` Expected: exit 0
Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh` Expected: exit 0, no findings (verified 2026-09-08)

- [x] **Step 2: Produce the behavior inventory**

Walk the issue's contract list against the current script and record the result — use the verification table in Research as the checklist; confirm each of the 12 contract items (including the nftables dependency set and the immediate uci-defaults run) and the D1–D4 notes. This inventory is the reference for the golden diff.

- [x] **Step 3: Preserve the oracle copy outside the repo**

Copy the current script to the OS temp dir (e.g. `/var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/install.sh.baseline`). It is the oracle for the harness and the golden diff; it never enters the repo and is deleted in Task 8.

**Verification**: all three checks in Step 1 are green and recorded; the inventory confirms every contract item; the baseline copy exists at the scratch path; `git status` shows no changes.

### [x] Task 2: Build the stub dry-run harness

**Files:**

- Create: `tests/install-harness.sh`

- [x] **Step 1: Write the harness skeleton + the chunk-1 scenarios (assertions first)**

Implement the harness per the Research design: docker scenario runner, neutralization of real `apk`/`opkg`/`uname`/`usign`/`wget`, the stub set with env-driven canned outputs and call log, prep mirroring release.yml, and the chunk-1 scenario set:

- `/etc/openwrt_release` hidden → die (exit 1), message says OpenWrt-only.
- No PM stubs and real PMs neutralized → die, message says neither apk nor opkg found.
- Only the `apk` stub present → PM detection passes for apk.
- Only the `opkg` stub present → PM detection passes for opkg.
- Crafted release `DISTRIB_RELEASE=21.02.7` with opkg → die mentioning 22.03; with apk → die mentioning 25.12.
- Crafted release `DISTRIB_RELEASE=25.12.0` with apk → passes; `22.03.7` with opkg → passes.
- Non-numeric major (D1) → warning printed, execution continues.

All harness code is new expression (it is not part of the inherited file).

- [x] **Step 2: Run the harness against the preserved current script (oracle green)**

Run: `TT_BASELINE_INSTALL=/var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/install.sh.baseline sh tests/install-harness.sh` Expected: every chunk-1 scenario PASSES against the inherited file (it is the oracle)

- [x] **Step 3: Negative control**

Temporarily invert one expectation (e.g., expect the wrong die message) → the harness must FAIL on the same scenario, proving it detects drift; revert.

**Verification**: oracle green for all chunk-1 scenarios; negative control fails and is reverted; `tests/run.sh` is unaffected (no `test_*.sh` file added).

### [x] Task 3: Chunk 1 — header, environment checks, PM detection with version floors

**Files:**

- Modify: `install.sh` (top slice only — shebang, `set -e`, helpers, `TT_REPO_URL` + derived key URLs, OpenWrt-only check, PM detection, version floors)

- [x] **Step 1: Rewrite the slice from the contract**

Write this slice fresh from the issue's contract text (items 1–4 plus D1/D3 notes), replacing the inherited slice. No line of the new text is a transformation of the inherited line; behavior stays identical. The rest of the file is still the inherited tail (replaced in Tasks 4–7).

- [x] **Step 2: Verify the slice**

Run: `sh -n install.sh` Expected: exit 0
Run: the pinned shellcheck command from Task 1 Expected: clean
Run: the harness with `TT_BASELINE_INSTALL` set, plus the new-file mode: `sh tests/install-harness.sh` with the harness pointed at the worktree `install.sh` Expected: all chunk-1 scenarios pass for BOTH the baseline copy and the new file

**Verification**: shellcheck clean; `sh -n` OK; harness chunk-1 scenarios green for new file and baseline (identical behavior); no `tests/` change beyond the harness.

### [x] Task 4: Chunk 2 — CPU check (`uname -m` allowlist, die before any writes)

**Files:**

- Modify: `install.sh` (replace the architecture-check slice with fresh expression)
- Modify: `tests/install-harness.sh` (add chunk-2 scenarios)

- [x] **Step 1: Add the chunk-2 harness scenarios**

- `STUB_UNAME_M` = each of the 10 accepted names (x86_64, x86-64, x64, amd64, aarch64, arm64, armv7l, armv8l, mips, mipsel) → check passes.
- `STUB_UNAME_M` ∈ {armv5tel, armv6l, mips64el, riscv64, powerpc, i386, (empty)} → die with an unsupported-CPU message, exit 1.
- **Negative-write assertion**: for the riscv64 case, record a pre-run hash of `/etc/opkg/customfeeds.conf` (if present) and assert after the run: no `/etc/apk/keys/trusttunnel.pub`, no `/etc/apk/repositories.d/trusttunnel.list`, no `/etc/opkg/keys/trusttunnel.pub`, feed file unchanged — the check dies BEFORE any changes.

- [x] **Step 2: Run against the baseline copy**

Expected: all chunk-2 scenarios green on the inherited file (it already dies before writes).

- [x] **Step 3: Rewrite the slice from the contract**

Replace the architecture-check slice (contract item 5): the same 10-name allowlist, the same die-before-any-writes position, message naming the unsupported CPU and the supported families.

- [x] **Step 4: Verify**

Run: pinned shellcheck + `sh -n` Expected: clean/OK
Run: harness (baseline + new file) Expected: all chunk-1 + chunk-2 scenarios green for both

**Verification**: allowlist and negative-CPU behavior identical between baseline and new file; the negative-write assertion passes (zero writes on unsupported CPU).

### [x] Task 5: Chunk 3 — repository setup per PM (apk branch, then opkg branch)

**Files:**

- Modify: `install.sh` (replace the repository-setup slice with fresh expression)
- Modify: `tests/install-harness.sh` (add chunk-3 scenarios)

- [x] **Step 1: Add the chunk-3 harness scenarios (apk branch first)**

apk scenarios:
- Happy path: `wget` stub records URL `<test-repo>/apk/key-build.pub` and `-O /etc/apk/keys/trusttunnel.pub`; file content = stub body; `apk --print-arch` stub prints `x86_64`; `/etc/apk/repositories.d/trusttunnel.list` contains exactly one line `<test-repo>/apk/x86_64/packages.adb`; call order: key fetch before `--print-arch` before the list write.
- `wget` failure (`STUB_WGET_RC=1`) → die, no list file.
- `apk --print-arch` failure → die.

opkg scenarios:
- Fresh `customfeeds.conf` absent → created with exactly one line `src/gz trusttunnel <test-repo>/opkg`.
- Pre-existing file with the line → run twice, still exactly one `trusttunnel` line, pre-existing other lines untouched (idempotence, matches uninstall's anchored removal).
- Key fetch: `wget` records `<test-repo>/opkg/opkg-key.pub` → `/etc/opkg/keys/trusttunnel.pub`; `usign` stub prints `$STUB_USIGN_FP`; both `/etc/opkg/keys/trusttunnel.pub` and `/etc/opkg/keys/<fp>` exist with identical content (D2).
- `wget` failure → die; `usign` missing (neutralized, no stub) → die; `usign` exit 1 → die.

- [x] **Step 2: Run against the baseline copy**

Expected: all chunk-3 scenarios green on the inherited file.

- [x] **Step 3: Rewrite the slice from the contract**

Replace the repository-setup slice (contract items 6a/6b): apk branch (key first, `apk --print-arch`, explicit `packages.adb` entry) and opkg branch (idempotent feed append, key fetch, fingerprint copy, stable-name copy).

- [x] **Step 4: Verify**

Run: pinned shellcheck + `sh -n` Expected: clean/OK
Run: harness (baseline + new file) Expected: chunks 1–3 green for both

**Verification**: resulting `/etc/apk` and `/etc/opkg` file contents/call orders byte-identical between baseline and new file; idempotence and all failure paths match.

### [x] Task 6: Chunk 4 — update/install sequence (deps, app, optional i18n, tripwire)

**Files:**

- Modify: `install.sh` (replace the update+install slice with fresh expression)
- Modify: `tests/install-harness.sh` (add chunk-4 scenarios)

- [x] **Step 1: Add the chunk-4 harness scenarios**

- Happy path: call-log subsequence for apk is `update`, then `add kmod-tun ip-full nftables curl ca-bundle`, then `add luci-app-trusttunnel`, then `add luci-i18n-trusttunnel-ru`, then `info -e trusttunnel-client`; same ordering for opkg with its verbs (`update`, then `install kmod-tun ip-full nftables curl ca-bundle`, ...).
- i18n failure is NOT fatal: `STUB_APK_ADD_RC`/`STUB_OPKG_FAIL_PKG=luci-i18n-trusttunnel-ru` → warning printed, exit 0, main package still installed.
- Tripwire failure IS fatal: `STUB_APK_INFO_RC=1` (or canned `opkg list-installed` without `trusttunnel-client`) → die mentioning trusttunnel-client.
- `update` failure → die.

- [x] **Step 2: Run against the baseline copy**

Expected: all chunk-4 scenarios green on the inherited file.

- [x] **Step 3: Rewrite the slice from the contract**

Replace the update/install slice (contract items 7 and 9): update, explicit dependency set `kmod-tun ip-full nftables curl ca-bundle`, main package (fatal on failure), optional translation package (warning on failure, never fatal), tripwire check that the client package is installed.

- [x] **Step 4: Verify**

Run: pinned shellcheck + `sh -n` Expected: clean/OK
Run: harness (baseline + new file) Expected: chunks 1–4 green for both

**Verification**: call order and failure semantics identical between baseline and new file (dependency set `kmod-tun ip-full nftables curl ca-bundle` — nftables included on both branches, i18n optional, tripwire fatal, update fatal).

### [x] Task 7: Chunk 5 — was_running remember/stop/restore, rpcd restart, immediate uci-defaults run, closing banner

**Files:**

- Modify: `install.sh` (replace the service-state slice and the closing banner with fresh expression)
- Modify: `tests/install-harness.sh` (add chunk-5 scenarios)

- [x] **Step 1: Add the chunk-5 harness scenarios**

Use the fake `/etc/init.d/trusttunnel`, the optional fake `/etc/init.d/rpcd`, and the planted fake `/etc/uci-defaults/40-luci-trusttunnel` (all call-recording stubs):
- First install: no fake init script planted → no `stop`/`start` calls recorded; service left disabled; script ends exit 0.
- Init script present, `running` exits 1 → `stop` recorded, no `start`.
- Init script present, `running` exits 0 → `stop` recorded (before the package-install calls), `start` recorded (after the `rpcd restart` AND the uci-defaults calls).
- `rpcd restart` is invoked (fake rpcd records it) and its failure is non-fatal.
- uci-defaults SUCCESS: `40-luci-trusttunnel` planted executable → invoked exactly once; call-log order is `rpcd restart` → `/etc/uci-defaults/40-luci-trusttunnel` → `start` (when `was_running=1`); invocation output is silenced (no stub stdout/stderr leaks into the script's output — the script's own "== Seeding the default routing profile" line IS present); script exits 0.
- uci-defaults FAILURE: planted stub exits 1 (`STUB_UCI_DEFAULTS_RC=1`) → the script prints EXACTLY `warning: the default routing profile was not created; run /etc/uci-defaults/40-luci-trusttunnel manually`, still exits 0, and `start` still happens when `was_running=1` (the step is non-fatal).
- uci-defaults ABSENT (not planted, or planted non-executable) → NOT invoked, no seeding line, no warning line, execution continues — the `-x` guard skips the step.
- **Log assertion**: the exact warning fallback text above appears verbatim in the captured stdout of the FAILURE scenario, and is absent from the SUCCESS and ABSENT scenarios.
- Closing output states the repository stays configured for `apk update && apk upgrade` / `opkg update && opkg upgrade`.

- [x] **Step 2: Run against the baseline copy**

Expected: all chunk-5 scenarios green on the inherited file.

- [x] **Step 3: Rewrite the slice from the contract**

Replace the service-state slice and closing banner (contract items 8, 10, 11): remember `was_running` before stopping, stop only when the init script exists, `rpcd restart` (quieted, non-fatal), the IMMEDIATE uci-defaults run between the restart and the restore — guarded by `-x /etc/uci-defaults/40-luci-trusttunnel`, output silenced (`>/dev/null 2>&1`), and on failure the exact warning `warning: the default routing profile was not created; run /etc/uci-defaults/40-luci-trusttunnel manually` — restore only when `was_running=1` and only after the uci-defaults step, first install stays disabled, repo persistence stated.

- [x] **Step 4: Verify**

Run: pinned shellcheck + `sh -n` Expected: clean/OK
Run: harness (baseline + new file) Expected: all chunks green for both — the new file is now the complete reimplementation with zero inherited expression

**Verification**: was_running restore semantics identical (first-install disabled; stop-then-start on reinstall with running service; no start when stopped); call order `rpcd restart` → `40-luci-trusttunnel` → `start` identical between baseline and new file; the exact warning fallback text present on uci-defaults failure and absent on success/absence; full harness suite green on both files.

### [x] Task 8: Full verification — shellcheck, sh -n, mode, repo suite, harness, rootfs golden diff, negative CPU

**Files:**

- Test: `install.sh`
- Test: `tests/install-harness.sh`
- Test: `tests/run.sh` (existing suite, unchanged — `tests/test_deps.sh` asserts both install.sh branches install `kmod-tun ip-full nftables curl ca-bundle` and the Makefile-declared deps)

- [x] **Step 1: Static gates**

Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh` Expected: clean
Run: `sh -n install.sh` Expected: OK
Run: `git ls-files -s install.sh` Expected: `100755` (re-run `chmod 755 install.sh && git add install.sh` if the mode dropped)

- [x] **Step 2: Repo unit suite gate**

Run: `sh tests/run.sh` Expected: all existing tests pass — in particular `tests/test_deps.sh` asserts the rewritten install.sh's dependency lines: both the `apk add` and the `opkg install` branches must contain `kmod-tun ip-full nftables curl ca-bundle` (nftables included), and the Makefile-declared deps must still match.

- [x] **Step 3: Full harness suite**

Run: `sh tests/install-harness.sh` (new file + baseline) Expected: every scenario green for both; negative control red when a single expectation is inverted.

- [x] **Step 4: Rootfs golden diff against the current script's behavior**

For each image `openwrt/rootfs:x86-64-25.12.0` (apk), `x86-64-22.03.7`, `x86-64-23.05.6`, `x86-64-24.10.8` (opkg):
- Run the baseline copy in container A and the new file in container B (identical prep mirroring release.yml: `mkdir -p /var/lock /etc/apk/keys /etc/apk/repositories.d /etc/opkg/keys`; real tools, default `TT_REPO_URL` = live Pages repo).
- `docker cp` out `/etc/apk/keys`, `/etc/apk/repositories.d`, `/etc/opkg/customfeeds.conf`, `/etc/opkg/keys`, `/etc/config/trusttunnel` from both; `diff -r` — Expected: byte-identical (including the seeded Default profile in `/etc/config/trusttunnel`).
- Assert the installed package set is identical: `apk info -e` / `opkg list-installed` show the three trusttunnel packages (luci-app-trusttunnel, luci-i18n-trusttunnel-ru, trusttunnel-client) + `kmod-tun ip-full nftables curl ca-bundle`.
- Assert first-install service state: `/etc/init.d/trusttunnel` present, no start link in `/etc/rc.d/`.

- [x] **Step 5: Negative CPU test (final gate)**

Run the harness scenario with `STUB_UNAME_M=riscv64` Expected: exit 1, clear unsupported-CPU message, zero writes to the four state locations (assertion from Task 4).

- [x] **Step 6: Tree-cleanliness and cleanup**

Run: `git status --porcelain` Expected: only `install.sh` modified and `tests/install-harness.sh` added; no `*.old`, no backup of the old script in the repo (PRD convention).
Delete the scratch baseline copy from the OS temp dir.

**Verification**: all static gates green; `sh tests/run.sh` green (test_deps.sh asserts the nftables dependency lines on both branches); full harness green (new + baseline); rootfs golden diff byte-identical on apk 25.12 and opkg 22.03/23.05/24.10 — including the seeded `/etc/config/trusttunnel`; negative CPU dies before any writes; index mode `100755`; `git status` shows only the intended changes; the release.yml verify flow (TT-20's dependency) is unaffected because the state contracts are byte-identical.

## Execution notes (implemented 2026-09-09, docker available — all steps ran)

All tasks/steps above are marked `[x]`; docker was available, so no
docker-dependent step was skipped. The deviations from the letter of the
plan, with reasons:

- **Task 3/4/5/6/7 — the new file was written in ONE pass from the contract,
  in the plan's chunk order, instead of physically splicing the inherited
  file slice by slice.** The clean-room rule forbids reading the inherited
  text; slice boundaries and the tail's interfaces are unknowable without
  reading it. Chunk-wise verification was preserved: each chunk's harness
  scenario set was added and verified (baseline + new file) before moving
  to the next chunk, red/green per chunk.
- **Task 7 — the was_running remember/stop sits between the dependency
  install and the main package install**, not before `apk update`/`opkg
  update`. The oracle's call log shows the stop after the dependency
  install; the harness assertion was calibrated to
  `deps install → running probe → stop → main package` and an opkg-flavor
  variant was added.
- **Harness scratch lives under `$HOME`**, not `/tmp`: Docker Desktop on
  macOS does not propagate mounts under `/tmp`/`/var/folders` into
  containers (they appear empty). The baseline oracle copy itself still
  lives in the OS temp dir and is mounted by copying it into the scratch.
- **The opkg "fresh feed file" scenario deletes the stock
  `customfeeds.conf` first**: the 22.03.7/23.05.6/24.10.8 rootfs images
  ship a commented file, so the "created if absent" case needed the stock
  file removed; a second scenario pins the append-to-stock-file behavior.
- **The harness prep empties the stock `/etc/opkg/keys`**: the images
  ship the OpenWrt feed key (e.g. `4d017e6f1ed5d616`), which otherwise
  pollutes the "no fingerprint copy" assertions.
- **Task 8 Step 4 — "no start link in /etc/rc.d/" calibrated**: the
  package's uci-defaults script runs `enable` unconditionally during the
  immediate install-time run, so `S95trusttunnel` appears in `/etc/rc.d/`
  after every install. The golden diff asserts byte-identical `/etc/rc.d`
  state (baseline == new) and that the service is never *started* by
  install.sh; the plan's literal "no start link" assertion was replaced by
  the equality check.
- **On 22.03, `nftables` is a virtual package** resolved to
  `nftables-json`; the `nft` binary installs, but the name does not appear
  in `opkg list-installed`. The package-set diff stays byte-identical
  (both sides show the same resolved set) and the nftables dependency
  lines are pinned by `tests/test_deps.sh`.
- **`git add` was not run**: the issue is not committed (per the dispatch);
  the index keeps the original blob at mode `100755`; the working-tree
  file is `100755` and will record that mode on commit.

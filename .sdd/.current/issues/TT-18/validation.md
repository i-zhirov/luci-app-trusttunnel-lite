# Issue Validation Report: install.sh

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-18/issue.md`
- **Plan**: `.sdd/.current/issues/TT-18/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 8 | 0 | 0 | 8 |
| Acceptance Criteria | 5 | 0 | 0 | 5 |
| Entities | 6 | 0 | 0 | 6 |
| Contracts | 1 | 0 | 0 | 1 |
| Guidelines | 0 | 0 | 0 | 0 (no AGENTS.md — N/A) |

## Task Status

- [x] **Task 1**: Baseline — shellcheck state, behavior inventory, preserve oracle copy - PASS
  - Baseline gates re-verified on the current tree: `git ls-files -s install.sh` → `100755`; `sh -n` OK; pinned shellcheck clean. The behavior inventory (12 contract items, D1–D4) is recorded in the plan's Research table and matches the implemented file item-by-item (spot-checked below). The oracle copy existed during implementation; the inherited script is recoverable from git (`2605983^:install.sh`, 281 lines as the plan states) and was used for the re-verification here.
- [x] **Task 2**: Build the stub dry-run harness - PASS
  - `tests/install-harness.sh` (749 lines) exists; docker-gated (exit 0 + skip note without docker); named `install-harness.sh` so `tests/run.sh` (globs `tests/test_*.sh`) ignores it. Ran green **twice**: against the worktree file and against the inherited script extracted from git (`TT_BASELINE_INSTALL`) — **143 assertions, 0 failed** in both modes, proving the harness is a genuine equivalence oracle, not just a self-fulfilling check.
- [x] **Task 3**: Chunk 1 — header, environment checks, PM detection with version floors - PASS
  - install.sh lines 1–54: `#!/bin/sh`, `set -e`, `say()`/`die()`, `TT_REPO_URL` default `https://i-zhirov.github.io/trusttunnel-openwrt`, `/etc/openwrt_release` existence check + source, PM detection (apk precedence, else opkg, neither → die), version floors on the `DISTRIB_RELEASE` major (apk ≥ 25, opkg ≥ 22), non-numeric major → warning and continue (D1 preserved). Harness chunk-1 scenarios (missing release file, no PM, apk/opkg-only detection, 21.x floors, 25.12.0/22.03.7 pass, non-numeric `rolling`) all green on both files.
- [x] **Task 4**: Chunk 2 — CPU check (`uname -m` allowlist, die before any writes) - PASS
  - install.sh lines 56–66: exactly the 10 allowlisted names (`x86_64 x86-64 x64 amd64 aarch64 arm64 armv7l armv8l mips mipsel`); positioned before the first write (repo setup starts at line 68). Harness chunk-2 green on both files: all 10 accepted, rejected `armv5tel armv6l mips64el riscv64 powerpc i386` + empty, and the riscv64 negative-write assertions (no apk key, no repo entry, no opkg key, feed file byte-unchanged).
- [x] **Task 5**: Chunk 3 — repository setup per PM (apk branch, then opkg branch) - PASS
  - install.sh lines 68–90. apk: `mkdir` both dirs, key fetched via wget **first** (`wget -O /etc/apk/keys/trusttunnel.pub "$TT_REPO_URL/apk/key-build.pub"`), `apk --print-arch` (failure → die, empty → die), single-line `<url>/apk/<arch>/packages.adb` into `/etc/apk/repositories.d/trusttunnel.list`. opkg: idempotent anchored `src/gz trusttunnel <url>/opkg` append (created if absent, stock file preserved, two-run idempotence), key → `/etc/opkg/keys/trusttunnel.pub`, `usign -F -p` fingerprint (missing usign → die, failure → die), **both** `trusttunnel.pub` and `/etc/opkg/keys/<fp>` copies kept (D2). Harness chunk-3 green on both files (incl. wget-fail, print-arch-fail, key-fetch-fail, usign-missing/fail).
- [x] **Task 6**: Chunk 4 — update/install sequence (deps, app, optional i18n, tripwire) - PASS
  - install.sh lines 92–125: `apk update`/`opkg update`; dependency set exactly `kmod-tun ip-full nftables curl ca-bundle` on both branches (lines 96/99 — nftables included per the 2026-09-09 actualization); `luci-app-trusttunnel` fatal; `luci-i18n-trusttunnel-ru` warning-only; tripwire `apk info -e` / `opkg list-installed | grep '^trusttunnel-client '` fatal. Harness chunk-4 green on both files (call order, i18n non-fatal, tripwire fatal, update-fail fatal). `tests/test_deps.sh`: 26/0, asserting the nftables set on both branches.
- [x] **Task 7**: Chunk 5 — was_running remember/stop/restore, rpcd restart, immediate uci-defaults run, closing banner - PASS
  - install.sh lines 127–151: `was_running` probed via `/etc/init.d/trusttunnel running` when the init script is executable, stop only then; `rpcd restart` quieted and non-fatal; immediate uci-defaults run guarded by `-x /etc/uci-defaults/40-luci-trusttunnel`, silenced (`>/dev/null 2>&1`), and on failure the **exact** warning `warning: the default routing profile was not created; run /etc/uci-defaults/40-luci-trusttunnel manually` (line 136, verbatim contract text); `start` only when `was_running=1` and only after the uci-defaults step; closing banner states `apk update && apk upgrade` / `opkg update && opkg upgrade`. Harness chunk-5 green on both files: first-install no stop/start, stopped-service stop-only, running-service stop→install→rpcd restart→uci-defaults→start ordering (apk and opkg flavors), rpcd failure non-fatal, uci-defaults success (invoked once, silenced, banner printed), failure (exact warning, still exits 0, start still happens), absent (not invoked, no banner/warning), closing banners.
- [x] **Task 8**: Full verification — shellcheck, sh -n, mode, repo suite, harness, rootfs golden diff, negative CPU - PASS
  - All gates re-run in this validation: pinned shellcheck (`koalaman/shellcheck:v0.11.0 -s sh`) clean on `install.sh` and `tests/install-harness.sh`; `sh -n` OK on both; index mode `100755` for both files; `sh tests/run.sh` fully green (314 assertions across the suite, incl. test_deps 26/0, test_uci_defaults 66/0); harness 143/0 (new file and oracle); rootfs golden-diff record verified in commit `2605983` ("byte-identical on 25.12.0, 22.03.7, 23.05.6 and 24.10.8 (keys, repositories, customfeeds, seeded config, rc.d, installed package set)"); independent spot-check on `openwrt/rootfs:x86-64-22.03.7` with real tools and the live repo reproduced byte-identical state (see Acceptance Criteria 1); negative CPU (riscv64) dies before any writes; `git status` clean; no `*.old`/baseline copies in the repo; baseline copy absent from the OS temp dir (deleted).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Fresh install on apk (25.12) and opkg (22.03/23.05/24.10) rootfs images installs the package set, leaves the service disabled, and configures the repo/keys exactly as today | MET | Record: commit `2605983` states byte-identical golden diffs on all four images. Independent spot-check this validation on `openwrt/rootfs:x86-64-22.03.7` (inherited script from `2605983^` vs new file, real tools, default `TT_REPO_URL` = live Pages repo): both exit 0; `diff -r` **IDENTICAL** on `/etc/apk/keys`, `/etc/apk/repositories.d`, `/etc/opkg/customfeeds.conf`, `/etc/opkg/keys`, `/etc/config/trusttunnel` (seeded Default profile), `/etc/rc.d` (K10/S95trusttunnel symlinks), and the `opkg list-installed` package set (only `ls -la` mtimes differ). Service-left-disabled: harness chunk-5 asserts zero `start` calls on first install; rc.d state byte-identical to today (the uci-defaults `enable` behavior is pre-existing, documented in the plan's execution notes) |
| 2 | Unsupported CPU dies early with a clear message, changing nothing | MET | install.sh lines 56–66: check runs before any write; message names the CPU and the supported families. Harness chunk-2: `riscv64` → exit 1, "unsupported CPU" message, and negative-write assertions (no `/etc/apk/keys/trusttunnel.pub`, no `/etc/apk/repositories.d/trusttunnel.list`, no `/etc/opkg/keys/trusttunnel.pub`, feed file byte-unchanged). Rejected set incl. ARMv5/6, mips64el, powerpc, i386, empty |
| 3 | Reinstall preserves a running service (was_running restore) | MET | Harness chunk-5: running service → `stop` recorded between the dependency install and the main package install, `start` recorded after `rpcd restart` AND the uci-defaults run (apk and opkg flavors); stopped service → stop only, no start; first install → neither. Matches the plan's calibrated call order |
| 4 | The release.yml verification steps (which mirror this script) pass | MET | release.yml verify steps read: apk key at `/etc/apk/keys/trusttunnel.pub` + explicit `packages.adb` entry in `/etc/apk/repositories.d/trusttunnel.list`; opkg `src/gz trusttunnel` line (URL not naming the index) + both key copies (`trusttunnel.pub` + usign fingerprint) — exactly the arrangement install.sh creates (lines 71–89). The spot-check exercised the same real-repo flow on 22.03.7. The verify steps themselves run in CI (TT-20 domain); the mirrored contracts hold |
| 5 | `shellcheck -s sh` clean | MET | `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh` → exit 0, no findings (exact pinned CI invocation); harness file also clean |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| `/etc/apk/keys/trusttunnel.pub` | content = fetched `key-build.pub` | created before first `apk update`; removed by uninstall.sh | wget failure → die before any repo entry (harness `sc_apk_repo_wget_fail`) | PASS |
| `/etc/apk/repositories.d/trusttunnel.list` | single line `<url>/apk/<arch>/packages.adb` | arch from `apk --print-arch`; explicit index name | print-arch failure/empty → die (lines 74–75; harness) | PASS |
| `/etc/opkg/customfeeds.conf` | appended `src/gz trusttunnel <url>/opkg` | removal pattern in uninstall.sh `^src\/gz trusttunnel ` | idempotent anchored append; created if absent; stock lines untouched (harness fresh/stock/idempotent scenarios) | PASS |
| `/etc/opkg/keys/trusttunnel.pub` + `/etc/opkg/keys/<fingerprint>` | two identical copies; fingerprint = `usign -F -p` | fingerprint copy is what opkg-key matches; stable name is uninstall.sh's handle | wget failure → die; usign missing/failure → die (harness); both copies byte-identical (harness + spot-check) | PASS |
| `/etc/config/trusttunnel` (seeded Default profile) | produced by the immediate uci-defaults run | created by this install, not the next boot | byte-identical in spot-check; failure → no file + exact warning fallback, exit 0 (harness) | PASS |
| TrustTunnel service state (was_running) | `was_running` ∈ {0,1} via `running` probe | stop before main package install; start after rpcd restart + uci-defaults, only when 1 | first install disabled; stopped stays stopped; running restored (harness chunk-5) | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| install.sh ↔ uninstall.sh ↔ release.yml cross-file consistency (repo URLs, key file names, `src/gz trusttunnel` line, fingerprint naming, stable-name copy) | — | PASS | All three artifacts agree: default URL `https://i-zhirov.github.io/trusttunnel-openwrt`; apk key `/etc/apk/keys/trusttunnel.pub` + explicit `<arch>/packages.adb` entry; opkg `src/gz trusttunnel <url>/opkg` (index not named) + `/etc/opkg/keys/trusttunnel.pub` and fingerprint copy; uninstall.sh removes exactly these (lines 132–167). No API contracts apply |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md | N/A | No AGENTS.md exists in the repo |

Clean-room rule (PRD Implementation Decisions, spot-checked): `diff 2605983^:install.sh install.sh` shows a full re-expression — comments, structure, variable names (`_arch`, `_arch_dir`, `_fp`, `_release`, `_major`), control flow (inline `if`/`elif` vs. chained `&&`/`||`, `case` merged), and messages are rewritten. The only verbatim-shared text is contract-mandated: URLs, key/repo paths, package names, the `src/gz trusttunnel` line, the quoted exact uci-defaults warning fallback, and short die-message subjects (`this script is for OpenWrt only`, `neither apk nor opkg found; unsupported OpenWrt variant` — user-facing contract per D4). New file is 151 lines vs 281 inherited; no inherited comment blocks or expression sequences survive.

## Issues Found

1. **[informational] Stale execution note in plan.md: "git add was not run; the issue is not committed (per the dispatch)"**
   - Location: `.sdd/.current/issues/TT-18/plan.md`, Execution notes, last bullet
   - Description: The implementation IS committed — `2605983` "install: reimplement the installer with new expression" contains both `install.sh` and `tests/install-harness.sh` — and `git status --porcelain` is clean (only unrelated untracked validation reports from other issues). The note describes a transient pre-commit state.
   - Impact: None on the implementation; only the plan's record no longer reflects the final state.
   - Recommendation: When the plan status is next updated, correct the note to reflect that the files were committed at `2605983`.
   - Resolved: (omitted — validation in progress)

## Recommendations

- All gates green and no code changes are required. The record for the remaining three golden-diff images (25.12.0 apk, 23.05.6, 24.10.8 opkg) rests on the commit-message record plus the stub harness; an independent spot-check on `25.12.0` (apk branch) would close the loop symmetrically to the 22.03.7 check performed here, if a full re-run is ever wanted.
- The acceptance criterion wording "leaves the service disabled" should be read as "never started by install.sh" — the package's uci-defaults creates the `S95trusttunnel` rc.d link on every install (pre-existing behavior, byte-identical between old and new). The plan's execution notes already document this calibration; no action needed.

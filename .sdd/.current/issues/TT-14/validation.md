# Issue Validation Report: TT-14 package Makefile

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-14/issue.md`
- **Plan**: `.sdd/.current/issues/TT-14/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 4 | 1 | 0 | 5 |
| Acceptance Criteria | 4 | 0 | 0 | 4 |
| Entities | 1 | 0 | 0 | 1 |
| Contracts | 7 | 0 | 0 | 7 |
| Guidelines | 3 | 0 | 0 | 3 |

## Task Status

- [x] **Task 1: Baseline — golden metadata from a REBASED-tree SDK build** - PASS
  Evidence: `.build-out/golden-22.03/` and `.build-out/golden-25.12/` contain the
  built artifacts (`luci-app-trusttunnel_1.0.15_all.ipk`,
  `luci-app-trusttunnel-1.0.15-r1.apk`, plus both `luci-i18n-trusttunnel-ru`
  packages) and the transcripts. `golden-ipk.control.txt`: `Version: 1.0.15`,
  `Architecture: all`, `Depends: libc, trusttunnel-client, luci-base, ip-full,
  nftables, curl, ucode-mod-math` (the NEW post-rebase split, `+` stripped),
  `License: GPL-2.0-only` (pre-flip). `golden-ipk.conffiles.txt` contains
  exactly `/etc/config/trusttunnel`. `golden-ipk.files.txt` shows the six
  scripts at 0755 and `records.sh` at 0644. `golden-apk.adbdump.txt`:
  `version: 1.0.15-r1`, `arch: noarch`, same 7-item depends, conffiles file at
  `lib/apk/packages/luci-app-trusttunnel.conffiles` (size 24 =
  `/etc/config/trusttunnel\n`), modes 0755/0644. The build state is pinned by
  the `.build-out/golden-tree/` snapshot (git HEAD `ef91ea9` — recorded in the
  golden i18n artifact filename; its Makefile is byte-identical to
  `git show 737c761:packages/luci-app-trusttunnel/Makefile`, i.e. the
  pre-rewrite inherited file with GPL-2.0-only and the marker present at line
  70). `.build-out/` is confirmed gitignored (`.gitignore:8`,
  `git check-ignore` matches).
- [x] **Task 2: Re-express the Makefile from the contract** - PASS
  Evidence: `packages/luci-app-trusttunnel/Makefile` (76 lines, committed in
  `f02abe1`, flip `a5c376b`, marker restored `2740ad2`) carries the full
  contract surface: SPDX `Apache-2.0` (line 1, post-TT-22 flip), `include
  $(TOPDIR)/rules.mk` first (line 6), `PKG_NAME:=luci-app-trusttunnel` (8),
  tag-derived `PKG_VERSION` with `1.0.13` fallback (22), `PKG_RELEASE:=1`
  (23), `PKG_LICENSE:=Apache-2.0` (24), `PKG_MAINTAINER` (25), `LUCI_TITLE`
  (27), single-line `LUCI_DESCRIPTION` (28), exact `LUCI_DEPENDS` split (41),
  `LUCI_URL` (44), `LUCI_PKGARCH:=all` (45), conffiles block lines 53-55
  BEFORE `include luci.mk` (57), `Build/Compile` lines 66-74 AFTER the include
  with six `chmod 0755` + `chmod 0644 records.sh`. All comments are new
  wording vs the inherited file (diff of `f02abe1` reviewed); the trailing
  `# call BuildPackage - OpenWrt buildroot signature` marker is restored as
  the file's final line (76) — see Issues Found #2 and the plan's Execution
  Record for why the earlier "drop it" conclusion was wrong.
- [x] **Task 3: Cheap static verification (no SDK build)** - PASS
  Evidence (all re-run during validation): version-derivation matrix — at HEAD
  `git describe --tags --abbrev=0` → `v1.0.15` and the exact Makefile
  expression yields `1.0.15`; in a git-less `mktemp -d` the fallback yields
  `1.0.13`; `sed 's/^v//'` passes `v1.0.10`→`1.0.10` and `1.0.10`→`1.0.10`.
  Ordering/value greps: `rules.mk`@6, `luci.mk`@57, conffiles@53 < 57 <
  `Build/Compile`@66; the exact `LUCI_DEPENDS` line present at 41; `kmod-tun`
  and `ca-bundle` counts on `LUCI_DEPENDS:` lines = 0/0; `chmod 0755` count =
  6; `records.sh` = single chmod 0644 line; SPDX present. `sh tests/test_deps.sh`
  → 26 assertions, 0 failed (asserts the app/client split, non-repetition,
  real script invocations, install.sh parity). `sh tests/run.sh` → 315 `ok:`
  assertions across all scenarios, 0 failed, "all tests passed". Diff hygiene:
  `git status --porcelain` empty; `.build-out/` ignored.
- [x] **Task 4: SDK build gate + metadata byte-diff vs golden** - PARTIAL
  Steps 1-2 verified from recorded evidence (see below); Step 3 (rootfs
  install + upgrade-survival smoke) is marked `[x]` but no evidence of it
  exists in the Execution Record or `.build-out/` — see Issues Found #1.
  Step 1/2 evidence: `.build-out/new-22.03/` and `.build-out/new-25.12/` hold
  the rebuilt artifacts + transcripts (build state pinned by
  `.build-out/new-tree/`, git HEAD `baccf04` — recorded in the new i18n
  filename; its Makefile is byte-identical to `git show 2740ad2:...` = the
  rewritten file post-marker-restore, Apache-2.0). `diff` golden vs new ipk
  control = exactly 3 lines: `License` (GPL-2.0-only → Apache-2.0, the TT-22
  flip), `SourceDateEpoch` (build time), `Installed-Size` (28937 → 28934).
  `Version`, `Depends`, `Architecture`, `Section`, `Maintainer`,
  `Description` byte-identical. `diff` of `data.tar.gz` file lists =
  identical paths/modes/sizes, only tar timestamps differ. apk adbdump golden
  vs new: `version: 1.0.15-r1`, depends, conffiles file (size 24, same hash),
  every per-file mode/size/content-hash identical; differing only `license`,
  file `mtime`s, `info.hashes`, and `maintainer: OpenWrt LuCI community`
  (luci.mk's own value — identical in both, so not a rewrite regression).
- [x] **Task 5: Full gates and clean-tree check** - PASS
  Evidence: `git status --porcelain` empty (verified); `.build-out/`
  gitignored and untracked (verified via `git check-ignore`); no `*.old`;
  only `packages/luci-app-trusttunnel/Makefile` modified by this issue's
  commits; the Execution Record (plan.md, 2026-09-10) documents the four SDK
  legs, the metadata byte-diff, the feed-scan marker bug and fix, and the
  environment notes.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | SDK build (22.03 + 25.12, x86-64) produces `luci-app-trusttunnel-<tag>-r1.apk` / `luci-app-trusttunnel_<tag>_all.ipk` with the tag-derived version | MET | `.build-out/{golden,new}-22.03/luci-app-trusttunnel_1.0.15_all.ipk` and `{golden,new}-25.12/luci-app-trusttunnel-1.0.15-r1.apk`; `Version: 1.0.15` (ipk control) and `1.0.15-r1` (apk adbdump); `git describe --tags --abbrev=0` → `v1.0.15` at HEAD; version expression verified (tag→1.0.15, no-git→1.0.13) |
| 2 | Conffiles ordering preserved (built package's `.conffiles` lists `/etc/config/trusttunnel`) | MET | `golden-ipk.conffiles.txt` / `new-ipk.conffiles.txt` = exactly `/etc/config/trusttunnel`; apk ships `lib/apk/packages/luci-app-trusttunnel.conffiles` (size 24, mode 0644, identical hash golden vs new) per adbdump; declaration block (Makefile lines 53-55) precedes `include luci.mk` (57) |
| 3 | `chmod` workaround present (files land with the right modes in the .ipk/.apk) | MET | ipk `data.tar.gz` listing: init.d/uci-defaults/hotplug/gen-config/routing/uci-export = `-rwxr-xr-x`, `records.sh` = `-rw-r--r--`; apk adbdump: same six paths `mode: 0755`, `records.sh` `mode: 0644` — identical golden vs new |
| 4 | Depends list matches the contract | MET | ipk control `Depends: libc, trusttunnel-client, luci-base, ip-full, nftables, curl, ucode-mod-math`; apk depends = same 7 items; exact Makefile `LUCI_DEPENDS` line at 41; no `kmod-tun`/`ca-bundle` in the app (greps = 0/0 and `test_deps.sh` 26/0, incl. the client-side split and install.sh parity) |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Package metadata (Makefile contract surface) | OK — all PKG_*/LUCI_* values match the Entity table (SPDX Apache-2.0 post-flip, PKG_NAME, tag-derived PKG_VERSION + 1.0.13 fallback, PKG_RELEASE 1, PKG_LICENSE Apache-2.0, PKG_MAINTAINER, LUCI_TITLE, single-line LUCI_DESCRIPTION, exact LUCI_DEPENDS split, LUCI_URL, LUCI_PKGARCH all, conffiles path, 7 chmod lines) | OK — conffiles block (53-55) before `include luci.mk` (57); `Build/Compile` (66-74) after; marker as final line (76); PKG_VERSION → artifact filenames 1.0.15 / 1.0.15-r1 | OK — `sh tests/run.sh` green (315/0), `test_deps.sh` 26/0, golden-vs-new metadata identity holds | PASS |

## Contract Status

| Contract | Method | Status | Notes |
| --- | --- | --- | --- |
| SPDX header + `include $(TOPDIR)/rules.mk` first | build metadata | PASS | line 1 / line 6 |
| Tag-derived PKG_VERSION, `v` stripped, fallback `1.0.13` | build metadata | PASS | line 22; matrix verified (1.0.15 / 1.0.13 / strip-only) |
| PKG_RELEASE/PKG_LICENSE/PKG_MAINTAINER | build metadata | PASS | lines 23-25; Apache-2.0 after the TT-22 flip |
| LUCI_TITLE / LUCI_DESCRIPTION | build metadata | PASS | lines 27-28; description ships byte-identical (verified in ipk control + apk adbdump) |
| LUCI_DEPENDS exact split, no kmod-tun/ca-bundle | build metadata | PASS | line 41; greps 0/0; test_deps.sh 26/0; built Depends match |
| LUCI_URL / LUCI_PKGARCH | build metadata | PASS | lines 44-45; `arch: noarch` / `Architecture: all` in artifacts |
| Conffiles before include; Build/Compile after; marker present | build metadata | PASS | 53-55 < 57 < 66-74; marker line 76 (feed-scan GREP_STRING `call BuildPackage` — verified absent at `a5c376b`, restored at `2740ad2`) |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| Clean-room reimplementation: metadata values are contract data; comment prose must be new wording, not copied or closely paraphrased (PRD Implementation Decisions; plan Research §6) | COMPLIANT | All comments re-expressed vs the inherited file (f02abe1 diff reviewed). One borderline sentence — see Issues Found #3. The restored `# call BuildPackage` marker is inherited text by deliberate, documented exception (feed-scan discovery marker, plan Execution Record) |
| Every issue ends with a `git status` check; no `*.old`; golden artifacts never committed (PRD; plan Research §6) | COMPLIANT | `git status --porcelain` empty; `.build-out/` gitignored and untracked |
| Tests stay green (PRD SC-002) | COMPLIANT | `sh tests/run.sh` 315 ok / 0 failed; `sh tests/test_deps.sh` 26 / 0 |

## Issues Found

1. **Task 4 Step 3 (rootfs install + upgrade-survival smoke) has no recorded evidence**
   - Location: plan.md Task 4 Step 3; `.build-out/`
   - Description: The step is marked `[x]`, but the Execution Record documents only the four SDK legs, the metadata byte-diff, the feed-scan bug, and environment notes. No rootfs install output (conffiles list on the installed system, `ls -l` modes) and no upgrade-survival result (modified `/etc/config/trusttunnel` preserved on reinstall) are recorded anywhere in `.build-out/` or the plan.
   - Impact: Low for the acceptance criteria (all four are MET via the built-package metadata, which is the stronger evidence: the conffiles file ships in both package formats and the modes are correct inside the archives). The upgrade-survival behavior is the runtime confirmation of the conffiles mechanism and remains unverified in the recorded trail.
   - Recommendation: Run the lightweight docker rootfs checks from Task 4 Step 3 (`openwrt/rootfs:x86-64-25.12.0` apk leg / `x86-64-22.03.7` opkg leg) against `.build-out/new-25.12/` and `.build-out/new-22.03/`, and append the results (conffiles list, modes, config-preserved-on-reinstall) to the Execution Record.
   - Resolved:
     (to be filled by `prd-implement-issue` if a revision addresses this)
2. **Execution Record imprecision: build-commit labels and hash claims**
   - Location: plan.md Execution Record (SDK build legs table; metadata byte-diff bullet)
   - Description: The table labels the new builds "a5c376b (rewritten Makefile)", but `git show a5c376b:packages/luci-app-trusttunnel/Makefile` has NO `call BuildPackage` text (grep exit 1) — a build at that state would hit the feed-scan failure the record itself documents. The actual new-build state is the `.build-out/new-tree/` snapshot (HEAD `baccf04`, recorded in the new i18n filename `git-26.253.25304-baccf04`), whose Makefile is byte-identical to `2740ad2` (marker restored). Likewise the golden build HEAD was `ef91ea9` (golden i18n filename), not literally `737c761` (that commit's tree matches the built Makefile; both hashes were rebased away). The record's "content hashes / Installed-Size" differ-claim is also loose: per-file content hashes in the adbdump are identical golden vs new (only the ADB `info.hashes` and mtimes differ), and `Installed-Size` differs by 3 bytes (28937 → 28934).
   - Impact: None on the implementation — all substantive identity claims (Version 1.0.15 / 1.0.15-r1, Depends, conffiles, modes) verify against the artifacts. The labels make the evidence trail harder to reconstruct.
   - Recommendation: Amend the record's table to cite the snapshot HEADs `ef91ea9` (golden) and `baccf04` (new; post-marker-restore state) or the current-history equivalents, and reword the diff bullet to "ADB info.hashes / mtimes / License / SourceDateEpoch / Installed-Size (3-byte build artifact)".
   - Resolved:
     (to be filled by `prd-implement-issue` if a revision addresses this)
3. **Clean-room borderline: `Build/Compile` comment opening sentence**
   - Location: packages/luci-app-trusttunnel/Makefile line 59
   - Description: "Executable bits set explicitly rather than taken from the repository:" closely tracks the inherited lead sentence "Executable bits are set EXPLICITLY rather than taken from the repository." The remainder of the block is genuinely new expression (the Windows-dev/scp-habit narrative is gone, the mechanism is restated), so this is a short factual lead-in rather than a close paraphrase of the inherited block.
   - Impact: None functionally; legal-expression risk is minimal but non-zero given the strict "must NOT be copied or paraphrased closely" rule in plan Research §6.
   - Recommendation: Optional — reword the opening sentence (e.g., "File modes are fixed in `Build/Compile` rather than trusted to the source tree:") for a fully distinct lead-in.
   - Resolved:
     (to be filled by `prd-implement-issue` if a revision addresses this)

## Recommendations

- Record the Task 4 Step 3 rootfs install/upgrade-survival results (Issue #1) — the only acceptance-adjacent verification without documented evidence; the docker rootfs check is lightweight.
- Tighten the Execution Record's commit labels and expected-diff wording (Issue #2) for an auditable evidence trail.
- Optionally reword the one borderline comment sentence (Issue #3).
- The SDK verification itself was not re-run (heavy images, per the task instructions); the recorded evidence and transcripts were verified against the claims and match.

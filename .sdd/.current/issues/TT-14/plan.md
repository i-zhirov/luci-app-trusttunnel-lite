# Implementation Plan: TT-14 package Makefile

- **Created**: 2026-09-08
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-14/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation: plan contains behavior/contract targets only, no inherited text; metadata values are contract data; the version-from-tag expression is fork work and part of the contract; verification gates are the release.yml build job / a local SDK build plus cheap static checks"

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles + system
deps); HEAD is now the branch tip `fa45849` — the planning docs commit on top of `c43e20a` (was `1fdf82c` at v1.0.13). Both Makefiles
changed; the issue contract was updated:

- **`luci-app-trusttunnel` LUCI_DEPENDS** is now
  `+trusttunnel-client +luci-base +ip-full +nftables +curl
  +ucode-mod-math` — `kmod-tun`/`ca-bundle` removed (transitive via the
  client package; the app must NOT repeat them), `+nftables` added.
- **`trusttunnel-client` DEPENDS** is now `+kmod-tun +ca-bundle` — its
  Makefile (original file, not reimplemented) changed on main; the
  rewrite of the app Makefile must respect the split.
- **`tests/test_deps.sh`** (new on main, original) asserts both
  Makefiles' declarations, the non-repetition rule, the real script
  invocations, and install.sh parity — the verification tasks must run
  it (`sh tests/run.sh` picks it up; green at plan time: 40 assertions,
  0 failed).
- Task 3's static checks and Task 4's metadata byte-diff must use the
  NEW depends strings; the golden transcript (Task 1) is derived from a
  LOCAL SDK BUILD of the REBASED tree (HEAD `fa45849` = the docs commit on top of `c43e20a`, where `git
  describe --tags --abbrev=0` → `v1.0.15`) — the v1.0.13 release assets
  predate the rebase and cannot serve as the golden (Research §4).

## Summary

Re-express the inherited `packages/luci-app-trusttunnel/Makefile` (98 lines
today) as new, original metadata text against the TT-14 contract. The file is
a thin declarative package manifest: `PKG_*`/`LUCI_*` metadata (contract
values), a tag-derived `PKG_VERSION` with the `1.0.13` fallback (fork work,
kept), the conffiles block placed **before** `include luci.mk`, and the
`Build/Compile` chmod workaround placed **after** it. No behavior change.

Verification is oracle-diff, not unit tests (a Makefile has none): the
golden metadata oracle (control fields, conffiles, file lists with modes) is
derived from a **local SDK build of the REBASED tree** (HEAD `fa45849`, on top of `c43e20a`,
pre-rewrite Makefile) — the official v1.0.13 release assets predate the
rebase and cannot serve as the golden (Research §4). Sequence: baseline
capture + golden build → rewrite from the contract → cheap static checks
(version-derivation matrix, ordering/values checklist, `sh tests/run.sh`) →
SDK build gate (local docker per the gh-action-sdk recipe, or the release.yml
build job via workflow_dispatch) → byte-diff the new built-package metadata
against the golden → rootfs install/upgrade smoke in docker → clean-tree
check.

## Technical Context

- **Language/Version**: GNU make, OpenWrt buildroot (SDK 22.03.7 for opkg /
  25.12.5 for apk, both x86-64; the package is noarch, `LUCI_PKGARCH:=all`).
  A POSIX-sh one-liner inside the Makefile computes `PKG_VERSION`.
- **Primary Dependencies**: the OpenWrt build system files
  `include/rules.mk` (via `$(TOPDIR)`), and the LuCI feed's `luci.mk`
  (via `include $(TOPDIR)/feeds/luci/luci.mk`). No source code is compiled —
  `Build/Compile` only chmods the staged `root/` tree.
- **Storage**: none (no runtime state; the file declares build metadata only).
- **Testing**: no unit tests exist for a Makefile. The equivalence oracle is
  the **built-package metadata** of a local SDK build of the rebased tree
  (see Research §4) plus the **release.yml build job** ("The package version
  matches the release tag" assertion). Cheap static checks — including the
  fork's own `sh tests/run.sh` (test_deps.sh asserts the dependency split,
  the non-repetition rule and install.sh parity) — run before any SDK build;
  the SDK build (~11–13 min per leg, release.yml's own measurements) is the
  final gate.
- **Target Platform**: OpenWrt 22.03 (opkg) and 25.12 (apk) SDK containers,
  x86-64; same CI matrix as the current `release.yml` build job.
- **Build gates that touch this issue** (`.github/workflows/release.yml`,
  currently inherited and live — it is the oracle, and TT-20 which rewrites it
  is *blocked by* TT-14): `openwrt/gh-action-sdk@v7` builds
  `luci-app-trusttunnel` on `ARCH: x86-64-22.03.7` (`.ipk`) and
  `x86-64-25.12.5` (`.apk`) with `FEEDNAME: ttowrt`, `FEED_DIR:
  ${{ github.workspace }}` (the whole repo as the feed, so `.git` is present),
  `PACKAGES: luci-app-trusttunnel`; on tag pushes it asserts
  `dist/luci-app-trusttunnel-${tag}-r1.apk` and
  `dist/luci-app-trusttunnel_${tag}_all.ipk` exist. `ci.yml` (TT-19) has no
  SDK build job today — it is not a gate for this issue's build behavior.

## Research

### 1. How the build consumes the Makefile (verified against OpenWrt 22.03 and master sources)

- `include $(TOPDIR)/rules.mk` (first) provides the buildroot's include-path
  variables (`INCLUDE_DIR`) and default target infrastructure; every package
  Makefile starts with it.
- `feeds/luci/luci.mk` (openwrt-22.03 branch, fetched 2026-09-08) maps the
  `LUCI_*` variables onto the package definition: `LUCI_TITLE`→`TITLE`,
  `LUCI_DESCRIPTION`→`description` (via `$(strip $(LUCI_DESCRIPTION))`),
  `LUCI_DEPENDS`→`DEPENDS`, `LUCI_URL`→`URL`, `LUCI_PKGARCH`→`PKGARCH`,
  `LUCI_MAINTAINER`→`MAINTAINER`. It defines `Build/Prepare` (copies
  `htdocs/`/`root`/`src` into `PKG_BUILD_DIR`), **an (empty) `Build/Compile`
  for packages without `src/`**, `Package/$(PKG_NAME)/install` (copies
  `root/` with `cp -pR`), and generates the `luci-i18n-trusttunnel-ru`
  translation package from `po/ru` (its version comes from luci.mk's
  `findrev`, a git-derived revision, not from `PKG_VERSION`). luci.mk's last
  line is `$(foreach pkg,$(LUCI_BUILD_PACKAGES),$(eval $(call
  BuildPackage,$(pkg))))` — **BuildPackage runs at include time**, while make
  parses the file top to bottom.
- Conffiles capture: in OpenWrt 22.03 `include/package-ipkg.mk`
  (`define BuildTarget/ipkg`), the package's conffiles list is frozen by an
  **immediate assignment** when `BuildPackage` expands:
  `KEEP_$(1):=$(strip $(call Package/$(1)/conffiles))` (verified, line 106).
  The same capture exists on master (25.12) in `include/package-pack.mk`
  (line 312); there the list additionally lands **inside the .apk** at
  `lib/apk/packages/<name>.conffiles` (with per-file checksums) — the
  per-package protected-file list the package managers read on upgrade
  (verified, lines 579–598).
- **Two ordering constraints on the same include** (this is the crux of the
  issue's conffiles requirement, plus one constraint the issue does not state
  explicitly):
  1. `define Package/luci-app-trusttunnel/conffiles` **must precede**
     `include luci.mk` — a definition after the include is parsed after
     `BuildPackage` has already captured the list, which freezes it empty;
     the file is then not protected and a package update overwrites
     `/etc/config/trusttunnel` with defaults.
  2. `define Build/Compile` (the chmod workaround) **must follow**
     `include luci.mk` — luci.mk itself defines an empty `Build/Compile`
     (for non-`src/` packages), and a package-level definition *before* the
     include would be clobbered by luci.mk's. Make's later `define` wins.
- `luci.mk` copies `root/` with `cp -pR` (modes preserved from the source
  files), which is exactly why the explicit `Build/Compile` chmods exist and
  why the git index cannot be the only carrier of the executable bits.

### 2. Version derivation semantics (verified on this branch)

The derivation is fork work (per the issue) and is contract:

```sh
v="$$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"; [ -n "$$v" ] && printf '%s' "$$v" || printf '%s' 1.0.13
```

Verified behaviors:

- **At this branch's HEAD** (`fa45849` — the planning docs commit on top of the
  rebased `c43e20a`): `git describe --tags --abbrev=0` → `v1.0.15` — HEAD is
  `v1.0.15-5-gfa45849`; tags
  `v1.0.14`/`v1.0.15` live on main and are now reachable, `v1.0.13` ==
  `1fdf82c` is an ancestor but not the nearest. sed strips the leading `v`
  → **`1.0.15`**. Every build at HEAD (the golden build, the SDK gate)
  therefore carries version **1.0.15**, not the fallback.
- **On a tag**: `git describe --tags --abbrev=0` returns the tag itself,
  stripped of the `v`; the release.yml filename assertion enforces the
  tag/version match on tag pushes.
- **On a commit between tags**: `git describe --tags --abbrev=0` still
  returns the *nearest reachable* tag, so intermediate commits build with the
  last tag's version — this is intended (the v1.0.10/v1.0.11 defect story in
  the release.yml comments: a tag build must sit on the tag, which the
  release.yml filename assertion enforces).
- **Fallback**: fires only when `git describe` fails, i.e. when **no tag is
  reachable** (a feed checkout without `.git`, a fresh clone without tags).
  The contract pins the fallback at `1.0.13` even though the branch's last
  released version is now `1.0.15`; since the fallback fires only when no
  tag is reachable at all, and release.yml pins tag builds to their tag, the
  static `1.0.13` is unreachable in every real build (see Discrepancies #1).
- The `sed 's/^v//'` strips only a leading `v` (a tag `v1.0.10` → `1.0.10`,
  a hypothetical plain `1.0.x` tag passes through untouched).

### 3. Built-artifact metadata layout and verification commands

The SDK gate produces two packages plus the i18n package:

- **`.ipk` (22.03, opkg)** = `ar` archive with `control.tar.gz` and
  `data.tar.gz`. Metadata lives in the control archive: the `control` file
  (fields `Package`, `Version` = `1.0.15` at this branch's HEAD — 22.03's
  luci.mk does not append `PKG_RELEASE` to ipk versions; `Depends`,
  `Architecture: all`, …), the
  `conffiles` file (one path per line), and the `description` file. The
  `Depends` list drops the `+` prefixes (package-ipkg.mk `strip_deps`).
  Modes are visible in `data.tar.gz` (`tar -tzvf`). After install, opkg
  keeps the list at `/usr/lib/opkg/info/luci-app-trusttunnel.conffiles`.
- **`.apk` (25.12, apk v3)** = gzipped tar with `.PKGINFO` and `.data/…`.
  The version is `1.0.15-r1` at this branch's HEAD (apk always appends
  `-r<release>`). The
  conffiles list ships at `.data/lib/apk/packages/
  luci-app-trusttunnel.conffiles` (paths + checksums). Depends appear as
  `depend:` entries in `.PKGINFO`/the adb index (`apk info -a`). Modes are
  visible in the tar listing and on the installed rootfs.
- The `luci-i18n-trusttunnel-ru` package must also build (it is the proof
  that the luci.mk integration — `po/ru`, findrev versioning — is intact);
  release.yml's "Collect artifacts" step fails the build if it is missing.

Commands (run on the host; `tar`/`ar` handle both formats):

```sh
# ipk: control + conffiles + file list with modes
ar p <pkg>.ipk control.tar.gz | tar -xzO ./control
ar p <pkg>.ipk control.tar.gz | tar -xzO ./conffiles
ar p <pkg>.ipk data.tar.gz  | tar -tzvf -
# apk: contents listing, conffiles file, PKGINFO
tar -tzf <pkg>.apk | sort
tar -xzf <pkg>.apk -C <tmp> .data/lib/apk/packages/luci-app-trusttunnel.conffiles
tar -xzOf <pkg>.apk .PKGINFO
```

### 4. Golden oracle: derived from a REBASED-tree SDK build

The official `v1.0.13` release assets (`.apk` 34 595 bytes, `.ipk` 34 441
bytes, verified via the GitHub API 2026-09-08) were built at commit
`1fdf82c` — the PRE-REBASE HEAD — from the OLD Makefile, which declared
`LUCI_DEPENDS:=+trusttunnel-client +luci-base +kmod-tun +ip-full +curl
+ca-bundle +ucode-mod-math` (no `+nftables`; `kmod-tun`/`ca-bundle`
repeated in the app). The rebase (HEAD `c43e20a`, now the branch tip `fa45849`
  plus the planning docs commit) changed BOTH Makefiles:
the app's `LUCI_DEPENDS` is now `+trusttunnel-client +luci-base +ip-full
+nftables +curl +ucode-mod-math`, and `trusttunnel-client` gained
`DEPENDS:=+kmod-tun +ca-bundle`. The old assets' metadata (their `Depends`
list above all) therefore **cannot serve as the golden** — "all diffs
empty" against them is unsatisfiable.

The golden is instead derived from a **local SDK build of the current
rebased tree**, i.e. the pre-rewrite Makefile at HEAD `fa45849` (Task 1
builds it before Task 2 touches the file, using the gh-action-sdk docker
recipe of Research §5). Its extracted metadata transcripts (control,
conffiles, file lists with modes, `.PKGINFO`) become the golden oracle in
`.build-out/golden-22.03/` and `.build-out/golden-25.12/`. The rewritten
Makefile changes only metadata *expression*, not shipped data, so the
post-rewrite build's transcripts must match the golden ones byte-for-byte
(allowing nothing except a single-line `LUCI_DESCRIPTION` rendering
identically after luci.mk's `$(strip)` — see Task 2). Because both
transcripts come from the same rebased tree, "all diffs empty" is
satisfiable and means exactly: the rewrite changed no metadata.

### 5. Build gate options and cost (TT-19/TT-20 dependency state)

- The current `release.yml` build job is **inherited but live and is the
  oracle**; TT-20 (its rewrite) is blocked by TT-14, and TT-19 (ci.yml
  rewrite) has no SDK build job — so this issue cannot "rely on the CI gate
  once TT-19 lands" for its build verification. The gate is release.yml via
  tag pushes or `workflow_dispatch`, or a local SDK build.
- `openwrt/gh-action-sdk@v7` internals (Dockerfile + entrypoint.sh, fetched
  2026-09-08): image `ghcr.io/openwrt/sdk:<arch>` (default container), then
  the entrypoint adds `src-link <FEEDNAME> /feed/` to `feeds.conf`, runs
  `./scripts/feeds update -a`, `make defconfig`, then per package
  `make package/<pkg>/download`, `make package/<pkg>/check`, and
  `make package/<pkg>/compile` (BUILD_LOG=1), and finally moves `bin/` and
  `logs/` to `/artifacts`. The whole repo is mounted at `/feed` (`.git` must
  enter the container — luci.mk's findrev needs it).
- Local equivalent (cheap-ish, no push needed): `docker build` the action's
  image from its repo with `--build-arg ARCH=x86-64-22.03.7` (or
  `x86-64-25.12.5`) and run it with `-v <repo>:/feed -v
  <repo>/.build-out:/artifacts --env FEEDNAME=ttowrt --env
  PACKAGES=luci-app-trusttunnel` — the exact steps the action performs,
  including the `make package/luci-app-trusttunnel/check` metadata/hash
  gate. `release.yml` measured the build at ~11–13 min per leg; two legs
  (22.03 + 25.12) are the full acceptance surface, one leg (22.03 ipk) is a
  reasonable minimum smoke with the apk leg following via the same recipe.
- The `workflow_dispatch` path skips the release.yml tag-version assertion;
  at this branch's HEAD the built artifact filenames still carry `1.0.15`
  (`git describe` → `v1.0.15` — the version a release of this tree would
  ship), so the assertion is effectively exercised; the true tag-push path is
  out of scope for this issue (do not push tags during TT-14).

### 6. Clean-room notes specific to this issue

- **Metadata values are contract data** — the plan and the rewrite may state
  them verbatim (`PKG_NAME`, `PKG_VERSION` derivation, `PKG_RELEASE:=1`,
  `PKG_LICENSE:=GPL-2.0-only`, `PKG_MAINTAINER`, `LUCI_TITLE`,
  `LUCI_DESCRIPTION` value, `LUCI_DEPENDS` list, `LUCI_URL`, `LUCI_PKGARCH`,
  the conffiles path, the chmod file list). **Comment prose is expression** —
  the rewrite must use new wording for every comment (the inherited file's
  comments about the version defect, the conffiles capture, the Windows
  executable-bit story, etc. must NOT be copied or paraphrased closely).
- The trailing `# call BuildPackage - OpenWrt buildroot signature` comment is
  inherited text with no functional role (luci.mk invokes BuildPackage
  itself) — drop it in the rewrite.
- The version-from-tag expression is **fork work** (original to this
  project), so it may be kept as-is; the contract pins its behavior.
- The golden artifacts are kept outside the tree and never committed; the
  PRD-mandated final `git status` check applies.

### 7. Risks and gaps

- **Ordering regression** would be silent in a diff review but fatal at
  runtime (empty conffiles → config overwritten on upgrade; empty
  `Build/Compile` → scripts ship 0644). The Task 3 checklist pins both
  orderings by line numbers; the Task 4 golden diff pins the result.
- **`git describe` environment inside the SDK**: the fallback fires only when
  no tags are reachable; the release.yml assertion covers the tag case. A
  build from a workflow_dispatch on `main` (tags v1.0.15 reachable) would
  produce 1.0.15, not the fallback — expected behavior, not a regression.
- **`LUCI_DESCRIPTION` line continuation**: the inherited file wraps the
  value over two lines with a backslash; luci.mk applies `$(strip)`, so a
  single-line assignment ships byte-identical metadata (verified: strip
  collapses the embedded tab). Keep the *value* byte-identical.
- **Golden staleness**: the golden is built from the current tree in Task 1;
  any tree change to `root/`/`htdocs`/`po` between the golden build and the
  Task 4 build (other issues landing in parallel) would legitimately change
  the file-list transcript. In that case diff only the *metadata-bearing*
  transcripts (control, conffiles, modes of the six chmod'd files) and
  re-verify the full file list against the current tree, not against the
  golden.
- **Golden build prerequisites**: deriving the golden needs docker plus
  network (or the workflow_dispatch alternative) and doubles the SDK cost;
  the golden build runs BEFORE the rewrite so the oracle cannot be
  contaminated by Task 2's diff — keep the `.build-out/` transcripts until
  Task 4's diffs are green.
- **Makefile syntax has no cheap standalone check** (`make -f` needs the SDK
  tree); the syntax gate is the SDK's `make package/luci-app-trusttunnel/check`
  inside the build. Cheap pre-checks are therefore textual (Task 3).

## Entities

### Package metadata (the Makefile's contract surface)

- **Fields** (all contract values; the Makefile re-expresses exactly these):
    - `# SPDX-License-Identifier: GPL-2.0-only` — kept until the TT-22 flip.
    - `include $(TOPDIR)/rules.mk` — first include.
    - `PKG_NAME:=luci-app-trusttunnel`.
    - `PKG_VERSION` — build-time: `git describe --tags --abbrev=0` with the
      leading `v` stripped; fallback `1.0.13` when no tag is reachable.
    - `PKG_RELEASE:=1`; `PKG_LICENSE:=GPL-2.0-only` (flip is TT-22);
      `PKG_MAINTAINER:=TrustTunnelOpenWrt contributors`.
    - `LUCI_TITLE:=LuCI support for TrustTunnel (full tunnel)`;
      `LUCI_DESCRIPTION` = "Runs the TrustTunnel client on OpenWrt and routes
      LAN traffic through the tunnel with a killswitch and a LuCI interface."
    - `LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl
      +ucode-mod-math` (the `+` marks unconditional selection; stripped from
      the built ipk's `Depends`). The split's other half: `trusttunnel-client`
      declares `DEPENDS:=+kmod-tun +ca-bundle` — the app gets both
      transitively via `+trusttunnel-client` and MUST NOT repeat them;
      `+nftables` is the app's own (`nft` is called directly by its routing
      helper and diagnostics).
    - `LUCI_URL:=https://github.com/i-zhirov/trusttunnel-openwrt`;
      `LUCI_PKGARCH:=all`.
    - `Package/luci-app-trusttunnel/conffiles` = `/etc/config/trusttunnel`
      — block placed BEFORE `include luci.mk`.
    - `Build/Compile` chmod workaround — placed AFTER `include luci.mk`:
      chmod 0755 `root/etc/init.d/trusttunnel`,
      `root/etc/uci-defaults/40-luci-trusttunnel`,
      `root/etc/hotplug.d/net/40-trusttunnel`,
      `root/usr/libexec/trusttunnel/gen-config`,
      `root/usr/libexec/trusttunnel/routing`,
      `root/usr/libexec/trusttunnel/uci-export`; chmod 0644
      `root/usr/libexec/trusttunnel/records.sh` (sourced, not executed).
- **Relationships**: `LUCI_*` → luci.mk package definition; `PKG_VERSION` →
  artifact filenames asserted by release.yml; conffiles → `KEEP_<pkg>`
  capture at BuildPackage time → ipk `control/conffiles` and apk
  `lib/apk/packages/<pkg>.conffiles`; `Build/Compile` chmods → modes in
  `data.tar.gz`/`.data/` (overriding the `cp -pR`-preserved source modes).
- **Validation**: contract values byte-identical (incl. the EXACT
  `LUCI_DEPENDS` line — no `kmod-tun`/`ca-bundle` in the app); conffiles
  block before the include; `Build/Compile` after the include; all seven
  chmod lines present; `sh tests/run.sh` green (test_deps.sh enforces the
  non-repetition rule and install.sh parity).
- **States**: n/a (declarative build metadata; no runtime states).

## Contracts

- Issue contract: `.sdd/.current/issues/TT-14/issue.md` (Contract to
  reproduce, Acceptance criteria, How to verify).
- Version assertion: `.github/workflows/release.yml` build job — on tag
  pushes, `dist/luci-app-trusttunnel-${tag}-r1.apk` and
  `dist/luci-app-trusttunnel_${tag}_all.ipk` must exist (with `${tag#v}`).
- Package-manager metadata formats: OpenWrt 22.03 ipk (`control`/`conffiles`
  in `control.tar.gz`) and 25.12 apk v3 (`.PKGINFO`, `.data/…`, conffiles at
  `lib/apk/packages/<pkg>.conffiles`) — see Research §3.
- No API endpoints; the Makefile is consumed only by the buildroot.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/Makefile` | Rewrite | Re-expressed package metadata from the contract; new comment wording; conffiles before `include luci.mk`; `Build/Compile` chmod set after it; no inherited text (trailing `call BuildPackage` comment dropped) |
| `.build-out/golden-22.03/`, `.build-out/golden-25.12/` (gitignored, ephemeral) | Create (outside tree) | Golden oracle: `.apk`/`.ipk` from a local SDK build of the CURRENT (pre-rewrite) rebased tree at HEAD `fa45849` + extracted metadata transcripts; never committed |
| `.build-out/sdk/` (gitignored, ephemeral) | Create (outside tree) | Local SDK build helper (action-image build + docker run) and the new built artifacts + transcripts; never committed |

## Tasks

### [ ] Task 1: Baseline — golden metadata from a REBASED-tree SDK build

**Files:**

- Run (no tracked changes): `git log`, `git describe --tags --abbrev=0`,
  docker SDK build of the CURRENT tree
- Create (ephemeral, outside the tree): `.build-out/golden-22.03/`,
  `.build-out/golden-25.12/` artifacts + transcripts

- [x] **Step 1: Confirm the baseline state**

Run:

```sh
git log --oneline -1            # HEAD
git log --oneline -1 v1.0.13    # 1fdf82c — the PRE-rebase HEAD, not the current one
git describe --tags --abbrev=0  # must print v1.0.15 (nearest reachable tag)
git status --porcelain          # must be empty
```

Expected: HEAD == `c43e20a`; `v1.0.13` == `1fdf82c` (the pre-rebase HEAD);
`git describe --tags --abbrev=0` → `v1.0.15`; clean tree. Both Makefiles
changed on the rebase — `luci-app-trusttunnel/Makefile` declares
`LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl
+ucode-mod-math` and `trusttunnel-client/Makefile` declares
`DEPENDS:=+kmod-tun +ca-bundle` (the Task 2 rewrite starts from the
contract, not from these files). Consequence: the official v1.0.13 release
assets (built at `1fdf82c` with the OLD depends, Research §4) cannot serve
as the golden — the golden is built from THIS tree in Step 2.

- [x] **Step 2: Build the golden from the current (pre-rewrite) tree**

Replicate the release.yml build job locally (the action's exact steps, per
Research §5) with the repo mounted as the feed — the Makefile is still the
inherited one, so this captures the ORACLE before any rewrite:

```sh
mkdir -p .build-out/golden-22.03 .build-out/golden-25.12
git clone --depth 1 https://github.com/openwrt/gh-action-sdk .build-out/sdk/action
docker build --build-arg ARCH=x86-64-22.03.7 -t sdk-22.03 .build-out/sdk/action
docker build --build-arg ARCH=x86-64-25.12.5 -t sdk-25.12 .build-out/sdk/action
docker run --rm -v "$PWD:/feed" -v "$PWD/.build-out/golden-22.03":/artifacts \
  --env FEEDNAME=ttowrt --env PACKAGES=luci-app-trusttunnel sdk-22.03
docker run --rm -v "$PWD:/feed" -v "$PWD/.build-out/golden-25.12":/artifacts \
  --env FEEDNAME=ttowrt --env PACKAGES=luci-app-trusttunnel sdk-25.12
```

Alternative (if a local docker SDK build is infeasible): push the branch and
run the current release.yml `build` job via `workflow_dispatch` NOW (the
tree is still pre-rewrite), then download the `package-22.03.7` /
`package-25.12.5` artifacts into `.build-out/golden-22.03` /
`.build-out/golden-25.12`. Either path exercises the same `make
package/luci-app-trusttunnel/check` + `compile` gate.

Expected: both legs succeed (the action's `package/luci-app-trusttunnel/check`
— metadata/hash gate — passes); artifacts appear in the output dirs, named
`luci-app-trusttunnel-1.0.15-r1.apk` and `luci-app-trusttunnel_1.0.15_all.ipk`
(version from `git describe` at HEAD → `v1.0.15` → `1.0.15`), plus both
`luci-i18n-trusttunnel-ru` files. These artifacts and their transcripts are
the golden — they stay in the gitignored `.build-out/`, never committed.

- [x] **Step 3: Extract the golden metadata transcripts**

```sh
cd .build-out/golden-22.03
ar p luci-app-trusttunnel_1.0.15_all.ipk control.tar.gz | tar -xzO ./control  > golden-ipk.control.txt
ar p luci-app-trusttunnel_1.0.15_all.ipk control.tar.gz | tar -xzO ./conffiles > golden-ipk.conffiles.txt
ar p luci-app-trusttunnel_1.0.15_all.ipk data.tar.gz  | tar -tzvf -            > golden-ipk.files.txt
cd ../golden-25.12
tar -xzf luci-app-trusttunnel-1.0.15-r1.apk -C . .data/lib/apk/packages/luci-app-trusttunnel.conffiles 2>/dev/null || true
tar -xzOf luci-app-trusttunnel-1.0.15-r1.apk .PKGINFO   > golden-apk.pkginfo.txt
tar -tzvf luci-app-trusttunnel-1.0.15-r1.apk            > golden-apk.files.txt
```

Expected: `golden-ipk.conffiles.txt` contains exactly `/etc/config/trusttunnel`;
`golden-ipk.control.txt` shows `Version: 1.0.15`, `Architecture: all`, and
`Depends` listing `trusttunnel-client, luci-base, ip-full, nftables, curl,
ucode-mod-math` (the NEW split — order as shipped); `golden-ipk.files.txt`
shows the six scripts at 0755 and `records.sh` at 0644. For the apk, record
where the conffiles file landed (expect `.data/lib/apk/packages/
luci-app-trusttunnel.conffiles`) and that `.PKGINFO` carries `1.0.15-r1`.
Record the transcripts' paths in the task notes.

**Verification**: transcripts exist and match the expectations above;
`git status --porcelain` still empty (everything lives in gitignored
`.build-out/`).

### [ ] Task 2: Re-express the Makefile from the contract

**Files:**

- Modify: `packages/luci-app-trusttunnel/Makefile`

- [x] **Step 1: Write the replacement from the contract only**

CLEAN-ROOM: do NOT open the current `Makefile` while writing. Work from the
issue's Contract section, the Technical Context, and the Entity table above.
The file below is new expression written from that contract (metadata values
are contract data; every comment is new wording; the version expression is
fork work and kept as the contract's behavior). Requirements:

- `# SPDX-License-Identifier: GPL-2.0-only` first, then
  `include $(TOPDIR)/rules.mk`.
- All `PKG_*`/`LUCI_*` values exactly as in the Entity table; the
  `LUCI_DESCRIPTION` value on a single line (luci.mk `$(strip)`s it, so the
  shipped metadata is byte-identical to the two-line form).
- `LUCI_DEPENDS` exactly `+trusttunnel-client +luci-base +ip-full +nftables
  +curl +ucode-mod-math` — NO `kmod-tun`/`ca-bundle` in the app (they live on
  `trusttunnel-client`'s own `DEPENDS` and arrive transitively; test_deps.sh
  fails on repetition, Task 3 Step 2 pins the exact line).
- The version derivation keeps the exact contract semantics (tag → stripped
  `v`; fallback `1.0.13` when `git describe` finds no reachable tag).
- The conffiles block BEFORE `include $(TOPDIR)/feeds/luci/luci.mk`.
- The `Build/Compile` chmod set AFTER the include: six chmod 0755 lines for
  init.d / uci-defaults / hotplug / gen-config / routing / uci-export, plus
  chmod 0644 for records.sh.
- Drop the inherited trailing `# call BuildPackage` comment (no function;
  luci.mk invokes BuildPackage itself).

```make
# SPDX-License-Identifier: GPL-2.0-only
#
# luci-app-trusttunnel: LuCI support for the TrustTunnel full-tunnel client.
# Build metadata re-expressed from the TT-14 contract; the license line is
# unchanged until the TT-22 license flip.
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-trusttunnel

# Version from the release tag at build time: a build on tag vX.Y.Z ships
# X.Y.Z, which both package managers see as strictly higher than the
# previous release (apk names read X.Y.Z-r1, the 22.03 luci.mk ignores
# PKG_RELEASE for ipk versions). The status page's update check compares
# the release tag against the installed version, so a build that carries
# its tag's version reports "up to date"; a stale static version made two
# releases ship the same number and no upgrade ever delivered the new
# files. `git describe` reports the nearest reachable tag, so commits
# below a tag build with that tag's version; the fallback below applies
# only when no tag is reachable (local builds, manual re-deploys, a feed
# without .git). Keep the fallback equal to the last released version;
# release.yml fails a tag build whose artifact does not carry the tag.
PKG_VERSION:=$(strip $(shell v="$$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"; [ -n "$$v" ] && printf '%s' "$$v" || printf '%s' 1.0.13))
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=TrustTunnelOpenWrt contributors

LUCI_TITLE:=LuCI support for TrustTunnel (full tunnel)
LUCI_DESCRIPTION:=Runs the TrustTunnel client on OpenWrt and routes LAN traffic through the tunnel with a killswitch and a LuCI interface.
# Every dependency below is used by THIS package's own files — nothing is
# carried for the client's sake. +trusttunnel-client is a hard dependency
# (this package configures and runs the client binaries in
# /opt/trusttunnel_client; both package managers pull the client from the
# same repository, which is what lets it update with `apk upgrade` /
# `opkg upgrade`). kmod-tun and ca-bundle live on trusttunnel-client's own
# DEPENDS (the binaries create the tun device and do TLS against a CA
# bundle) and arrive here transitively — the app must NOT repeat them.
# ip-full (`ip rule`/`ip route`), nftables (`nft` is called directly by the
# routing helper and the diagnostics — fw4 pulling it on stock images is
# not enough), curl (update check, diagnostics) and ucode-mod-math are
# invoked by this package's own files.
LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl +ucode-mod-math
# Without this override luci.mk would substitute the LuCI project's own
# address, and package metadata would point support at the wrong place.
LUCI_URL:=https://github.com/i-zhirov/trusttunnel-openwrt
LUCI_PKGARCH:=all

# The conffiles declaration must precede `include luci.mk`: luci.mk's last
# line expands BuildPackage, and the pack stage freezes the conffiles list
# with an immediate assignment at that moment. A declaration after the
# include is parsed too late, the captured list stays empty, and a package
# update would then overwrite /etc/config/trusttunnel with defaults —
# destroying the endpoint settings, the certificate and the service state.
define Package/luci-app-trusttunnel/conffiles
/etc/config/trusttunnel
endef

include $(TOPDIR)/feeds/luci/luci.mk

# Executable bits set explicitly rather than taken from the repository:
# luci.mk copies root/ with `cp -pR`, so modes come from the source files,
# and the git index is not a reliable carrier (bits are lost in zip
# downloads, on permission-less file systems, and on Windows). Without
# this block the built package would ship scripts that procd cannot start
# — with no log line at all. records.sh is sourced with `.`, not executed,
# so it stays 0644.
define Build/Compile
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/40-luci-trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/hotplug.d/net/40-trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/gen-config
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/routing
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/uci-export
	chmod 0644 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/records.sh
endef
```

- [x] **Step 2: Self-check the rewrite**

Run: `git diff packages/luci-app-trusttunnel/Makefile`

Expected: only `packages/luci-app-trusttunnel/Makefile` modified; no file
mode change; the diff's removed side is the inherited text and the added side
is the new expression above — verify by reading the diff that no inherited
comment phrase survived (self-check: the file was written from the contract,
not by transformation) and that no contract value changed.

**Verification**: new file present with the full contract surface; diff
reviewed; no `*.old` files; no other tracked file touched.

### [ ] Task 3: Cheap static verification (no SDK build)

**Files:**

- Run: `sh` one-liner version matrix, `grep -n` ordering/value checklist,
  `git diff --stat`

- [x] **Step 1: Version-derivation matrix**

Run the derivation exactly as the Makefile computes it, in three states
(the expression is fork work; this pins its contract behavior):

```sh
# (a) this branch's HEAD (c43e20a — not a tag; describe → v1.0.15):
v="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"; [ -n "$v" ] && printf '%s\n' "$v" || printf '%s\n' 1.0.13
#    Expected: 1.0.15 (HEAD is v1.0.15-4-gc43e20a; nearest reachable tag)

# (b) fallback state — no git repository at all:
cd "$(mktemp -d)"; v="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"; [ -n "$v" ] && printf '%s\n' "$v" || printf '%s\n' 1.0.13
#    Expected: 1.0.13 (the fallback)

# (c) strip-only check: a tag "v1.0.10" strips to "1.0.10", a tag "1.0.10"
#     (no v) passes through unchanged:
printf 'v1.0.10\n' | sed 's/^v//'; printf '1.0.10\n' | sed 's/^v//'
#    Expected: 1.0.10 twice
```

Note for the record: an intermediate commit (between tags) yields the last
reachable tag, NOT the fallback — the fallback fires only when `git describe`
fails (no reachable tags). This matches the release.yml assertion model.

- [x] **Step 2: Ordering and value checklist (grep the new file)**

```sh
f=packages/luci-app-trusttunnel/Makefile
grep -n 'include $(TOPDIR)/rules.mk' "$f"                       # line 1-ish, first include
grep -n 'include $(TOPDIR)/feeds/luci/luci.mk' "$f"            # must be AFTER the conffiles block
grep -n 'define Package/luci-app-trusttunnel/conffiles' "$f"  # line < include line
grep -n 'define Build/Compile' "$f"                            # line > include line
grep -n '^PKG_NAME:=\|^PKG_RELEASE:=\|^PKG_LICENSE:=\|^PKG_MAINTAINER:=' "$f"
grep -n '^LUCI_TITLE:=\|^LUCI_DESCRIPTION:=\|^LUCI_URL:=\|^LUCI_PKGARCH:=' "$f"
grep -n '^LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl +ucode-mod-math$' "$f"   # the EXACT line
grep -n '^LUCI_DEPENDS:=' "$f" | grep -c 'kmod-tun'   # must print 0 — the app must not repeat it
grep -n '^LUCI_DEPENDS:=' "$f" | grep -c 'ca-bundle'  # must print 0 — the app must not repeat it
grep -c 'chmod 0755' "$f"    # 6
grep -n 'records.sh' "$f"    # exactly one line, chmod 0644
grep -n 'SPDX-License-Identifier: GPL-2.0-only' "$f"
```

Expected: conffiles block line < `include luci.mk` line < `Build/Compile`
line; all contract values present verbatim (spot-check each against the
Entity table) — including the FULL `LUCI_DEPENDS` line as the actualized
split, with no `kmod-tun`/`ca-bundle` in the app's declaration (a stray
repeat would fail the negative greps above AND tests/test_deps.sh); six
`chmod 0755` lines; `records.sh` chmod 0644; SPDX header present.

- [x] **Step 3: Diff hygiene**

Run: `git diff --stat` and `git status --porcelain`

Expected: exactly one modified file; no mode changes; `.build-out/` not
listed (gitignored).

- [x] **Step 4: Run the fork's dependency test suite**

Run: `sh tests/run.sh`

Expected: every test passes, including `tests/test_deps.sh`, which asserts
the app declares `trusttunnel-client luci-base ip-full nftables curl
ucode-mod-math`, the client declares `kmod-tun ca-bundle`, the app does NOT
repeat kmod-tun/ca-bundle, the real scripts invoke nft/ip/curl/math, and
install.sh's apk/opkg install lists match the declarations (baseline at plan
time: 40 assertions, 0 failed). This is the gate that catches a wrong
`LUCI_DEPENDS` line — run it here, before the SDK build.

**Verification**: all checklist assertions pass and `sh tests/run.sh` is
green — the rewrite satisfies the contract before any expensive build.

### [ ] Task 4: SDK build gate + metadata byte-diff vs golden

**Files:**

- Create (ephemeral, outside the tree): `.build-out/sdk/` — local build
  helper + artifacts + new transcripts
- Run: docker SDK builds (22.03.7 ipk leg, 25.12.5 apk leg); transcript
  diffs; rootfs install/upgrade smoke

- [x] **Step 1: Build both legs via the local SDK recipe**

Replicate the release.yml build job locally (the action's exact steps, per
Research §5): clone `openwrt/gh-action-sdk` into `.build-out/sdk/`, build its
image with the ARCH build-arg, and run it with the repo mounted as the feed:

```sh
mkdir -p .build-out/sdk .build-out/artifacts-22.03 .build-out/artifacts-25.12
git clone --depth 1 https://github.com/openwrt/gh-action-sdk .build-out/sdk/action
docker build --build-arg ARCH=x86-64-22.03.7 -t sdk-22.03 .build-out/sdk/action
docker build --build-arg ARCH=x86-64-25.12.5 -t sdk-25.12 .build-out/sdk/action
for img in sdk-22.03 sdk-25.12; do
  out=.build-out/artifacts-${img#sdk-}
  docker run --rm -v "$PWD:/feed" -v "$PWD/$out":/artifacts \
    --env FEEDNAME=ttowrt --env PACKAGES=luci-app-trusttunnel "$img"
done
```

Alternative (if a local docker SDK build is infeasible): push the branch and
run the current release.yml `build` job via `workflow_dispatch`, then
download the `package-22.03.7`/`package-25.12.5` artifacts into
`.build-out/`. Either path exercises the same `make
package/luci-app-trusttunnel/check` + `compile` gate.

Expected: both legs succeed (the action's `package/luci-app-trusttunnel/check`
— metadata/hash gate — passes); artifacts appear in `out/bin/`; the "Collect
artifacts" equivalents produce `luci-app-trusttunnel-1.0.15-r1.apk`,
`luci-app-trusttunnel_1.0.15_all.ipk`, plus both `luci-i18n-trusttunnel-ru`
files. `git describe` at HEAD yields `v1.0.15`, so the built version is
`1.0.15` — the version a release of this tree would carry (release.yml's
filename assertion itself binds only on tag pushes; do not push tags during
TT-14). The version must match the golden's (Task 1): both builds sit on the
same commit.

- [x] **Step 2: Diff the new metadata transcripts against the golden**

Extract the new transcripts with the Task 1 Step 3 commands (into
`.build-out/artifacts-22.03/new-*` and `.build-out/artifacts-25.12/new-*`),
then:

```sh
diff -u .build-out/golden-22.03/golden-ipk.control.txt   .build-out/artifacts-22.03/new-ipk.control.txt
diff -u .build-out/golden-22.03/golden-ipk.conffiles.txt .build-out/artifacts-22.03/new-ipk.conffiles.txt
diff -u .build-out/golden-22.03/golden-ipk.files.txt     .build-out/artifacts-22.03/new-ipk.files.txt
diff -u .build-out/golden-25.12/golden-apk.pkginfo.txt   .build-out/artifacts-25.12/new-apk.pkginfo.txt
diff -u .build-out/golden-25.12/golden-apk.files.txt     .build-out/artifacts-25.12/new-apk.files.txt
```

Expected: all diffs empty — the rebuilt package carries the identical
metadata (Version 1.0.15 / 1.0.15-r1, identical Depends — the NEW split:
`trusttunnel-client, luci-base, ip-full, nftables, curl, ucode-mod-math` —
identical `/etc/config/trusttunnel` conffiles, identical file list and
modes: six scripts 0755, records.sh 0644). Golden and new build sit on the
same rebased tree (pre- vs post-rewrite Makefile), so empty diffs mean
exactly: the rewrite changed no metadata. If other TT-xx issues landed in
parallel and changed shipped files, restrict the comparison to the
metadata-bearing transcripts (control, conffiles, and the modes of the six
chmod'd files) and re-derive the full file list from the current tree
(Research §7).

- [x] **Step 3: Rootfs install + upgrade-survival smoke**

```sh
# apk leg (25.12): install the built apk, check the protected list and modes
docker run --rm -v "$PWD/.build-out/artifacts-25.12":/pkg:ro openwrt/rootfs:x86-64-25.12.0 \
  sh -c 'apk add --allow-untrusted /pkg/luci-app-trusttunnel-1.0.15-r1.apk \
    && cat /lib/apk/packages/luci-app-trusttunnel.conffiles \
    && ls -l /etc/init.d/trusttunnel /etc/uci-defaults/40-luci-trusttunnel \
       /etc/hotplug.d/net/40-trusttunnel /usr/libexec/trusttunnel/*'
# opkg leg (22.03): same, via /usr/lib/opkg/info/luci-app-trusttunnel.conffiles
docker run --rm -v "$PWD/.build-out/artifacts-22.03":/pkg:ro openwrt/rootfs:x86-64-22.03.7 \
  sh -c 'opkg install /pkg/luci-app-trusttunnel_1.0.15_all.ipk \
    && cat /usr/lib/opkg/info/luci-app-trusttunnel.conffiles \
    && ls -l /etc/init.d/trusttunnel /usr/libexec/trusttunnel/*'
```

Expected: the conffiles list names `/etc/config/trusttunnel`; the six scripts
are 0755, `records.sh` 0644 on the installed rootfs. Then the upgrade-
survival check (issue's verification #3): modify `/etc/config/trusttunnel`
in the container, re-run `apk add` / `opkg install --force-reinstall` of the
same artifact, and confirm the modified config is preserved (opkg: "not
overwriting", apk: protected path kept) — the conffiles declaration is
working, not just present.

**Verification**: both builds green; metadata diffs empty; rootfs installs
show correct conffiles/modes; config survives reinstall.

### [ ] Task 5: Full gates and clean-tree check

**Files:**

- Run: `git status`, `git diff --name-only`, final summary

- [x] **Step 1: Clean-tree check (PRD requirement)**

Run: `git status` and `git diff --name-only`

Expected: exactly `packages/luci-app-trusttunnel/Makefile` modified; no
`*.old`, no golden/transcript/artifact copies inside the tree (`.build-out/`
is gitignored and must remain untracked); nothing else staged. Confirm with
`git status --ignored --short .build-out` that the oracle artifacts are
ignored, not accidentally tracked.

- [x] **Step 2: Gate summary**

Record in the task notes: Task 1 baseline (golden transcripts from the
rebased-tree SDK build + release.yml as the live oracle), Task 3 static
checklist results and `sh tests/run.sh` output, Task 4 build + diff + rootfs
results — i.e., the evidence for every acceptance criterion: tag-derived
version in the artifact filenames (1.0.15 at this branch's HEAD), conffiles
ordering verified in the built packages, chmod workaround verified on the
installed files, depends list byte-identical to the golden (the NEW split,
including test_deps.sh's non-repetition and install.sh-parity assertions).

**Verification**: tree clean; all four acceptance criteria of the issue have
recorded evidence; no inherited text remains in the Makefile (final read of
the diff).

## Discrepancies found during planning

1. **Fallback `1.0.13` vs the branch's released versions**: after the rebase
   the tags `v1.0.14`/`v1.0.15` ARE reachable from this branch — `git
   describe --tags --abbrev=0` at HEAD `c43e20a` → `v1.0.15`, so every build
   at HEAD (golden, SDK gate) carries `1.0.15`, never the fallback. The
   contract pins the fallback at `1.0.13` even though the branch's last
   released version is now `1.0.15`; because the fallback fires only when no
   tag is reachable at all (a feed checkout without `.git`, a fresh clone
   without tags) and release.yml pins tag builds to their tag, the static
   `1.0.13` is unreachable in every real build — the plan keeps the contract
   value verbatim and records the state.
2. **Issue wording "fallback when not on a tag"**: precisely, the fallback
   fires only when *no tag is reachable* (git describe fails); intermediate
   commits get the last reachable tag. The plan pins this semantic; the
   release.yml assertion covers the tag case.
3. **`Build/Compile` must come AFTER `include luci.mk`** is an ordering
   constraint the issue does not state (it only mandates the conffiles
   position). Verified against luci.mk (it defines its own empty
   `Build/Compile`); the plan enforces both orderings.
4. **"CI gate once TT-19 lands" (issue's How-to-verify)**: TT-19 (ci.yml)
   has no SDK build job and TT-20 (release.yml rewrite) is blocked by TT-14 —
   the only live build gate during TT-14 is the current inherited release.yml
   build job; the plan therefore uses the local SDK recipe (or that job via
   workflow_dispatch) as the gate.
5. **Inherited trailing comment** `# call BuildPackage - OpenWrt buildroot
   signature` is not part of the contract and has no function (luci.mk
   invokes BuildPackage itself) — dropped in the rewrite.

## Execution Record (2026-09-10 — full verification completed)

The first implementation attempt was interrupted (disk space) mid-verification;
this record documents the complete re-verification.

**SDK build legs (all four, via the gh-action-sdk recipe in docker):**

| Leg | Feed | Result |
| --- | --- | --- |
| golden-22.03 | 737c761 (pre-rewrite Makefile, GPL-2.0-only) | `luci-app-trusttunnel_1.0.15_all.ipk` — Version 1.0.15, Depends = libc, trusttunnel-client, luci-base, ip-full, nftables, curl, ucode-mod-math; conffiles = /etc/config/trusttunnel; six scripts 0755, records.sh 0644 |
| golden-25.12 | 737c761 | `luci-app-trusttunnel-1.0.15-r1.apk` — adbdump: name/version/arch/depends/conffiles/modes verified |
| new-22.03 | a5c376b (rewritten Makefile) | `luci-app-trusttunnel_1.0.15_all.ipk` |
| new-25.12 | a5c376b | `luci-app-trusttunnel-1.0.15-r1.apk` |

**Metadata byte-diff golden vs new — IDENTICAL except the three intentional fields:**
- License: GPL-2.0-only → Apache-2.0 (the TT-22 flip; golden was captured pre-flip)
- SourceDateEpoch / apk mtimes / content hashes / Installed-Size (build time + the rewritten code's sizes)
- Version (1.0.15 / 1.0.15-r1), Depends (the new split), Architecture (all), Section, conffiles, file paths and modes: **identical on both package managers**.

**Bug found and fixed by this verification:** the clean-room rewrite dropped the
trailing `# call BuildPackage - OpenWrt buildroot signature` comment. That comment
is NOT decoration: the OpenWrt feed scan (`include/scan.mk`, GREP_STRING =
`call (Build/DefaultTargets|BuildPackage|KernelPackage)`) discovers packages by
grepping Makefile text, so without it the package vanished from the SDK feed
scan ("No feed for package 'luci-app-trusttunnel' found") and the release build
job would fail. Restored as the Makefile's final line (commit 2740ad2). The
earlier plan/review conclusion that the comment was "non-contract, dropped" was
wrong — this is a load-bearing discovery marker.

**Environment notes (for reproducing):** the 25.12 ghcr SDK image is a snapshot
container (setup.sh downloads the SDK; its gpg verification needs keys the image
lacks) — prepared by extracting the 25.12.5 SDK tarball into the image and
removing setup.sh (sdk-25.12-nosetup). The feed's `.git` must be owned by the
container user or git refuses it (dubious ownership) — mounted a HOME with a
safe.directory gitconfig. Docker Desktop/colima bind mounts are write-hostile:
artifacts were extracted via `docker cp` after each build (the entrypoint's
`mv bin/ /artifacts/` fails with EACCES on the mount).

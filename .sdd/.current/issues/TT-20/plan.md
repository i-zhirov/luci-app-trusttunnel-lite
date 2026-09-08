# Implementation Plan: release.yml workflow (TT-20)

- **Created**: 2026-09-09
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-20/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation of `.github/workflows/release.yml` (577 lines, inherited GPL-2.0 release-flow skeleton + fork work). Re-express from the workflow spec — NO YAML copied from the inherited file into the plan or the new file. TDD-ordered chunks: baseline → build → build-client → publish-repo apk half → publish-repo opkg half → verification → release upload → site assembly/deploy, validating YAML syntax and action references after each chunk. Final verification: workflow_dispatch release from a test tag vX.Y.Z-rc; verify published repos install cleanly via the verification jobs and install.sh."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles + site
changes). `release.yml` changed; the issue contract was updated:

- **Site assembly rewritten**: the static `apk-index.html`/`opkg-index.html`
  copies are gone. Now: copy `repo-site/_layouts/` → `site/_layouts`;
  `apk-index.md` with the `__ARCH_LIST__` placeholder substituted from
  the assembled `site/apk/*/` dirs → `site/apk/index.md`; `opkg-index.md`
  → `site/opkg/index.md`; per-arch `apk-arch-index.md` with
  `__ARCH__`/`__FILES__` (packages.adb + *.apk listing generated from
  each repo dir) → `site/apk/<arch>/index.md`. Jekyll renders all of
  them. Chunk 7 (site assembly) must be re-expressed around the markdown
  templates and the sed-substitution loops.
- Verification jobs' comments changed (kmod-tun/ca-bundle/nftables
  wording) — behavior identical.
- Everything else (build, build-client, publish-repo signing, release
  upload, Pages actions) unchanged.

## Summary

Reimplement `.github/workflows/release.yml` from the TT-20 contract as the
project's own pipeline spec, preserving every externally visible behavior:
trigger + permission declaration, the noarch LuCI build matrix, the
per-architecture client build matrix, the signed per-arch apk repositories
and the signed merged opkg feed, the in-workflow rootfs verification of both
package-manager generations, the single-writer GitHub release upload, and the
GitHub Pages site assembly (nothing committed to any branch).

The plan is TDD-ordered: baseline first (validation state of the inherited
file + a job-by-job contract checklist + a scratch reference copy outside the
repo), then seven re-expression chunks in dependency order (skeleton+build →
build-client → publish-repo apk half → publish-repo opkg half → verification
→ release upload → site assembly/deploy), each validated locally (YAML parse
+ actionlint + contract-checklist tick + negative control) before the next
chunk, then the final gate: a `workflow_dispatch` run from a test tag
`vX.Y.Z-rc` that exercises the full pipeline (tag assertion, verification
jobs, release upload, Pages deploy) and a live install from the published
Pages repo via the TT-18 installer. Zero YAML structure or comments are
copied from the inherited file; the contract (commands, pins, digests,
secrets, artifact names) is carried over exactly and re-expressed.

## Technical Context

- **Language/Platform**: GitHub Actions workflow YAML (expression syntax
  `${{ }}`, `if:` conditions, matrix strategies, artifact upload/download,
  Pages deploy actions). Runner: `ubuntu-latest`; the file is not executed
  locally — "tests" are static validation + one live `workflow_dispatch` run.
- **Primary Dependencies**:
  - `openwrt/gh-action-sdk@v7` — SDK-container build delegate (feed in via
    docker volume; absolute `FEED_DIR` mandatory).
  - `actions/checkout@v7`, `actions/upload-artifact@v7`,
    `actions/download-artifact@v7`, `softprops/action-gh-release@v3`,
    `actions/jekyll-build-pages@v1`, `actions/configure-pages@v5`,
    `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4`.
  - apk-tools 3.x (`apk mkndx`, `apk adbsign`) via the pinned
    `alpine:edge@sha256:266f2925…` container (stable Alpine ships apk-tools
    2.14, which lacks mkndx/adbsign).
  - OpenWrt opkg tooling: `ipkg-make-index.sh` (fetched at run time from the
    `openwrt-22.03` branch of the OpenWrt tree), a `sha256sum`-based `MKHASH`
    shim, field filtering, the usign SHA-512 padding workaround, `gzip -9nc`,
    and `usign -S` inside `openwrt/rootfs:x86-64-22.03.7`.
  - Verification images: `openwrt/rootfs:x86-64-25.12.0` (apk),
    `openwrt/rootfs:x86-64-23.05.6` and `x86-64-24.10.8` (opkg).
- **Storage**: none (workflow artifacts only): GitHub release assets,
  GitHub Pages site at `https://i-zhirov.github.io/trusttunnel-openwrt/`,
  workflow `dist/`/`staging/`/`site/` dirs inside the runner workspace.
- **Testing**: local static validation (`ruby` YAML parse + `actionlint`
  v0.64.x from nix profile; docker available) after every chunk; final live
  gate: `workflow_dispatch` from a test tag, verification jobs, and the
  TT-18 `install.sh` against the published Pages repo on the four rootfs
  images.
- **Target Platform**: GitHub Actions (public repo
  `i-zhirov/trusttunnel-openwrt`), OpenWrt routers 22.03–25.12 via the
  produced repositories.

## Research

### Baseline state of the inherited file (verified 2026-09-09)

- `git ls-files -s .github/workflows/release.yml` → mode `100644` (workflow
  file; no executable bit involved). Worktree is clean except `.sdd/` and
  `docs/`.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'`
  → parses OK (Ruby 2.6 psych; do not pass `aliases:`).
- `actionlint .github/workflows/release.yml` → exit 0 with exactly TWO
  pre-existing info-level shellcheck findings inside `run:` bodies:
  - `SC2086` at the apk assemble+index step (actionlint reports the
    `run:` key at line 368; the flagged payload sits around line 403 —
    the `sh -c 'for d in /repo/*/; do …'` glob loop): intentional POSIX
    glob use;
  - `SC2016` at the opkg assemble+index step (actionlint reports the
    `run:` key at line 412; the flagged single-quoted text sits around
    line 452 — the `sh -c 'cd /repo && usign -S …'` payload and the
    mkhash shim `printf '…"$2"…'`): literal `$` — intentional.
  The file is 620 lines at commit c43e20a (2026-09-09). Task 1
  re-records this baseline against the working tree when the rewrite
  starts, so the exact line numbers are re-cited there.
  The new file must not add any NEW actionlint/shellcheck findings; the two
  inherited ones should ideally be eliminated (quote/escape the lint
  findings without changing command behavior) or reproduced knowingly.
- Matrix facts verified programmatically from the inherited YAML: build =
  `25.12.5/apk` + `22.03.7/ipk`; build-client = 20 apk archs (25.12.5) and
  19 ipk archs (22.03.7); the ipk list is exactly the apk list minus
  `aarch64_cortex-a76`.

### Contract vs current behavior — job-by-job verification

The issue's "Contract to reproduce" was checked step by step against the
inherited workflow (2026-09-09). Every contract item is present and behaves
as described; the issue omits a set of precision details that the new file
MUST preserve. None are contract-breaking; all are recorded as D1–D12.

| # | Issue contract item | Inherited behavior | Verdict |
|---|---|---|---|
| 1 | Triggers tags `v*` + `workflow_dispatch`; permissions contents+pages+id-token | `on.push.tags ['v*']` + `workflow_dispatch`; `contents: write`, `pages: write`, `id-token: write` | matches |
| 2 | build: matrix 25.12.5/.apk + 22.03.7/.ipk, x86-64 SDK, `FEEDNAME=ttowrt`, `FEED_DIR=${{github.workspace}}` (absolute), `PACKAGES=luci-app-trusttunnel` | present; `ARCH: x86-64-<version>`; plus `ARTIFACTS_DIR: <workspace>/out` and a `mkdir -p out` step BEFORE the SDK action (D2); `fail-fast: false` (D7) | matches + D2, D7 |
| 3 | collect `luci-app-trusttunnel*` + `luci-i18n-trusttunnel-*`; both must exist | `find out/bin/` copies both into `dist/`, then hard `ls` existence assertions on both patterns | matches |
| 4 | assert built filename matches tag (`.apk` = `luci-app-trusttunnel-<tag>-r1.apk`, `.ipk` = `luci-app-trusttunnel_<tag>_all.ipk`) | `if: startsWith(github.ref, 'refs/tags/')`; `tag="${GITHUB_REF_NAME#v}"` (D3); `test -f` per ext; `::error::` + exit 1 on mismatch; skipped on dispatch | matches + D3 |
| 5 | upload artifacts (+ build logs on failure) | `package-<version>` from `dist/*`; `build-logs-<version>` from `out/logs/` with `if: failure()` and `if-no-files-found: ignore` (D8) | matches + D8 |
| 6 | build-client: 20 apk archs / 19 ipk archs (no aarch64_cortex-a76) | matrix verified programmatically; `ARCH: <arch>-<version>`; `PACKAGES: trusttunnel-client` | matches |
| 7 | build-client: rename apk files to append `-<arch>`, write `ARCH-<arch>` markers | apk: `cp "$f" "dist/$(basename "$f" .apk)-<arch>.apk"` + `printf '%s\n' <arch> > dist/ARCH-<arch>`; ipk: plain copy (name already carries the arch); missing build → explicit error | matches |
| 8 | publish-repo (needs build + build-client; tag or dispatch): download artifacts | present; clients via `pattern: package-client-25.12.5-*` / `-22.03.7-*` with `merge-multiple: true` into `staging/apk-pkgs` / `staging/opkg-pkgs`; luci via exact names into `staging/luci-apk` / `staging/luci-ipk` | matches |
| 9 | apk repos: copy `key-build.pub`; per-arch dirs with noarch LuCI apks + that arch's client (renamed to metadata name, arch suffix stripped); `apk mkndx --output packages.adb` + `apk adbsign` (secret `TT_APK_SIGN_KEY`) in pinned `alpine:edge@sha256:…` | present; arch list recovered from `ARCH-*` markers (no second matrix copy); client file placed as `$(basename "$f" -<arch>.apk).apk`; missing client for an arch → error; private key via `printf '%s\n' "$SIGN_KEY" > key-build.sec` mounted read-only; commands carry `--allow-untrusted` (D1); digest pinned exactly (D4) | matches + D1, D4 |
| 10 | opkg repo: one merged dir with all ipks + `opkg-key.pub`; index via `ipkg-make-index.sh` (mkhash shim over sha256sum); filter Maintainer/LicenseFiles/Source/SourceName/Require/SourceDateEpoch; usign padding workaround; `gzip -9nc Packages`; sign with `usign -S` (secret `TT_OPKG_SIGN_KEY`) in `openwrt/rootfs:x86-64-22.03.7` | present; `ipkg-make-index.sh` fetched at run time via curl from the `openwrt-22.03` branch (D9); shim = `sha256sum "$2" | cut -d" " -f1`; filter via `grep -vE '^(Maintainer|LicenseFiles|Source|SourceName|Require|SourceDateEpoch)'`; padding appends two empty lines when `(64 + stat size) % 128` ∈ {110, 111}; `usign -S -s /opkg.sec -m Packages -x Packages.sig` | matches + D9 |
| 11 | Verification apk: install `luci-app-trusttunnel` into `openwrt/rootfs:x86-64-25.12.0` from file:// repo, key installed exactly as install.sh; then `--version` | present; `mkdir -p /var/lock`; key at `/etc/apk/keys/trusttunnel.pub`; repo entry names the arch dir AND `packages.adb` explicitly (D5); `apk update` + `apk add luci-app-trusttunnel` (resolves real deps against official feeds); client checked via full path `/opt/trusttunnel_client/trusttunnel_client --version` (D5) | matches + D5 |
| 12 | Verification opkg: same on `x86-64-23.05.6` and `x86-64-24.10.8` | loop over the two images; `/etc/opkg/keys/trusttunnel.pub` + usign-fingerprint-named copy (`usign -F -p`) (D5); `src/gz trusttunnel file:///repo` in `customfeeds.conf`; `opkg update` + `opkg install luci-app-trusttunnel` + full-path `--version` | matches + D5 |
| 13 | Publish: `softprops/action-gh-release@v3` uploads all package files (single writer) | present; `if: startsWith(github.ref, 'refs/tags/')` — release assets only on tag pushes, never on dispatch (D6); files = `staging/luci-apk/*.apk`, `staging/apk-pkgs/trusttunnel-client-*.apk`, `staging/luci-ipk/*.ipk`, `staging/opkg-pkgs/*.ipk`; runs only in publish-repo → single writer | matches + D6 |
| 14 | Site: `site/apk/` + `site/opkg/` from staging; copy `repo-site/_layouts/` → `site/_layouts`; `repo-site/README.md` with `__TAG__` → ref name; index pages are MARKDOWN templates rendered by Jekyll: `apk-index.md` (`__ARCH_LIST__` substituted from `site/apk/*/`) → `site/apk/index.md`, `opkg-index.md` → `site/opkg/index.md`, per-arch `apk-arch-index.md` (`__ARCH__`/`__FILES__` from each repo dir) → `site/apk/<arch>/index.md`; the static `apk-index.html`/`opkg-index.html` are REMOVED; `jekyll-build-pages@v1`; Pages actions; `https://i-zhirov.github.io/trusttunnel-openwrt/`; nothing committed | present; site/opkg receives ONLY `*.ipk` + `Packages` + `Packages.gz` + `Packages.sig` + `opkg-key.pub` (D10); `rm -rf staging` before the template copy (D10); `cp -r repo-site/_layouts site/_layouts`; `sed -i "s/__TAG__/$GITHUB_REF_NAME/g" site/README.md` — on branch dispatch the branch name lands in the tag slot, same as inherited (D12); apk index via `sed "/__ARCH_LIST__/{r $arch_list; d}" repo-site/apk-index.md > site/apk/index.md` with the arch list generated from `site/apk/*/`; `cp repo-site/opkg-index.md site/opkg/index.md`; per-arch loop `sed -e "s/__ARCH__/$arch/g" -e "/__FILES__/{r $files; d}" repo-site/apk-arch-index.md > "$d/index.md"` with the dir's packages.adb + *.apk listing; `jekyll-build-pages@v1` source `site`; `configure-pages@v5`, `upload-pages-artifact@v3` path `_site`, `deploy-pages@v4` (D11) | matches + D10–D12 |
| 15 | publish-repo runs on tag OR dispatch | `if: startsWith(github.ref, 'refs/tags/') || github.event_name == 'workflow_dispatch'` | matches |

**Discrepancy summary (all precision notes, none contract-breaking):**

- **D1** — `apk mkndx` and `apk adbsign` run with `--allow-untrusted`
  (packages are built unsigned; only the index is signed). Issue omits the
  flag; preserve.
- **D2** — build/build-client prepare `out/` (`mkdir -p out`) and set
  `ARTIFACTS_DIR: <workspace>/out`: the artifacts dir is kept separate from
  the feed (the whole repository) so the SDK action's `bin/` move cannot
  dump foreign packages into the tree; the dir must pre-exist because the
  action `chown`s both mount paths before starting the container. Also the
  reason `FEED_DIR` must be absolute: a relative value is interpreted by
  docker as a volume NAME (empty feed → build failure). Preserve both env
  values exactly.
- **D3** — the tag assertion strips the leading `v` from the ref name
  (`${GITHUB_REF_NAME#v}`) and then expects `-r1` (apk) / `_all` (ipk)
  filename suffixes; the step is skipped on `workflow_dispatch`.
- **D4** — the pinned alpine digest is exactly
  `sha256:266f29255458134745f2bf588cb23ed1ed1768b96ff2580a05d70a8aba59e145`
  (the issue writes `sha256:…`); keep byte-identical.
- **D5** — verification container details: `mkdir -p /var/lock` first; the
  apk repository entry names `packages.adb` explicitly (a bare directory URL
  would make apk look for Alpine-style `APKINDEX.tar.gz` — the same reason
  install.sh does it); the opkg key exists under BOTH the stable name
  `trusttunnel.pub` and its `usign -F -p` fingerprint name; the client
  binary is invoked by full path `/opt/trusttunnel_client/trusttunnel_client
  --version` (not on PATH).
- **D6** — the release upload step is tag-only; a `workflow_dispatch` run
  never touches releases. Single-writer is achieved by uploading from
  publish-repo only, never from the matrix jobs.
- **D7** — both build matrices set `fail-fast: false` (one failed arch must
  not cancel the rest; every artifact is needed).
- **D8** — build-log uploads use `if-no-files-found: ignore` (logs may be
  absent on some failure modes).
- **D9** — `ipkg-make-index.sh` is downloaded at run time from
  `https://raw.githubusercontent.com/openwrt/openwrt/openwrt-22.03/scripts/ipkg-make-index.sh`;
  the mkhash shim is the two-line script `sha256sum "$2" | cut -d" " -f1`;
  the usign padding appends two empty lines to `Packages` when
  `(64 + <byte size of Packages>) % 128` is 110 or 111 (usign SHA-512 bug
  for two specific message sizes — same workaround as OpenWrt's
  `package/Makefile`).
- **D10** — site assembly copies `staging/opkg` selectively (never the
  index tooling `mkhash.sh`/`ipkg-make-index.sh`, never the manifest) and
  deletes `staging` entirely before copying the `repo-site/` templates.
  The templates are markdown: `cp -r repo-site/_layouts site/_layouts`;
  `README.md` with `sed -i "s/__TAG__/$GITHUB_REF_NAME/g"`;
  `apk-index.md` with the `__ARCH_LIST__` placeholder substituted by the
  per-arch links generated from `site/apk/*/` → `site/apk/index.md`;
  `opkg-index.md` → `site/opkg/index.md`; `apk-arch-index.md` with
  `__ARCH__`/`__FILES__` (each repo dir's packages.adb + *.apk listing) →
  `site/apk/<arch>/index.md`. The old static `apk-index.html`/
  `opkg-index.html` templates are gone — no html rename anywhere.
- **D11** — Pages action versions: `actions/configure-pages@v5`,
  `actions/upload-pages-artifact@v3` (path `_site`), `actions/deploy-pages@v4`
  (the issue names only `jekyll-build-pages@v1`).
- **D12** — `__TAG__` is substituted with `$GITHUB_REF_NAME`: on a tag push
  it is the tag, on a branch dispatch it is the branch name — same behavior
  as inherited; do not "fix" it.

### Pin inventory (must be carried over byte-identically)

**Actions (owner/name@version):**

| Action | Version | Where | Key inputs |
|---|---|---|---|
| `actions/checkout` | `@v7` | build, build-client, publish-repo | — |
| `openwrt/gh-action-sdk` | `@v7` | build, build-client | env `ARCH`, `FEEDNAME: ttowrt`, `FEED_DIR: ${{ github.workspace }}`, `ARTIFACTS_DIR: ${{ github.workspace }}/out`, `PACKAGES` |
| `actions/upload-artifact` | `@v7` | build, build-client | names `package-<version>`, `build-logs-<version>`, `package-client-<version>-<arch>`, `build-logs-client-<version>-<arch>`; logs: `if: failure()`, `if-no-files-found: ignore` |
| `actions/download-artifact` | `@v7` | publish-repo | exact names `package-25.12.5`/`package-22.03.7`; patterns `package-client-25.12.5-*`/`package-client-22.03.7-*` with `merge-multiple: true` |
| `softprops/action-gh-release` | `@v3` | publish-repo (tag only) | files: the four staging globs |
| `actions/jekyll-build-pages` | `@v1` | publish-repo | source `site` |
| `actions/configure-pages` | `@v5` | publish-repo | — |
| `actions/upload-pages-artifact` | `@v3` | publish-repo | path `_site` |
| `actions/deploy-pages` | `@v4` | publish-repo | — |

**Container images (exact tags/digests):**

| Image | Purpose |
|---|---|
| `alpine:edge@sha256:266f29255458134745f2bf588cb23ed1ed1768b96ff2580a05d70a8aba59e145` | `apk mkndx` + `apk adbsign` per arch dir |
| `openwrt/rootfs:x86-64-22.03.7` | `usign -S` over `Packages` |
| `openwrt/rootfs:x86-64-25.12.0` | apk verification install |
| `openwrt/rootfs:x86-64-23.05.6`, `openwrt/rootfs:x86-64-24.10.8` | opkg verification installs |

**Secrets (names exactly):** `TT_APK_SIGN_KEY` (written to `key-build.sec`,
mounted into the alpine container), `TT_OPKG_SIGN_KEY` (written to
`opkg.sec`, mounted into the 22.03.7 rootfs container). Public halves
`key-build.pub` / `opkg-key.pub` are committed ORIGINAL files (PRD
assumptions) — copied to the site, never rewritten.

**Artifact names:** `package-25.12.5`, `package-22.03.7`,
`package-client-25.12.5-<arch>` (×20), `package-client-22.03.7-<arch>`
(×19); failure-only `build-logs-<version>` / `build-logs-client-<version>-<arch>`.

**Matrix data (build-client; verified programmatically):** apk (25.12.5):
`x86_64, aarch64_generic, aarch64_cortex-a53, aarch64_cortex-a72,
aarch64_cortex-a76, arm_cortex-a5_vfpv4, arm_cortex-a7,
arm_cortex-a7_neon-vfpv4, arm_cortex-a7_vfpv4, arm_cortex-a8_vfpv3,
arm_cortex-a9, arm_cortex-a9_neon, arm_cortex-a9_vfpv3-d16,
arm_cortex-a15_neon-vfpv4, mips_24kc, mips_mips32, mipsel_24kc,
mipsel_24kc_24kf, mipsel_74kc, mipsel_mips32`. ipk (22.03.7): the same list
minus `aarch64_cortex-a76` (19).

### Repository/site layout contract (what the pipeline must produce)

- `apk/<arch>/` per architecture: `luci-app-trusttunnel-*.apk`,
  `luci-i18n-trusttunnel-*.apk` (the noarch pair copied into EVERY arch
  dir), `trusttunnel-client-<version>-r<release>.apk` (file name WITHOUT
  arch suffix — apk reconstructs names from metadata; the `-<arch>` suffix
  from build-client is stripped on placement), `packages.adb` +
  `packages.adb.sig` (signed index), `index.md` (the per-arch page, from
  the `apk-arch-index.md` template); `apk/key-build.pub` at the repo root.
- `opkg/`: every arch's `luci-app-trusttunnel_*.ipk`,
  `luci-i18n-trusttunnel-*.ipk`, `trusttunnel-client_*_<arch>.ipk` (merged
  feed; arch in file names keeps builds apart), `Packages`, `Packages.gz`,
  `Packages.sig` (signature over the UNCOMPRESSED `Packages`), `opkg-key.pub`,
  `index.md` (from the `opkg-index.md` template).
- Release assets (tag pushes only): the four staging globs — 2 apks + 20
  client apks (with `-<arch>` suffix), 2 ipks + 19 client ipks.
- Pages site: `apk/index.md` (`__ARCH_LIST__` → per-arch links from
  `site/apk/*/`) rendered to `apk/index.html`, per-arch
  `apk/<arch>/index.md` (`__ARCH__`/`__FILES__`) rendered to
  `apk/<arch>/index.html`, `opkg/index.md` rendered to `opkg/index.html` —
  all three via the `_layouts/repo-index.html` layout (`cp -r
  repo-site/_layouts site/_layouts`); plus `favicon.ico`, `_config.yml`,
  `README.md` rendered to `index.html` with `__TAG__` → `$GITHUB_REF_NAME`.
- Nothing is committed to any branch; the site is the workflow's direct
  output (Pages Actions deployment).

### Local validation methodology (the "TDD harness" for a workflow)

A workflow cannot run locally, so each chunk is validated by:

1. **YAML parse**: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'` — must exit 0 (Ruby 2.6 psych; no `aliases:` keyword).
2. **Actionlint**: `actionlint .github/workflows/release.yml` — exit 0, no NEW findings beyond the two inherited info-level ones (SC2086/SC2016; try to eliminate them without changing command behavior).
3. **Contract checklist**: tick every step/pin of the chunk against the job-by-job table and the pin inventory above — behavior parity, not text parity.
4. **Negative control** (once, in Task 2): deliberately break a pin (e.g., typo an action version) and confirm the tooling FAILS — proves the validation detects drift; revert.

The final equivalence oracle is the live run (Task 9); the scratch reference
copy of the inherited file (Task 1) is used only to re-check facts during the
rewrite and is deleted at the end (PRD convention: no `*.old`, no committed
old-vs-new diffs).

### Clean-room rules for the re-expression

- The new file is written fresh from the contract in this plan; not one line
  of YAML structure, not one comment, and no `run:` text is copied from the
  inherited file. Comments must be new prose explaining the same facts.
- What IS carried over byte-identically (it is the contract, not expression):
  action refs, image tags/digests, env VALUES, secret names, artifact names,
  matrix values, shell command behavior (commands may be re-expressed only
  if behavior stays identical; prefer keeping the exact command text where
  the command itself is the behavior).
- The inherited file must not be kept alongside the new one, and no
  old-vs-new diff may be committed (PRD convention); the reference copy
  lives in the OS temp dir only.
- Files NOT in scope (PRD assumptions, already original): `repo-site/*`,
  `key-build.pub`, `opkg-key.pub`, `install.sh`/`uninstall.sh` (TT-18),
  `ci.yml` (TT-19), the SDK/rootfs images, `packages/*`.

## Entities

### Built artifacts (workflow inputs/outputs)

- **Fields**: per job — `dist/` contents: `luci-app-trusttunnel-*.<ext>`,
  `luci-i18n-trusttunnel-*.<ext>` (build); `trusttunnel-client-*` + optional
  `ARCH-<arch>` markers (build-client).
- **Validation**: build asserts BOTH luci patterns exist; tag runs assert
  the exact filename `luci-app-trusttunnel-<tag-without-v>-r1.apk` /
  `luci-app-trusttunnel_<tag-without-v>_all.ipk`; build-client errors when no
  client package was built for an arch.
- **States**: built → uploaded (`package-*` artifacts) → downloaded into
  `staging/` → merged/signed/verified → uploaded as release assets and/or
  copied into `site/`.

### Published repository layout (`apk/<arch>/` + `opkg/`)

- **Fields**: as in the layout contract above; per-arch dirs keyed by
  `ARCH-<arch>` markers; opkg single merged dir.
- **Validation**: every arch dir must contain a client apk (missing build →
  hard error); the index is signed in-container; the verification steps
  install from the assembled repos with the committed keys, mirroring
  install.sh exactly.
- **States**: assembled → signed → verified (25.12 apk; 23.05.6/24.10.8
  opkg) → released + deployed to Pages.

### Pages site (`site/`)

- **Fields**: `apk/` (`index.md` with `__ARCH_LIST__` substituted, per-arch
  dirs with the repo files + each dir's `index.md` from the
  `__ARCH__`/`__FILES__` template, `key-build.pub`), `opkg/` (`*.ipk`,
  `Packages`, `Packages.gz`, `Packages.sig`, `opkg-key.pub`, `index.md`),
  `_layouts/` (the `repo-index` layout the index templates reference via
  front matter `layout: repo-index`), `favicon.ico`, `_config.yml`,
  `README.md` (with `__TAG__` already substituted).
- **Validation**: `jekyll-build-pages@v1` renders `README.md` → `index.html`
  and the three `index.md` templates → their `index.html` pages through
  `_layouts/repo-index.html`, and copies packages through byte-identically;
  `upload-pages-artifact@v3` packages `_site`; `deploy-pages@v4` publishes;
  nothing is committed.
- **States**: assembled → rendered → deployed.

## Contracts

The contract is the issue's "Contract to reproduce" section plus the
precision notes D1–D12 and the pin/layout inventories in Research (they are
binding — acceptance criterion 1 requires identical commands, pins, and
secrets). Cross-file consistency contract: the verification steps mirror
TT-18's `install.sh` (key files `trusttunnel.pub` in `/etc/apk/keys` and
`/etc/opkg/keys`, apk entry naming `packages.adb`, `src/gz trusttunnel`
feed line, fingerprint key naming) and `uninstall.sh`'s removal handles —
none of those files are touched by this issue. No API endpoints.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `.github/workflows/release.yml` | Re-create (modify in place) | Full clean-room re-expression of the TT-20 contract in seven chunks (Tasks 2–8); identical behavior, pins, digests, secrets; zero inherited expression; validated after every chunk |

No other repository file changes. `ci.yml` (TT-19), `install.sh`/
`uninstall.sh` (TT-18), `repo-site/*`, the committed public keys, and the
SDK/rootfs images are untouched.

## Tasks

### [ ] Task 1: Baseline — validation state, contract checklist, reference copy

**Files:**

- Read: `.github/workflows/release.yml` (the inherited file)
- Read: `.sdd/.current/issues/TT-20/issue.md` (contract)
- Read: `.sdd/.current/issues/TT-18/issue.md` (install.sh parity the verify steps mirror)

- [ ] **Step 1: Record the inherited file's validation baseline**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'` Expected: exit 0 (parses)
Run: `actionlint .github/workflows/release.yml` Expected: exit 0 with exactly the two known info-level findings (SC2086 in the apk assemble step, SC2016 in the opkg assemble step)
Run: `git ls-files -s .github/workflows/release.yml` Expected: mode `100644`

- [ ] **Step 2: Verify the matrix facts programmatically**

Run a ruby/python one-liner over the inherited YAML that asserts: build matrix = `25.12.5/apk` + `22.03.7/ipk`; build-client apk arch count = 20; ipk arch count = 19; ipk list == apk list minus `aarch64_cortex-a76`. Expected: all true (verified 2026-09-09; re-check before starting).

- [ ] **Step 3: Build the contract checklist**

Transcribe the job-by-job table from Research (contract items 1–15 + D1–D12) into a working checklist (scratch file in the OS temp dir, NOT in the repo). Each chunk task below ticks its rows. Also copy the pin inventory (actions, image digests, secrets, artifact names) and the layout contract into the same scratch file.

- [ ] **Step 4: Preserve the reference copy outside the repo**

Copy the inherited file to the OS temp dir (e.g. `/var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/release.yml.baseline`). It is only for fact re-checking during the rewrite; it never enters the repo and is deleted in Task 9.

**Verification**: baseline checks green and recorded; matrix facts re-verified; scratch checklist + pin inventory + reference copy exist; `git status` shows no changes beyond `.sdd/`/`docs/`.

### [ ] Task 2: Chunk 1 — workflow skeleton + build job

**Files:**

- Modify: `.github/workflows/release.yml` (top of file: name, triggers, permissions; then the `build` job with its full step sequence)

- [ ] **Step 1: Write the chunk from the contract (no YAML copied)**

Write fresh expression for: workflow name; triggers = tag pushes `v*` + `workflow_dispatch`; permissions = `contents: write`, `pages: write`, `id-token: write` (with a new comment explaining the 403 failure mode and the pages/id-token need — own words). Then the `build` job on `ubuntu-latest`, matrix `fail-fast: false` with the two rows (`25.12.5`/`apk`, `22.03.7`/`ipk`), and these steps in order:

1. checkout (`actions/checkout@v7`).
2. `mkdir -p out` (comment: artifacts dir kept separate from the whole-repo feed; must pre-exist because the SDK action chowns both mount paths before starting the container — own words).
3. SDK build via `openwrt/gh-action-sdk@v7` with env: `ARCH: x86-64-<matrix.version>`, `FEEDNAME: ttowrt`, `FEED_DIR: ${{ github.workspace }}` (absolute — comment the docker volume-name pitfall and the luci.mk findrev/.git reason in own words), `ARTIFACTS_DIR: ${{ github.workspace }}/out`, `PACKAGES: luci-app-trusttunnel`.
4. Collect: `mkdir -p dist`; copy `out/bin/` matches of `luci-app-trusttunnel*.<ext>` and `luci-i18n-trusttunnel-*.<ext>` into `dist/`; hard existence assertion on both patterns (missing package = build error).
5. Tag assertion `if: startsWith(github.ref, 'refs/tags/')`: `tag="${GITHUB_REF_NAME#v}"`; per-ext filename test `dist/luci-app-trusttunnel-${tag}-r1.apk` (apk) / `dist/luci-app-trusttunnel_${tag}_all.ipk` (ipk); on mismatch emit `::error::` and exit 1; own-words comment on why the tag is the single source of truth (the v1.0.10/v1.0.11 regression).
6. Upload `package-<version>` from `dist/*` (`actions/upload-artifact@v7`).
7. Upload `build-logs-<version>` from `out/logs/`, `if: failure()`, `if-no-files-found: ignore`.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'` Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no NEW findings (the partial file now contains only this job; the two inherited info-level findings are gone with the inherited text — good)
Expected: every action ref (`actions/checkout@v7`, `openwrt/gh-action-sdk@v7`, `actions/upload-artifact@v7`) spelled exactly as in the pin inventory.

- [ ] **Step 3: Tick the contract checklist**

Against the scratch checklist: triggers, permissions, matrix rows, env values (FEEDNAME/FEED_DIR/ARTIFACTS_DIR/PACKAGES), collect patterns, assertion pattern + skip condition, artifact names, log-upload condition — all match items 1–5, D2, D3, D7, D8.

- [ ] **Step 4: Negative control on the tooling (once)**

Temporarily change one pin in the chunk (e.g., `openwrt/gh-action-sdk@v6`); Expected: actionlint FAILS on the unknown version (or the checklist tick fails); revert the break. This proves the validation catches drift; do not repeat in later chunks.

**Verification**: YAML parses; actionlint clean (no new findings); checklist rows 1–5 green; negative control proved the tooling catches a broken pin; file remains a parseable partial workflow.

### [ ] Task 3: Chunk 2 — build-client job

**Files:**

- Modify: `.github/workflows/release.yml` (add the `build-client` job after `build`)

- [ ] **Step 1: Write the chunk from the contract**

Job on `ubuntu-latest`, matrix `fail-fast: false` with the 20 apk rows and 19 ipk rows (exact arch strings from the Research matrix data; ipk = apk minus `aarch64_cortex-a76`; own-words comment about the vendor family-binary mapping and apk's byte-exact arch matching vs opkg's merged-feed leniency). Steps in order:

1. checkout (`actions/checkout@v7`).
2. `mkdir -p out` (same reason as build).
3. SDK build via `openwrt/gh-action-sdk@v7` with env `ARCH: <matrix.arch>-<matrix.version>`, `FEEDNAME: ttowrt`, `FEED_DIR: ${{ github.workspace }}`, `ARTIFACTS_DIR: ${{ github.workspace }}/out`, `PACKAGES: trusttunnel-client`.
4. Collect: `mkdir -p dist`; if ext = apk: locate the single `trusttunnel-client*.apk` in `out/bin/` (missing → explicit error), copy as `<name>-<arch>.apk` (arch appended — otherwise the 20 artifacts overwrite each other on merge), and write `ARCH-<arch>` marker file; if ext = ipk: copy the built `trusttunnel-client*.ipk` unchanged (name already carries the arch; missing → explicit error).
5. Upload `package-client-<version>-<arch>` from `dist/*`.
6. Upload `build-logs-client-<version>-<arch>` from `out/logs/`, `if: failure()`, `if-no-files-found: ignore`.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings
Expected: 39 matrix rows total (20 + 19); action refs exactly `openwrt/gh-action-sdk@v7`, `actions/upload-artifact@v7`.

- [ ] **Step 3: Tick the contract checklist**

Matrix counts + exact arch strings, env values, apk rename pattern (`$(basename "$f" .apk)-<arch>.apk`), `ARCH-<arch>` marker content (single line = arch), ipk plain copy, artifact names — items 6, 7, D7.

**Verification**: YAML parses; actionlint clean; matrix programmatically re-countable from the NEW file (20/19, ipk = apk − aarch64_cortex-a76); checklist rows 6–7 green.

### [ ] Task 4: Chunk 3 — publish-repo skeleton, artifact downloads, apk repository half

**Files:**

- Modify: `.github/workflows/release.yml` (add `publish-repo` with `needs: [build, build-client]`, its `if:` gate, and the download + apk-assemble steps)

- [ ] **Step 1: Write the chunk from the contract**

Job gate: `if: startsWith(github.ref, 'refs/tags/') || github.event_name == 'workflow_dispatch'`; `needs: [build, build-client]`; `runs-on: ubuntu-latest`; own-words header comment about the Pages-hosted repos (why the repositories live on Pages, not in release assets: the i18n `~` version vs release-asset naming, and byte-identical file serving). Steps:

1. checkout (`actions/checkout@v7`) — provides `repo-site/`, `key-build.pub`, `opkg-key.pub`.
2. Download exact artifact `package-25.12.5` → `staging/luci-apk`; `package-22.03.7` → `staging/luci-ipk`.
3. Download pattern `package-client-25.12.5-*` → `staging/apk-pkgs` with `merge-multiple: true`; `package-client-22.03.7-*` → `staging/opkg-pkgs` with `merge-multiple: true`.
4. Assemble and index the apk repositories (env `SIGN_KEY: ${{ secrets.TT_APK_SIGN_KEY }}`), fresh expression implementing exactly: `mkdir -p staging/apk`; copy `key-build.pub` → `staging/apk/`; write the secret to `key-build.sec` (`printf '%s\n' "$SIGN_KEY" > key-build.sec`); iterate the `staging/apk-pkgs/ARCH-*` markers (no marker → error "no client artifacts for any architecture"); for each arch: create `staging/apk/<arch>`, copy both luci apks in, locate the client apk `trusttunnel-client-*-<arch>.apk` (missing → error), copy it under the metadata name (`$(basename "$f" -<arch>.apk).apk` — arch suffix stripped because apk reconstructs file names from metadata); then one `docker run --rm` with `-v "$PWD/staging/apk:/repo"` and `-v "$PWD/key-build.sec:/key-build.sec"` over the EXACT image `alpine:edge@sha256:266f29255458134745f2bf588cb23ed1ed1768b96ff2580a05d70a8aba59e145` running the per-dir loop: `(cd <dir> && apk mkndx --output packages.adb --allow-untrusted *.apk && apk adbsign --allow-untrusted --sign-key /key-build.sec packages.adb) || exit 1`; finally list the produced `packages.adb` files.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings (if the `sh -c` payload triggers SC2086 again, re-express the quoting so the lint is clean WITHOUT changing the command's behavior — e.g., quote the glob or use `sh -c` with an explicit inner shell that the linter does not flag; the inherited finding is not a license to keep it)
Expected: secret name `TT_APK_SIGN_KEY`; image digest byte-identical to the pin inventory; download patterns/names exact.

- [ ] **Step 3: Tick the contract checklist**

Gate + needs, the four download steps with exact names/patterns/merge flags, key copy, marker-driven arch loop (no second matrix copy), client rename rule, mkndx/adbsign command with `--allow-untrusted` (D1), pinned digest (D4), secret name — items 8, 9, D1, D4.

**Verification**: YAML parses; actionlint clean (SC2086 eliminated or knowingly identical); every apk-half pin matches the inventory; the chunk's behavior is a faithful re-expression of item 9 (verified by reading the new text against the checklist, not against the inherited file).

### [ ] Task 5: Chunk 4 — publish-repo opkg repository half

**Files:**

- Modify: `.github/workflows/release.yml` (add the opkg assemble+sign step after the apk step)

- [ ] **Step 1: Write the chunk from the contract**

One step, env `SIGN_KEY: ${{ secrets.TT_OPKG_SIGN_KEY }}`, fresh expression implementing exactly: `mkdir -p staging/opkg`; copy `staging/luci-ipk/*.ipk` and `staging/opkg-pkgs/*.ipk` into it; copy `opkg-key.pub` into it (merged feed — opkg ignores foreign-arch packages and picks the matching build; own-words comment); fetch the canonical index script at run time: `curl -fsSL -o ipkg-make-index.sh https://raw.githubusercontent.com/openwrt/openwrt/openwrt-22.03/scripts/ipkg-make-index.sh`; write the mkhash shim `printf '#!/bin/sh\nsha256sum "$2" | cut -d" " -f1\n' > mkhash.sh` + `chmod +x`; run the indexer from `staging/opkg` with `MKHASH=<workspace>/mkhash.sh` (relative `$PWD/../../mkhash.sh` from the staging dir is the inherited mechanism — the path must resolve to the workspace root; re-express with an equivalent absolute path if cleaner, keeping the indexed output byte-identical): `bash <index-script> . > Packages.manifest`; filter the manifest with `grep -vE '^(Maintainer|LicenseFiles|Source|SourceName|Require|SourceDateEpoch)'` into `Packages`; remove the manifest; apply the usign padding workaround: when `(64 + <byte size of Packages>) % 128` ∈ {110, 111}, append two empty lines to `Packages`; `gzip -9nc Packages > Packages.gz`; write the secret to `opkg.sec`; one `docker run --rm` with `-v "$PWD/staging/opkg:/repo"` and `-v "$PWD/opkg.sec:/opkg.sec"` over `openwrt/rootfs:x86-64-22.03.7` running `cd /repo && usign -S -s /opkg.sec -m Packages -x Packages.sig` (sign the UNCOMPRESSED Packages — opkg zcats the list before verifying; own-words comment); list the resulting `staging/opkg/`.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings (re-express the `sh -c` quoting so SC2016 does not reappear, without changing the signed content)
Expected: secret name `TT_OPKG_SIGN_KEY`; rootfs image tag exact.

- [ ] **Step 3: Tick the contract checklist**

Merged-dir contents, curl URL (openwrt-22.03 branch), mkhash shim text, filter field list, padding condition + payload (two empty lines), `gzip -9nc`, usign sign target (`Packages`, not `.gz`), container image, secret name — item 10, D9.

**Verification**: YAML parses; actionlint clean (SC2016 eliminated or knowingly identical); opkg-half pins match the inventory; the chunk is a faithful re-expression of item 10.

### [ ] Task 6: Chunk 5 — publish-repo verification steps

**Files:**

- Modify: `.github/workflows/release.yml` (add the two verification steps after the opkg step)

- [ ] **Step 1: Write the chunk from the contract**

Step "Verify the apk installs on 25.12": one `docker run --rm` with read-only mount `-v "$PWD/staging/apk:/repo:ro"` over `openwrt/rootfs:x86-64-25.12.0`; inside: `mkdir -p /var/lock /etc/apk/keys /etc/apk/repositories.d`; copy `/repo/key-build.pub` → `/etc/apk/keys/trusttunnel.pub` (exactly install.sh's arrangement); write the repository entry `file:///repo/x86_64/packages.adb` into `/etc/apk/repositories.d/trusttunnel.list` (index file named explicitly — own-words comment); `apk update`; `apk add luci-app-trusttunnel` (resolves the real dependency set against the version's official feeds); run `/opt/trusttunnel_client/trusttunnel_client --version` (full path — not on PATH; proves the right statically-linked binary landed).

Step "Verify the ipk installs on 23.05/24.10": loop `for img in x86-64-23.05.6 x86-64-24.10.8`; per image one `docker run --rm` with read-only mount `-v "$PWD/staging/opkg:/repo:ro"` over `openwrt/rootfs:<img>`; inside: `mkdir -p /var/lock /etc/opkg/keys`; copy `/repo/opkg-key.pub` → `/etc/opkg/keys/trusttunnel.pub`; compute the fingerprint (`usign -F -p`) and copy the key to `/etc/opkg/keys/<fingerprint>` (BOTH files — the same arrangement install.sh sets up); write `src/gz trusttunnel file:///repo` into `/etc/opkg/customfeeds.conf` (URL must NOT name the index — opkg appends `/Packages.gz` and verifies `Packages.sig` against the key; own-words comment); `opkg update`; `opkg install luci-app-trusttunnel`; full-path `--version`. Own-words comments on why the 22.03-built ipk is verified on the NEWER rootfs versions (dependencies are unversioned; building again on those SDKs would prove nothing about the artifact).

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings
Expected: the three image tags exact (`x86-64-25.12.0`, `x86-64-23.05.6`, `x86-64-24.10.8`); read-only mounts; no secrets used in these steps.

- [ ] **Step 3: Tick the contract checklist**

Key placement matching install.sh (stable name + fingerprint copy for opkg), explicit `packages.adb` entry, `src/gz trusttunnel` line shape, `/var/lock`, full-path `--version`, image list — items 11, 12, D5.

**Verification**: YAML parses; actionlint clean; verification steps re-express items 11–12 with every detail of D5; the steps still mirror the TT-18 contract (cross-read `.sdd/.current/issues/TT-18/issue.md` repository-setup items to confirm the arrangement textually agrees).

### [ ] Task 7: Chunk 6 — release upload step

**Files:**

- Modify: `.github/workflows/release.yml` (add the release-assets step between the verification steps and the site step)

- [ ] **Step 1: Write the chunk from the contract**

One step `if: startsWith(github.ref, 'refs/tags/')` using `softprops/action-gh-release@v3` with files = the four staging globs exactly: `staging/luci-apk/*.apk`, `staging/apk-pkgs/trusttunnel-client-*.apk` (arch-suffixed client apks), `staging/luci-ipk/*.ipk`, `staging/opkg-pkgs/*.ipk`. Own-words comment: uploading from publish-repo (rather than from each matrix job) makes the release a single writer; tag-only so dispatch runs never touch releases.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings
Expected: action ref `softprops/action-gh-release@v3`; the four globs byte-identical to the pin inventory.

- [ ] **Step 3: Tick the contract checklist**

Tag-only condition, single-writer placement, exact file set — item 13, D6.

**Verification**: YAML parses; actionlint clean; release-upload step re-expresses item 13 (4 file groups, tag-only, inside publish-repo only).

### [ ] Task 8: Chunk 7 — site assembly + Pages deploy

**Files:**

- Modify: `.github/workflows/release.yml` (add the final five steps: site assemble, Jekyll build, Pages configure, Pages upload, Pages deploy)

- [ ] **Step 1: Write the chunk from the contract**

Assemble step: `mkdir -p site/apk site/opkg`; `cp -r staging/apk/. site/apk/` (per-arch dirs + `key-build.pub` + signed indexes); copy ONLY `staging/opkg/*.ipk`, `Packages`, `Packages.gz`, `Packages.sig`, `opkg-key.pub` into `site/opkg/` (never the index tooling or the manifest); `rm -rf staging`; then copy the repo-site templates in the ACTUAL order and destinations:

1. `cp repo-site/favicon.ico site/favicon.ico` and `cp repo-site/_config.yml site/_config.yml` (own-words comments: the favicon keeps the browsers' auto-request from 404ing; the config points the theme's "Improve this page" link at the real homepage template).
2. `cp -r repo-site/_layouts site/_layouts` — the layout all three index templates reference via front matter `layout: repo-index` (the theme's default minus the "Improve this page" footer).
3. `cp repo-site/README.md site/README.md`, then `sed -i "s/__TAG__/$GITHUB_REF_NAME/g" site/README.md` (on branch dispatch the branch name lands in the slot — same as inherited; do not change).
4. The apk index from the `__ARCH_LIST__` template: `arch_list=$(mktemp)`; loop `for d in site/apk/*/` writing one `- [<arch>](<arch>/)` line per assembled dir (no second copy of the build-client matrix to keep in sync); then `sed "/__ARCH_LIST__/{r $arch_list; d}" repo-site/apk-index.md > site/apk/index.md`; `rm -f "$arch_list"`.
5. `cp repo-site/opkg-index.md site/opkg/index.md` — a fully static opkg index template.
6. Per-arch apk indexes from the `__ARCH__`/`__FILES__` template: `files=$(mktemp)`; loop `for d in site/apk/*/`; per dir write the file list from the dir's actual contents (a `packages.adb` line when present + one line per `*.apk`), then `sed -e "s/__ARCH__/$arch/g" -e "/__FILES__/{r $files; d}" repo-site/apk-arch-index.md > "$d/index.md"`; `rm -f "$files"`.

Own-words comments for the index pages: directory indexes for humans — Pages serves no listings, so the bare `apk/`, `apk/<arch>/`, `opkg/` URLs would 404 in a browser; the package managers never fetch the bare URLs (apk fetches `<url>/apk/<arch>/packages.adb`, opkg appends `/Packages.gz`). There is NO `apk-index.html`/`opkg-index.html` anywhere — those static templates were removed from repo-site on main; do not reproduce the html renames.

Then: `actions/jekyll-build-pages@v1` with source `site` (renders `README.md` → `index.html` and the three `index.md` templates → their `index.html` pages via `_layouts/repo-index.html`, and copies the package files through byte-identically); `actions/configure-pages@v5`; `actions/upload-pages-artifact@v3` with path `_site`; `actions/deploy-pages@v4`. Own-words comment that nothing is committed to any branch and the site is the workflow's direct output at `https://i-zhirov.github.io/trusttunnel-openwrt/`.

- [ ] **Step 2: Validate YAML syntax and action references**

Run: ruby YAML parse Expected: exit 0
Run: `actionlint .github/workflows/release.yml` Expected: exit 0, no findings
Expected: the four Pages action refs exactly `@v1`/`@v5`/`@v3`/`@v4`; inputs `source: site` and `path: _site`; `repo-site/` template names and their destinations (`_layouts/` → `site/_layouts`, `apk-index.md` → `site/apk/index.md`, `opkg-index.md` → `site/opkg/index.md`, `apk-arch-index.md` → `site/apk/<arch>/index.md`, `favicon.ico`, `_config.yml`, `README.md`) exact; no `apk-index.html`/`opkg-index.html` reference anywhere in the chunk.

- [ ] **Step 3: Tick the contract checklist**

Selective opkg copy, `rm -rf staging`, `cp -r repo-site/_layouts site/_layouts`, the three markdown index templates with their placeholders and destinations (`apk-index.md`/`__ARCH_LIST__` → `site/apk/index.md`, `opkg-index.md` → `site/opkg/index.md`, `apk-arch-index.md`/`__ARCH__`+`__FILES__` → `site/apk/<arch>/index.md`), `__TAG__` substitution target and variable, Jekyll source, Pages action versions, upload path — items 14, 15, D10–D12. Confirm `repo-site/` holds the 7-entry set (verified 2026-09-09): `apk-index.md`, `apk-arch-index.md`, `opkg-index.md`, `README.md` (still contains the `__TAG__` placeholder, line 19), `_config.yml`, `favicon.ico`, `_layouts/repo-index.html` — and NO `apk-index.html`/`opkg-index.html`.

- [ ] **Step 4: Full-file re-validation**

Run: ruby YAML parse + `actionlint .github/workflows/release.yml` over the COMPLETE new file Expected: exit 0 both, no findings beyond (ideally none at all — the two inherited info-level findings must not silently reappear)
Run: re-run the matrix-count verification against the NEW file Expected: 20/19, ipk = apk − `aarch64_cortex-a76`
Walk the ENTIRE scratch checklist (items 1–15 + D1–D12 + pin inventory) one final time against the new file; any missing row blocks Task 9.
Run: `git diff --stat .github/workflows/release.yml` and read the diff — Expected: no inherited comment/expression remnants (spot-check: the new text must not contain phrases from the inherited comments; comments are the implementer's own prose).

**Verification**: complete file parses and lints clean; matrix counts re-verified on the new file; full checklist green; diff shows a full re-expression with zero copied YAML/comments.

### [ ] Task 9: Final verification — workflow_dispatch release from a test tag + live install

**Files:**

- Test: `.github/workflows/release.yml` (live run)
- Test: `install.sh` (TT-18 artifact, unchanged — used as the installer oracle)

- [ ] **Step 1: Pre-flight**

Run: `git status --porcelain` Expected: only the workflow modified (+ `.sdd/`/`docs/`); push the new workflow to the repo (tag push will not trigger yet — the tag comes next). Confirm `key-build.pub`/`opkg-key.pub` are in the tree and `repo-site/` intact (the publish job consumes them from checkout).

- [ ] **Step 2: Create and dispatch the test tag**

Create tag `v<X>.<Y>.<Z>-rc` (e.g. `v1.0.14-rc`) on the current HEAD and push it. Dispatch the workflow FROM THE TAG REF (exercises the tag assertion AND the release upload, which are `refs/tags/`-gated): `gh workflow run release.yml --ref v<X>.<Y>.<Z>-rc`. Monitor with `gh run watch`. Document in the issue/PR: a branch-ref dispatch would skip the tag assertion and the release assets — the tag-ref dispatch is the full-pipeline path.

- [ ] **Step 3: Verify the run job by job (documented checklist)**

- `build` (×2): green; both artifacts present (`luci-app-trusttunnel-<X.Y.Z-rc>-r1.apk` + `luci-i18n-trusttunnel-<gitrev>.apk`; `luci-app-trusttunnel_<X.Y.Z-rc>_all.ipk` + i18n ipk); tag assertion step passed (it runs because the dispatch ref is the tag).
- `build-client` (×39): green; per-arch artifacts + `ARCH-*` markers present.
- `publish-repo`: apk step produced `packages.adb` + `packages.adb.sig` in all 20 arch dirs with `key-build.pub` at `staging/apk/`; opkg step produced `Packages`/`Packages.gz`/`Packages.sig` + `opkg-key.pub` (verify: `Packages.sig` is valid for the UNCOMPRESSED `Packages` — e.g. `usign -V -p opkg-key.pub -m Packages -x Packages.sig` on a local copy of the published files).
- Verification steps: "Verify the apk installs on 25.12" green; "Verify the ipk installs on 23.05/24.10" green — these ARE the acceptance-criteria install checks.
- Release upload: a GitHub release exists for the test tag with the 4 file groups (2 luci apks, 20 client apks with `-<arch>`, 2 luci ipks, 19 client ipks); `~`-bearing i18n names intact (release assets replace `~` with `.` — the reason the repos live on Pages; the release's i18n names may show the substitution, that is inherited behavior).
- Site/deploy: Pages deployment succeeded; site serves `apk/<arch>/packages.adb` for all 20 archs, `apk/key-build.pub`, `opkg/Packages.gz` + `Packages.sig` + `opkg-key.pub`, `favicon.ico`, and a rendered homepage where `__TAG__` was substituted by the tag name. Index pages and layout: `apk/index.html` lists all 20 archs (the `__ARCH_LIST__` substitution); every `apk/<arch>/index.html` shows the arch name and the files actually served there (`packages.adb` + the apks — the `__ARCH__`/`__FILES__` substitution); `opkg/index.html` renders; spot-check one index page's markup for the `repo-index` layout from `_layouts/` (a missing per-arch index or a missing/broken layout fails this step).
- No commits to any branch: `git status` clean after the run; Pages deployments show "from GitHub Actions", not a branch.

- [ ] **Step 4: Live install from the published Pages repo with install.sh**

For each image `openwrt/rootfs:x86-64-25.12.0` (apk) and `x86-64-22.03.7`, `x86-64-23.05.6`, `x86-64-24.10.8` (opkg): run the TT-18 `install.sh` in a fresh container (default `TT_REPO_URL` = the live Pages repo), then assert: `luci-app-trusttunnel` + `trusttunnel-client` installed; `/opt/trusttunnel_client/trusttunnel_client --version` runs; repo entry + both key files present as the TT-18 contract specifies; service installed but NOT started on first install. This is the issue's acceptance criterion 2 end-to-end.

- [ ] **Step 5: Cleanup and tree-cleanliness**

Decide and document the Pages site state after the test run (the site now serves the `-rc` packages): either accept until the next real release or re-run a dispatch on the last real tag to restore it — document the choice in the issue. Delete the scratch reference copy of the inherited file from the OS temp dir (PRD convention). Run: `git status --porcelain` Expected: only the workflow modified; no `*.old`, no backup, no old-vs-new diff committed. If the test tag should not remain, delete it (`git tag -d` + push delete) and document.

**Verification**: full pipeline green from a tag-ref dispatch; published `apk/<arch>/packages.adb` + `opkg/Packages.gz` + signatures verified; verification jobs green; install.sh installs from the live Pages repo on all four rootfs images; release assets present; site serves the substituted tag; no branch commits; scratch copy deleted.

## Risks and Notes

- **The verification jobs cannot run locally** — their correctness rests on the chunk-by-chunk contract checklist and the live Task 9 run; a wrong pin (image tag, digest, secret name) only surfaces in a real run. The negative control in Task 2 plus the pin inventory mitigate this.
- **The live run mutates shared state** (release + Pages site): always use a `-rc` tag, never the last real version; document the site-restore decision (Task 9 Step 5).
- **Intermediate states of the file are partial workflows** — never push between Task 2 and Task 8 (or push only at Task 8 completion); local validation is the only gate during the rewrite.
- **SC2086/SC2016 findings**: the inherited file carries two info-level findings inside `run:` bodies. Re-express the quoting so the new file lints clean WITHOUT changing command behavior; if a finding must be kept, document why (behavior wins over lint cosmetics).
- **Out of scope (PRD)**: bug fixes, behavior changes, the two public keys, `repo-site/*`, `install.sh`/`uninstall.sh`, `ci.yml`, and anything outside `.github/workflows/release.yml`.

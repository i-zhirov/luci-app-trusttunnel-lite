# Issue TT-20: release.yml workflow

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: TT-14 (package build), TT-18 (installer parity),
  TT-19 (CI conventions)
- **Effort**: M
- **Files**: `.github/workflows/release.yml`

## Context

`release.yml` was inherited (the release-flow skeleton is inherited
expression; the apk/opkg repository signing, verification rootfs installs,
Pages site assembly and single-writer publishing are fork work). It
produces and publishes the package repositories the installer consumes.

## Contract to reproduce

- Triggers: tags `v*` + `workflow_dispatch`; permissions
  contents+pages+id-token.
- **build job** (matrix: OpenWrt 25.12.5 → .apk, 22.03.7 → .ipk; x86-64
  SDK; package is noarch): `openwrt/gh-action-sdk@v7` with
  `FEEDNAME=ttowrt`, `FEED_DIR=${{github.workspace}}` (absolute — .git
  must be inside for luci.mk findrev), `PACKAGES=luci-app-trusttunnel`;
  collect `luci-app-trusttunnel*` and `luci-i18n-trusttunnel-*`;
  assert the built filename matches the tag
  (`luci-app-trusttunnel-<tag>-r1.apk` / `luci-app-trusttunnel_<tag>_all.ipk`);
  upload artifacts (+ build logs on failure).
- **build-client job**: matrix of 20 apk archs (25.12.5) and 19 ipk archs
  (22.03.7, no aarch64_cortex-a76); build `trusttunnel-client` per arch;
  rename apk files to append `-<arch>` and write `ARCH-<arch>` markers.
- **publish-repo job** (needs build + build-client; tag or
  workflow_dispatch): download artifacts;
  - apk repos: copy `key-build.pub`; per-arch dirs containing the noarch
    LuCI apks + that arch's client apk (renamed to the metadata name,
    arch suffix stripped); `apk mkndx --output packages.adb` +
    `apk adbsign` (secret `TT_APK_SIGN_KEY`) inside pinned
    `alpine:edge@sha256:…` container;
  - opkg repo: one merged dir with all ipks + `opkg-key.pub`; index via
    OpenWrt's `ipkg-make-index.sh` (mkhash shim over sha256sum), filter
    Maintainer/LicenseFiles/Source/SourceName/Require/SourceDateEpoch
    fields, usign padding workaround, `gzip -9nc Packages`, sign with
    `usign -S` (secret `TT_OPKG_SIGN_KEY`) in
    `openwrt/rootfs:x86-64-22.03.7`.
- **Verification**: apk — install `luci-app-trusttunnel` into
  `openwrt/rootfs:x86-64-25.12.0` from the file:// repo with the key
  installed exactly as install.sh does, then run
  `/opt/trusttunnel_client/trusttunnel_client --version`; opkg — same on
  `x86-64-23.05.6` and `x86-64-24.10.8`.
- **Publish**: `softprops/action-gh-release@v3` uploads all package files
  (single writer).
- **Site assembly** (changed on main 2026-09-09): `site/apk/` +
  `site/opkg/` from staging; copy `favicon.ico`, `_config.yml`, and now
  `repo-site/_layouts/` → `site/_layouts` (the theme's layout minus the
  "Improve this page" footer); `repo-site/README.md` with `__TAG__` → the
  ref name; index pages are now MARKDOWN templates rendered by Jekyll:
  `repo-site/apk-index.md` (with the `__ARCH_LIST__` placeholder
  substituted from the assembled `site/apk/*/` directories) →
  `site/apk/index.md`, `repo-site/opkg-index.md` → `site/opkg/index.md`,
  and a per-arch template `repo-site/apk-arch-index.md` (with
  `__ARCH__`/`__FILES__` substituted from each repository dir — the
  packages.adb + *.apk listing) → `site/apk/<arch>/index.md`. The old
  static `apk-index.html`/`opkg-index.html` templates are REMOVED from
  repo-site. Then `jekyll-build-pages@v1` renders;
  `configure-pages`/`upload-pages-artifact`/`deploy-pages` to GitHub
  Pages (`https://i-zhirov.github.io/trusttunnel-openwrt/`). Nothing is
  committed to any branch.

## Acceptance criteria

- [ ] All jobs/steps above present with identical behavior (same commands,
      pinned versions/digests, secrets).
- [ ] A workflow_dispatch release from the current tree produces repos
      that install cleanly on the verification rootfs images.

## How to verify

1. Run `workflow_dispatch` on a test tag; check the published
   `apk/<arch>/packages.adb` + `opkg/Packages.gz` + signatures; run the
   verification jobs.
2. Install from the published Pages repo with the current install.sh.

## Notes

- Re-express from the workflow spec; keep the pinned digests/versions and
  secret names exactly.

# Issue Validation Report: release.yml workflow (TT-20)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-20/issue.md`
- **Plan**: `.sdd/.current/issues/TT-20/plan.md`
- **Overall Status**: Incomplete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 8 | 1 | 0 | 9 |
| Acceptance Criteria | 1 | 0 | 1 | 2 |
| Entities | 3 | 0 | 0 | 3 |
| Contracts | 8 | 0 | 0 | 8 |
| Guidelines | 1 | 0 | 0 | 1 |

The implementation (Tasks 1–8) is complete and statically verified: the
workflow re-expresses the full contract with byte-identical pins, the matrix
data, all precision details D1–D12, and clean tooling (YAML parse OK,
actionlint exit 0 with zero findings — the two inherited info-level
SC2086/SC2016 findings were eliminated, not reproduced; shellcheck v0.11.0 on
the substituted run bodies: no real findings). The overall status is
**Incomplete** solely because Task 9's live gate — a `workflow_dispatch` run
from a test tag plus the install.sh installs from the published Pages repo
(acceptance criterion 2) — is a documented pending item that cannot execute
in this environment (no GitHub access; plan Task 9 note, 2026-09-09). Per
instructions, issue/plan statuses were not touched.

**Closing runbook**: `live-run-checklist.md` in the issue directory — the
exact dispatch commands (test tag `v1.0.16-rc`, tag-ref dispatch), the
job-by-job assertions, the live `install.sh` checks A1–A5 on the four
rootfs images, the site-state decision, and the closing steps (plan
checkboxes, this report's flip to Complete, statuses).

## Task Status

- [x] **Task 1**: Baseline — validation state, contract checklist, reference copy - PASS
  - Baseline re-verified against the current tree: file parses, matrix facts
    hold (build = 25.12.5/apk + 22.03.7/ipk; build-client = 20 apk / 19 ipk
    archs; ipk == apk − `aarch64_cortex-a76`), working tree clean, no
    `*.old`/backup files tracked, scratch reference copy deleted from the
    temp dir (Task 9 Step 5 evidence).
- [x] **Task 2**: Chunk 1 — workflow skeleton + build job - PASS
  - Triggers `push.tags: ["v*"]` + `workflow_dispatch`; permissions
    `contents: write` / `pages: write` / `id-token: write` (with own-words
    comment on the 403/Pages-OIDC rationale); matrix rows `25.12.5`/`apk` and
    `22.03.7`/`ipk`, `fail-fast: false`; `mkdir -p out` before the SDK step;
    `openwrt/gh-action-sdk@v7` with `ARCH: x86-64-<version>`,
    `FEEDNAME: ttowrt`, absolute `FEED_DIR: ${{ github.workspace }}`
    (docker volume-name pitfall + luci.mk findrev/.git commented),
    `ARTIFACTS_DIR: ${{ github.workspace }}/out`, `PACKAGES: luci-app-trusttunnel`;
    collect via `find out/bin/` for both `luci-app-trusttunnel*` and
    `luci-i18n-trusttunnel-*` patterns with hard existence assertions;
    tag assertion `${GITHUB_REF_NAME#v}` with `-r1.apk` / `_all.ipk` expected
    names, `::error::` + exit 1 on mismatch, skipped on dispatch
    (`if: startsWith(github.ref, 'refs/tags/')`); `package-<version>` upload;
    `build-logs-<version>` with `if: failure()` + `if-no-files-found: ignore`.
- [x] **Task 3**: Chunk 2 — build-client job - PASS
  - 20 apk rows (25.12.5) + 19 ipk rows (22.03.7, no `aarch64_cortex-a76`),
    no duplicate arch rows, `fail-fast: false`; SDK env
    `ARCH: <arch>-<version>` + same feed/artifacts envs, `PACKAGES: trusttunnel-client`;
    apk: missing-build error, rename `<name>-<arch>.apk`, `ARCH-<arch>`
    marker (`printf '%s\n'`); ipk: plain copy with missing-build error;
    `package-client-<version>-<arch>` upload; failure-only log upload.
- [x] **Task 4**: Chunk 3 — publish-repo skeleton, artifact downloads, apk repository half - PASS
  - Gate `startsWith(github.ref, 'refs/tags/') || github.event_name == 'workflow_dispatch'`;
    `needs: [build, build-client]`; exact downloads `package-25.12.5` /
    `package-22.03.7` and pattern downloads `package-client-25.12.5-*` /
    `package-client-22.03.7-*` with `merge-multiple: true`; `key-build.pub`
    copy; arch discovery from `ARCH-*` markers only (no second matrix copy),
    marker-missing and client-missing hard errors; client placed as
    `$(basename "$client" "-${arch}.apk").apk` (arch suffix stripped);
    `apk mkndx --output packages.adb --allow-untrusted *.apk` +
    `apk adbsign --allow-untrusted --sign-key /key-build.sec packages.adb`
    per arch dir inside `alpine:edge@sha256:266f29255458134745f2bf588cb23ed1ed1768b96ff2580a05d70a8aba59e145`
    (digest byte-identical to D4); secret `TT_APK_SIGN_KEY` written to
    `key-build.sec` via `printf '%s\n'`; `--allow-untrusted` preserved (D1).
- [x] **Task 5**: Chunk 4 — publish-repo opkg repository half - PASS
  - Merged `staging/opkg` with luci ipks + client ipks + `opkg-key.pub`;
    `curl -fsSL` fetch of `ipkg-make-index.sh` from the
    `openwrt-22.03` branch; mkhash shim `sha256sum "$2" | cut -d" " -f1`
    (heredoc form of the D9 two-line script, behavior identical); manifest
    field filter `^(Maintainer|LicenseFiles|Source|SourceName|Require|SourceDateEpoch)`;
    usign padding `(64 + size) % 128 ∈ {110, 111}` → two empty lines appended;
    `gzip -9nc Packages > Packages.gz`; `usign -S -s /opkg.sec -m Packages
    -x Packages.sig` on the UNCOMPRESSED `Packages` inside
    `openwrt/rootfs:x86-64-22.03.7`; secret `TT_OPKG_SIGN_KEY`.
- [x] **Task 6**: Chunk 5 — publish-repo verification steps - PASS
  - apk (25.12.0): `mkdir -p /var/lock /etc/apk/keys /etc/apk/repositories.d`;
    key → `/etc/apk/keys/trusttunnel.pub` (install.sh arrangement);
    entry `file:///repo/x86_64/packages.adb` (index named explicitly, D5);
    `apk update` + `apk add luci-app-trusttunnel`; full-path
    `/opt/trusttunnel_client/trusttunnel_client --version`.
  - opkg (loop `x86-64-23.05.6`, `x86-64-24.10.8`): key → both
    `/etc/opkg/keys/trusttunnel.pub` and the `usign -F -p` fingerprint copy;
    `src/gz trusttunnel file:///repo` (URL without the index, D5);
    `opkg update` + `opkg install luci-app-trusttunnel`; full-path `--version`.
  - Cross-read against `.sdd/.current/issues/TT-18/issue.md` confirms the
    key names, `packages.adb` entry shape, `src/gz trusttunnel` line and
    fingerprint naming match install.sh exactly. Read-only mounts (`:ro`),
    no secrets in these steps.
- [x] **Task 7**: Chunk 6 — release upload step - PASS
  - `softprops/action-gh-release@v3`, `if: startsWith(github.ref, 'refs/tags/')`
    (dispatch runs never touch releases, D6); files = the four staging globs
    exactly: `staging/luci-apk/*.apk`, `staging/apk-pkgs/trusttunnel-client-*.apk`,
    `staging/luci-ipk/*.ipk`, `staging/opkg-pkgs/*.ipk`; single writer —
    upload happens only in publish-repo, never in the matrix jobs.
- [x] **Task 8**: Chunk 7 — site assembly + Pages deploy - PASS
  - `site/apk` + selective `site/opkg` copy (ipks, `Packages`,
    `Packages.gz`, `Packages.sig`, `opkg-key.pub` — never index tooling/manifest);
    `rm -rf staging` before the template copy (D10); `favicon.ico` +
    `_config.yml`; `cp -r repo-site/_layouts site/_layouts`; `README.md` +
    `sed -i "s/__TAG__/$GITHUB_REF_NAME/g"` (D12); `apk-index.md` via
    `sed "/__ARCH_LIST__/{r $arch_list; d}"` with the arch list generated
    from `site/apk/*/`; `opkg-index.md` plain copy; per-arch `apk-arch-index.md`
    via `sed -e "s/__ARCH__/$arch/g" -e "/__FILES__/{r $files; d}"` with
    each dir's `packages.adb` + `*.apk` listing; `jekyll-build-pages@v1`
    (source `site`), `configure-pages@v5`, `upload-pages-artifact@v3`
    (path `_site`), `deploy-pages@v4`; no `apk-index.html`/`opkg-index.html`
    anywhere (repo-site holds exactly the 7-entry markdown set); nothing
    committed. `repo-site/` verified to contain `apk-index.md`,
    `apk-arch-index.md`, `opkg-index.md`, `README.md` (with `__TAG__` at
    line 19), `_config.yml`, `favicon.ico`, `_layouts/repo-index.html` and
    no static html index templates; all templates carry the expected
    placeholders (`__ARCH_LIST__`, `__ARCH__`, `__FILES__`) and
    `layout: repo-index` front matter.
- [ ] **Task 9**: Final verification — workflow_dispatch release from a test tag + live install - PARTIAL
  - Completed: Step 1's local tree checks (clean tree, keys present,
    `repo-site/` intact) and Step 5's scratch-reference-copy deletion — the
    plan's deferral note documents this. Not executed: Steps 2–4 (create and
    dispatch test tag `vX.Y.Z-rc` from the tag ref, job-by-job verification
    of the live run, install.sh install from the live Pages repo on the four
    rootfs images). Cannot be run here: no GitHub access. Documented pending
    item, to be run from a real checkout before closing the issue.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All jobs/steps above present with identical behavior (same commands, pinned versions/digests, secrets) | MET | Static verification of `.github/workflows/release.yml` (597 lines) against the issue contract + plan D1–D12: all commands, action refs (`checkout@v7`, `gh-action-sdk@v7`, `upload/download-artifact@v7`, `softprops/action-gh-release@v3`, `jekyll-build-pages@v1`, `configure-pages@v5`, `upload-pages-artifact@v3`, `deploy-pages@v4`), the alpine digest `sha256:266f29255458134745f2bf588cb23ed1ed1768b96ff2580a05d70a8aba59e145`, rootfs images (`x86-64-22.03.7`, `x86-64-25.12.0`, `x86-64-23.05.6`, `x86-64-24.10.8`), secrets (`TT_APK_SIGN_KEY`, `TT_OPKG_SIGN_KEY`), artifact names and matrix values are byte-identical to the pin inventory; `ruby` YAML parse OK; actionlint exit 0, zero findings; shellcheck v0.11.0 on the run bodies (GH expressions substituted) shows no real shell findings; matrix re-count 20/19 with ipk = apk − `aarch64_cortex-a76`. |
| 2 | A workflow_dispatch release from the current tree produces repos that install cleanly on the verification rootfs images | NOT MET | Pending: requires the Task 9 live run (test tag `vX.Y.Z-rc` dispatched from the tag ref) on a real checkout with GitHub access. The verification steps themselves are implemented and mirror install.sh, but no live evidence exists yet. Documented deferral in plan Task 9 note (2026-09-09). |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Built artifacts (`dist/`, `ARCH-*` markers, artifacts) | OK — collect patterns, apk rename with `-<arch>` suffix, `ARCH-<arch>` markers, ipk plain copy | OK — artifact names `package-*` / `package-client-<version>-<arch>` match the download patterns in publish-repo | OK — hard existence assertions in build/build-client; tag filename assertion; missing-client errors | PASS |
| Published repository layout (`apk/<arch>/` + `opkg/`) | OK — per-arch dirs from `ARCH-*` markers, noarch luci pair in every dir, client renamed to metadata name, `packages.adb`(+`.sig`), `Packages`/`Packages.gz`/`Packages.sig`, `key-build.pub`/`opkg-key.pub` | OK — release asset globs and site copies consume exactly these dirs | OK — signing in pinned containers; in-workflow verification installs (static). Live signed output depends on Task 9 | PASS |
| Pages site (`site/`) | OK — `apk/` (index.md + per-arch index.md + repos), `opkg/` (feed + index.md), `_layouts/`, `favicon.ico`, `_config.yml`, `README.md` with `__TAG__` substituted | OK — Jekyll source `site`, upload path `_site`, `deploy-pages@v4` | OK — jekyll-build-pages renders the three `index.md` templates through `_layouts/repo-index.html`; nothing committed | PASS |

## Contract Status

The contract is the issue's "Contract to reproduce" plus plan precision notes D1–D12 (binding per acceptance criterion 1). Every item verified by reading the workflow against the checklist.

| Contract item | Status | Notes |
| --- | --- | --- |
| Triggers tags `v*` + `workflow_dispatch`; permissions contents+pages+id-token | PASS | `on.push.tags: ["v*"]` + `workflow_dispatch`; `contents: write`, `pages: write`, `id-token: write` |
| build job: 25.12.5/apk + 22.03.7/ipk, x86-64 SDK, FEEDNAME=ttowrt, absolute FEED_DIR, PACKAGES=luci-app-trusttunnel; collect both luci patterns; tag assertion; artifacts + failure logs | PASS | All present incl. D2 (mkdir -p out, ARTIFACTS_DIR), D3 (`${GITHUB_REF_NAME#v}`, `-r1`/`_all`), D7 (fail-fast false), D8 (`if-no-files-found: ignore`) |
| build-client: 20 apk / 19 ipk archs (no aarch64_cortex-a76); `-<arch>` rename + `ARCH-<arch>` markers; fail-fast false | PASS | Matrix verified programmatically: 20/19, ipk == apk − `aarch64_cortex-a76`, no dupes; apk rename `$(basename "$f" .apk)-<arch>.apk`, marker via `printf '%s\n'` |
| publish-repo gate + downloads (exact names, patterns, merge-multiple) | PASS | `needs: [build, build-client]`; tag-or-dispatch gate; four downloads exactly as pinned |
| apk repos: key copy, per-arch dirs, client renamed (suffix stripped), mkndx + adbsign with `--allow-untrusted` (D1), pinned alpine digest (D4), TT_APK_SIGN_KEY | PASS | Marker-driven arch discovery (no second matrix copy); digest byte-identical |
| opkg repo: merged dir, ipkg-make-index.sh (openwrt-22.03, D9), mkhash shim, field filter, usign padding, `gzip -9nc`, `usign -S` in rootfs 22.03.7, TT_OPKG_SIGN_KEY | PASS | Filter fields exact; padding `(64+size)%128 ∈ {110,111}` → two empty lines; signature over UNCOMPRESSED `Packages` |
| Verification: apk 25.12.0 (`/var/lock`, key as install.sh, explicit packages.adb entry, full-path `--version`); opkg 23.05.6/24.10.8 (both key copies incl. `usign -F -p` fingerprint, `src/gz trusttunnel` line) (D5) | PASS | Mirrors TT-18 install.sh arrangement (cross-read TT-18 issue, lines 30–36) |
| Publish: softprops/action-gh-release@v3, tag-only, four staging globs, single writer (D6) | PASS | Only in publish-repo; dispatch runs never touch releases |
| Site assembly: markdown templates (`__ARCH_LIST__`/`__ARCH__`/`__FILES__`), `_layouts` copy, `__TAG__` → `$GITHUB_REF_NAME` (D12), selective opkg copy + `rm -rf staging` (D10), jekyll-build-pages + Pages actions (D11), no static html templates, nothing committed | PASS | Template files verified present with correct placeholders and `layout: repo-index` front matter; action versions `@v1`/`@v5`/`@v3`/`@v4` exact |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md | N/A | No AGENTS.md exists in the repo |
| PRD clean-room conventions: new expression only; contract data (pins, digests, secrets, matrix values, commands) byte-identical; no `*.old`/backups; no old-vs-new diff committed | COMPLIANT | Comment-level diff vs the inherited file (git `2a9b74c^`): 276 inherited comment lines vs 134 new; exactly 1 identical comment line (a bare `#` separator) — no substantive comment text copied. Non-comment line overlap (188 of 423) is exactly the contract data the plan requires byte-identical (action refs, env values, matrix rows, image digests, artifact names, shell commands). No `*.old`/`*.bak`/baseline files tracked; tree clean at HEAD `9b4f457`; scratch reference copy deleted from the OS temp dir |

## Issues Found

1. **Task 9 live-run gate pending (acceptance criterion 2 unverified)**
   - Location: plan Task 9 Steps 2–4 / issue acceptance criterion 2
   - Description: The static implementation is complete and all local
     validation gates pass, but the live `workflow_dispatch` run from a test
     tag (`vX.Y.Z-rc` dispatched from the tag ref) and the subsequent
     install.sh installs from the published Pages repo on the four rootfs
     images have not been executed. This is the documented deferral in the
     plan's Task 9 note (2026-09-09, no GitHub access during implementation);
     it is an environmental gap, not an implementation defect.
   - Impact: Acceptance criterion 2 cannot be confirmed; the signed
     `packages.adb`/`Packages.gz` outputs and the end-to-end install behavior
     are only statically validated. Until this runs, the issue should not be
     closed as fully validated.
   - Recommendation: From a real checkout with GitHub access, run Task 9
     Steps 2–4: create and push `vX.Y.Z-rc` on the current HEAD, dispatch
     `gh workflow run release.yml --ref v<X.Y.Z-rc>`, verify the run
     job-by-job (build ×2, build-client ×39, publish-repo signing +
     verification, release assets, Pages site), then run install.sh from the
     published Pages repo on `x86-64-25.12.0` (apk) and `x86-64-22.03.7`,
     `x86-64-23.05.6`, `x86-64-24.10.8` (opkg). Re-validate afterwards
     (validation attempt 2) and record the site-restore decision (Task 9
     Step 5).
2. **Plan tooling-version drift (documentation only)**
   - Location: plan.md Technical Context ("actionlint v0.64.x from nix profile")
   - Description: The environment provides actionlint 1.7.12 (not v0.64.x),
     and no `shellcheck` binary is installed locally, so actionlint ran
     without its shellcheck integration. This does not affect the
     implementation: actionlint exits 0 with zero findings, and a
     shellcheck v0.11.0 run (docker `koalaman/shellcheck:v0.11.0`) over the
     ten `run:` bodies with GH expressions substituted found no real shell
     issues (only artifacts of static extraction/substitution: SC2148
     shebang, SC2296 on `${{ }}`, SC2050 on a constant after substitution).
   - Impact: None on the workflow behavior; the two inherited
     SC2086/SC2016 info-level findings were in fact eliminated, exceeding
     the plan's requirement.
   - Recommendation: When updating plan documentation, record the actual
     actionlint/shellcheck versions used.

## Recommendations

- Execute the Task 9 live gate (test tag `vX.Y.Z-rc` dispatched from the tag
  ref; verify the 4 file groups of release assets, the 20 signed apk dirs,
  the opkg `Packages.sig` with `usign -V -p opkg-key.pub -m Packages -x
  Packages.sig`, the rendered index pages through `_layouts/repo-index.html`,
  and no branch commits), then the four install.sh installs from the live
  Pages repo; re-run this validation afterwards.
- Optionally install a local `shellcheck` binary so future actionlint runs
  include the SC-* integration.
- No implementation changes are required from this validation; all static
  gates and the contract checklist are green.

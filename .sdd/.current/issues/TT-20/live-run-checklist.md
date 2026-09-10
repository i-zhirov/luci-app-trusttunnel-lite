# TT-20 live-run checklist — closing the release pipeline verification

This is the exact procedure to close TT-20's remaining acceptance criterion
(the live `workflow_dispatch` run) and promote the issue to Validated. Every
command is copy-pasteable; every check names the exact artifact, URL, or
state to assert. Run it from a real checkout with GitHub access (the local
worktree has none).

- **Purpose**: verify `.github/workflows/release.yml` end-to-end from a
  tag-ref dispatch: builds → client matrix → signed repos → rootfs
  verification installs → release upload → Pages site → `install.sh`
  against the live published repositories.
- **Why a `-rc` tag**: the live run mutates shared state (a GitHub release
  + the Pages site). The rc tag exercises the full pipeline including the
  tag-gated paths (filename assertion, release upload) without touching a
  real version.
- **Why `v1.0.16_rc` and not a lower number**: the nearest real tag is
  `v1.0.15`. The version derives from `git describe --tags --abbrev=0`, and
  the ci.yml release-tag gate rejects a new tag older than the previous
  one. `v1.0.16_rc` is the smallest correct choice.

## 0. Prerequisites (do not start until all hold)

```sh
# The working tree is the final implementation state.
git status --porcelain            # expect: empty
git log --oneline -1              # expect: the TT-20 validation commit (or later)
git tag --sort=-v:refname | head -1   # expect: v1.0.15 (the previous tag)

# The two signing keys are in the tree (publish-repo consumes them from the checkout).
ls -l key-build.pub opkg-key.pub

# The repo's Actions secrets exist (the publish job reads them).
#   Settings → Secrets and variables → Actions:
#     TT_APK_SIGN_KEY  (the private half of key-build.pub)
#     TT_OPKG_SIGN_KEY (the private half of opkg-key.pub)
# Without them publish-repo fails at the apk/opkg signing steps.
# Verified 2026-09-10: `gh secret list -R i-zhirov/trusttunnel-openwrt` shows
# both (created 2026-09-04).

# Pages is configured to deploy from GitHub Actions (not a branch).
#   Settings → Pages → Source: "GitHub Actions"

# The gh CLI is authenticated and can see the repo.
gh auth status
gh repo view --json nameWithOwner -q .nameWithOwner   # the target repo
```

## 1. Push the branch

The workflow file must exist on the ref the dispatch runs from. The current
worktree branch (`consider-reimplementation`) is not on the remote.

```sh
git push -u origin consider-reimplementation
```

(The `.sdd/` spec docs and `docs/` ride along — they are part of the tree and
harmless to the pipeline; the publish job only consumes `key-build.pub`,
`opkg-key.pub`, `repo-site/`, `packages/`, and `install.sh`.)

### Pre-run site snapshot (record before starting)

The Pages site currently serves the LAST REAL RELEASE built from the
PRE-REBASE tree: `opkg/Packages` shows `luci-app-trusttunnel_1.0.15_all.ipk`
(git `26.251.39727-dc127ec` — the inherited code). The rc run therefore
does NOT regress the site relative to today; it replaces stale inherited
builds with the reimplemented code under `1.0.16-rc`.

```sh
curl -s https://i-zhirov.github.io/trusttunnel-openwrt/opkg/Packages | grep -E '^(Version|Filename):' | head -2
# record the output as the "before" state
```

### The tag name must produce a valid apk version

Discovered during the first live dispatch: apk-tools 3.x REJECTS versions
with a dash-prerelease suffix — `apk version -c 1.0.16-rc-r1` fails (and
the apk packaging step of the build dies in ~0.5s with no output). The
underscore form `1.0.16_rc-r1` is accepted (`apk version -c` exits 0),
and the ipk side accepts any string. Hence the test tag is `v1.0.16_rc`,
not `v1.0.16-rc`; the plan's `-rc` example is wrong for apk.

## 2. Create and push the test tag

```sh
git tag v1.0.16_rc
git push origin v1.0.16_rc
```

Pushing the tag triggers the workflow automatically (trigger `push: tags:
"v*"`). Confirm it started:

```sh
gh run list --workflow=release.yml --limit 3
# expect: a run on ref v1.0.16_rc, status in_progress
```

Note: pushing the tag also triggers the **CI** workflow (its triggers
include tags `v*`). That run is expected and harmless — it executes the
gates on the tag commit.

If the Release run does not appear (trigger missed), dispatch explicitly
FROM THE TAG REF — a branch-ref dispatch would skip the tag assertion and
the release upload:

```sh
gh workflow run release.yml --ref v1.0.16_rc
```

Watch it to completion:

```sh
gh run watch --exit-status
```

## 3. Verify the run job by job

Take the run URL from `gh run list` (or `gh run view`). Go through every
job in `gh run view --web` and assert the items below. All names assume
`v1.0.16_rc`; adjust if you picked another number.

### 3.1 `build` (2 matrix legs)

- Both legs green (25.12.5 → apk, 22.03.7 → ipk).
- **Tag assertion step ran and passed** (it is `if: startsWith(github.ref,
  'refs/tags/')` — the dispatch ref is the tag, so it must be present, not
  skipped).
- Artifacts (the `dist/` contents uploaded by the job):
  - `luci-app-trusttunnel-1.0.16-rc-r1.apk`
  - `luci-i18n-trusttunnel-ru-<gitrev>.apk`
  - `luci-app-trusttunnel_1.0.16-rc_all.ipk`
  - `luci-i18n-trusttunnel-ru_git-<rev>_all.ipk`

### 3.2 `build-client` (39 matrix legs)

- All legs green (20 apk archs + 19 ipk archs; ipk = apk minus
  `aarch64_cortex-a76`).
- Every apk artifact renamed with its arch suffix
  (`trusttunnel-client-1.1.5-r1-<arch>.apk`) and each arch dir carries an
  `ARCH-<arch>` marker file (publish-repo discovers archs from the markers).

### 3.3 `publish-repo`

- **apk half**: 20 arch directories each containing `packages.adb` +
  `packages.adb.sig` (signed with `TT_APK_SIGN_KEY` via `apk adbsign
  --allow-untrusted` in the pinned `alpine:edge@sha256:266f29…` container);
  `key-build.pub` present.
- **opkg half**: `Packages`, `Packages.gz`, `Packages.sig` +
  `opkg-key.pub` (signed with `TT_OPKG_SIGN_KEY` via `usign -S`).
  **Verify the signature against the UNCOMPRESSED `Packages`** (this is the
  classic mistake — the index step signs `Packages`, then `Packages.gz` is
  made from it):

  ```sh
  # on a machine with usign, or inside openwrt/rootfs:x86-64-22.03.7:
  docker run --rm -v "$PWD:/d" openwrt/rootfs:x86-64-22.03.7 sh -c '
    cd /tmp && mkdir -p v && cd v
    wget -q https://i-zhirov.github.io/trusttunnel-openwrt/opkg/Packages
    wget -q https://i-zhirov.github.io/trusttunnel-openwrt/opkg/Packages.sig
    wget -q https://i-zhirov.github.io/trusttunnel-openwrt/opkg/opkg-key.pub
    usign -V -p opkg-key.pub -m Packages -x Packages.sig
  '   # expect: "Signature check: OK"
  ```
- **Verification steps green** — these ARE the acceptance installs:
  - "Verify the apk installs on 25.12": installs `luci-app-trusttunnel`
    from the signed repo into `openwrt/rootfs:x86-64-25.12.0` and runs
    `/opt/trusttunnel_client/trusttunnel_client --version`.
  - "Verify the ipk installs on 23.05/24.10": same on the two opkg images.

### 3.4 Release upload

- A GitHub release exists for `v1.0.16_rc` with the four file groups:
  2 luci apks (1.0.16-rc), 20 client apks (`-<arch>` suffixes), 2 luci
  ipks, 19 client ipks.
- Known inherited quirk, no action: the release UI may display `~` in the
  i18n names as `.` (the reason the repositories live on Pages, not on the
  release assets).

### 3.5 Site assembly + Pages deploy

- Deployment green; the site serves:
  - `https://i-zhirov.github.io/trusttunnel-openwrt/apk/<arch>/packages.adb`
    for all 20 archs;
  - `…/apk/key-build.pub`, `…/opkg/Packages.gz`, `…/opkg/Packages.sig`,
    `…/opkg/opkg-key.pub`, `…/favicon.ico`;
  - the homepage with `__TAG__` substituted by `v1.0.16_rc`.
- Index pages:
  - `…/apk/index.html` lists all 20 archs (the `__ARCH_LIST__`
    substitution);
  - every `…/apk/<arch>/index.html` shows the arch name and the files
    served there (`packages.adb` + the apks — the `__ARCH__`/`__FILES__`
    substitution);
  - `…/opkg/index.html` renders;
  - spot-check one index page's markup for the `repo-index` layout from
    `_layouts/` (a missing per-arch index or a broken layout fails this
    check).
- No commits to any branch: the Pages deployment shows "from GitHub
  Actions" (not a branch source); `git ls-remote origin
  consider-reimplementation` shows the pushed branch with no extra
  commits from the workflow.

## 4. Live install from the published Pages repo with install.sh

The installer (TT-18, unchanged) defaults to the live Pages repo — run it
in a fresh container per image and assert the TT-18 contract:

```sh
for img in x86-64-25.12.0 x86-64-22.03.7 x86-64-23.05.6 x86-64-24.10.8; do
  docker run --rm openwrt/rootfs:$img sh -c '
    apk update >/dev/null 2>&1 || opkg update >/dev/null 2>&1
    sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/consider-reimplementation/install.sh)"
    echo "--- assertions ---"
    test -x /opt/trusttunnel_client/trusttunnel_client && echo "client binary: OK"
    /opt/trusttunnel_client/trusttunnel_client --version
    if [ -f /etc/apk/repositories.d/trusttunnel.list ]; then
      echo "apk repo entry: OK"; ls /etc/apk/keys/trusttunnel.pub >/dev/null && echo "apk key: OK"
    fi
    if [ -f /etc/opkg/customfeeds.conf ] && grep -q "src/gz trusttunnel" /etc/opkg/customfeeds.conf; then
      echo "opkg feed: OK"
      ls /etc/opkg/keys/trusttunnel.pub >/dev/null && echo "opkg stable-name key: OK"
      [ "$(ls /etc/opkg/keys | wc -l)" -ge 3 ] && echo "opkg keys (stock + both copies): OK"
    fi
    /etc/init.d/trusttunnel enabled && echo "service enabled" || echo "service NOT enabled (first install)"
    /etc/init.d/trusttunnel running && echo "service RUNNING (unexpected)" || echo "service NOT running (correct)"
  '
done
```

Assertions per image:

| # | Assertion |
|---|---|
| A1 | `trusttunnel-client` + `luci-app-trusttunnel` installed (the binary exists) |
| A2 | `/opt/trusttunnel_client/trusttunnel_client --version` runs |
| A3 | apk: `/etc/apk/repositories.d/trusttunnel.list` + `/etc/apk/keys/trusttunnel.pub`; opkg: the `src/gz trusttunnel` line + both key copies (`/etc/opkg/keys/trusttunnel.pub` and the fingerprint-named copy) |
| A4 | service installed but **NOT running** and not auto-enabled by the installer on first install (the uci-defaults registers the rc.d link; the installer never starts it) |
| A5 | the seeded default routing profile exists: `uci show trusttunnel.routing_profile` shows `name='Default'`, `mode='vpn'` |

This is acceptance criterion 2 of the issue, end to end.

## 5. Cleanup and site-state decision

1. **Site state**: the Pages site now serves the `-rc` packages. Decide and
   document in the issue. **The only sane option is to accept until the
   next real release**:
   - The "restore by re-dispatch on the last real tag" idea from the plan
     is WRONG in the reimplementation context: `v1.0.15` points at
     `dc127ec`, the PRE-rebase commit — re-dispatching on it would rebuild
     and republish the INHERITED (GPL-2.0-era) tree that this whole effort
     replaced.
   - The current site already serves pre-rebase v1.0.15 builds, so the rc
     run strictly improves the site (reimplemented code) and nothing is
     regressed.
   - The proper restore is the next real release (a real `vX.Y.Z` tag on
     the current tree) — that is a release decision, out of this runbook's
     scope.
2. **Release**: if the rc release should not remain:
   ```sh
   gh release delete v1.0.16_rc --yes --cleanup-tag
   ```
   (this also deletes the tag on the remote; `--cleanup-tag` removes the
   tag with the release).
3. **Local tag** (if the remote tag was deleted):
   ```sh
   git tag -d v1.0.16_rc
   ```
4. **Scratch reference copy** (PRD convention): delete the preserved copy
   of the inherited `release.yml` from the OS temp dir if it still exists
   (`/var/folders/…/opencode/release.yml.baseline` or wherever it was kept).
5. **Tree cleanliness**:
   ```sh
   git status --porcelain   # expect: empty (or only intended files)
   git log --oneline -1     # the branch tip is unchanged
   ```

## 6. Closing the issue

1. In `.sdd/.current/issues/TT-20/plan.md`, mark Task 9's steps `[x]`
   (Step 1 pre-flight, Steps 2–5 with the actual run evidence; append a
   short execution record with the run URL and the assertion results).
2. In `.sdd/.current/issues/TT-20/validation.md`, set `**Overall Status**`
   to Complete and fill the live-run issue's `Resolved:` line with the run
   evidence (run URL, job results, install assertions A1–A5, site state
   decision). Increment `**Validation attempt**` to 2.
3. Flip the statuses:
   ```sh
   sed -i '' 's/^- \*\*Status\*\*: Implemented$/- **Status**: Validated/' \
     .sdd/.current/issues/TT-20/issue.md .sdd/.current/issues/TT-20/plan.md
   ```
4. Commit the plan/validation/status changes with a message like
   `docs: TT-20 live run verified (v1.0.16_rc dispatch)`.
5. Optionally run a final `prd-validate-issue TT-20` re-validation to
   confirm the report.

## What must NOT happen

- Do not use a real version tag (`v1.0.16` etc.) — the pipeline mutates the
  release and the site; the `_rc` suffix is the safety boundary.
- Do not dispatch from a branch ref for the closing run — the tag assertion
  and the release upload are `refs/tags/`-gated; a branch dispatch would
  silently skip them.
- Do not push partial workflow states — the workflow is already final; only
  the current tree should ever be pushed for this run.

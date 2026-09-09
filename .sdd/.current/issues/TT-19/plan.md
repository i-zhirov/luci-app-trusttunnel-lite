# Implementation Plan: TT-19 — ci.yml workflow (the continuous gate)

- **Created**: 2026-09-09
- **Status**: Approved
- **Issue**: `.sdd/.current/issues/TT-19/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation. .github/workflows/ci.yml is inherited GPL-2.0 code (SDK-build skeleton inherited; the check set is mostly fork work). Workflow YAML is functional configuration with thin expression — the rewrite is a re-expression against the workflow spec. This is the continuous gate every other issue's implementation must pass."

## Summary

Re-express `.github/workflows/ci.yml` (inherited GPL-2.0, 233 lines, single
job `tests` with 11 steps) as this project's own pipeline spec written from
the issue's "Contract to reproduce" — zero YAML text copied from the
inherited file; every gate reproduced with the same commands and the same
pinned versions (`actions/checkout@v7`, `koalaman/shellcheck:v0.11.0`,
ucode `v0.0.20250529` built with `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON`).
Baseline verified on the current tree (2026-09-09): every locally-runnable
gate is green (exec bits 100755 × 8, `sh tests/run.sh` green — 180
assertions, 0 failed, per file: test_deps 26, test_gen_config 47,
test_harness 5, test_init_apply 29, test_init_reload 21, test_records 12,
test_routing 40 — shellcheck clean, `sh -n` OK, ucode-import grep OK,
JSON × 2 OK, LuCI requires OK, JS `vm.Script` × 3 OK); the ucode compile
gate and the release-tag gate have documented docker/branch equivalents
because they cannot run bare on the dev machine.

One deliberate, documented coverage decision (see Discrepancies #1): the
shellcheck gate keeps the contract's 8-file list strict and *extends* the
same pinned invocation to the hotplug script and to `tests/test_deps.sh` —
unconditional, because it already exists on the current tree and is linted
nowhere today — and to the three test files that sibling issues add
(`tests/test_hotplug.sh` — TT-08 explicitly asked for this;
`tests/test_uci_defaults.sh` — TT-07; `tests/install-harness.sh` — TT-18),
including the three not-yet-existing files only when they exist, so the
workflow stays green on the current tree and covers them automatically the
moment the sibling issues land. Everything else reproduces the contract
exactly; the only file touched is `.github/workflows/ci.yml`
(`release.yml` is TT-20's file and stays untouched).

## Technical Context

- **Language/Version**: GitHub Actions workflow YAML (GitHub's `on:` key
  makes plain YAML parsers complain; validate with `actionlint` (installed
  at `/Users/iliazhirov/.nix-profile/bin/actionlint`) and `ruby -e 'require
  "yaml"; YAML.load_file(...)'`). `run:` blocks execute in POSIX `sh`-compatible
  shells on the runner (`bash -e` default on `ubuntu-latest`); every step in
  this workflow is written to be shell-agnostic.
- **Primary Dependencies**: `actions/checkout@v7` (floating major tag — the
  only unpinned dependency; kept as-is for identical behavior, see
  Discrepancies #4); `ubuntu-latest` runner; docker on the runner for
  `koalaman/shellcheck:v0.11.0` and for building ucode; apt packages
  `build-essential cmake libjson-c-dev pkg-config`; `git` (exec-bits and
  release-tag steps); `python3` (JSON gate); node (JS gate, preinstalled on
  ubuntu-latest); `jow-/ucode` tag `v0.0.20250529` (depth-1 clone).
- **Storage**: none — CI only; the job reads the repository tree and the
  git index; no artifacts, no caches, no uploads.
- **Testing**: the workflow itself is the regression net (PRD Testing
  Decisions). Local equivalents, one per gate, are listed in Research
  ("Local verification vehicles"); shellcheck and the ucode build are
  docker-based so they reproduce on any machine.
- **Target Platform**: GitHub-hosted `ubuntu-latest` runners; the gates
  guard OpenWrt package artifacts (shell, ucode backend, LuCI views, JSON
  metadata) in this repository.

## Research

### Baseline verification of the current workflow (verified 2026-09-09)

Every locally-runnable gate executed on the current tree, exact commands:

| Gate | Command run locally | Result |
| --- | --- | --- |
| Executable bits | `git ls-files -s -- <8 paths>` | all `100755` (install.sh, uninstall.sh, init.d/trusttunnel, uci-defaults/40-luci-trusttunnel, hotplug.d/net/40-trusttunnel, gen-config, routing, uci-export) |
| Unit tests | `sh tests/run.sh` | `== all tests passed` — 180 assertions, 0 failed (per file: test_deps 26, test_gen_config 47, test_harness 5, test_init_apply 29, test_init_reload 21, test_records 12, test_routing 40) |
| Shellcheck (contract list) | `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh uninstall.sh tests/run.sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel` | clean (exit 0) |
| Shellcheck (extension: hotplug) | same image on `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel` | clean (exit 0) — safe to add to the list |
| Shellcheck (extension: test_deps.sh) | same image on `tests/test_deps.sh` | clean (exit 0) — safe to add to the list unconditionally (the file exists on the current tree) |
| Init script syntax | `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` | OK |
| ucode module imports | the 17 `mod:fn` grep pairs against `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` | OK (every used module function is imported) |
| JSON syntax | `find packages -name '*.json'` + `python3 -c "import json,sys; json.load(open(sys.argv[1]))"` | 2 files OK (`menu.d/luci-app-trusttunnel.json`, `acl.d/luci-app-trusttunnel.json`) |
| LuCI module requires | 10-module call-grep vs `'require <mod>'` over `htdocs/luci-static/resources/view/trusttunnel/*.js` | OK (status.js, settings.js, diagnostics.js) |
| JavaScript syntax | node `vm.Script("(function(){\n"+src+"\n})")` per view | OK × 3 |
| Workflow lint | `actionlint .github/workflows/ci.yml` | 1 pre-existing finding: SC2044 (`for f in $(find packages -name '*.json')`) in the JSON step — not a gate failure, fixed in the re-expression (see Discrepancies #3) |
| ucode compile gate | not runnable bare: `libjson-c` absent on the dev machine; equivalent documented below (docker `ubuntu:24.04`) | see "Local verification vehicles" |
| Release-tag gate | not runnable bare: needs two real tags | see "Local verification vehicles" |

Baseline state: GREEN (with the two documented exceptions that need tags /
a container build).

### Contract vs current ci.yml — job-by-job verification

| # | Contract item | Current ci.yml | Verdict |
| --- | --- | --- | --- |
| 1 | Triggers: push to main, tags `v*`, pull requests | `push: branches [main]`, `tags ['v*']`, `pull_request:` (all branches) | matches |
| 2 | `actions/checkout` with `fetch-depth: 0` | `actions/checkout@v7`, `fetch-depth: 0` | matches (version pinned as a major tag; issue leaves it unpinned) |
| 3 | Executable-bits check: `git ls-files -s` mode `100755` for the 6 package scripts + install.sh + uninstall.sh | exactly the 6 package paths + install.sh + uninstall.sh; per-file `awk '{print $1}'` mode comparison, `::error` per failure, single exit code | matches (verified 100755 × 8) |
| 4 | Release-tag check (tags only): new tag's commit date newer than previous tag | `if: startsWith(github.ref, 'refs/tags/')`; `git tag --sort=-v:refname` previous-tag lookup; `git log -1 --format=%ct` both sides; fail on `new_ts < old_ts` | matches |
| 5 | Unit tests: `sh tests/run.sh` | `run: sh tests/run.sh` | matches |
| 6 | Shellcheck: pinned `koalaman/shellcheck:v0.11.0 -s sh` over install.sh, uninstall.sh, tests/run.sh, records.sh, gen-config, routing, uci-export, uci-defaults | exact 8-file list, docker invocation `-v "$PWD:/src" -w /src` | matches (list gap: see Discrepancies #1) |
| 7 | Init script syntax: `sh -n` | `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` | matches |
| 8 | ucode module-import check: grep for `math`/`fs`/`ubus`/`uci` functions, verify each imported | 17 pairs: math rand/srand/sqrt/pow/abs, fs readfile/writefile/popen/access/unlink/stat/mkdir/chmod/mkstemp/opendir, ubus connect, uci cursor; call-grep `fn(` vs `import {…fn…} from '<mod>'` | matches |
| 9 | ucode syntax: build `v0.0.20250529` with `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON`; `ucode -L … -c` on `luci.trusttunnel`; negative control | apt installs build-essential cmake libjson-c-dev pkg-config; depth-1 clone of tag; the two `_SUPPORT=ON` flags plus all other modules `_SUPPORT=OFF`; build `-j$(nproc)`; `-L '/tmp/ucode/build/*.so' -c` on the backend; negative control `printf 'let x = ;\n'` must be rejected | matches |
| 10 | JSON syntax over all `packages/**/*.json` | `find packages -name '*.json'` + python3 `json.load` per file | matches (loop shape flagged SC2044, see #3) |
| 11 | LuCI requires: each used module (ui/dom/rpc/uci/form/view/poll/fs/network/validation) has a matching `'require X'` | the exact 10-module list; call-grep `m.fn(` (word-boundary) vs `^'require m'` | matches |
| 12 | JavaScript syntax: node `vm.Script` wrapping each view in a function | `new vm.Script("(function(){\n" + src + "\n})")` per view file | matches |

### Discrepancies and decisions

1. **Shellcheck list gap — test files (the main finding).** The current
   (and contracted) shellcheck list covers only `tests/run.sh`, never
   `tests/test_*.sh`; the individual test files are exercised by
   `tests/run.sh` (glob `tests/test_*.sh`) but never linted. One of them —
   `tests/test_deps.sh` — already exists on the current tree (2026-09-09,
   verified clean under v0.11.0), so it is added unconditionally. The
   reimplementation also adds three new shell files that sibling issues
   deliver: `tests/test_hotplug.sh` (TT-08 — whose plan explicitly says
   "when TT-19 rewrites ci.yml, add `tests/test_hotplug.sh` to the
   shellcheck invocation"), `tests/test_uci_defaults.sh` (TT-07), and
   `tests/install-harness.sh` (TT-18 — deliberately NOT `test_*.sh`, so
   `tests/run.sh` never runs it; nothing covers it in CI). **Decision**: the
   re-expressed shellcheck step keeps the contract's 8-file list strict
   (missing contract file ⇒ step fails) and extends the *same* pinned
   image/command with the hotplug script and `tests/test_deps.sh`
   (unconditional — both exist, verified clean) and the three sibling test
   files (included only if present at run time, so the workflow passes on
   the current tree today and covers each file automatically once its issue
   lands). Behavior of the contracted gates is unchanged (same command,
   same pinned version); the extension widens coverage only.
2. **Hotplug script not linted anywhere in CI.** `40-trusttunnel` is
   executable shell in the exec-bits gate but in neither the current nor
   the contracted shellcheck list (and no `sh -n`). Covered by the #1
   extension (verified clean under v0.11.0).
3. **`sh -n` scope.** The contract names only the init script; TT-07's plan
   noted that extending `sh -n` to `40-luci-trusttunnel` "belongs to the
   packaging/CI issue". **Decision**: keep the contract scope (init script
   only). Every other shell file is covered by the shellcheck gate (after
   the #1 extension) and the test files additionally by execution in
   `run.sh`; a widened `sh -n` would be a new gate beyond the contract, and
   the acceptance criteria require identical gates.
4. **actionlint SC2044 (pre-existing).** The JSON step's `for f in $(find
   …)` loop trips actionlint's embedded shellcheck. Not a workflow failure;
   the re-expression writes the loop in a robust form (`find -print0` /
   `while IFS= read -r`) with byte-identical gate behavior, leaving
   `actionlint` fully clean.
5. **`actions/checkout@v7` is a floating major tag.** The repo's own
   pinning philosophy (shellcheck, ucode) would prefer a full SHA; changing
   it is a behavior risk outside the contract. **Decision**: keep `@v7`;
   note full pinning as a maintainer decision for a follow-up.
6. **No `permissions:`/`concurrency:`/`env:` keys exist.** The contract
   does not specify them; the job needs only the default `GITHUB_TOKEN`
   (checkout). Keep the workflow minimal — absent keys stay absent.
7. **Comments are inherited expression.** The inherited file carries long
   rationale comments (pinning, fetch-depth, negative controls). The new
   file's comments must be the implementer's own words describing the same
   *reasons* (they are part of the spec's rationale, not of the gate
   behavior); Task 7 checks no inherited comment text survives verbatim.

### Local verification vehicles (docker-based equivalents per gate)

| Gate | Local equivalent | Notes |
| --- | --- | --- |
| Executable bits | `git ls-files -s -- <8 paths>` | exact command; verified |
| Release tag | `git tag vA vB` in a scratch clone + the step's two `git log -1 --format=%ct` lines | needs two real tags; step's shell logic is reproducible outside GH; see Task 6 negative control |
| Unit tests | `sh tests/run.sh` | exact command; verified |
| Shellcheck | `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh <files>` | exact CI command; verified |
| Init `sh -n` | `sh -n <path>` | exact command; verified |
| ucode imports | the 17-pair grep block | exact command; verified |
| ucode syntax | `docker run --rm -v "$PWD:/src" -w /src ubuntu:24.04 bash -lc 'apt-get update -qq && apt-get install -y -qq git build-essential cmake libjson-c-dev pkg-config && git clone --depth 1 -b v0.0.20250529 https://github.com/jow-/ucode /tmp/ucode && cmake -S /tmp/ucode -B /tmp/ucode/build -DCMAKE_BUILD_TYPE=Release -DFS_SUPPORT=ON -DMATH_SUPPORT=ON -DUBUS_SUPPORT=OFF -DUCI_SUPPORT=OFF -DRTNL_SUPPORT=OFF -DNL80211_SUPPORT=OFF -DRESOLV_SUPPORT=OFF -DLOG_SUPPORT=OFF -DDEBUG_SUPPORT=OFF && cmake --build /tmp/ucode/build -j"$(nproc)" && /tmp/ucode/build/ucode -L "/tmp/ucode/build/*.so" -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel && printf "let x = ;\n" > /tmp/broken.uc && ! /tmp/ucode/build/ucode -L "/tmp/ucode/build/*.so" -c /tmp/broken.uc 2>/dev/null'` | mirrors the runner (ubuntu 24.04 ≈ ubuntu-latest) command-for-command; the dev machine lacks libjson-c, so the container is the documented vehicle |
| JSON | `find packages -name '*.json'` + python3 `json.load` | exact command; verified |
| LuCI requires | the 10-module call-grep | exact command; verified |
| JS syntax | the node `vm.Script` one-liner | exact command; verified |
| Workflow YAML/schema | `actionlint .github/workflows/ci.yml` + `ruby -e 'require "yaml"; YAML.load_file(...)'` | final file must be actionlint-clean (no new findings; SC2044 gone) |

### Clean-room constraints for this file

- The contract is the issue's "Contract to reproduce" + this plan's
  verification matrix; the new file is written from it, never by
  transforming the inherited text. No YAML block from the inherited file is
  copied; step names and comments are re-expressed in the implementer's own
  words (the *rationales* — pinned versions, negative control, fetch-depth —
  are spec facts and are restated, not quoted).
- The only deliverable is `.github/workflows/ci.yml`; `release.yml` (TT-20)
  and everything else stay untouched.
- PRD convention: the issue ends with `git status` clean — no `*.old`, no
  backup copy of the inherited workflow committed.

## Entities

### Workflow job `tests` (single job, `runs-on: ubuntu-latest`)

- **Fields**: triggers (`push` to `main`, `push` of `v*` tags, all
  `pull_request`s); 11 sequential steps; no env, no permissions, no
  concurrency, no artifacts.
- **Steps** (order is contractual):

| # | Step | Contract (exact command / version) | Guards |
| --- | --- | --- | --- |
| 1 | checkout | `actions/checkout@v7`, `fetch-depth: 0` | full history for tag comparison |
| 2 | Executable bits | `git ls-files -s` mode `100755` for init.d/trusttunnel, uci-defaults/40-luci-trusttunnel, hotplug.d/net/40-trusttunnel, gen-config, routing, uci-export, install.sh, uninstall.sh | package scripts shippable |
| 3 | Release tag newer than previous | `if: startsWith(github.ref, 'refs/tags/')`; `git tag --sort=-v:refname`, `git log -1 --format=%ct` compare | i18n version downgrade |
| 4 | Unit tests | `sh tests/run.sh` | suite (180 assertions today: 26/47/5/29/21/12/40 per file) |
| 5 | Shellcheck | `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh` over the 8 contract files + hotplug script + `tests/test_deps.sh` (unconditional) + the 3 sibling test files (present-only) | lint all project shell |
| 6 | Init script syntax | `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel` | parse check |
| 7 | ucode module imports | 17 `mod:fn` grep pairs vs `import {…} from '<mod>'` on `luci.trusttunnel` | runtime import errors |
| 8 | ucode syntax | apt deps; clone `jow-/ucode` tag `v0.0.20250529`; cmake `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON` (+ all other modules OFF); build; `ucode -L '/tmp/ucode/build/*.so' -c` on `luci.trusttunnel`; negative control `printf 'let x = ;\n'` must fail | backend parse + control on the check |
| 9 | JSON syntax | `find packages -name '*.json'`; python3 `json.load` per file | metadata parse |
| 10 | LuCI module requires | 10-module call-grep (`ui dom rpc uci form view poll fs network validation`) vs `'require X'` per view | runtime `require` errors |
| 11 | JavaScript syntax | node `vm.Script("(function(){\n"+src+"\n})")` per view | view parse |

- **Validation**: each step exits non-zero on its gate failing; order
  fixed; commands and versions pinned per the matrix.
- **States**: n/a — stateless CI job.

## Contracts

The issue's "Contract to reproduce" section is the contract for this plan;
it is reproduced item-by-item in Research ("Contract vs current ci.yml")
with the two documented coverage decisions (Discrepancies #1–#2). No API
endpoints or runtime interfaces involved.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `.github/workflows/ci.yml` | Re-create (modify in place) | Clean-room re-expression of the CI gate from the issue contract: identical triggers, checkout, and 11 step contracts (same commands, same pinned versions); shellcheck list extended per Discrepancies #1–#2; SC2044-free JSON loop; all comments re-expressed in the project's own words |

No other files change (`release.yml` belongs to TT-20; test files belong to
TT-07/TT-08/TT-18 and are only *referenced* by the shellcheck list).

## Tasks

TDD order: baseline first (prove the current gate is green and know each
gate's exact behavior), then re-express the workflow in chunks —
skeleton/repo-truth gates → test/shell gates → ucode gates → static-content
gates — validating YAML/schema and each gate's command locally per chunk,
then negative controls per gate, then final verification. Each chunk is
written fresh from the contract (no copied YAML; comments re-expressed).

### [ ] Task 1: Baseline — verify every gate of the current workflow on the current tree

**Files:**

- Read: `.github/workflows/ci.yml`, `.sdd/.current/issues/TT-19/issue.md`

- [ ] **Step 1: Run the locally-runnable gates with the exact CI commands**

Run (each separately, record results):
`git ls-files -s -- install.sh uninstall.sh packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export`
Expected: all 8 modes `100755`.

Run: `sh tests/run.sh`
Expected: `== all tests passed` (180 assertions, 0 failed — per-file
counts: test_deps 26, test_gen_config 47, test_harness 5, test_init_apply
29, test_init_reload 21, test_records 12, test_routing 40).

Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh install.sh uninstall.sh tests/run.sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/records.sh packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/uci-export packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel`
Expected: exit 0, no findings.

Run: `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel`
Expected: silent, exit 0.

Run: the 17-pair ucode-import grep block from the current ci.yml (copy it as a local command, not as YAML)
Expected: exit 0, "every module function used is imported".

Run: `for f in $(find packages -name '*.json'); do python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"; done`
Expected: exit 0 (2 files).

Run: the node `vm.Script` one-liner over `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/*.js`
Expected: `ok:` × 3, exit 0.

Run: the 10-module LuCI-requires grep block
Expected: exit 0, "every LuCI module used is declared".

Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
Expected: exit 0 (proves the #1 extension is safe on the current tree).

Run: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh tests/test_deps.sh`
Expected: exit 0 (proves test_deps.sh can join the shellcheck list
unconditionally — the file exists on the current tree).

- [ ] **Step 2: Document the two non-bare gates**

Run the ucode compile gate exactly as the container command in Research
("Local verification vehicles") — `docker run --rm -v "$PWD:/src" -w /src ubuntu:24.04 bash -lc '…'` — or, if the network/container run is not
possible, record that the definitive run happens on a branch (Task 7) and
capture the command in the plan record. Same for the release-tag gate:
record that it needs a tags-only push (or two local tags; Task 6 covers the
negative direction).

- [ ] **Step 3: Baseline the workflow linter**

Run: `actionlint .github/workflows/ci.yml`
Expected: exactly one finding — SC2044 at the JSON step (pre-existing; the
re-expression must end actionlint-clean).

**Verification**: baseline matrix complete and green (exec bits, unit
tests, shellcheck, `sh -n`, ucode imports, JSON, JS, LuCI requires), the
two non-bare gates have a recorded procedure, `git status` clean.

### [ ] Task 2: Re-express the skeleton and the repo-truth gates (triggers, checkout, exec bits, release tag)

**Files:**

- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow skeleton from the contract**

New file: `name: CI`; the `on:` block with exactly the three contract
triggers (push to `main`, push of `v*` tags, all pull requests); one job
`tests` on `ubuntu-latest`; step 1 `actions/checkout@v7` with
`fetch-depth: 0`. Own words for names and comments (rationale: full history
required for tag comparison; pinned action version). No `permissions`/
`concurrency`/`env` keys (Discrepancies #6).

- [ ] **Step 2: Write the executable-bits step**

Contract: the 8 paths (6 package scripts + install.sh + uninstall.sh); per
path `git ls-files -s` mode must equal `100755`; report each mismatch as a
`::error` naming the file and the found mode; single non-zero exit when any
mismatch. Implement in the project's own expression (e.g., iterate the
fixed list, compare the mode field, aggregate failures).

Run: `actionlint .github/workflows/ci.yml` and `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'`
Expected: no syntax/schema findings; YAML parses.

Run: the step's command directly against the repo
Expected: exit 0 (baseline from Task 1).

- [ ] **Step 3: Write the release-tag step**

Contract: runs only on tag pushes (`startsWith(github.ref, 'refs/tags/')`);
previous tag via `git tag --sort=-v:refname`; exit 0 when no previous tag;
compare `git log -1 --format=%ct` of the pushed tag vs the previous tag;
fail with a `::error` when the new commit date is older (i18n version
downgrade). Own words for the error message semantics.

Run: `actionlint .github/workflows/ci.yml`
Expected: clean (no new findings).

**Verification**: YAML parses, actionlint clean, exec-bits command exit 0,
release-tag step present with the exact contract commands/versions
(`git tag --sort=-v:refname`, `git log -1 --format=%ct`).

### [ ] Task 3: Re-express the test and shell gates (unit tests, shellcheck, sh -n)

**Files:**

- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the unit-tests step**

Contract: `sh tests/run.sh`. Own words for the name and the (one-line)
rationale.

- [ ] **Step 2: Write the shellcheck step with the decided file list**

Contract: `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh <files>` with:
- the 8 contract files, in the contract order, strict (missing ⇒ step fails);
- `packages/luci-app-trusttunnel/root/etc/hotplug.d/net/40-trusttunnel`
  and `tests/test_deps.sh` (unconditional — both exist on the current
  tree; Discrepancies #1–#2);
- `tests/test_hotplug.sh`, `tests/test_uci_defaults.sh`,
  `tests/install-harness.sh` — appended only when present at run time
  (Discrepancies #1), so the step is green on the current tree and covers
  each file automatically once TT-07/TT-08/TT-18 land. Own words for the
  comments (pinned version rationale; why the test files are included).

Run: the full command locally (contract files + hotplug + test_deps.sh +
the three not-yet-existing sibling files — the sibling files will be
skipped on the current tree)
Expected: exit 0.

- [ ] **Step 3: Write the init-script `sh -n` step**

Contract: `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel`.
Scope stays at the init script (Discrepancies #3).

Run: the command
Expected: silent, exit 0.

**Verification**: all three steps' commands run green locally; the
shellcheck list in the file matches the decided set; actionlint clean.

### [ ] Task 4: Re-express the ucode gates (module imports + syntax build with negative control)

**Files:**

- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the ucode module-import step**

Contract: over `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel`,
the 17 pairs (`math:rand srand sqrt pow abs`, `fs:readfile writefile popen
access unlink stat mkdir chmod mkstemp opendir`, `ubus:connect`,
`uci:cursor`): a pair is "used" when the function name appears followed by
`(` (word-boundary, not part of another word); it is "imported" when an
`import { …fn… } from '<mod>'` line contains it; used-but-not-imported is a
`::error` and a non-zero exit. Own words for the comments (runtime errors
are not parse errors — the rand() incident rationale, restated).

Run: the block against the current backend
Expected: exit 0.

- [ ] **Step 2: Write the ucode syntax step**

Contract, verbatim commands: apt install `build-essential cmake
libjson-c-dev pkg-config`; `git clone --depth 1 -b v0.0.20250529
https://github.com/jow-/ucode /tmp/ucode`; cmake with `-DCMAKE_BUILD_TYPE=Release
-DFS_SUPPORT=ON -DMATH_SUPPORT=ON` and all other modules OFF
(`-DUBUS_SUPPORT=OFF -DUCI_SUPPORT=OFF -DRTNL_SUPPORT=OFF -DNL80211_SUPPORT=OFF
-DRESOLV_SUPPORT=OFF -DLOG_SUPPORT=OFF -DDEBUG_SUPPORT=OFF`);
`cmake --build /tmp/ucode/build -j"$(nproc)"`; `ucode -L '/tmp/ucode/build/*.so' -c`
on `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel`;
negative control: write `let x = ;` to `/tmp/broken.uc` and fail the step
if the compiler accepts it. Own words for the comments (pinned version;
`-c` resolves imports so the fs/math modules are required; the control on
the check itself).

Run: the exact container equivalent from Research
Expected: exit 0, `ucode syntax ok` (or equivalent), control rejects the
broken file.

**Verification**: both steps' commands green locally (imports grep + full
container build incl. negative control); versions in the file exactly
`v0.0.20250529`, `koalaman/shellcheck` untouched; actionlint clean.

### [ ] Task 5: Re-express the static-content gates (JSON, LuCI requires, JS syntax)

**Files:**

- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the JSON syntax step**

Contract: every `packages/**/*.json` parses with python3 `json.load`. New
expression for the loop (robust `find -print0` / `while IFS= read -r`
form) — this removes the pre-existing SC2044 (Discrepancies #4) with
byte-identical gate behavior.

Run: the new loop command
Expected: exit 0 (2 files).

- [ ] **Step 2: Write the LuCI requires step**

Contract: per view file under
`packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/`,
for each of the 10 modules (`ui dom rpc uci form view poll fs network
validation`): a call pattern `m.fn(` (word-boundary on both sides of `m`,
function name word chars, then `(`) marks usage; usage without a line
`'require m'` is a `::error` and a non-zero exit. Own words for the comment
(runtime `require` errors vs `node --check` rationale, restated).

Run: the block
Expected: exit 0.

- [ ] **Step 3: Write the JavaScript syntax step**

Contract: node parses each view's source wrapped in a function expression:
`new vm.Script("(function(){\n" + src + "\n})")`; per-file `ok:` lines;
non-zero exit on any failure. Own words for the comment (views end with a
top-level `return`; wrapping sidesteps module-type detection).

Run: the node one-liner
Expected: `ok:` × 3, exit 0.

**Verification**: all three commands green locally; `actionlint` reports
zero findings (SC2044 gone); action references unchanged.

### [ ] Task 6: Negative controls per gate (break a file, see the gate fail)

**Files:**

- Test only: scratch copies — never modify the working tree's real files
  (use a temp copy / `git worktree add` for index-sensitive controls)

- [ ] **Step 1: Negative control for each repo-truth gate**

- Exec bits: in a scratch clone, `git update-index --chmod=-x` one of the 8
  files, run the step's command → must fail naming that file and its mode.
- Release tag: in a scratch clone, create tag A on the current commit and
  tag B on an older commit (`git log --format=%ct` shows B older) → the
  step's comparison logic must exit non-zero with the downgrade error.
- `sh -n`: run the command against a file with a syntax error → non-zero.

- [ ] **Step 2: Negative control for each lint gate**

- Shellcheck: break the last line of a scratch copy of `tests/run.sh`
  (or of `tests/test_deps.sh`) → the pinned docker command exits non-zero.
- ucode imports: temporarily comment out one `import` line in a scratch
  copy of `luci.trusttunnel` → the grep block exits non-zero naming the
  missing import.
- ucode syntax: the step's built-in negative control already proves the
  compiler rejects broken input; additionally run `-c` on the scratch
  broken file → non-zero.
- JSON: write an invalid file under a scratch `packages/` copy → the loop
  exits non-zero.
- LuCI requires: drop the `'require ui'` line in a scratch copy of a view
  that uses `ui.` → the block exits non-zero.
- JS syntax: insert a syntax error in a scratch copy of a view → the node
  one-liner exits non-zero.

- [ ] **Step 3: Restore and confirm the tree is untouched**

Run: `git status --porcelain`
Expected: only the planned ci.yml change (and the scratch artifacts
outside the repo); no real file modified by the controls.

**Verification**: every gate fails on its broken target and passes on the
real tree; the tree is clean afterwards (PRD convention: no stray files).

### [ ] Task 7: Final verification — full suite on the new workflow

**Files:**

- Verify: `.github/workflows/ci.yml`

- [ ] **Step 1: Full local gate suite against the re-expressed workflow**

Run every command from Task 1 (exec bits, `sh tests/run.sh`, shellcheck
with the full decided list incl. the extension files, `sh -n`, ucode
imports, JSON, LuCI requires, JS syntax) — each exactly as written in the
new file
Expected: all green.

- [ ] **Step 2: Workflow-level validation and action references**

Run: `actionlint .github/workflows/ci.yml` + `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'`
Expected: clean, zero findings (pre-existing SC2044 gone).

Verify the action reference resolves: `actions/checkout@v7` is the only
`uses:` line; every `run:` command and version matches the contract matrix
(no drift in `koalaman/shellcheck:v0.11.0`, ucode `v0.0.20250529`, the
`_SUPPORT` flag set, the 17 import pairs, the 10 LuCI modules).

- [ ] **Step 3: Branch run (or documented docker equivalent)**

Push the branch and open a PR → the workflow must run all jobs green
(baseline acceptance). If a branch run is not possible, record the docker
equivalents per gate (Research table), including the ucode container build
and the release-tag scratch-clone check.

- [ ] **Step 4: Clean-room self-check**

Run: `git status --porcelain` and grep the new file for any comment/step
text that survives verbatim from the inherited file
Expected: only `.github/workflows/ci.yml` modified; no `*.old`, no backup;
no inherited expression in the new file (the grep check of the PRD).

**Verification**: acceptance criteria of the issue — (1) all 12 contracted
gates present with identical commands and pinned versions (plus the
documented shellcheck extension), (2) the workflow passes on the current
tree and stays the green gate for every subsequent reimplementation
commit.

## Discrepancies found (vs. the issue contract)

1. **Shellcheck list gap (test files)**: the contracted/current list
   covers only `tests/run.sh`; `tests/test_deps.sh` already exists on the
   tree and is linted nowhere, and the reimplementation's sibling issues
   add `tests/test_hotplug.sh` (TT-08 explicitly requested its addition),
   `tests/test_uci_defaults.sh` (TT-07), `tests/install-harness.sh`
   (TT-18, never run by `tests/run.sh`). Resolved by the documented
   extension — `tests/test_deps.sh` unconditional (exists today), the
   three sibling files present-only — same pinned command/image, so the
   contracted gates stay identical in behavior.
2. **Hotplug script is executable shell with no lint coverage**: in the
   exec-bits gate but in neither the current nor the contracted shellcheck
   list; added to the extension (verified clean under v0.11.0).
3. **Pre-existing actionlint SC2044** in the JSON step's `for $(find …)`
   loop; re-expressed away with identical behavior (not a contract item —
   the loop form is expression, not gate).
4. **`actions/checkout@v7` floating major tag**: kept for identical
   behavior; full-SHA pinning is a follow-up maintainer decision.
5. **TT-07 expected a widened `sh -n`** for `40-luci-trusttunnel`; the
   TT-19 contract names only the init script and the file is already
   shellchecked — scope kept per contract.
6. Everything else in the contract matched the current file exactly
   (triggers, checkout depth, exec-bit list, release-tag comparison, unit
   tests, shellcheck list and image, `sh -n` target, ucode import pairs,
   ucode build flags/version/negative control, JSON coverage, LuCI module
   list, JS wrapper).

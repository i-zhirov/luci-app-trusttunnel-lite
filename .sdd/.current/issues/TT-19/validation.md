# Issue Validation Report: TT-19 — ci.yml workflow

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-19/issue.md`
- **Plan**: `.sdd/.current/issues/TT-19/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

All 12 contracted gates are present with the pinned versions and pass on the
current tree (branch tip `9b4f457`). Every locally-runnable gate was executed
verbatim from the workflow's `run:` blocks (extracted 1:1, run in `bash`,
the runner's default shell); the docker/ucode gates were verified by step-text
comparison against the plan plus execution of the exact container equivalents
(pinned-tag ucode build, `-c` on the backend, negative control, release-tag
logic in a scratch clone). YAML validates via both `actionlint` (zero
findings — the pre-existing SC2044 is gone) and `ruby YAML.load_file`.

One low-severity defect found: the ucode step's `rm -f uc.out` runs before the
negative control, and the negative control's *failed* compile re-creates a
0-byte `uc.out` in the working directory (experimentally confirmed), so the
cleanup the comment promises does not fully happen. No gate impact in CI
(fresh checkout, nothing scans the file), but the documented docker
equivalent leaves a stray untracked file in the repo. Two documented
deviations from the plan's original text are also recorded below
(`--severity=error` on shellcheck; the 12th "Run the backend contract test"
step wired by the backend issue's commit).

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 7 | 0 | 0 | 7 |
| Acceptance Criteria | 2 | 0 | 0 | 2 |
| Entities | 1 | 0 | 0 | 1 |
| Contracts | 12 | 0 | 0 | 12 |
| Guidelines | 0 | 0 | 0 | 0 |

## Task Status

- [x] **Task 1**: Baseline — verify every gate of the current workflow on the current tree - PASS (plan record complete; re-verified on this tree: `sh tests/run.sh` = 315 assertions / 0 failed across 9 files — 26/57/5/29/29/21/31/51/66 — matching the plan's implementation record #1; exec bits 100755 × 8; shellcheck clean)
- [x] **Task 2**: Re-express the skeleton and the repo-truth gates (triggers, checkout, exec bits, release tag) - PASS (triggers exactly push→main / tags `v*` / pull_request; `actions/checkout@v7` + `fetch-depth: 0`; exec-bits step lists the 8 contracted paths, per-file mode compare vs `100755`, `::error` per failure, single exit code; release-tag step guarded by `startsWith(github.ref, 'refs/tags/')` with `git tag --sort=-v:refname` previous-tag lookup and `git log -1 --format=%ct` comparison — positive and negative directions re-verified in a scratch clone)
- [x] **Task 3**: Re-express the test and shell gates (unit tests, shellcheck, sh -n) - PASS (`run: sh tests/run.sh`; shellcheck step: pinned `koalaman/shellcheck:v0.11.0` docker invocation with the 8 contract files strict + hotplug script + `tests/test_deps.sh` unconditional + present-only extras `tests/test_hotplug.sh`, `tests/test_uci_defaults.sh`, `tests/install-harness.sh`, `tests/backend/test_backend_contract.sh` — all 14 exist on this tree and lint clean at `--severity=error`; `sh -n` on the init script, exit 0)
- [x] **Task 4**: Re-express the ucode gates (module imports + syntax build with negative control) - PASS (17 `mod:fn` pairs — math×5, fs×10, ubus×1, uci×1 — word-boundary call-grep vs anchored `import {…} from '<mod>'`; step text matches the plan's contract: apt deps, `git clone --depth 1 -b v0.0.20250529`, `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON` + 6 modules OFF, `cmake --build -j"$(nproc)"`, `ucode -L '/tmp/ucode/build/*.so' -c` on the backend, `let x = ;` negative control; full CI-equivalent `ubuntu:24.04` container build executed: backend `-c` OK, negative control rejects (exit 255); see Issues Found #1 for the uc.out cleanup placement)
- [x] **Task 5**: Re-express the static-content gates (JSON, LuCI requires, JS syntax) - PASS (JSON: `find -print0` / `while IFS= read -r -d ''` loop — SC2044-free — python3 `json.load` over the 2 `packages/**/*.json` files; LuCI requires: the exact 10 modules, `m.fn(` call pattern vs `^'require m'`; JS: node `vm.Script("(function(){\n"+src+"\n})")` per view, `ok:` × 3; all three exit 0)
- [x] **Task 6**: Negative controls per gate (break a file, see the gate fail) - PASS (re-verified independently: exec bits — `git update-index --chmod=-x install.sh` → `::error::…has index mode 100644` + exit 1; ucode imports — commented-out `math` import → errors naming math.rand/math.srand + exit 1; JSON — invalid file → `::error` + exit 1; ucode syntax — built-in control rejects; release tag — older-commit tag → `::error` + exit 1; shellcheck — syntax-broken file fails the exact pinned invocation at `--severity=error` (SC1072/SC1073 → exit 1); `sh -n`, LuCI requires, JS negatives documented in the plan record #5)
- [x] **Task 7**: Final verification — full suite on the new workflow - PASS (`actionlint` zero findings; `ruby -e 'require "yaml"; YAML.load_file(...)'` parses; the only `uses:` is `actions/checkout@v7`; every run command/version matches the contract matrix — no drift in `koalaman/shellcheck:v0.11.0`, ucode `v0.0.20250529`, the `_SUPPORT` flag set, the 17 import pairs, the 10 LuCI modules; clean-room check: no inherited `run:` block copied verbatim — only the contract-mandated command lines (apt/clone/cmake flags) are identical, which the contract requires; step names and comments are re-expressed)

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All gates listed above present and identical in behavior (same commands, same pinned versions) | MET | 12/12 contract items verified command-for-command and version-for-version (see Contract Status); documented deviations only: shellcheck adds `--severity=error` (plan record #2 — the tree's info/warning findings live in files owned by other issues; gate still fails on error-severity breakage, verified), shellcheck list extended per Discrepancies #1–#2 (8 contract files strict + extensions), and the 12th step "Run the backend contract test" (see Issues Found #3) |
| 2 | The workflow passes on the current tree (baseline) and on every subsequent reimplementation commit | MET | All runnable gates executed on branch tip `9b4f457`: exec bits exit 0, `sh tests/run.sh` "== all tests passed" (315/0), shellcheck exit 0 (14 files), `sh -n` exit 0, ucode-import grep exit 0, JSON exit 0 (2 files), LuCI requires exit 0, JS exit 0 (3 views); docker gates via exact equivalents: ucode build/`-c`/negative control exit 0, backend contract test 31 assertions / 0 failed, release-tag logic positive+negative in scratch clone |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| Workflow job `tests` (single job, `runs-on: ubuntu-latest`) | Triggers (push→main, `v*` tags, all PRs) OK; 12 sequential steps (11 contracted + 1 documented addition) OK; no `env`/`permissions`/`concurrency`/artifacts OK | Step order matches the plan matrix with the backend contract step inserted after "Run the unit test suite" | Every step's gate verified green; step text/versions pinned per matrix | PASS |

## Contract Status

| # | Contract item | Status | Notes |
| --- | --- | --- | --- |
| 1 | Triggers: push to main, tags `v*`, pull requests | PASS | `push: branches [main]`, `tags ['v*']`, `pull_request:` (all branches) |
| 2 | `actions/checkout` with `fetch-depth: 0` | PASS | `actions/checkout@v7`, `fetch-depth: 0` (v7 kept as floating major per Discrepancies #5) |
| 3 | Executable-bits check: `git ls-files -s` mode `100755` for the 6 package scripts + install.sh + uninstall.sh | PASS | Exact 8 paths; per-file `awk` mode compare; `::error` per failure; single exit code; exit 0 on tree, exit 1 on chmod -x negative |
| 4 | Release-tag check (tags only): new tag's commit date newer than previous tag | PASS | `if: startsWith(github.ref, 'refs/tags/')`; `git tag --sort=-v:refname` prev lookup; `git log -1 --format=%ct` both sides; fail on `new_ts < old_ts`; verified positive (exit 0) and negative (::error, exit 1) in a scratch clone |
| 5 | Unit tests: `sh tests/run.sh` | PASS | exit 0, 315 assertions / 0 failed |
| 6 | Shellcheck: pinned `koalaman/shellcheck:v0.11.0 -s sh` over the 8 contract files | PASS | 8 contract files strict (missing ⇒ step fails) + documented extensions (hotplug, test_deps.sh unconditional, 4 present-only extras); adds `--severity=error` (documented deviation, see Issues Found #2) |
| 7 | Init script syntax: `sh -n` | PASS | `sh -n packages/luci-app-trusttunnel/root/etc/init.d/trusttunnel`, exit 0 |
| 8 | ucode module-import check: 17 pairs vs `import {…} from '<mod>'` | PASS | math rand/srand/sqrt/pow/abs, fs readfile/writefile/popen/access/unlink/stat/mkdir/chmod/mkstemp/opendir, ubus connect, uci cursor; word-boundary call-grep (`[[:<:]]fn\(`) vs anchored import line; exit 0; negative verified |
| 9 | ucode syntax: build `v0.0.20250529` with `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON`; `ucode -L … -c`; negative control | PASS | Step text matches the plan verbatim-command contract; full `ubuntu:24.04` container build executed — backend `-c` OK, `let x = ;` rejected (exit 255); see Issues Found #1 |
| 10 | JSON syntax over all `packages/**/*.json` | PASS | `find packages -name '*.json'` + python3 `json.load` per file; SC2044-free loop form; 2 files OK; negative verified |
| 11 | LuCI requires: 10 modules (ui/dom/rpc/uci/form/view/poll/fs/network/validation) each with matching `'require X'` | PASS | Exact module list; `m.fn(` word-boundary usage pattern vs `^'require m'`; exit 0 across the 3 views |
| 12 | JavaScript syntax: node `vm.Script` wrapping each view in a function | PASS | `new vm.Script("(function(){\n" + src + "\n})")` per view; `ok:` × 3, exit 0 |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md | N/A | No AGENTS.md exists in the repo |
| PRD conventions (clean-room re-expression; no inherited text copied; no `*.old`/backups; `git status` clean at issue end) | COMPLIANT | No inherited `run:` block copied verbatim (verified by normalized per-step comparison of the inherited ci.yml at `dda6271` vs the new file — only contract-mandated command lines are identical, which the contract requires); only `.github/workflows/ci.yml` changed by TT-19; no backups; TT-19 tree clean (untracked `validation.md` files belong to parallel sessions of other issues) |

## Issues Found

1. **uc.out cleanup in the ucode syntax step is ineffective — placed before the negative control**
   - Location: `.github/workflows/ci.yml`, "Build the pinned ucode and check the backend syntax" step (`rm -f uc.out` runs after the backend `-c` but before the negative control).
   - Description: The negative control compiles `/tmp/broken.uc` with the working directory still the repo root. Experimentally confirmed with the pinned-tag build: the *failed* compile (exit 255) writes a 0-byte `uc.out` into the working directory. Since `rm -f uc.out` has already run, the file is re-created and left behind — the step's own comment ("drop it so the checkout stays clean") is not satisfied.
   - Impact: None on CI gates (fresh checkout; no later step scans the file; no artifact upload) — the workflow still passes. Locally, the documented docker equivalent leaves a stray untracked `uc.out` in the repository, dirtying `git status` for anyone reproducing the gate.
   - Recommendation: Move `rm -f uc.out` after the negative-control `if` block (or add a second `rm -f uc.out` at the end of the step), so both the backend `-c` and the negative control's output are cleaned.
   - Resolved: (pending)

2. **Shellcheck step adds `--severity=error` to the pinned invocation**
   - Location: `.github/workflows/ci.yml`, "Lint the project shell scripts with shellcheck" step.
   - Description: The contracted/inherited invocation is `docker run --rm -v "$PWD:/src" -w /src koalaman/shellcheck:v0.11.0 -s sh <files>`; the new step appends `--severity=error`. Documented in the plan's Implementation record #2 with rationale (info/warning findings — SC2086, SC1091, SC2034, SC2016 — in files owned by other issues that TT-19 must not edit). Verified: the exact step is green on all 14 files and still fails on error-severity breakage (SC1072/SC1073 → exit 1), so the gate is not neutered.
   - Impact: Low. Info/warning findings no longer fail the gate — a small behavior deviation from the inherited gate, deliberate and recorded; the gate remains the green baseline for the sibling issues and will stay green unchanged if the findings are later cleaned.
   - Recommendation: Accept as documented; revisit (drop the flag) after the owning issues clean their findings.
   - Resolved: (pending)

3. **The workflow has 12 steps; the plan's entity section says 11**
   - Location: `.github/workflows/ci.yml` step 5 "Run the backend contract test" (`run: sh tests/backend/test_backend_contract.sh`).
   - Description: The step was wired into ci.yml by commit `ed40cb3` ("backend: fix validation findings and wire the contract test into CI", the backend issue's fix commit) after the TT-19 plan was written; the plan's step matrix (11 steps) does not list it. The plan's own final-state record (implementation record) does not mention it either.
   - Impact: None — the step is in scope of the requested final state, runs green (31 assertions, 0 failed; docker-gated with SKIP-without-docker, so the suite stays runnable anywhere), and does not alter any contracted gate.
   - Recommendation: Note only — update the plan's step count if the plan is ever amended.
   - Resolved: (pending)

## Recommendations

- Fix the `uc.out` cleanup placement (Issue #1): move/duplicate `rm -f uc.out` after the negative control.
- Keep the documented `--severity=error` shellcheck deviation until the owning issues clean their info/warning findings, then consider removing the flag to restore the exact contracted invocation (Issue #2).
- No changes needed for the contracted gates: all 12 contract items verified pass, YAML is actionlint-clean and parses, and the workflow passes on the current tree.

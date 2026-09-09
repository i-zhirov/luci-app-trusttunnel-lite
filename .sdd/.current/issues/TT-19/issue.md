# Issue TT-19: ci.yml workflow

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent; may run in parallel — but is the
  gate for every other issue)
- **Effort**: M
- **Files**: `.github/workflows/ci.yml`

## Context

`ci.yml` was inherited (the SDK-build skeleton is inherited expression;
the check set is mostly fork work). It is the continuous gate every
reimplementation step must pass. Workflow YAML is functional configuration
with thin expression — the rewrite is a re-expression against the
workflow spec.

## Contract to reproduce

- Triggers: push to main, tags `v*`, pull requests.
- `actions/checkout` with `fetch-depth: 0` (tag comparisons need full
  history).
- Executable-bits check: `git ls-files -s` mode must be `100755` for the
  6 package scripts + install.sh + uninstall.sh.
- Release-tag check (tags only): new tag's commit date newer than the
  previous tag (prevents i18n version downgrades).
- Unit tests: `sh tests/run.sh`.
- Shellcheck: pinned `koalaman/shellcheck:v0.11.0 -s sh` over install.sh,
  uninstall.sh, tests/run.sh, records.sh, gen-config, routing, uci-export,
  uci-defaults (via docker for local reproducibility).
- Init script syntax: `sh -n`.
- ucode module-import check: grep the backend for functions needing
  `math`/`fs`/`ubus`/`uci` imports and verify each is imported.
- ucode syntax: build ucode `v0.0.20250529` from source with
  `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON`; `ucode -L ... -c` on
  `luci.trusttunnel`; plus a negative control (broken file must be
  rejected).
- JSON syntax over all `packages/**/*.json`.
- LuCI module requires: each used module (`ui/dom/rpc/uci/form/view/poll/
  fs/network/validation`) must have a matching `'require X'`.
- JavaScript syntax: node `vm.Script` wrapping each view in a function.

## Acceptance criteria

- [ ] All gates listed above present and identical in behavior (same
      commands, same pinned versions).
- [ ] The workflow passes on the current tree (baseline) and on every
      subsequent reimplementation commit.

## How to verify

1. Run the workflow on a branch with the current code — all jobs green
   (baseline).
2. Negative-control checks: temporarily break a shell script / a JSON /
   a view and confirm the corresponding job fails.

## Notes

- Re-expressed as the project's own pipeline spec; no inherited text
  copied. Keep the docker-based shellcheck (local reproducibility).

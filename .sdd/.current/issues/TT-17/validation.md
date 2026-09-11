# Issue Validation Report: menu manifest

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-17/issue.md`
- **Plan**: `.sdd/.current/issues/TT-17/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 2 | 1 | 0 | 3 |
| Acceptance Criteria | 2 | 0 | 0 | 2 |
| Entities | N/A | N/A | N/A | N/A |
| Contracts | 4 | 0 | 0 | 4 |
| Guidelines | N/A | N/A | N/A | N/A |

## Task Status

- [x] **Task 1: Baseline — record current JSON validity** - PASS: the manifest parses with `python3 json.load` (exit 0), it is the only file in `root/usr/share/luci/menu.d/`, and its entries map 1:1 to the issue's "Contract to reproduce" (re-verified independently during this validation: parent `admin/services/trusttunnel` with title TrustTunnel / order 40 / firstchild / acl+uci depends; children status/settings/diagnostics with orders 10/20/30 and view paths `trusttunnel/{status,settings,diagnostics}`).
- [x] **Task 2: Re-create the manifest from the contract** - PASS: the deliverable on disk matches the contract byte-for-byte in behavior (title, order, action type, depends for all 4 entries), is valid JSON, and no old copy or stray file is kept alongside (`git status` clean for `packages/`; `menu.d/` contains exactly one file). Caveat recorded in Issues Found: the physical rewrite leaves no git trace (content byte-identical by design), so the re-creation act is evidenced only by the commit message of `8bdd775`, not by a diff.
- [x] **Task 3: Verify — gate, view paths, manual menu check** - PARTIAL: Step 1 (CI JSON gate) re-executed green — exit 0 over every `packages/**/*.json`, mirroring `.github/workflows/ci.yml` lines 180–189. Step 2 (path/ACL resolution) verified — `htdocs/luci-static/resources/view/trusttunnel/{status,settings,diagnostics}.js` all exist; `depends.acl` name `luci-app-trusttunnel` is the top-level key of `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`; UCI config `trusttunnel` shipped at `root/etc/config/trusttunnel`. Step 3 (manual LuCI menu check on a device) is unchecked and explicitly deferred in the plan; the documented structural assertion substitute was executed (4/4 entries match, no extra/missing keys).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Menu tree, titles, orders, actions and depends match the contract. | MET | `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`: parent `admin/services/trusttunnel` (TrustTunnel, order 40, `action {type: firstchild}`, `depends {acl: [luci-app-trusttunnel], uci: {trusttunnel: true}}`); children status (order 10, view `trusttunnel/status`), settings (order 20, view `trusttunnel/settings`), diagnostics (order 30, view `trusttunnel/diagnostics`). All 4 entries verified against the contract; no extra or missing keys. |
| 2 | JSON gate passes. | MET | Full gate re-run: `for f in $(find packages -name '*.json'); do python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"; done` — exit 0, no failures; matches the CI "Check the JSON syntax of the package metadata" step (`.github/workflows/ci.yml` lines 180–189). Additional green: `sh tests/run.sh` — all test files pass, "all tests passed", exit 0 (PRD SC-002). |

## Entity Status

N/A — the plan declares no data entities (`Storage: n/a (static package data shipped under /usr/share/luci/menu.d/)`). The menu manifest structure itself was verified as the deliverable: 4 nodes, correct title/order/action/depends per node, valid JSON.

## Contract Status

The issue's "Contract to reproduce" is the spec (no API contracts exist for this issue).

| Entry | Path | Status | Notes |
| --- | --- | --- | --- |
| Parent section | `admin/services/trusttunnel` | PASS | title TrustTunnel, order 40, firstchild, depends acl `[luci-app-trusttunnel]` + uci `{trusttunnel: true}`; both depends targets resolve (ACL file and `root/etc/config/trusttunnel` exist) |
| Status page | `admin/services/trusttunnel/status` | PASS | title Status, order 10, view `trusttunnel/status`; view file exists |
| Settings page | `admin/services/trusttunnel/settings` | PASS | title Settings, order 20, view `trusttunnel/settings`; view file exists |
| Diagnostics page | `admin/services/trusttunnel/diagnostics` | PASS | title Diagnostics, order 30, view `trusttunnel/diagnostics`; view file exists |

## Guidelines Compliance

N/A — no `AGENTS.md` exists in the repository; the PRD implementation decisions applicable here (no `*.old` copies kept alongside, clean `git status` at issue end) are verified: `git status --short -- packages/` is empty, `menu.d/` holds a single file.

## Issues Found

1. **Re-creation of the manifest is not evidenced by git history (informational)**
   - Location: `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`
   - Description: `git log --follow` shows zero modification commits for this file — the last touch is the rename commit `dda6271` (2026-09-07), and the file is byte-identical to the initial upstream snapshot (`64a2d41`). Commit `8bdd775` ("config/acl/menu: re-create the three functional-data manifests", 2026-09-09) asserts the re-creation in its message, but its diff contains no change to this file. Since the plan deliberately reproduces the content byte-identically, a rewrite is invisible to git — the clean-room "act of writing" cannot be independently confirmed.
   - Impact: None on behavior or acceptance criteria — the deliverable state is fully verified (contract match, valid JSON, gates green, paths resolve). Only the provenance evidence of the write is a commit-message assertion.
   - Recommendation: No code change required. If independent clean-room evidence is desired, record the re-creation act in the issue/commit trail (the commit message assertion plus this validation's 4/4 contract-match evidence) and keep the plan's note that a byte-identical rewrite leaves no diff.
   - Resolved: (omit while a validation is in progress)

2. **Manual LuCI device check deferred (informational)**
   - Location: plan Task 3, Step 3 (unchecked)
   - Description: "Services → TrustTunnel renders the three pages in order" and the ACL/uci hiding behavior are not verified on real hardware; the plan explicitly defers this ("none available in this environment") and substitutes structural assertions, which were re-verified here.
   - Impact: None on the acceptance criteria (JSON gate + contract match); device-level rendering remains unverified until hardware is available.
   - Recommendation: Perform the manual menu pass on a router with LuCI when available, per plan Task 3 Step 3. Not a blocker.
   - Resolved: (omit while a validation is in progress)

## Recommendations

- No blocking actions. The deferred manual device check (plan Task 3 Step 3) is the only outstanding verification item and can be closed on hardware.
- Optionally note the byte-identical rewrite provenance (issue found #1) in the final reimplementation summary so the clean-room trail is explicit without a git diff.

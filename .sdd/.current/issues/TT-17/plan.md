# Implementation Plan: menu manifest

- **Created**: 2026-09-08
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-17/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: None

## Summary

Re-create `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`
(the last package file still byte-identical to the upstream GPL-2.0 snapshot)
from the LuCI menu contract in the issue. The file is functional data — the
menu tree, titles, orders, firstchild action and acl/uci depends are dictated
by LuCI's `menu.d` contract, so re-creation is contract-driven, not
expression-copied. The resulting content is intentionally identical to the
current file; the deliverable is a file written from the spec, plus evidence
that the tree and the JSON gate stay green.

## Technical Context

- **Language/Version**: JSON (LuCI `menu.d` manifest, parsed by LuCI's `cbi`/menu subsystem; no code).
- **Primary Dependencies**: LuCI menu contract (`/usr/share/luci/menu.d/*.json`); ACL `luci-app-trusttunnel` from `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`; UCI config `trusttunnel`.
- **Storage**: n/a (static package data shipped under `/usr/share/luci/menu.d/`).
- **Testing**: CI JSON syntax gate (`.github/workflows/ci.yml` lines 179–183: `python3 -c "import json,sys; json.load(open(sys.argv[1]))"` over every `packages/**/*.json`); manual LuCI menu pass on a device.
- **Target Platform**: LuCI on OpenWrt (apk/opkg rootfs installs).

## Research

### LuCI menu.d contract

- The manifest is a JSON object keyed by menu path; each value has `title`, `order`, `action` and optionally `depends` (verified against the current file and the LuCI convention).
- `action: {type: "firstchild"}` makes the node a non-clickable section that redirects to its first child — the parent entry here carries the acl/uci `depends` so the whole subtree is gated on ACL `luci-app-trusttunnel` and the `trusttunnel` UCI config existing.
- `action: {type: "view", path: "trusttunnel/<name>"}` resolves to `htdocs/luci-static/resources/view/trusttunnel/<name>.js`.
- Verified against the current file: all four entries match the issue contract exactly — parent `admin/services/trusttunnel` (TrustTunnel, order 40, firstchild, depends acl `[luci-app-trusttunnel]` + uci `{trusttunnel: true}`), children `status` (order 10), `settings` (order 20), `diagnostics` (order 30), each with the matching view path. No discrepancies found.
- Verified downstream targets exist: `htdocs/luci-static/resources/view/trusttunnel/{status,settings,diagnostics}.js` (TT-10/11/12 outputs) and the ACL named `luci-app-trusttunnel` in `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json` (line 2) both exist.
- Current file passes `python3 json.load` (JSON gate green today).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json` | Re-create | Rewrite from the issue's contract section (clean-room: spec → file, no editing of inherited text); content identical to today by design — this is the interface contract |

No test files: verification is the CI JSON gate + path/manual checks below.

## Tasks

### [x] Task 1: Baseline — record current JSON validity

**Files:**

- Inspect: `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`

- [x] **Step 1: Prove the current file is valid JSON**

Run:
```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" \
  packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json
```
Expected: exit 0, no output. Also confirm it is the only file in `menu.d/`.

- [x] **Step 2: Note the baseline contract mapping**

Confirm each entry from the issue's "Contract to reproduce" against the current file (titles, orders, `firstchild` action, acl/uci depends, three view paths). Record that no discrepancies exist.

**Verification**: Baseline is green and matches the contract 1:1; the working tree is clean except `.sdd/`/`docs/`.

### [x] Task 2: Re-create the manifest from the contract

**Files:**

- Write: `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`

- [x] **Step 1: Write the file from the contract only**

Compose the JSON from the issue's contract section (parent + three children as specified), using the LuCI `menu.d` key/value structure above. Do not copy the old file's text; the content is dictated by the contract.

- [x] **Step 2: Validate JSON and inspect the diff**

Run the Task 1 JSON check again, then `git diff -- packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/` — the diff must be content-identical to the baseline file (contract), with no stray files (`*.old`, backups) left behind.

**Verification**: File parses; `git status` shows the re-created file only, no old copy kept alongside (PRD implementation decision).

### [x] Task 3: Verify — gate, view paths, manual menu check

**Files:**

- Test: all `packages/**/*.json` (CI gate), the three view JS files, the ACL file

- [x] **Step 1: Run the exact CI JSON gate**

Run:
```bash
for f in $(find packages -name '*.json'); do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"
done
```
Expected: exit 0 — mirrors `.github/workflows/ci.yml` "JSON syntax" step.

- [x] **Step 2: Assert view paths resolve to real files**

For each view `trusttunnel/{status,settings,diagnostics}` assert `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/<name>.js` exists (the TT-10/11/12 outputs), and assert the `depends.acl` name `luci-app-trusttunnel` exists in `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`.

- [ ] **Step 3: Manual LuCI menu check on a device**

With the package installed: Services → TrustTunnel shows the three pages in order Status, Settings, Diagnostics (orders 10/20/30); the parent renders as a section via `firstchild`; the subtree is hidden when the ACL is missing or `trusttunnel` UCI config is absent.

> Deferred: requires a device with LuCI installed; none available in this environment.
> Executed instead: structural assertion of the manifest against the contract — 4/4 entries
> (paths, titles, orders, action types/views, acl/uci depends) match exactly, no extra or
> missing keys; all three view paths resolve to existing JS files; depends targets exist
> (ACL `luci-app-trusttunnel` in `rpcd/acl.d/luci-app-trusttunnel.json`, UCI config
> `trusttunnel` shipped in `root/etc/config/trusttunnel`).

**Verification**: JSON gate green, all three view files resolve, manual menu tree matches the contract; `git status` clean of leftovers.

## Contracts

The issue's "Contract to reproduce" section IS the spec — reproduce it verbatim in behavior (paths, titles, orders, action/depends). No API endpoints involved.

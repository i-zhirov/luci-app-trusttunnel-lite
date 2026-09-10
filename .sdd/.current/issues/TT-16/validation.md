# Issue Validation Report: ACL manifest

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-16/issue.md`
- **Plan**: `.sdd/.current/issues/TT-16/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 2 | 1 | 0 | 3 |
| Acceptance Criteria | 2 | 0 | 0 | 2 |
| Entities | 0 | 0 | 0 | 0 |
| Contracts | 0 | 0 | 0 | 0 |
| Guidelines | 0 | 0 | 0 | 0 |

Entities and Contracts are N/A: the plan declares no data entities, and the ACL
file itself is the contract artifact (the issue's "Contract to reproduce"
section); its verification is carried by the acceptance criteria. No
`AGENTS.md` exists, so the Guidelines category does not apply.

## Task Status

- [x] **Task 1: Baseline — JSON validity + method cross-check vs TT-09** - PASS
  - Step 1 (CI JSON gate on the file): exit 0 — re-ran
    `python3 -c "import json,sys; json.load(open(sys.argv[1]))" packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`.
  - Step 2 (method cross-check): the assertion script passes — re-ran it;
    printed `ACL cross-check OK`. Read = `[status, ping, probe, check_domain,
    log, versions, diagnose]` (7), write = `[service, import_config]` (2),
    `uci [trusttunnel]` in both groups, and the union is exactly TT-09's 9
    exports with no duplicates and no extras.
  - Step 3 (record): the inherited file already satisfied the contract; baseline
    established.
- [x] **Task 2: Re-create the ACL manifest from the contract** - PASS
  - The file exists at the planned path and its content is exactly the
    contract: top-level ACL `luci-app-trusttunnel`, `description` present,
    read/write split preserved, tab indentation.
  - Step 2 (`python3 -m json.tool ... > /dev/null`): exit 0, no output.
  - Step 3: only this file changed in the tree; `acl.d/` contains exactly one
    file, no `*.old` or backup files anywhere under `packages/`; working tree
    is clean (`git status --porcelain` empty). The re-created content is
    byte-identical to the inherited file by design (`cmp` against the `dda6271`
    rename commit confirms) — expected: the file is functional data dictated by
    the rpcd ACL contract, so a from-contract rewrite reproduces the same
    bytes. This is the issue's stated design ("byte-identical by design
    (functional data)"), not a defect.
- [ ] **Task 3: Verify — JSON gate, TT-09 export match, device session access** - PARTIAL
  - Step 1 (exact CI JSON gate loop, `find packages -name '*.json'`): PASS —
    re-ran the loop; all 2 JSON files under `packages/` parse, exit 0.
  - Step 2 (cross-check re-run vs TT-09 exports): PASS — `ACL cross-check OK`;
    the union of read+write methods equals the backend's exports. Confirmed
    independently against the backend `root/usr/share/rpcd/ucode/luci.trusttunnel`
    return block (lines 226–228): exactly `status`, `service`, `ping`,
    `probe`, `check_domain`, `log`, `diagnose`, `versions`, `import_config`.
  - Step 3 (device `ubus call session access '{"scope":"luci.trusttunnel"}'`):
    NOT EXECUTED — no device/rootfs available on this macOS host; the plan
    itself marks the step `[ ]` and defers it to the on-device verification
    pass with the static equivalent verified. Recorded as a documented
    deviation (Issue 1); same precedent as TT-10/TT-11/TT-13.
  - Step 4 (tree-cleanliness): PASS — `git status --porcelain` is empty; no
    `*.old`/backup files.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | ACL grants match the contract exactly (read/write split preserved) | MET | `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`: `read.ubus.luci.trusttunnel` = `[status, ping, probe, check_domain, log, versions, diagnose]` + `read.uci` = `[trusttunnel]`; `write.ubus.luci.trusttunnel` = `[service, import_config]` + `write.uci` = `[trusttunnel]`. Assertion script (plan Task 1 Step 2) passes; method union equals the TT-09 backend's 9 exports, each exactly once, in the correct group |
| 2 | `python3 -m json.tool` (or the CI JSON gate) validates it | MET | `python3 -m json.tool ... > /dev/null` exit 0; the exact ci.yml JSON gate loop (lines 180–189) over `find packages -name '*.json'` passes (2 files) |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| N/A | — | — | — | N/A (functional configuration data, not a data entity; per plan) |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| ACL `luci-app-trusttunnel` — read group | `status, ping, probe, check_domain, log, versions, diagnose` + uci `trusttunnel` | PASS | Matches issue contract; matches backend exports |
| ACL `luci-app-trusttunnel` — write group | `service, import_config` + uci `trusttunnel` | PASS | Matches issue contract; `service`/`import_config` are the two mutating methods (init.d actions, setup wizard) |
| JSON validity | — | PASS | CI gate + `json.tool` both exit 0 |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| N/A | N/A | No `AGENTS.md` in the repository |

PRD conventions were checked instead: tab indentation preserved; no `*.old`
file left alongside (PRD "Implementation Decisions" — every issue ends with a
`git status` check); working tree clean.

## Issues Found

1. **Device session-access check not executed (documented pending deviation)**
   - Location: plan Task 3 Step 3 — `ubus call session access
     '{"scope":"luci.trusttunnel"}'` on a device/rootfs.
   - Description: no device/rootfs with the package installed is available in
     this environment (macOS host); the check was not performed. The plan
     records the step as `[ ]` and defers it to the on-device verification
     pass; the static equivalent (ACL file content + TT-09 export match) was
     verified instead. Same precedent as TT-09's live-ubus deviation and the
     TT-10/TT-11/TT-13 pending device passes.
   - Impact: the runtime grant resolution on a live rpcd session is not
     directly observed. The file is functional data that is byte-identical to
     the previously shipped inherited manifest, so no behavioral drift is
     expected; impact is limited to the unperformed observation.
   - Recommendation: on a device/rootfs, verify a read-only LuCI user is
     granted exactly `status, ping, probe, check_domain, log, versions,
     diagnose` + uci `trusttunnel`, and a write-capable user additionally
     `service` and `import_config`. Non-blocking for the acceptance criteria,
     which are both met by the automated checks.
   - Resolved:
     (Omitted — validation in progress.)

## Recommendations

- Run the deferred on-device `session access` check (Issue 1) when a
  device/rootfs is available and record the result; it is the only open
  verification item.
- No implementation changes are required: the manifest is valid JSON, matches
  the TT-16 contract exactly, and its method union equals the TT-09 backend's
  9 exports with the read/write split intact.
- Issue/plan statuses were not touched, per the validation instructions.

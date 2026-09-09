# Implementation Plan: ACL manifest

- **Created**: 2026-09-08
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-16/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: None

## Summary

Re-create the inherited rpcd ACL manifest
(`packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`)
from the TT-16 contract: a valid JSON ACL `luci-app-trusttunnel` with the
read/write split preserved — read = `[status, ping, probe, check_domain, log,
versions, diagnose]` + uci `[trusttunnel]`; write = `[service, import_config]`
+ uci `[trusttunnel]`. The file is functional data dictated by the rpcd ACL
contract; the reimplementation is a from-contract rewrite of a 19-line file.
Baseline check first (JSON gate + method cross-check vs TT-09), then rewrite,
then verify (CI JSON gate, TT-09 export match, device `session access` check).

## Technical Context

- **Language/Version**: JSON (rpcd ACL schema; ubus/uci keys per group)
- **Primary Dependencies**: rpcd ACL format — top-level key = ACL name
  (`luci-app-trusttunnel`), `read`/`write` groups, each with `ubus`
  (`<object>` → method name array) and `uci` (config name array)
- **Storage**: n/a (static manifest shipped in the package rootfs)
- **Testing**: CI "JSON syntax" gate in `.github/workflows/ci.yml`
  (lines 179–183): `for f in $(find packages -name '*.json'); do python3 -c
  "import json,sys; json.load(open(sys.argv[1]))" "$f"; done`; plus
  `python3 -m json.tool` locally and the on-device
  `ubus call session access '{"scope":"luci.trusttunnel"}'` check
- **Target Platform**: OpenWrt LuCI package (`luci-app-trusttunnel`), rpcd
  sessions

## Research

### Baseline state of the inherited file

- The current file already matches the TT-16 contract exactly:
  - `read.ubus.luci.trusttunnel` = `["status","ping","probe","check_domain","log","versions","diagnose"]`, `read.uci` = `["trusttunnel"]`
  - `write.ubus.luci.trusttunnel` = `["service","import_config"]`, `write.uci` = `["trusttunnel"]`
  - Valid JSON (`python3 -m json.tool` passes).
- Git history confirms the lineage: upstream import (`64a2d41`), fork trim
  (`cddcc19`), rename (`dda6271`). The read/write split is the fork's 1-line
  diff described in the issue.

### Method cross-check vs TT-09

- TT-09 exports exactly 9 methods: `status`, `service`, `ping`, `probe`,
  `check_domain`, `log`, `versions`, `diagnose`, `import_config`.
- ACL read (7) + write (2) = 9; every TT-09 method appears exactly once; the
  read group holds the read-only methods and the write group holds the two
  mutating ones (`service` runs init.d actions, `import_config` runs the
  setup wizard). No discrepancies.

### Pattern notes

- Only one ACL file exists in the tree (`packages/**/acl.d/*.json` matches
  nothing else), so this issue touches exactly one file.
- Indentation is tabs (inherited style); keep tabs.
- PRD convention: every reimplementation issue ends with a `git status` check
  that the old file was not kept alongside (no `*.old`).

## Entities

N/A — the ACL manifest is functional configuration data, not a data entity.

## Contracts

N/A — no API endpoints; the ACL file itself is the contract artifact (see the
issue's "Contract to reproduce" section).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json` | Re-create | Rewritten from the TT-16 contract: valid JSON, ACL `luci-app-trusttunnel`, read/write split preserved |

## Tasks

### [x] Task 1: Baseline — JSON validity + method cross-check vs TT-09

**Files:**

- Read: `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`

- [x] **Step 1: Run the CI JSON gate on the current file**

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json
```

- [x] **Step 2: Cross-check the method names against TT-09's exports**

```bash
python3 - <<'EOF'
import json
acl = json.load(open('packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json'))['luci-app-trusttunnel']
read = acl['read']['ubus']['luci.trusttunnel']
write = acl['write']['ubus']['luci.trusttunnel']
expected_read = ['status','ping','probe','check_domain','log','versions','diagnose']
expected_write = ['service','import_config']
tt09 = ['status','service','ping','probe','check_domain','log','versions','diagnose','import_config']
assert read == expected_read, f"read mismatch: {read}"
assert write == expected_write, f"write mismatch: {write}"
assert sorted(set(read) | set(write)) == sorted(tt09), "union != TT-09 exports"
assert acl['read']['uci'] == ['trusttunnel'] and acl['write']['uci'] == ['trusttunnel']
print('ACL baseline OK')
EOF
```

- [x] **Step 3: Record the result**

Expected: PASS on both commands — the inherited file already satisfies the
contract. If PASS, the baseline is established; if FAIL, stop and report the
discrepancy (the file drifted from the contract).

**Verification**: both commands above exit 0; the printed cross-check matches
TT-09's 9 exports exactly (read 7 + write 2, no duplicates, no extras).

### [x] Task 2: Re-create the ACL manifest from the contract

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`

- [x] **Step 1: Write the file from the TT-16 contract (not from the inherited text)**

```json
{
	"luci-app-trusttunnel": {
		"description": "Grant access to TrustTunnel configuration and diagnostics",
		"read": {
			"ubus": {
				"luci.trusttunnel": [
					"status", "ping", "probe", "check_domain", "log", "versions", "diagnose"
				]
			},
			"uci": [ "trusttunnel" ]
		},
		"write": {
			"ubus": {
				"luci.trusttunnel": [ "service", "import_config" ]
			},
			"uci": [ "trusttunnel" ]
		}
	}
}
```

The structure is dictated by the rpcd ACL schema; the content is the issue's
contract (read/write split preserved, tab indentation).

- [x] **Step 2: Validate the rewritten file**

Run: `python3 -m json.tool packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json > /dev/null` Expected: exit 0, no output

- [x] **Step 3: Check the diff**

Run: `git diff --stat packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json` Expected: the file is the only change; no `*.old` files exist (`ls packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/`)

**Verification**: JSON parses; the file content matches the contract exactly
(read/write split preserved, 7 + 2 method names, `uci [trusttunnel]` in both
groups); `git status` shows only this file changed.

### [x] Task 3: Verify — JSON gate, TT-09 export match, device session access

**Files:**

- Test: `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`

- [x] **Step 1: Run the exact CI JSON gate**

```bash
for f in $(find packages -name '*.json'); do python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"; done
```

Expected: exit 0 (all JSON files in `packages/` parse)

- [x] **Step 2: Re-run the method cross-check against TT-09 exports**

Run the same `python3 - <<'EOF' ... EOF` assertion script from Task 1.
Expected: `ACL baseline OK` — every one of TT-09's 9 exports is present
exactly once, in the correct read/write group.

- [ ] **Step 3: Device session-access check (manual, on a device/rootfs)**

> NOT EXECUTED in this environment (no device/rootfs available; macOS host).
> Deferred to the on-device verification pass. Static equivalent verified:
> read = 7 methods + uci [trusttunnel], write = 2 methods + uci [trusttunnel]
> exactly per the contract.

```bash
ubus call session access '{"scope":"luci.trusttunnel"}'
```

Expected: for a read-only LuCI user the granted ubus methods are exactly
`status, ping, probe, check_domain, log, versions, diagnose` and `uci` grants
`trusttunnel`; for a write-capable user `service` and `import_config` are
granted too.

- [x] **Step 4: Tree-cleanliness check**

Run: `git status --porcelain` Expected: only
`packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`
is modified; no `*.old` or backup files (PRD implementation-decision
convention).

**Verification**: CI JSON gate passes; the ACL's ubus method union equals
TT-09's exports with the read/write split intact; device `session access`
shows the expected grants; `git status` is clean.

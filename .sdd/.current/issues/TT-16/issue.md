# Issue TT-16: ACL manifest

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-09
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json`

## Context

The ACL manifest was inherited; the fork's only change was splitting the
method list into read and write groups (1-line diff). It is functional
data dictated by the rpcd ACL contract.

## Contract to reproduce

- ACL `luci-app-trusttunnel`:
  - read → ubus `luci.trusttunnel` = `[status, ping, probe, check_domain,
    log, versions, diagnose]`, uci `[trusttunnel]`
  - write → ubus `luci.trusttunnel` = `[service, import_config]`, uci
    `[trusttunnel]`
- Valid JSON (ci.yml JSON gate).

## Acceptance criteria

- [ ] ACL grants match the contract exactly (read/write split preserved).
- [ ] `python3 -m json.tool` (or the CI JSON gate) validates it.

## How to verify

1. JSON validation gate.
2. On a device: `ubus call session access '{"scope":"luci.trusttunnel"}'`
   for read/write users shows the expected grants.

## Notes

- Part of the rpcd contract; the method names must match TT-09's exports.

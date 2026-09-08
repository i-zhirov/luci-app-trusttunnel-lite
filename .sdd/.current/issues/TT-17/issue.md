# Issue TT-17: menu manifest

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent; may run in parallel)
- **Effort**: S
- **Files**: `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json`

## Context

This is the ONLY package file still byte-identical to the upstream
snapshot. It is functional data dictated by the LuCI menu contract —
re-created from the contract, no creative expression involved.

## Contract to reproduce

- `admin/services/trusttunnel` — title "TrustTunnel", order 40,
  `action: {type: firstchild}`, `depends: {acl: [luci-app-trusttunnel],
  uci: {trusttunnel: true}}`
- `admin/services/trusttunnel/status` — "Status", order 10, view
  `trusttunnel/status`
- `admin/services/trusttunnel/settings` — "Settings", order 20, view
  `trusttunnel/settings`
- `admin/services/trusttunnel/diagnostics` — "Diagnostics", order 30, view
  `trusttunnel/diagnostics`
- Valid JSON.

## Acceptance criteria

- [ ] Menu tree, titles, orders, actions and depends match the contract.
- [ ] JSON gate passes.

## How to verify

1. JSON validation gate.
2. LuCI renders the menu with the three pages under Services → TrustTunnel.

## Notes

- The content is identical to the current file by design — this is the
  interface contract, not copied expression.

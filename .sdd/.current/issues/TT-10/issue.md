# Issue TT-10: status.js view

- **Status**: Validated
- **PRD**: `../../prd.md`
- **Blocked by**: TT-09
- **Effort**: M
- **Files**: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

## Context

`status.js` was inherited (view scaffolding, `verdict()`, RPC declarations
and the polling loop are inherited expression; list fields deleted, update
check states added). It renders the Status page and answers one question:
does the tunnel work?

## Contract to reproduce

- `'use strict';` with the standard LuCI requires (`view`, `poll`, `rpc`,
  `ui`, `dom`).
- RPC declarations: `luci.trusttunnel/status`, `/service` (arg `action`),
  `/versions` (arg `refresh`), `/log` (arg `lines`).
- `verdict(st)` — 4 states, in order:
  1. client not installed → danger "The TrustTunnel client is not
     installed" / detail "Run install.sh: the package does not ship the
     client binary."
  2. service not running → danger if `enabled`, info if disabled.
  3. running but `device_up` false → warning "Connecting to …" (host =
     `endpoint_hostname` or first `address`; no-host fallbacks "Connecting
     to the server").
  4. success — profile-aware (added on main 2026-09-09, BEFORE the legacy
     success return):
     - `routing_profile` set and `routing_mode == 'bypass'` → "Tunnel
       works, profile %s — only the VPN rules go through %s" (host
       variant) / "…go through the tunnel" (no-host), detail "Everything
       else stays direct."
     - `routing_profile` set (vpn mode) → "Tunnel works, profile %s —
       everything except the bypass rules goes through %s" / "…through
       the tunnel", detail "The bypass rules are sent out directly."
     - no profile → legacy "All LAN traffic goes through %s" /
       "All LAN traffic goes through the tunnel".
- Layout: full-width verdict alert only when NOT success; "Now" facts table
  (State=working only on success, Mode row — profile-aware: "Profile %s —
  bypass, only the VPN rules are tunneled" / "Profile %s — VPN, everything
  except the bypass rules is tunneled" when `st.routing_profile`, else
  "Everything through VPN"; Server=endpoint_hostname); "Versions" table
  (Package, client, Update line with states: "unavailable — no network and
  no cached result" when `latest==null`; "%s is available" when
  `update_available`; "installed version is newer than latest" when
  `ahead`; "up to date"; stale-cache row) with a "Check now" button calling
  `versions(true)`.
- Start/Stop/Restart buttons → `service`; `not_running:true` → warning
  notification; non-zero `code` → show `output` in a `<pre>`; else "Done".
- Polling: `status` every 10 s (updates verdict + facts), `log(80)` every
  10 s into a `<pre>` client-log box; `versions(false)` once at render.
- Translation keys: keep the same `_()` keys as today (the `.po` maps
  them) — the key set grew on main 2026-09-09 with the profile verdicts
  and Mode rows (8 new keys: "Tunnel works, profile %s — only the VPN
  rules go through %s", "…through the tunnel", "Everything else stays
  direct.", "Tunnel works, profile %s — everything except the bypass
  rules goes through %s", "…through the tunnel", "The bypass rules are
  sent out directly.", "Profile %s — bypass, only the VPN rules are
  tunneled", "Profile %s — VPN, everything except the bypass rules is
  tunneled").

## Acceptance criteria

- [ ] All 4 verdict states render exactly as today (test with stubbed RPC
      responses).
- [ ] Polling cadence (10 s status + log, one versions call at render).
- [ ] Buttons and update-check flows behave identically.
- [ ] LuCI require checks pass (ci.yml gate) and JS syntax passes (node
      `vm.Script` gate).
- [ ] Translation keys unchanged.

## How to verify

1. JS syntax + LuCI requires gates from ci.yml.
2. Manual LuCI pass on a device: all 4 states (client removed / disabled /
   connecting / working), button actions, update states (stale cache,
   available, ahead, up-to-date).
3. Compare the `_()` key list against the current view's — identical.

## Notes

- Response keys come from TT-09's contract — read the method shapes from
  the TT-09 issue, not from the old file.

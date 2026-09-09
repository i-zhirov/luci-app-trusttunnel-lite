# Issue TT-12: diagnostics.js view

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-09
- **Effort**: M–L
- **Files**: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

## Context

`diagnostics.js` was inherited (page scaffolding and group rendering are
inherited expression; the diagnose/ping/probe/check_domain tool flows are
fork work). It renders the Diagnostics page: the link-by-link breakdown
that the Status page deliberately avoids duplicating.

## Contract to reproduce

- `'use strict';` with LuCI requires (`view`, `rpc`, `ui`, `dom`).
- No Save/Apply: `handleSaveApply`/`handleSave`/`handleReset` = null.
- RPC declarations: `luci.trusttunnel/diagnose`, `/ping` (arg `target`),
  `/probe`, `/check_domain` (arg `domain`).
- On render, `diagnose()` runs immediately; "Check again" button re-runs
  it.
- Results grouped in fixed order: config → prereq → service → kernel →
  network; fail/warn rows shown first, ok/skip behind a "Show … checks"
  toggle button; verdict word + counts banner ("checks passed: %d,
  remarks: %d, problems: %d, skipped: %d").
- "Check a domain" tool: input + button (Enter also submits) →
  `check_domain(domain)`; renders Normalized, Verdict badge (tunnel if
  `verdict` starts with 'tunnel'), Why.
- "Ping the server": button → `ping('')` (no target → backend pings all
  configured endpoints); table of Host / Loss / min-avg-max.
- "Compare the external address": button → `probe()`; two rows "Through
  the tunnel" and "Directly" with IP or error.
- `DIAG_TEXT` translation map: maps backend English strings to `_()`
  lookups — the key set stays as today. Note (main 2026-09-09): the
  backend `diagnose` gained a "Routing profile" config check whose label
  and strings are NOT in the map — they render as-is (raw English),
  exactly like other unmapped strings; reproduce that behavior (do not
  add the mapping).
- Translation keys unchanged.

## Acceptance criteria

- [ ] Group ordering, fail/warn-first rendering, toggle, verdict banner
      behave identically.
- [ ] All three tools (domain check, ping, probe) work with the same
      input/output handling.
- [ ] `DIAG_TEXT` map covers the same backend strings.
- [ ] LuCI require + JS syntax gates pass.
- [ ] Translation keys unchanged.

## How to verify

1. JS syntax + LuCI requires gates.
2. Manual LuCI pass: run diagnose with a working tunnel, with the service
   stopped, and with the client missing — the same checks/verdicts as the
   current view; exercise all three tools; verify the toggle shows the
   ok/skip checks.
3. Compare the `_()` key list against the current view — identical.

## Notes

- Response shapes come from TT-09's `diagnose`/`ping`/`probe`/
  `check_domain` contracts.

# Issue Validation Report: TT-10 — status.js view

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-10/issue.md`
- **Plan**: `.sdd/.current/issues/TT-10/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 7 | 0 | 0 | 7 |
| Acceptance Criteria | 5 | 0 | 0 | 5 |
| Entities | 0 | 0 | 0 | 0 |
| Contracts | 4 | 0 | 0 | 4 |
| Guidelines | 2 | 1 | 0 | 3 |

## Task Status

- [x] **Task 1**: Baseline — prove the gates green and capture the key-list oracle - PASS
  (The implementation's own oracle `/tmp/tt10-keys-baseline.txt` still exists and diffs **identical** to a fresh extraction of the shipped file; both ci.yml gates pass on the current tree, and `sh tests/run.sh` is green — the oracle preconditions hold.)
- [x] **Task 2**: Skeleton — requires, RPC declarations, minimal `view.extend` - PASS
  (`'use strict';`, the five `'require ...'` lines `view poll rpc ui dom`, four `rpc.declare` calls with params arrays `[] / ['action'] / ['refresh'] / ['lines']` and object `luci.trusttunnel`, `return view.extend({...})` — all present, lines 1–37.)
- [x] **Task 3**: `verdict()` and the verdict banner - PASS
  (All 4 states in contract order, profile-aware success branches **before** the legacy return — verified by direct read (lines 38–91) and an independent 20-assertion vm spot-check of the shipped file: every head/detail string and no-host fallback matches the issue contract byte-for-byte; `renderVerdict` renders an empty `div` on success.)
- [x] **Task 4**: Facts and Versions tables with the "Check now" button - PASS
  (`State`/`working` row only on success, profile-aware `Mode` row (bypass → vpn → `Everything through VPN`), `Server` row, all four update-state branches (`latest==null` → unavailable, `update_available`, `ahead`, up-to-date), `stale` cache row, `Check now` → `callVersions(true)` with in-place re-render and danger-notification failure path — lines 105–173.)
- [x] **Task 5**: Start/Stop/Restart buttons and `handleAction` - PASS
  (`Please wait` modal with `Running…`, all four result branches: `not_running` → warning, `code !== 0` → `<pre>` with `output`, success → `Done`, rejection → danger; three buttons wired to `start`/`stop`/`restart` — lines 175–191, 229–243.)
- [x] **Task 6**: Polling, `load()`, and the full page layout - PASS
  (Two `poll.add(..., 10)` registrations — status refreshing verdict+facts, `callLog(80)` into the `<pre>` log box; `callVersions(false)` exactly once at render (line 205); `load()` returns `callStatus()`; three `cbi-section` layout blocks.)
- [x] **Task 7**: Full verification — gates, key diff, `.po` coverage, manual LuCI checklist, clean tree - PASS (device pass pending, documented deviation)
  (Both ci.yml gates PASS; key diff vs pre-rewrite empty (51/51); `.po` coverage 51/51; clean tree; the on-device checklist was executed as the documented stubbed-RPC vm harness — 110 checks, 0 failed — the device pass remains pending, see Issues Found #1.)

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All 4 verdict states render exactly as today (test with stubbed RPC responses) | MET | `verdict()` lines 38–91; independent 20-assertion spot-check of the shipped file — all head/detail strings (incl. both profile branches, legacy branch, and the no-host fallbacks) byte-match the contract; implementation harness `/tmp/tt10-behavior-test.js` loads the shipped file: 110 checks, 0 failed (covers checklist items 1–7) |
| 2 | Polling cadence (10 s status + log, one versions call at render) | MET | grep: two `poll.add(..., 10)` (status → verdict+facts, `callLog(80)` → log box), exactly one `callVersions(false)` at render, one `callVersions(true)` on Check now; harness covers item 10 |
| 3 | Buttons and update-check flows behave identically | MET | `handleAction` four result branches (lines 175–191); `renderVersions` four update states + stale row + Check-now re-render (lines 134–173); harness covers items 8–9 |
| 4 | LuCI require checks pass (ci.yml gate) and JS syntax passes (node `vm.Script` gate) | MET | Ran the **exact ci.yml loops** (lines 196–226) via `bash` over the whole `view/trusttunnel/` dir: JS syntax gate — `ok` on all 3 files, exit 0; LuCI requires gate — exit 0 |
| 5 | Translation keys unchanged | MET | Fresh extraction: 51 unique keys; `diff -u` vs the pre-rewrite file (`git show 44db74c:...status.js`) — **empty**; identical to the implementation baseline `/tmp/tt10-keys-baseline.txt`; `.po` coverage 51/51, 0 missing |

## Entity Status

N/A — the view persists nothing and defines no data entities (per the plan).

## Contract Status

| Endpoint (luci.trusttunnel) | Params | Status | Notes |
| --- | --- | --- | --- |
| `status` | `[]` | PASS | Consumes the TT-09 keys the view needs: `enabled`, `running`, `device_up`, `client_installed`, `endpoint_hostname`, `addresses[]`, `routing_profile`, `routing_mode` |
| `service` | `['action']` | PASS | Handles `code`/`output`/`not_running` per the contract |
| `versions` | `['refresh']` | PASS | Handles `latest == null`, `update_available`, `ahead`, `stale` |
| `log` | `['lines']` | PASS | `(r.lines || []).join('\n')` into the log box |

## Guidelines Compliance

| Guideline (PRD Implementation Decisions) | Status | Notes |
| --- | --- | --- |
| Clean-room method: spec first, never transform the inherited file | COMPLIANT | Spot-check: the new file (263 lines, no comments) is fresh expression — verdict/row are `view.extend` methods vs. inherited top-level functions; direct `click` handlers vs. `ui.createHandlerFn`; if/else blocks vs. nested ternaries; different element classes/attrs and layout styles; only the contract-pinned `_()` strings and the LuCI-framework idioms overlap (required for byte-identical keys) |
| Clean tree: no `*.old`, no committed old-vs-new diffs | COMPLIANT | `git status --porcelain` empty; no `*.old`/`*.orig`/`*~` under `packages/`; only the contract strings are shared with the inherited file (key-set diff is the deliberate equivalence proof) |
| Manual verification checklist documented per component | PARTIAL | Checklist exists (plan Task 7 Step 3, items 1–10) but was executed as the documented stubbed-RPC harness (110/110) because no device/rootfs was available; the on-device LuCI pass remains pending — recorded deviation, not an implementation defect |

## Issues Found

1. **Manual on-device LuCI pass pending (documented deviation)**
   - Location: plan.md Task 7 Step 3 (execution note 2026-09-09) + "Deviations" section
   - Description: The device-dependent verification step (all 4 states on a real router/rootfs, real button actions, real polling) was substituted by the stubbed-RPC node vm harness (`/tmp/tt10-behavior-test.js`, not committed) — 110 checks, 0 failed — because no device/rootfs was available in the implementation environment. The on-device rendering pass is not yet done.
   - Impact: Rendering-level behavior (LuCI theme styling, real `poll`/`dom.content` interaction, backend integration) is verified only indirectly; a device pass could in principle surface theme/integration issues invisible to the harness.
   - Recommendation: Run the Task 7 Step 3 checklist (items 1–10) on a device/rootfs with the TT-09 backend, including the profile states (assign a routing profile in vpn/bypass mode in UCI) and the network-tab check that `versions` is requested once on load. Non-blocking for this issue's acceptance criteria, which are all met by the automated gates.
   - Resolved:
     (Omit while a validation is in progress.)

## Recommendations

- Execute the pending device LuCI pass (Task 7 Step 3 items 1–10) when hardware is available and record the result.
- Optional plan nit (from review.md, non-blocking, no implementation impact): the Contracts table labels the `status` response "the full 14-key set" while the enumeration lists 13 keys; the enumeration itself is correct and the view consumes only the keys it declares.

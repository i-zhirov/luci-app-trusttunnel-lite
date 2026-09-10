# Issue Validation Report: TT-12 diagnostics.js view (clean-room reimplementation)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-12/issue.md`
- **Plan**: `.sdd/.current/issues/TT-12/plan.md`
- **Overall Status**: Complete
- **Validation attempt**: 2

## Summary

The clean-room reimplementation of `diagnostics.js` is present at the branch
tip (`1fd9828`; landed at `0979c3f`), is new expression (spot-checked against
the inherited file at `0979c3f^`), and passes every automated check: both
ci.yml JS gates (syntax via `vm.Script`, LuCI require grep) re-run green with
the exact ci.yml logic, the `_()` key set is identical to the pre-rewrite
file's (89 = 89, diff empty), the 48-entry `DIAG_TEXT` map is intact with the
stale 'Run install.sh — the package does not ship the client binary.' entry
kept and no mappings added for the 'Routing profile' strings or the
'The client is a dependency of the package; reinstall trusttunnel-client.'
hint, and `sh tests/run.sh` passes (9 files, 315 assertions, 0 failed).
Null save handlers, immediate diagnose + "Check again", the fixed group
order, the global fail/warn-first split with the toggle, the verdict banner,
the three tools (incl. the null-avg em dash and the `{error}` envelopes) all
match the plan.

**Re-validation note (attempt 2, 2026-09-10, tip `1fd9828`)**: Issue 1 is
resolved — commit `1f4135f` restored `'class': 'spinning'` to all four
progress paragraphs (`E('p', { 'class': 'spinning' }, …)` at lines
215/230/264/295; grep count = 4). Re-ran both ci.yml JS gates with the exact
workflow logic (10-module require loop and the `vm.Script` wrapped parse over
all `view/trusttunnel/*.js`): green. The 89-key diff vs the pre-rewrite file
at `0979c3f^` is empty (89 = 89, `diff` exit 0), and `sh tests/run.sh`
passes (9 files, 315 assertions, 0 failed). Issues 2–3 are documented
deviations, not defects: the styling differences are presentational and
deferred to the device pass, and the manual LuCI checklist stays
device-pending.

At attempt 1 two categories of findings remained: (1) the four progress
paragraphs dropped the `'class': 'spinning'` that the plan pins ("spinning
`<p>`") in Tasks 4–7 and that the sibling reimplemented `status.js` still
uses — a presentational deviation, restored since (see the re-validation note
above); (2) the manual LuCI checklist (Task 8 Step 3, 9 items) could not be
executed — no device available, recorded as a documented deviation (same
precedent as TT-09's live-ubus step). Minor styling differences vs the
inherited view (verdict badge pill, table CSS classes, toggle button wrapper)
should be judged during that device pass.

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 7 | 1 | 0 | 8 |
| Acceptance Criteria | 5 | 0 | 0 | 5 |
| Entities | 0 | 0 | 0 | 0 (N/A) |
| Contracts | 4 | 0 | 0 | 4 |
| Guidelines | 0 | 0 | 0 | 0 (no AGENTS.md) |

## Task Status

- [x] **Task 1: Baseline — capture the key list, pin the gates** - PASS: the 89-key reference is reproduced independently — the inherited file at `0979c3f^` yields 89 unique `_()` keys and the new file yields 89, diff empty. The syntax/require gate one-liners from the plan were re-run against the final file and match ci.yml's logic exactly (the one-time negative controls themselves are not reproducible from git, but the gate logic was re-verified against the workflow).
- [x] **Task 2: Scaffold — requires, RPC declarations, save handlers, page shell** - PASS: `'use strict';` + `'require view'/'require rpc'/'require dom'/'require ui'` (lines 1–6); four `rpc.declare` calls on `luci.trusttunnel` (`diagnose` no params, `ping` `['target']`, `probe` no params, `check_domain` `['domain']`); `handleSaveApply/handleSave/handleReset: null`; `cbi-map` shell with `<h2> Diagnostics` and the four `cbi-section` blocks with the exact inventory strings.
- [x] **Task 3: Verdict banner + group rendering + DIAG_TEXT map** - PASS: the verdict-class map, verdict-word switch, per-check mark (6.5em bold, per-status colors), group titles, the full 48-entry `DIAG_TEXT` map (counted: 48 entries, incl. `/dev/net/tun present` → `_('present')` and the stale install.sh entry), and `dtr` (truthy-in-map → mapped, else raw, `''` for falsy) are all present and match the contract table. The grouped renderer iterates `config → prereq → service → kernel → network`, skips empty groups, renders hint rows full-width in `<em>`.
- [x] **Task 4: Diagnose flow — banner, fail/warn-first, toggle, immediate run + "Check again"** - PASS: global split (`fail`/`warn` first, `ok`/`skip` in a `display:none` box), toggle labels ("Show the checks that passed" / "Show all checks" / "Hide"), banner (`alert-message` + verdict class, `<strong>` word, `<br>`, counts line `.format(counts.ok||0, …)`), immediate `handleDiagnose(diagnoseBox)` in `render()`, "Check again" via `ui.createHandlerFn`, and the mandatory catch → `alert-message danger` all verified. The progress paragraph now carries `E('p', { 'class': 'spinning' }, …)` (line 215) — Issue 1 resolved in `1f4135f`.
- [x] **Task 5: "Check a domain" tool** - PASS: trim + empty no-op, Enter via `keydown`/`keyCode 13`/`preventDefault`, "Check" button binding, `res.error` → plain `<p>`, Normalized (`<code>`)/Verdict (tunnel-first, green `#2e7d32` / red `#c62828`)/Why rows, catch → plain `<p>` — all verified. The "Checking…" paragraph carries `E('p', { 'class': 'spinning' }, …)` (line 230) — Issue 1 resolved; the verdict renders as colored bold text rather than the inherited pill badge (background + padding + white text) — presentational, colors per plan, deferred to the device pass (Issue 2).
- [x] **Task 6: "Ping the server" tool** - PASS: `callPing('')`, `res.error` → plain `<p>`, header row Host / Loss / "min / avg / max", one row per `res.results`, `loss + '%'`, and `r.avg === null ? '—' : r.min + ' / ' + r.avg + ' / ' + r.max + ' ms'` (em dash confirmed) — all verified. The "Pinging…" paragraph carries `E('p', { 'class': 'spinning' }, …)` (line 264) — Issue 1 resolved.
- [x] **Task 7: "Compare the external address" tool** - PASS: `callProbe()`, two-row table "Through the tunnel"/"Directly", IP in `<code>` when truthy else red error span (defensively `entry && entry.ip`), catch → plain `<p>` — all verified. The "Checking…" paragraph carries `E('p', { 'class': 'spinning' }, …)` (line 295) — Issue 1 resolved.
- [x] **Task 8: Full verification — gates, key diff, manual LuCI checklist, repo hygiene** - PARTIAL: Step 1 both gates re-run green (syntax `vm.Script` wrapper parse ok; require loop fail=0 — also re-run over all `view/trusttunnel/*.js` with ci.yml's exact commands, all ok; re-confirmed green at attempt 2). Step 2 key diff empty (89 = 89, `diff` exit 0 — re-confirmed at attempt 2). Step 4 repo hygiene clean (`git status --short` empty; no `*.old`, no stray reference files in the repo — the reference lives in `${TMPDIR}`). Step 3 the 9-item manual LuCI checklist was NOT executed — no device available; documented deviation (Issue 3), still pending at attempt 2.

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Group ordering, fail/warn-first rendering, toggle, verdict banner behave identically | MET | `renderChecks` order array `['config','prereq','service','kernel','network']`; global `fail`/`warn` → problems first, rest behind `display:none` box + toggle (labels incl. `_('Hide')` swap); banner class/strong/br/counts-format identical to the pinned behavior. Full visual confirmation pending the device pass (Issue 3). |
| 2 | All three tools (domain check, ping, probe) work with the same input/output handling | MET | Enter/trim/no-op, `res.error` → plain `<p>`, `ping('')` empty target, `avg === null` → em dash, ip-vs-error cells, catch paths — all match the plan and the inherited behavior (new code is strictly more defensive: `res.verdict && …` and `entry && entry.ip` guards; output identical when the TT-09 contract holds). |
| 3 | `DIAG_TEXT` map covers the same backend strings | MET | Counted 48 entries matching the plan table exactly, incl. `/dev/net/tun present` → `_('present')`; the stale 'Run install.sh — the package does not ship the client binary.' entry is KEPT (line 88); grep confirms NO mappings for 'Routing profile' or 'The client is a dependency of the package; reinstall trusttunnel-client.' — both pass through `dtr` raw. |
| 4 | LuCI require + JS syntax gates pass | MET | Re-run both ci.yml gates (require loop over `ui dom rpc uci form view poll fs network validation`; `node -e` + `vm.Script` wrapped parse) → exit 0 on the file and on the whole view directory. |
| 5 | Translation keys unchanged | MET | `grep -ohE "_\\('[^']*'\\)" | sort -u` → 89 keys new vs 89 keys old (`0979c3f^`), `diff` empty (exit 0). |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| (none — N/A) | The plan declares no data entities; the only "entity" is the `diagnose` response object, consumed read-only | — | — | N/A |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| `luci.trusttunnel.diagnose` | rpc.declare, no params | PASS | Consumes `{checks[{group,label,status,detail,hint}], counts{ok,warn,fail,skip}, verdict}`; statuses `ok|warn|fail|skip` and groups `config|prereq|service|kernel|network` rendered per pinned semantics. |
| `luci.trusttunnel.ping` | rpc.declare, `params:['target']` | PASS | View passes `''`; reads `res.results || []`, `avg: null` → `—`; `{error}` envelope → plain `<p>`. |
| `luci.trusttunnel.probe` | rpc.declare, no params | PASS | `{tunnel:{ip|error}, direct:{ip|error}}` — two-row table with code/red-span cells. |
| `luci.trusttunnel.check_domain` | rpc.declare, `params:['domain']` | PASS | `res.verdict` starts-with-`tunnel` badge logic; `res.error` defensive branch kept (plain `<p>`); Normalized/Verdict/Why rows. |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md code guidelines | N/A | No `AGENTS.md` in the repo. |
| Clean-room rule (new expression, no copied text) | COMPLIANT | Spot-checked old (`0979c3f^`, 376 lines, comment-heavy, `view.extend` method decomposition, `table`/`tr`/`td left` classes) vs new (408 lines, comment-free, module-level `var` helpers, `cbi-section-table*` classes): 653 diff lines; shared text is limited to contract-mandated strings (UI labels, DIAG_TEXT entries, RPC declaration boilerplate). No `*.old`/`*.bak` copies in the tree. |

## Issues Found

1. **The four progress paragraphs drop the `spinning` class the plan pins**
   - Location: `diagnostics.js` lines 215 ("Running checks — this takes a few seconds…"), 230 ("Checking…" — domain), 264 ("Pinging…"), 295 ("Checking…" — probe): `E('p', _('…'))` without `'class': 'spinning'`.
   - Description: the plan's Task 4/5/6/7 Step 1 each specify the "spinning `<p>`"; the inherited file used `E('p', { 'class': 'spinning' }, …)` in all four places, and the sibling reimplemented `status.js` (line 176) still uses `E('p', { 'class': 'spinning' }, …)`. The class is absent from the whole new file (grep confirms zero matches).
   - Impact: presentational only — while an RPC runs the user sees static text instead of LuCI's loading spinner; no functional difference. The manual checklist item "Check again re-runs (spinner appears)" would fail its letter.
    - Recommendation: add `'class': 'spinning'` to the four `E('p', …)` progress paragraphs.
    - Resolved: fixed in commit `1f4135f` — all four progress paragraphs restored to `E('p', { 'class': 'spinning' }, …)` (lines 215/230/264/295); `grep -c "'class': 'spinning'"` = 4. Re-confirmed at attempt 2; both gates and the key diff stay green.

2. **Minor styling differences vs the inherited view, to judge on the device pass**
   - Location: `diagnostics.js` — verdict badge (line 248: colored bold span), table classes (`cbi-section-table`/`-row`/`-cell` vs the inherited `table`/`tr`/`td left`), toggle button (no wrapper `div` with `margin-top:1em`, no `ev.preventDefault()`), hint row (`colspan=3` vs inherited empty-first-cell + `colspan=2`).
   - Description: the plan pins the badge colors (green `#2e7d32` / red `#c62828` — both match) and the 6.5em bold mark cell (matches), but not the exact CSS treatment; the inherited verdict was a pill badge (background, padding, white text) and used LuCI's `table` classes, so the rendered look can differ slightly (badge vs colored text, table borders/striping).
   - Impact: cosmetic; functionally the rows, labels, colors and badge logic are identical. Exactly the class of difference the pending manual LuCI pass is meant to catch.
    - Recommendation: on the device pass, compare the tool tables/badge against the current view's look; either accept the `cbi-section-table` styling or add the badge background/padding and the inherited classes to match byte-for-byte visually.
    - Resolved: accepted as a documented deviation at attempt 2 — presentational only (verdict badge vs colored bold text at line 248, `cbi-section-table`/`-row`/`-cell` classes, toggle without wrapper `div`/`ev.preventDefault()`); no fix made; deferred to the device pass.

3. **Manual LuCI checklist (Task 8 Step 3) not executed — documented device-pending deviation**
   - Location: plan Task 8 Step 3 (9 items: working tunnel, service stopped, client missing with the raw reinstall hint, domain tool, ping `—`, probe rows, no Save/Apply/Reset, routing-profile assigned/unassigned states with the 17/18-entry max).
   - Description: no device/rootfs with the package installed is available in this environment; all 9 items remain unperformed. Same precedent as TT-09's documented live-ubus deviation.
   - Impact: behavioral oracle evidence (verdicts, toggle, raw pass-through rendering of the 'Routing profile' strings and the reinstall hint, check counts) is code-level only; the visual equivalence of Issues 1–2 is unconfirmed.
    - Recommendation: run the 9-item checklist on a router before closing TT-12 (or keep this as the documented deviation); re-validate afterwards.
    - Resolved: documented environment-pending deviation, unchanged at attempt 2 — the 9-item manual LuCI checklist remains unexecuted (no device available); the device pass stays the open follow-up for TT-12.

## Recommendations

1. Issue 1 is fixed (commit `1f4135f`) — no further action; attempt 2 re-confirms both ci.yml JS gates, the 89-key diff, and `sh tests/run.sh` stay green (9 files, 315 assertions, 0 failed).
2. Run the 9-item manual LuCI checklist on a device (Issue 3); use it to also settle the badge/table styling question (Issue 2) — the only open follow-up before closing TT-12.
3. Issue/plan statuses were not touched (per the re-validation instruction); re-validate after the device pass.

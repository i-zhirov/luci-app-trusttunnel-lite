# Implementation Plan: TT-12 diagnostics.js view

- **Created**: 2026-09-08
- **Status**: Validated
- **Issue**: `.sdd/.current/issues/TT-12/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash (sdd-planner)
- **User Input**: "CLEAN-ROOM reimplementation. Inherited GPL-2.0 file to be replaced by an independently written view with identical behavior. RPC shapes from the TT-09 contract. CI gates: JS syntax + LuCI require checks. No code copied from the inherited file into the plan."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`diagnostics.js` itself is UNCHANGED, but the backend `diagnose` gained
the "Routing profile" config check:

- Two backend strings are NOT in the DIAG_TEXT map and render raw
  (untranslated) through dtr(); the plan's DIAG_TEXT table and key-diff
  task must NOT add mappings — reproduce the raw pass-through for both:
  1. The "Routing profile" check's label/detail/hint strings ("Routing
     profile", "none — legacy full-tunnel mode", "Assign a routing
     profile on the Settings page to control what goes through the
     tunnel.").
  2. The client-missing hint "The client is a dependency of the
     package; reinstall trusttunnel-client." (emitted by the backend
     for the "TrustTunnel client" prereq check when the client binary
     is absent).
  Conversely, the map entry "Run install.sh — the package does not ship
  the client binary." is NEVER emitted by the current backend (it was
  replaced by the reinstall hint above). Keep the 48-entry DIAG_TEXT
  map and the 89-key set exactly as-is, including that stale entry —
  dropping it would change the key set.
- Manual checklist (Task 8): with a profile assigned the diagnose shows
  the extra ok check; without one a warn "none — legacy full-tunnel
  mode" appears. Check count is up to 18 entries.
- Nothing else changes (grouping, tools, toggle).

## Summary

Replace the inherited `diagnostics.js` view with a clean-room reimplementation that is functionally identical: the Diagnostics page (link-by-link breakdown) with a fixed group order (config → prereq → service → kernel → network), fail/warn checks shown first with the ok/skip checks behind a toggle, a verdict word + counts banner, three tools ("Check a domain", "Ping the server", "Compare the external address"), and the 48-entry `DIAG_TEXT` backend-English→`_()` map unchanged.

The view is written from this plan and the TT-09 RPC contracts only — never by transforming the inherited file. The inherited file serves only as a behavioral oracle during verification (translation-key diff, manual LuCI comparison). The implementation is a single-file rewrite; the CI gates (JS syntax via `vm.Script`, LuCI require grep) are the automated regression net, and the manual LuCI pass is the behavioral oracle.

Dependency note: TT-12 is blocked by TT-09 (`luci.trusttunnel` backend), which is still **Draft** (not yet planned). Its contract section already pins the four RPC shapes this view consumes, so planning can proceed; if TT-09's plan changes those shapes, this plan must be revisited.

## Technical Context

- **Language/Version**: LuCI client-side JavaScript (ES5 style, `'use strict';`), executed inside LuCI's view loader (wrapped in a function — the file ends with a top-level `return view.extend({...})`). Runs in the browser on OpenWrt LuCI (luci-base), package `luci-app-trusttunnel`.
- **Primary Dependencies**: LuCI runtime modules `view` (view.extend), `rpc` (rpc.declare), `dom` (dom.content), `ui` (ui.createHandlerFn); global helpers `E()`, `_()` (literal string catalog lookup), `L`-style string `.format()`; rpcd object `luci.trusttunnel` (methods `diagnose`, `ping`, `probe`, `check_domain`).
- **Storage**: None — the page is read-only, calls RPCs on demand, saves nothing.
- **Testing**: CI gates in `.github/workflows/ci.yml`: (1) "LuCI module requires" — for each of `ui dom rpc uci form view poll fs network validation`, if the file contains a call `module.something(` the matching `'require module'` line must exist; (2) "JavaScript syntax" — every view file is parsed wrapped in `(function(){\n...\n})` via `node` + `vm.Script`; plus the manual LuCI checklist and the `_()` key diff against the inherited file.
- **Target Platform**: OpenWrt router (LuCI web UI), browsers of LuCI-supported devices.

## Research

### Inherited file inventory (behavioral, read-only oracle)

`packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js` (376 lines). Behavior to reproduce exactly (expression must be new):

- **Header**: `'use strict';` and `'require'` lines for `view`, `rpc`, `dom`, `ui`. Four `rpc.declare` calls on object `luci.trusttunnel`: `diagnose` (no params), `ping` (params `['target']`), `probe` (no params), `check_domain` (params `['domain']`).
- **No form**: `handleSaveApply`, `handleSave`, `handleReset` all `null`.
- **Status/verdict display data**:
  - Verdict → LuCI alert class: `ok`→`success`, `warn`→`warning`, `fail`→`danger`, `skip`→`info` (unknown → `info`).
  - Verdict word: `ok`→"everything checks out", `warn`→"works, with remarks", `fail`→"there are problems", anything else→"not checked".
  - Per-check word/color: `ok` (#2e7d32) "ok", `warn` (#ef6c00) "check", `fail` (#c62828) "problem", `skip` (#757575) "skipped"; unknown status falls back to the raw status word.
  - Group titles: `config`→"Configuration", `prereq`→"Prerequisites", `service`→"Service", `kernel`→"Kernel state", `network`→"Network"; unknown group title falls back to the raw group name.
- **Grouped check rendering**: rows in a table per group, groups in the fixed order config → prereq → service → kernel → network; groups with no checks are skipped. Each check row has three cells: the per-check mark (fixed width ~6.5em, bold), the translated label, the translated detail. A check with a truthy `hint` gets an additional full-width row under it rendering the hint in `<em>`.
- **Verdict banner**: a div with class `alert-message` + the verdict alert class, containing the verdict word in `<strong>`, a `<br>`, then the counts line `_('checks passed: %d, remarks: %d, problems: %d, skipped: %d').format(counts.ok||0, counts.warn||0, counts.fail||0, counts.skip||0)`.
- **Fail/warn-first + toggle**: checks are split into "problems" (status `fail` or `warn`) and the rest (`ok`/`skip`). Problems render first (grouped, fixed order). The rest render inside a box with inline style `display:none`, preceded by a button (`class` `cbi-button`) whose label is "Show the checks that passed" when problems exist, else "Show all checks". Clicking the button toggles the box between `display:none` and `''` and swaps the label to "Hide" / back.
- **Diagnose flow**: `handleDiagnose(container)` replaces the container content with a spinning `<p>` ("Running checks — this takes a few seconds…"), calls `diagnose()`, and on success renders the banner + check list into the container; on rejection it renders a div `alert-message danger` with the error message (the catch is mandatory — a stuck spinner must never remain).
- **Tools** (each: button → spinner → RPC → result table; on rejection render a plain `<p>` with the error, never a stuck spinner):
  - **Check a domain**: text input (`cbi-input-text`, placeholder `youtube.com`, width ~16em) + "Check" button; pressing Enter in the field triggers the same handler; input is trimmed and an empty value is a no-op; calls `check_domain(domain)`; on `res.error` renders it as a plain `<p>`; else a table with rows "Normalized" (value in `<code>`), "Verdict" (a badge: green `#2e7d32` "through the tunnel" when `res.verdict` starts with `tunnel`, red `#c62828` "direct" otherwise), "Why" (raw `res.reason`).
  - **Ping the server**: "Ping" button calls `ping('')` (empty target → backend pings every configured endpoint); on `res.error` renders a plain `<p>`; else a table with header row (Host / Loss / "min / avg / max") and one row per result: host, `loss + '%'`, and `min / avg / max ms` — or the em dash `—` when `avg` is `null`.
  - **Compare the external address**: "Compare" button calls `probe()`; always renders a two-row table "Through the tunnel" / "Directly"; each cell shows the IP in `<code>` when present, else the error in a red span (`#c62828`).
- **Page layout** (`render()`): a `cbi-map` div with an `<h2>` "Diagnostics" and four `cbi-section` blocks: (1) the intro paragraph ("Checks the whole chain — configuration, prerequisites, service, kernel state and network — and says what to do about anything it finds."), a `cbi-button-action` "Check again" button, and the diagnose container; (2) "Check a domain" (h3, intro paragraph, input + "Check" button, result container); (3) "Ping the server" (h3, intro paragraph, "Ping" button, result container); (4) "Compare the external address" (h3, intro paragraph, "Compare" button, result container). `render()` calls the diagnose handler immediately on the diagnose container, then returns the page.

### RPC contracts consumed (pinned from TT-09)

1. `diagnose` → `{checks: [{group, label, status, detail, hint}], counts: {ok, warn, fail, skip}, verdict}`; `status` ∈ `ok|warn|fail|skip`, `group` ∈ `config|prereq|service|kernel|network`.
2. `ping` (arg `target`, view passes `''`) → `{results: [{host, sent, received, loss, min, avg, max}]}`; no addresses → `{error: 'no endpoint address configured'}`.
3. `probe` → `{tunnel: {ip|error}, direct: {ip|error}}`.
4. `check_domain` (arg `domain`) → `{domain, normalized, verdict: 'direct'|'tunnel', reason}`.

### CI gates (exact commands, from `.github/workflows/ci.yml`)

- **LuCI module requires** (lines 191–208): for each module in `ui dom rpc uci form view poll fs network validation`, a call `module.ident(` in any `view/trusttunnel/*.js` requires a matching `'require module'` line; otherwise the job fails. The view uses `view.`, `rpc.`, `dom.`, `ui.` — all four requires are mandatory.
- **JavaScript syntax** (lines 210–233): parse each view file with `node -e` + `vm.Script` wrapping the source in `(function(){\n...\n})`; any syntax error fails the job. Run locally with the same one-liner against the single file.
- **Translation-key diff** (not a CI gate; manual): `grep -ohE "_\\('[^']*'\\)" <file> | sort -u` extracts the literal `_()` key set. The current file yields **89 unique keys**, including the 48 `DIAG_TEXT` entries. The new file must yield an identical set.

### DIAG_TEXT map (contract data — must stay as-is, 48 entries)

Backend English string → `_()` key (all entries map to themselves except the last):

| # | Backend string → `_()` key |
| --- | --- |
| 1 | `Endpoint address` |
| 2 | `Credentials` |
| 3 | `TLS host name` |
| 4 | `TrustTunnel client` |
| 5 | `tun device` |
| 6 | `Enabled` |
| 7 | `Running` |
| 8 | `Tunnel device` |
| 9 | `Route attached to the device` |
| 10 | `Tunnel carrier` |
| 11 | `MTU matches settings` |
| 12 | `Routing rule` |
| 13 | `Routing table` |
| 14 | `nftables table` |
| 15 | `Firewall zone` |
| 16 | `Endpoint reachable` |
| 17 | `Traffic goes through the tunnel` |
| 18 | `Fill in the address on the Settings page, or import the server config.` |
| 19 | `Both the user name and the password are required.` |
| 20 | `Without it the TLS session uses the bare address, which many servers reject.` |
| 21 | `Run install.sh — the package does not ship the client binary.` |
| 22 | `Install kmod-tun.` |
| 23 | `Turn on Enable on the Settings page, then press Start.` |
| 24 | `Press Start and read the client log below.` |
| 25 | `The device belongs to the client, not to this package. Read the client log below.` |
| 26 | `The device exists but the client has not established the tunnel yet. This is the client side, not the routing — read the client log.` |
| 27 | `Restart the service so the client picks up the configured value.` |
| 28 | `Marked traffic falls into the killswitch instead of the tunnel. Restart the service.` |
| 29 | `Run /etc/init.d/firewall reload — traffic into the tunnel is dropped without the zone.` |
| 30 | `Check the address, and that the router itself has internet access.` |
| 31 | `The tunnel is up but traffic is not using it.` |
| 32 | `A request bound to the device can fail even on a healthy tunnel, because the default route lives in the marked table. Judge by a LAN client instead.` |
| 33 | `not set` |
| 34 | `not installed` |
| 35 | `installed` |
| 36 | `missing` |
| 37 | `yes` |
| 38 | `no` |
| 39 | `present` |
| 40 | `absent` |
| 41 | `up` |
| 42 | `no carrier` |
| 43 | `the client has not created one` |
| 44 | `not attached` |
| 45 | `loaded in fw4` |
| 46 | `not in the live ruleset` |
| 47 | `the router itself has no internet access` |
| 48 | `/dev/net/tun present` → `_('present')` (reuses the existing key) |

Lookup semantics: `dtr(s)` returns the mapped translation when `s` is truthy and present in the map, otherwise the raw string (or `''` for falsy input) — unknown backend strings pass through untranslated. All `_()` calls are literal (never `_()` on a variable), so the strings land in the catalog.

### Discrepancies found (contract vs. inherited view)

1. **TT-09 `ping` envelope under-specified**: the contract lists per-result keys but not the top-level `results` array the view reads (`res.results || []`). Also `avg` must be `null` on 100% loss (the view renders `—` only when `avg !== null` is false). TT-09's plan/implementation must keep `{results: [...]}` and `avg: null`.
2. **TT-09 `check_domain` has no error envelope**; the view checks `res.error` and renders it as a plain paragraph. Keep the defensive branch (behavior is part of the contract with today's backend).
3. **TT-09 `diagnose` label wording is abbreviated** ("Route attached", "Tunnel device") while the view maps the exact strings `Route attached to the device`, `Tunnel device`, etc. The backend must emit the exact label strings listed in the DIAG_TEXT table, or the mapping silently passes them through untranslated.
4. **Fail/warn-first is global, not per-group**: all problem checks (grouped in fixed order) render first; all ok/skip checks (grouped) render behind the toggle. The issue wording "fail/warn rows shown first" matches this, but the plan pins it explicitly so the implementer does not interleave per group.
5. **Ping header label is "min / avg / max"** (issue says "min-avg-max") — keep the slash-separated key for translation compatibility.
6. **Dependency status**: TT-09 is `Draft` (unplanned). The RPC shapes are pinned in its issue text, but if TT-09's plan alters them, revisit this plan.

## Entities

N/A — no data entities. The only "entity" is the `diagnose` response object, whose shape is fixed by the TT-09 contract and consumed read-only (see Contracts).

## Contracts

No new API endpoints. The view consumes four existing `luci.trusttunnel` RPC methods, pinned from TT-09 (see Research → RPC contracts). This issue adds nothing to the backend; it only declares the four RPC calls and consumes the shapes above.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js` | Rewrite | Clean-room reimplementation of the whole Diagnostics view (requires, RPC declarations, null save handlers, verdict banner, group rendering with fail/warn-first + toggle, diagnose flow, three tools, DIAG_TEXT map). |
| `${TMPDIR:-/tmp}/tt12-keys-current.txt` | Create (temp, never committed) | Reference `_()` key list extracted from the inherited file in Task 1; used for the Task 8 diff. |

## Tasks

The CI gates are the automated tests for this file. TDD shape: Task 1 proves the gates are a working oracle (they pass on the inherited file and fail when a require is removed); each later task lands a chunk of the new file and re-runs the gates; Task 8 runs the full verification (gates, key diff, manual LuCI checklist, no stray files). The file is written in place, one chunk at a time; the gates run against the whole file after every chunk.

### [x] Task 1: Baseline — capture the key list, pin the gates

**Files:**

- Create: `${TMPDIR:-/tmp}/tt12-keys-current.txt` (temporary reference, not committed)

- [x] **Step 1: Capture the translation-key reference**

Extract the literal `_()` key set from the current (inherited) file and store it outside the repo:

```sh
grep -ohE "_\\('[^']*'\\)" \
  packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js \
  | sort -u > "${TMPDIR:-/tmp}/tt12-keys-current.txt"
wc -l "${TMPDIR:-/tmp}/tt12-keys-current.txt"
```

Expected: **89** unique keys (48 DIAG_TEXT entries plus the UI/verdict/counts/tool strings). This reference is the equivalence oracle for translation keys.

- [x] **Step 2: Prove the syntax gate fails on broken input (negative control)**

Run the ci.yml "JavaScript syntax" check against the current file:

```sh
node -e '
const fs = require("fs"), vm = require("vm");
for (const f of process.argv.slice(1)) {
  try { new vm.Script("(function(){\n" + fs.readFileSync(f, "utf8") + "\n})"); console.log("ok: " + f); }
  catch (e) { console.error(f + ": " + e.message); process.exitCode = 1; }
}' packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js
```

Expected: PASS (`ok: …diagnostics.js`). Then temporarily corrupt the file (e.g. insert an unbalanced brace), re-run, confirm FAIL, and restore the file with `git checkout -- <file>`. This proves the gate catches syntax errors.

- [x] **Step 3: Prove the require gate fails on a missing require (negative control)**

Run the ci.yml "LuCI module requires" logic for this file:

```sh
mods="ui dom rpc uci form view poll fs network validation"
f=packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js
fail=0
for m in $mods; do
  grep -qE "(^|[^A-Za-z0-9_.$])${m}\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(" "$f" || continue
  grep -qE "^'require ${m}'" "$f" && continue
  echo "error: ${m} used but not declared"; fail=1
done
exit "$fail"
```

Expected: PASS (the file uses `view`, `rpc`, `dom`, `ui` and declares all four). Temporarily delete the `'require ui'` line, re-run, confirm FAIL on `ui`, restore via `git checkout -- <file>`.

- [x] **Step 4: Record the response-shape notes**

In a comment-free scratch note (or this plan's Research section — already done), confirm the four RPC shapes from TT-09 that the view consumes (see Research → RPC contracts), including the pinned ambiguities: `ping` returns `{results: [...]}` with `avg: null` on total loss; `check_domain` may return `{error}`; `diagnose` emits the exact label strings from the DIAG_TEXT table.

**Verification**: `wc -l` shows 89 reference keys; both negative controls failed and were reverted (`git status` clean); the four RPC shapes are written down and match TT-09.

### [x] Task 2: Scaffold — requires, RPC declarations, save handlers, page shell

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Write the scaffold**

Replace the file with new expression that contains: `'use strict';`, `'require view';`, `'require rpc';`, `'require dom';`, `'require ui';`, four `rpc.declare` declarations (object `luci.trusttunnel`; methods `diagnose` with no params, `ping` with `params: ['target']`, `probe` with no params, `check_domain` with `params: ['domain']`), a `view.extend({...})` returning `handleSaveApply: null`, `handleSave: null`, `handleReset: null`, and a minimal `render()` returning the page shell: `cbi-map` div with the `<h2>` "Diagnostics" and the four `cbi-section` blocks (diagnose section with intro paragraph + "Check again" button + an empty container div; domain section with heading, intro, input + "Check" button + container; ping section with heading, intro, "Ping" button + container; probe section with heading, intro, "Compare" button + container). Use the exact UI strings from the Research → inherited inventory. No handler logic yet.

- [x] **Step 2: Run the gates**

```sh
node -e '<syntax check one-liner from Task 1>' packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js
```

Expected: PASS. Then run the require gate from Task 1 — Expected: PASS (all four requires are used: `ui.createHandlerFn` on the tool buttons makes `'require ui'` mandatory).

**Verification**: both gates pass on the new scaffold; the page shell and all UI strings match the inventory list.

### [x] Task 3: Verdict banner + group rendering + DIAG_TEXT map

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Add the display-data tables and the render helper**

Inside the existing file add, with new expression: the verdict-class map (`ok`→`success`, `warn`→`warning`, `fail`→`danger`, `skip`→`info`), the verdict-word function (four `_()` cases, fallback "not checked"), the per-check mark helper (fixed-width bold span; word+color per status from the inventory; unknown status renders the raw word), the group-title map (five `_()` titles with raw fallback), the full 48-entry `DIAG_TEXT` map (exact backend strings from the Research table, each mapped to its literal `_()` call — including `/dev/net/tun present` → `_('present')`), and the lookup helper `dtr(s)` (mapped translation when truthy and present, else raw string or `''`).

- [x] **Step 2: Add the grouped renderer**

Add a render helper that takes a check list and produces the group tables: iterate the fixed order `config, prereq, service, kernel, network`, bucket checks by `group`, skip empty groups, render one `<h4>` group title + one table per group; per check a row with the mark cell, `dtr(label)`, `dtr(detail)`, plus a full-width hint row with `dtr(hint)` in `<em>` when the hint is truthy. No code copied from the inherited file — write it from this contract.

- [x] **Step 3: Run the gates**

Run the syntax check and the require gate. Expected: both PASS (the new helpers use only `E`, `_`, and DOM element construction).

**Verification**: gates pass; the DIAG_TEXT table in the file matches the 48-entry contract table exactly (compare with the Research table); `dtr` fallback behavior verified by a quick reading pass.

### [x] Task 4: Diagnose flow — banner, fail/warn-first, toggle, immediate run + "Check again"

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Add the diagnose handlers**

Add, with new expression: `handleDiagnose(container)` — replace container content with the spinning `<p>` "Running checks — this takes a few seconds…", call `callDiagnose()`, on success render the banner + check list, on rejection render a `div.alert-message.danger` with the error message (never leave the spinner); `renderDiagnose(res)` — build the `alert-message` banner (verdict class, `<strong>` verdict word, `<br>`, counts line with `_('checks passed: %d, remarks: %d, problems: %d, skipped: %d').format(counts.ok||0, counts.warn||0, counts.fail||0, counts.skip||0)`), split checks into problems (`fail`/`warn`) and the rest, render problems via the grouped renderer, and — when any rest exists — a hidden box (`display:none`) with the rest rendered, plus the toggle button (`cbi-button`): label "Show the checks that passed" when problems exist else "Show all checks"; click toggles the box display and the label to "Hide" / back.

- [x] **Step 2: Wire render()**

In `render()`, call the diagnose handler immediately on the diagnose container (the check runs on page open), and bind the "Check again" button to the same handler. Use the exact strings from the inventory ("Running checks — this takes a few seconds…", "Check again").

- [x] **Step 3: Run the gates**

Run the syntax check and the require gate. Expected: both PASS (`dom.content` keeps `'require dom'` satisfied).

**Verification**: gates pass; reading pass confirms: banner format, global fail/warn-first split, hidden box + toggle labels, immediate run, "Check again" re-runs, catch paths render an error instead of a stuck spinner.

### [x] Task 5: "Check a domain" tool

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Add the domain handler and bindings**

Add, with new expression: `handleCheckDomain(input, container)` — trim the input value, no-op when empty; replace container content with the spinning `<p>` "Checking…"; call `callCheckDomain(d)`; on `res.error` render a plain `<p>` with it; else render the result table with rows "Normalized" (`<code>` with `res.normalized`), "Verdict" (badge span: green "through the tunnel" when `res.verdict` starts with `tunnel`, else red "direct"), "Why" (raw `res.reason`); on rejection render a plain `<p>` with the error. In `render()`, bind the "Check" button via `ui.createHandlerFn` and add a `keydown` listener on the input so Enter (with `preventDefault`) triggers the same handler.

- [x] **Step 2: Run the gates**

Run the syntax check and the require gate. Expected: both PASS (the button handler keeps `ui.` usage and `'require ui'` satisfied).

**Verification**: gates pass; reading pass confirms trim/no-op, Enter submission, error paragraph, and the three result rows with the tunnel-first badge logic.

### [x] Task 6: "Ping the server" tool

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Add the ping handler and binding**

Add, with new expression: `handlePing(container)` — replace container content with the spinning `<p>` "Pinging…"; call `callPing('')`; on `res.error` render a plain `<p>`; else render a table with the header row ("Host", "Loss", "min / avg / max") and one row per `res.results` entry: host, `loss + '%'`, and `min + ' / ' + avg + ' / ' + max + ' ms'`, or the em dash `—` when `avg === null`; on rejection render a plain `<p>` with the error. Bind the "Ping" button in `render()` via `ui.createHandlerFn`.

- [x] **Step 2: Run the gates**

Run the syntax check and the require gate. Expected: both PASS.

**Verification**: gates pass; reading pass confirms the empty-target call (`''`), the error branch, the header, and the `null`-avg em dash.

### [x] Task 7: "Compare the external address" tool

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Add the probe handler and binding**

Add, with new expression: `handleProbe(container)` — replace container content with the spinning `<p>` "Checking…"; call `callProbe()`; render a two-row table: "Through the tunnel" and "Directly", each cell showing the IP in `<code>` when `res.tunnel.ip` / `res.direct.ip` is truthy, else the corresponding error in a red span; on rejection render a plain `<p>` with the error. Bind the "Compare" button in `render()` via `ui.createHandlerFn`.

- [x] **Step 2: Run the gates**

Run the syntax check and the require gate. Expected: both PASS.

**Verification**: gates pass; reading pass confirms both rows, the ip-vs-error cell logic, and the catch path.

### [x] Task 8: Full verification — gates, key diff, manual LuCI checklist, repo hygiene

**Files:**

- Inspect: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js`

- [x] **Step 1: Run both CI gates**

Run the exact syntax-check and require-gate commands from Task 1 against the final file. Expected: both PASS.

- [x] **Step 2: Diff the translation-key set**

```sh
grep -ohE "_\\('[^']*'\\)" \
  packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js \
  | sort -u | diff "${TMPDIR:-/tmp}/tt12-keys-current.txt" -
```

Expected: no output (exit 0) — the new file's `_()` key set is identical to the inherited file's (89 keys): the 48-entry DIAG_TEXT map is kept as-is including the stale 'Run install.sh — the package does not ship the client binary.' entry, and no new keys were added for the unmapped 'Routing profile' strings or the 'The client is a dependency of the package; reinstall trusttunnel-client.' hint — all of those render raw.

- [x] **Step 3: Manual LuCI checklist**

On a device/rootfs with the package installed, load Diagnostics and verify against the current view's behavior:

1. Working tunnel: diagnose renders the verdict banner with the counts line; ok/skip checks are hidden behind the toggle; "Show all checks"/"Show the checks that passed" shows them; "Hide" collapses them; "Check again" re-runs (spinner appears).
2. Service stopped: same page structure; fail/warn rows on top with hints; verdict word/counts differ accordingly.
3. Client missing (`/opt/trusttunnel_client` absent): the "TrustTunnel client" check fails with its hint "The client is a dependency of the package; reinstall trusttunnel-client." — rendered raw (untranslated), NOT via the stale 'Run install.sh — the package does not ship the client binary.' map entry; banner reflects it.
4. Check a domain: type a domain, press Enter and the Check button — same Normalized/Verdict/Why table; a `domains.direct` entry shows the red "direct" badge, anything else the green "through the tunnel" badge.
5. Ping the server: table shows one row per configured endpoint with Loss and min/avg/max; an unreachable endpoint shows `—`.
6. Compare the external address: two rows with IPs (or red errors); identical IPs in both rows when traffic bypasses the tunnel.
7. No Save/Apply/Reset buttons anywhere on the page.
8. Routing profile assigned (on the Settings page): the diagnose list shows the extra ok "Routing profile" check — label and "<profile> (<mode>)" detail render raw (untranslated); the total check count is at the 18-entry max and the counts include the extra ok.
9. No routing profile assigned: the "Routing profile" check renders as a warn with the raw detail "none — legacy full-tunnel mode" and the raw hint "Assign a routing profile on the Settings page to control what goes through the tunnel."; the verdict/counts reflect the remark, and the check list still reaches the 18-entry max (the warn row stands in for the ok row, the count does not drop).

- [x] **Step 4: Repo hygiene**

```sh
git status --short
```

Expected: only `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/diagnostics.js` modified (plus `.sdd/` docs if tracked); no `*.old`, no leftover reference file in the repo (it lives in `${TMPDIR:-/tmp}`), no other files touched.

**Verification**: gates green, key diff empty, all 9 manual checklist items pass, `git status` clean of strays.

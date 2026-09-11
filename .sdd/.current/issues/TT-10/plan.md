# Implementation Plan: TT-10 status.js view

- **Created**: 2026-09-08
- **Revised**: 2026-09-09 (plan revision — review #1 Open findings resolved)
- **Status**: Validated
- **Issue**: `.sdd/.current/issues/TT-10/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation of the inherited LuCI Status view: write `status.js` from the TT-10 contract + TT-09 RPC shapes, keep the `_()` keys byte-identical, pass the ci.yml JS gates, no code copied from the inherited file into the plan."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
`status.js` changed; the issue contract was updated. Adjust the plan:

- **Verdict success states are profile-aware** (checked BEFORE the legacy
  success return): `routing_profile` + `routing_mode === 'bypass'` →
  "Tunnel works, profile %s — only the VPN rules go through %s" /
  "…through the tunnel", detail "Everything else stays direct.";
  `routing_profile` (vpn) → "Tunnel works, profile %s — everything except
  the bypass rules goes through %s" / "…through the tunnel", detail "The
  bypass rules are sent out directly."; else legacy. Task 3 implements
  all three branches with these exact strings.
- **Mode row**: when `st.routing_profile` is set — bypass → "Profile %s —
  bypass, only the VPN rules are tunneled", vpn → "Profile %s — VPN,
  everything except the bypass rules is tunneled"; else "Everything
  through VPN". Task 4 implements both variants.
- **Key count is 51 unique `_()` keys / 54 call sites** — the delta from
  the pre-rebase 43 is 8 (the six profile verdict strings plus the two
  Mode strings listed in the issue contract). The earlier "~54 keys"
  wording was the CALL-SITE count, not the unique-key count; the issue's
  "11 new keys" shorthand enumerates the 8 distinct profile strings —
  the extraction command is the source of truth (51). The baseline
  capture (Task 1), every task checkpoint, and the Task 7 final diff all
  pin 51; the `.po` coverage check is 51/51.
- **Status response grew**: `routing_profile`, `routing_mode`, `vpn_mode`
  join the TT-09 `status` response (the full 14-key set) — the Contracts
  table and the Research RPC shapes are updated; the verdict and the Mode
  row consume `routing_profile`/`routing_mode`.
- RPC declarations unchanged (`status`/`service`/`versions`/`log` — the
  new keys ride in `status`'s response).

## Summary

Rewrite `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js` as an independent LuCI view that answers one question — "does the tunnel work?" — exactly as today: a 4-state verdict banner (danger/info/warning/success, where the success state is profile-aware — bypass/vpn-profile heads checked before the legacy one), a "Now" facts table, a "Versions" table with update-check states and a "Check now" button, Start/Stop/Restart buttons, and two 10-second polls (status + client log). The implementation is written from the TT-10 issue contract and the TT-09 RPC response shapes only — the inherited file is the *behavioral oracle* (gates, key list, manual pass), never the source text. All 51 `_()` keys stay byte-identical so the existing `.po` keeps working. Success = the two ci.yml JS gates pass, the extracted key list diffs identical to the baseline (51 unique keys), and the manual LuCI checklist passes.

## Technical Context

- **Language/Version**: LuCI client-side JavaScript, ES5-style (single file wrapped by the LuCI loader in a function — the file's top-level statement is `return view.extend({...})`; no CommonJS module semantics).
- **Primary Dependencies**: LuCI resource modules, all five declared via `'require X'` lines: `view`, `poll`, `rpc`, `ui`, `dom`. RPC calls via `rpc.declare` against the rpcd object `luci.trusttunnel` (backend from TT-09).
- **Storage**: none — the page reads live rpcd state; the versions cache (`/var/cache/trusttunnel/release.json`, TTL 21600 s) is backend-side and invisible to the view.
- **Testing**: the ci.yml gates are the automated oracle — (1) JS syntax via `node` `vm.Script` wrapping each view file in a function expression, (2) LuCI require check via grep (module used ⇒ `'require module'` present). Behavior is verified by a key-list byte-diff against the baseline and a manual LuCI checklist with stubbed RPC responses.
- **Target Platform**: LuCI web UI on OpenWrt; file ships under `htdocs/luci-static/resources/view/trusttunnel/`.

## Research

### Inherited-file status and clean-room rule

`status.js` (259 lines) is GPL-2.0 inherited expression: view scaffolding, `verdict()`, RPC declarations and the polling loop are inherited; list/catalog fields were deleted; update-check states were added; the routing-profile verdict and Mode variants were added on main (2026-09-09) after the rebase. The reimplementation must be new expression written against the contracts below. `view.extend` with `load`/`render`/`render*` helpers is LuCI framework convention, not inherited expression. Comments are not part of the contract — the new file may have its own (fresh) comments or none. No code from the inherited file is reproduced in this plan.

### RPC response shapes (TT-09 contract, section "Methods")

- `status` (no args) → `{enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses[], client_installed, routing_profile, routing_mode, vpn_mode}` — the full 14-key set; `routing_profile`/`routing_mode` are empty when no profile is assigned.
- `service` (arg `action` ∈ start|stop|restart, default restart) → `{code, output}`; on `start` the backend sleeps 1 s and re-checks `running`, and if still not running returns `{code:1, output, not_running:true}`; invalid action → `{error:'unsupported action'}`.
- `versions` (arg `refresh`, default false) → `{client, package, latest, update_available, checked_at, stale, ahead}`; `latest == null` means the check failed (no network AND no cache); `stale:true` means the shown value is an old cached one; `update_available`/`ahead` come from backend `vercmp`.
- `log` (arg `lines`) → `{lines: [...]}` (string array from `logread -e trusttunnel`).

### Verdict/status text specifics (pinned strings)

The issue's shorthand ("Connecting to …", "All LAN traffic goes through %s") elides two fallback strings and several detail strings; the exact strings are pinned here because they are `_()` keys the `.po` maps (see key list in Task 1/7):

- Host derivation used by states 3 and 4: `endpoint_hostname`, else the first entry of `addresses`; when both are empty the no-host fallback strings are used. `profile` is `st.routing_profile`.
- State 3 (running, `device_up` false): head `Connecting to %s` formatted with the host, or `Connecting to the server` when there is no host; detail `The client is running but the tunnel is not established yet. If this persists, the client log below says why.`
- State 4 (success) — profile-aware, evaluated BEFORE the legacy return, in this order:
  - `st.routing_profile` truthy and `st.routing_mode === 'bypass'` → head `Tunnel works, profile %s — only the VPN rules go through %s`.format(profile, host), or `Tunnel works, profile %s — only the VPN rules go through the tunnel`.format(profile) when there is no host; detail `Everything else stays direct.`
  - `st.routing_profile` truthy (vpn profile) → head `Tunnel works, profile %s — everything except the bypass rules goes through %s`.format(profile, host), or `Tunnel works, profile %s — everything except the bypass rules goes through the tunnel`.format(profile) when there is no host; detail `The bypass rules are sent out directly.`
  - no profile → head `All LAN traffic goes through %s` formatted with the host, or `All LAN traffic goes through the tunnel`; detail `Domains from the "do not bypass" list are sent out directly.`
- State 2 detail depends on `enabled` (see Task 3). State 1's detail references `install.sh`, not the log.
- The UI strings reference "install.sh" and "the client log below"; no UI string mentions the Diagnostics tab (that only appeared in old comments, which are not contract).

### `_()` key list details (baseline, extracted 2026-09-09)

51 unique keys, 54 call sites (labels `Update` and `Update check` each occur in two branches; the six profile verdict strings and the two Mode strings add the 8 call sites beyond the pre-rebase 46). All 51 are present in `po/ru/trusttunnel.po` — 0 missing. Byte-level specifics that the diff must preserve:

- Format placeholders: `%s` in `Connecting to %s`, `All LAN traffic goes through %s`, the four profile verdict heads (`Tunnel works, profile %s — only the VPN rules go through %s` and `Tunnel works, profile %s — everything except the bypass rules goes through %s` each have TWO `%s`), `%s is available`, `the installed version is newer than the latest release (%s)`.
- Non-ASCII: U+2014 em dash in `unavailable — no network and no cached result`, in all four profile verdict heads, and in the two Mode strings (`Profile %s — bypass, only the VPN rules are tunneled`, `Profile %s — VPN, everything except the bypass rules is tunneled`); U+2026 ellipsis in `Running…` and `Checking…`.
- Embedded double quotes: `Press Start to run it now, or turn on "Start on boot" in Settings.` and `Domains from the "do not bypass" list are sent out directly.`

### CI gates (exact commands from `.github/workflows/ci.yml`)

- **JS syntax gate** (ci.yml "JavaScript syntax", lines 210–233): parses each view file wrapped in a function expression, because views end with a top-level `return` and `node --check` is unreliable on them. Single-file form (pass the file path; the CI form passes the whole directory glob):

```bash
node -e '
  const fs = require("fs");
  const vm = require("vm");
  let failed = false;
  for (const f of process.argv.slice(1)) {
    const src = fs.readFileSync(f, "utf8");
    try {
      new vm.Script("(function(){\n" + src + "\n})");
      console.log("ok: " + f);
    } catch (e) {
      failed = true;
      console.error(f + ": " + e.message);
    }
  }
  if (failed) process.exit(1);
' packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js
```

- **LuCI require gate** (ci.yml "LuCI module requires", lines 191–208): for each module in `ui dom rpc uci form view poll fs network validation`, a *call* (`module.name(`) without a matching `'require module'` line fails. Single-file form:

```bash
mods="ui dom rpc uci form view poll fs network validation"
f=packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js
fail=0
for m in $mods; do
  grep -qE "(^|[^A-Za-z0-9_.$])${m}\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(" "$f" || continue
  grep -qE "^'require ${m}'" "$f" && continue
  echo "::error file=$f::${m} is used but not declared with 'require ${m}'"
  fail=1
done
[ "$fail" = 0 ] && echo "every LuCI module used is declared"
exit "$fail"
```

ci.yml's JS gate has no negative control (unlike its ucode gate) — Task 1 adds one so the gate is proven to detect breakage before we rely on it.

## Entities

N/A — the view persists nothing and defines no data entities. The four RPC response shapes it consumes are documented under Contracts (from the TT-09 issue; do not read shapes from the inherited file).

## Contracts

The view consumes exactly four `luci.trusttunnel` methods (declared via `rpc.declare`, params arrays as listed):

| Method | Params | Response keys (TT-09) | View usage |
| --- | --- | --- | --- |
| `status` | `[]` | `enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses[], client_installed, routing_profile, routing_mode, vpn_mode` (full 14-key set) | initial `load()`, then polled every 10 s; drives verdict (incl. the profile-aware success branches) + facts (Mode row profile variants) |
| `service` | `['action']` | `{code, output}`; `not_running:true` on failed start; `{error}` on bad action | Start/Stop/Restart buttons |
| `versions` | `['refresh']` | `client, package, latest, update_available, checked_at, stale, ahead` | once at render with `false`; "Check now" with `true` |
| `log` | `['lines']` | `{lines: [...]}` | polled every 10 s with `80` |

Behavioral notes the view must implement (from the TT-10 issue): `service` start result with `not_running:true` → warning notification; non-zero `code` → show `output` in a `<pre>`; otherwise "Done". `versions` with `latest == null` → "unavailable" line (not "up to date"); `stale` → extra cached-result row.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js` | Rewrite | Independent reimplementation of the Status view per the TT-10 contract; only file changed by this issue |
| `/tmp/tt10-keys-baseline.txt` | Create (temp, NOT committed) | Baseline `_()` key list captured in Task 1 before the file is replaced; oracle for the key-diff |
| `/tmp/tt10-keys-new.txt` | Create (temp, NOT committed) | Key list of the new implementation; diffed against baseline in Task 7 |

The repo must stay clean: no `*.old` copies, no old-vs-new diffs committed (PRD "Implementation Decisions" — verified in Task 7).

## Tasks

### [x] Task 1: Baseline — prove the gates green and capture the key-list oracle

**Files:**

- Read: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js` (oracle only — do not copy)
- Read: `.github/workflows/ci.yml` (gate commands, lines 191–233)

- [x] **Step 1: Write the failing check — negative control for the JS gate**

Create a temp file that must be rejected, proving the gate detects breakage (ci.yml only has this control for ucode):

```bash
printf 'let x = ;\n' > /tmp/tt10-broken.js
node -e '
  const fs = require("fs");
  const vm = require("vm");
  let failed = false;
  for (const f of process.argv.slice(1)) {
    const src = fs.readFileSync(f, "utf8");
    try {
      new vm.Script("(function(){\n" + src + "\n})");
      console.log("ok: " + f);
    } catch (e) {
      failed = true;
      console.error(f + ": " + e.message);
    }
  }
  if (failed) process.exit(1);
' /tmp/tt10-broken.js
```

- [x] **Step 2: Run the negative control to verify it fails**

Run: the command above. Expected: FAIL — exit code 1 with a `SyntaxError` naming `/tmp/tt10-broken.js`.

- [x] **Step 3: Run both ci.yml gates on the current view directory**

Run: the JS syntax gate with the directory glob `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/*.js`, then the LuCI require gate loop over the same directory (`mods="ui dom rpc uci form view poll fs network validation"`). Expected: PASS for every file, including the current `status.js`. This is the green baseline the rewritten file must reproduce.

- [x] **Step 4: Capture the baseline key list and check `.po` coverage**

Extract the sorted unique `_()` keys of the current view into the oracle file, and verify every key exists in the `.po`:

```bash
node -e '
  const fs = require("fs");
  const s = fs.readFileSync("packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js", "utf8");
  const u = [...new Set([...s.matchAll(/_\(\x27([^\x27]*)\x27\)/g)].map(m => m[1]))].sort();
  u.forEach(k => console.log(JSON.stringify(k)));
' > /tmp/tt10-keys-baseline.txt
wc -l /tmp/tt10-keys-baseline.txt
```

Run a coverage check: parse `msgid` lines from `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`, unescape them, and diff against the baseline. Expected: all 51 keys covered, 0 missing (verified in research: 51 unique keys / 54 call sites, all present).

**Verification**: negative control fails, both gates pass on the untouched directory, `/tmp/tt10-keys-baseline.txt` contains 51 sorted unique keys (54 call sites), `.po` coverage 0 missing.

### [x] Task 2: Skeleton — requires, RPC declarations, minimal `view.extend`

**Files:**

- Rewrite: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

- [x] **Step 1: Write the failing test — require-gate fixture**

Create a fixture in `/tmp` (not in the repo) that calls `ui` without declaring it, proving the gate catches an undeclared module:

```bash
printf "%s\n" \
  "'use strict';" \
  "'require view';" \
  "return view.extend({ render: function() { ui.addNotification(null, E('p', {}), 'info'); return E('div', {}); } });" \
  > /tmp/tt10-norequire.js
```

- [x] **Step 2: Run the test to verify it fails**

Run: the LuCI require gate single-file form against `/tmp/tt10-norequire.js`. Expected: FAIL — exit 1 with `ui is used but not declared with 'require ui'` — proves the gate guards exactly what the skeleton must satisfy.

- [x] **Step 3: Write the minimal implementation**

Write the new `status.js` with: `'use strict';`; the five `'require ...'` lines (`view`, `poll`, `rpc`, `ui`, `dom`); the four `rpc.declare` declarations per the Contracts table (`status` no params, `service`/`versions`/`log` with their params arrays, object `luci.trusttunnel`); and `return view.extend({ ... })` containing a minimal `render` that returns a single heading with the page title key `TrustTunnel`. No other methods yet. Write the file from the contract only.

- [x] **Step 4: Run the gates to verify they pass**

Run: the JS syntax gate on the single file, then the LuCI require gate on the single file. Expected: PASS on both (requires used are all declared; syntax wraps cleanly in the loader function).

**Verification**: both gates pass on the single file; `git diff --stat` shows only `status.js` modified; no other view file touched.

### [x] Task 3: `verdict()` and the verdict banner

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

- [x] **Step 1: Write the failing check — key-list prefix diff**

Run the key-extraction command from Task 1 Step 4 against the current file into `/tmp/tt10-keys-new.txt` and diff against the baseline. Expected: FAIL — the skeleton has 1 key, the baseline has 51; the diff shows the missing verdict/status strings. This is the TDD loop's "red": the implemented contract keys must appear before the check is green.

- [x] **Step 2: Run the check to verify it fails**

Run: `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt`. Expected: FAIL (baseline keys missing from the new file).

- [x] **Step 3: Write the minimal implementation — `verdict(st)` and `renderVerdict`**

Add to the view:

- A `verdict(st)` helper returning one of four objects `{level, head, detail}` evaluated in this order (contract from the issue):
  1. `client_installed` falsy → `danger`, head key `The TrustTunnel client is not installed`, detail key `Run install.sh: the package does not ship the client binary.`
  2. `running` falsy → `danger` when `enabled` truthy (head `The service is not running`, detail `Press Start and read the client log below.`), `info` when disabled (head `The service is off`, detail `Press Start to run it now, or turn on "Start on boot" in Settings.`)
  3. `device_up` falsy → `warning`, head `Connecting to %s`.format(host) or `Connecting to the server` when no host, detail `The client is running but the tunnel is not established yet. If this persists, the client log below says why.`
  4. otherwise → `success` — profile-aware, checked BEFORE the legacy return, in this order:
     a. `st.routing_profile` truthy and `st.routing_mode === 'bypass'` → head `Tunnel works, profile %s — only the VPN rules go through %s`.format(st.routing_profile, host), or `Tunnel works, profile %s — only the VPN rules go through the tunnel`.format(st.routing_profile) when no host; detail `Everything else stays direct.`
     b. `st.routing_profile` truthy (vpn profile) → head `Tunnel works, profile %s — everything except the bypass rules goes through %s`.format(st.routing_profile, host), or `Tunnel works, profile %s — everything except the bypass rules goes through the tunnel`.format(st.routing_profile) when no host; detail `The bypass rules are sent out directly.`
     c. no profile → head `All LAN traffic goes through %s`.format(host) or `All LAN traffic goes through the tunnel` when no host; detail `Domains from the "do not bypass" list are sent out directly.`
  - `host` = `st.endpoint_hostname || (st.addresses || [])[0] || ''`.
- A `renderVerdict(st)` method: for `success` render an empty `div`; otherwise render a `div` with class `alert-message <level>` containing a `strong` with the head, plus the detail text (after a line break) when the detail is non-empty.
- Wire `renderVerdict` into `render` output above the heading content. No facts/versions/buttons/polling yet.

- [x] **Step 4: Run the check to verify it passes**

Run: JS syntax gate (single file), LuCI require gate (single file), and the key-extraction + diff from Step 1. Expected: gates PASS; the diff now shows fewer missing keys — the 18 verdict/status strings present.

**Verification**: gates pass; the 18 verdict-state keys appear in the extracted list — states 1–3 (9 keys: heads/details plus the two no-host fallbacks) and the three success branches (9 keys: bypass-profile head/no-host head/detail, vpn-profile head/no-host head/detail, legacy head/no-host head/detail); self-review: the two profile branches precede the legacy `success` return in `verdict()`, exactly as the issue contract orders them; `State`/`working` arrive in Task 4 with the facts table; no old code text copied (self-review: file reads as fresh expression of the contract).

### [x] Task 4: Facts and Versions tables with the "Check now" button

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

- [x] **Step 1: Write the failing check — key-list prefix diff**

Run the extraction+diff again. Expected: FAIL — the facts/versions keys (`Now`, `Versions`, `Mode`, `Profile %s — bypass, only the VPN rules are tunneled`, `Profile %s — VPN, everything except the bypass rules is tunneled`, `Everything through VPN`, `State`, `working`, `Server`, `Package`, `unknown`, `TrustTunnel client`, `not installed`, `Update check`, `Update`, `unavailable — no network and no cached result`, `%s is available`, `run install.sh again to update`, `the installed version is newer than the latest release (%s)`, `up to date`, `GitHub unreachable, showing the last cached result`, `Check now`, `Checking…`) are still missing.

- [x] **Step 2: Run the check to verify it fails**

Run: `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt`. Expected: FAIL.

- [x] **Step 3: Write the minimal implementation — `renderFacts`, `renderVersions`, `row`**

Add:

- A `row(label, value)` helper building a two-cell table row (label cell `td.left` ~30% width, value cell).
- `renderFacts(st)` — a `table.table` built in this order:
  - when `verdict(st).level === 'success'`: row `State` → a `span` styled green/bold with key `working`;
  - row `Mode` → profile-aware: when `st.routing_profile` truthy — `st.routing_mode === 'bypass'` → `Profile %s — bypass, only the VPN rules are tunneled`.format(st.routing_profile), else (vpn profile) → `Profile %s — VPN, everything except the bypass rules is tunneled`.format(st.routing_profile); when no profile → `Everything through VPN`;
  - when `st.endpoint_hostname` truthy: row `Server` → a `code` element with the hostname value.
- `renderVersions(v, box)` — a `div` containing a `table.table` with:
  - row `Package` → `v.package || _('unknown')`;
  - row `TrustTunnel client` → `v.client || _('not installed')`;
  - exactly one Update-state row, first matching rule wins:
    - `v.latest == null` → label `Update check`, text `unavailable — no network and no cached result`;
    - `v.update_available` → label `Update`, a `strong` with `%s is available`.format(v.latest), a separator, and `run install.sh again to update`;
    - `v.ahead` → label `Update`, text `the installed version is newer than the latest release (%s)`.format(v.latest);
    - else → label `Update`, text `up to date`;
  - when `v.stale` truthy: extra row `Update check` → `GitHub unreachable, showing the last cached result`;
  - below the table: a `button` (class `cbi-button cbi-button-neutral`) with key `Check now` whose click handler calls `callVersions(true)` and, on success, re-renders the versions block in place (replacing the container content with `renderVersions(nv, box)`); on failure shows a danger notification with the error message.
- In `render`: create the versions box initially containing an `em` with key `Checking…`, and fire `callVersions(false)` once at render time, replacing the box content with `renderVersions(v, box)`; on failure show the error as an `em` inside the box.
- Place the two tables side by side under headings `Now` and `Versions` in a two-column flex container (each column `flex:1 1 24em;min-width:0` so they stack on narrow screens).

- [x] **Step 4: Run the check to verify it passes**

Run: both gates on the single file, then the extraction+diff. Expected: gates PASS; the diff shows all facts/versions keys present, including the two profile Mode strings.

**Verification**: gates pass; key diff shows the full facts/versions set (23 keys incl. `Profile %s — bypass, only the VPN rules are tunneled` and `Profile %s — VPN, everything except the bypass rules is tunneled`); the Mode row branches on `st.routing_profile`/`st.routing_mode` (grep the file for `routing_profile` in `renderFacts`); `Check now` click path is present (grep the file for `callVersions(true)` and `renderVersions`).

### [x] Task 5: Start/Stop/Restart buttons and `handleAction`

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

- [x] **Step 1: Write the failing check — key-list prefix diff**

Run the extraction+diff. Expected: FAIL — button keys (`Start`, `Stop`, `Restart`, `Please wait`, `Running…`, `The service did not start. The client log below says why.`, `Command failed`, `Done`) are still missing.

- [x] **Step 2: Run the check to verify it fails**

Run: `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt`. Expected: FAIL.

- [x] **Step 3: Write the minimal implementation — `handleAction` and buttons**

Add:

- `handleAction(action, ev)`:
  - show a modal: title `Please wait`, body a `p.spinning` with key `Running…`;
  - `callService(action)` then hide the modal and branch on the result:
    - `res.not_running` truthy → warning notification with `The service did not start. The client log below says why.`;
    - `res.code !== 0` → warning notification whose body is a `pre` containing `res.output || _('Command failed')`;
    - else → info notification with `Done`;
  - on rejection: hide the modal, show a danger notification with the error message (`e.message || String(e)`).
- In `render`, below the verdict box: three buttons — `Start` (class `cbi-button cbi-button-apply`), `Stop` (`cbi-button cbi-button-reset`), `Restart` (`cbi-button cbi-button-action`) — each wiring its click to `handleAction` with the matching action string (`start`/`stop`/`restart`), separated by spaces.

- [x] **Step 4: Run the check to verify it passes**

Run: both gates on the single file, then the extraction+diff. Expected: gates PASS; all 8 button/modal keys present in the diff.

**Verification**: gates pass; diff shows button keys; the four result branches (`not_running`, `code !== 0`, success, rejection) are all present in `handleAction`.

### [x] Task 6: Polling, `load()`, and the full page layout

**Files:**

- Modify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`

- [x] **Step 1: Write the failing check — key-list diff + behavioral gap**

Run the extraction+diff. Expected: still FAIL only if `Client log` is missing (the last missing key); all other 50 keys present. Also run both gates. The behavioral gap (no polling, no initial status) is not caught by gates — note it for the manual checklist.

- [x] **Step 2: Run the check to verify it fails**

Run: `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt`. Expected: FAIL (missing `Client log` key, if not yet added).

- [x] **Step 3: Write the minimal implementation — `load`, polls, layout**

Add to the view:

- `load()` returning `callStatus()` — the view lifecycle provides the initial status to `render`.
- In `render`, the remaining pieces:
  - a client-log `pre` box (inline style `max-height:22em;overflow:auto;margin:0`);
  - two polls, both registered in `render`:
    - every 10 s: `callStatus()` → replace the verdict box content with `renderVerdict(s)` and the facts box content with `renderFacts(s)`;
    - every 10 s: `callLog(80)` → set the log box text to `(r.lines || []).join('\n')`;
  - full page layout: page title `TrustTunnel`; section 1 (verdict box + buttons); section 2 (the `Now`/`Versions` flex pair); section 3 with heading `Client log` and the log box. Use the LuCI container classes `cbi-map` / `cbi-section`.
- Remove any leftover skeleton content; the file now implements the whole contract.

- [x] **Step 4: Run the check to verify it passes**

Run: both gates on the single file, then the extraction+diff. Expected: gates PASS; `diff` reports the lists identical (all 51 unique keys).

**Verification**: gates pass; `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt` is empty (identical — 51 keys); grep confirms two `poll.add(..., 10)` registrations (status, log) and exactly one `callVersions(false)` plus one `callVersions(true)` (Check now).

### [x] Task 7: Full verification — gates, key diff, `.po` coverage, manual LuCI checklist, clean tree

**Files:**

- Verify: `packages/luci-app-trusttunnel/htdocs/luci-static/resources/view/trusttunnel/status.js`
- Verify: `packages/luci-app-trusttunnel/po/ru/trusttunnel.po`

- [x] **Step 1: Run the full ci.yml JS gates on the view directory**

Run: the JS syntax gate over `.../view/trusttunnel/*.js` and the LuCI require gate over the same directory (exact ci.yml commands from Task 1). Expected: PASS on every file.

- [x] **Step 2: Run the key-list diff and `.po` coverage check**

Run: extract the new key list to `/tmp/tt10-keys-new.txt` (same command as baseline) and `diff -u /tmp/tt10-keys-baseline.txt /tmp/tt10-keys-new.txt`. Expected: empty output — 51 unique keys, byte-identical (including the `%s` placeholders — two of them in the two-host profile heads — the em dashes in the profile and Mode strings, the ellipses, and the embedded quotes). Then re-run the `.po` coverage check from Task 1 Step 4. Expected: 0 keys missing — 51/51 — the existing translation maps every string.

- [x] **Step 3: Manual LuCI checklist (stubbed RPC responses)**

On a device/rootfs with LuCI, verify each state by controlling the backend inputs (removing the client binary, toggling `enabled`, observing the real device state; the RPC responses come from the TT-09 backend):

1. Client not installed (`client_installed:false`) → full-width danger banner with the install.sh detail; no State row; buttons still render.
2. Disabled (`enabled:false`, not running) → info banner "The service is off"; State row absent.
3. Enabled but not running → danger banner "The service is not running".
4. Running, `device_up:false` → warning "Connecting to …" with the endpoint hostname (or the first address); verify the no-host fallback by clearing both.
5. Working — no profile (legacy success): no banner; facts table shows State=working (green), Mode row "Everything through VPN", Server; verdict text visible nowhere as a bar.
6. Working — bypass profile (`routing_profile` set, `routing_mode:'bypass'`): no banner; State=working; Mode row "Profile %s — bypass, only the VPN rules are tunneled"; the bypass success head/detail strings ("Tunnel works, profile %s — only the VPN rules go through %s" / "…through the tunnel" / "Everything else stays direct.") are byte-identical per the Step 2 diff (the success banner is intentionally empty, so the Mode row + the diff are the on-device proof).
7. Working — vpn profile (`routing_profile` set, vpn mode): no banner; State=working; Mode row "Profile %s — VPN, everything except the bypass rules is tunneled"; the vpn success head/detail strings ("Tunnel works, profile %s — everything except the bypass rules goes through %s" / "…through the tunnel" / "The bypass rules are sent out directly.") are byte-identical per the Step 2 diff.
   - To drive items 6–7, assign a routing profile in vpn/bypass mode in UCI — the backend returns `routing_profile`/`routing_mode` in `status` (`vpn_mode` is derived; the view does not read it).
8. Buttons: Start (with the backend start re-check path → `not_running` warning when the service fails to start), Stop, Restart; success path shows "Done"; failure shows the `output` in a `pre`.
9. Update states: force `latest:null` (unavailable line), `update_available` (available line), `ahead` (newer-than-latest line), plain up-to-date, and `stale` (extra cached row); "Check now" re-renders the table in place and errors surface as a danger notification.
10. Polling: status + log refresh every 10 s (observe the log box and facts updating without a page reload); versions requested once on load, not on each poll (network tab / backend log shows a single non-refresh call).

> **Execution note (2026-09-09)**: no device/rootfs was available in the
> implementation environment; this step was executed as a stubbed-RPC node
> `vm` harness (`/tmp/tt10-behavior-test.js`, not committed) loading the
> shipped file with stubbed `rpc`/`view`/`E`/`ui`/`dom`/`poll`/`_`
> (LuCI-style `String.prototype.format`) — 110 assertions, 0 failed,
> covering checklist items 1–10: all four verdict states incl. the three
> success variants and the no-host fallbacks (items 1–7), button result
> branches `not_running`/`code!==0`/`Done`/rejection (item 8), all four
> update states + stale row + Check-now presence (item 9), two
> `poll.add(..., 10)` registrations + single `callVersions(false)` at
> render + poll-driven verdict/facts/log updates (item 10). The
> on-device LuCI rendering pass remains for the device-verification step.

- [x] **Step 4: Clean-tree check**

Run: `git status --porcelain` and `git log --oneline -3`. Expected: only `status.js` modified (plus the issue/plan files of this issue); no `*.old` files, no committed old-vs-new diffs; nothing else in the tree changed by this issue.

**Verification**: all four acceptance criteria of the issue are met — all 4 verdict states render as specified, including the three success variants (checklist items 1–7), polling cadence correct (item 10), buttons/update flows behave identically (items 8–9), ci.yml gates pass (step 1), translation keys unchanged (step 2: 51 unique keys, byte-identical, `.po` 51/51).

## Implementation report (2026-09-09)

- All 7 tasks executed in order; every step completed (see the checkboxes
  above). Final file: 263 lines, fresh expression written from the TT-10
  issue contract + the TT-09 RPC shapes only; the inherited file was never
  read as source (only the `_()` key extraction ran against it, which is
  contract data).
- **Gate note**: the interactive shell is zsh, which does not word-split
  unquoted `$mods`; the ci.yml require-gate loop is bash semantics. All
  require-gate runs in this issue therefore executed under `bash -c` with
  the exact ci.yml loop to mirror CI. (A zsh run would vacuously pass.)
- **Deviations**: Task 7 Step 3 executed as a stubbed-RPC node `vm`
  harness (110/110 assertions) because no device/rootfs was available; the
  on-device LuCI rendering pass remains pending. No code deviations from
  the contract: all verdict strings, button flows, poll cadence, update
  states, and the 51-key set match byte-identically.
- **Environment note**: during Task 7, a concurrent process (TT-11
  diagnostics work) modified `README.md`, `diagnostics.js`, and created
  `tests/zz_tt11_keys_baseline.txt` and `uc.out`. Those changes are not
  part of this issue and were left untouched; this issue changed only
  `status.js` and this plan file.
- Nothing committed; `/tmp/tt10-keys-baseline.txt`,
  `/tmp/tt10-keys-new.txt`, `/tmp/tt10-behavior-test.js` are the temp
  oracle/harness artifacts (not in the repo).

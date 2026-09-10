# Issue Validation Report: TT-09 rpcd ucode backend (clean-room reimplementation)

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-09/issue.md`
- **Plan**: `.sdd/.current/issues/TT-09/plan.md`
- **Overall Status**: Incomplete
- **Validation attempt**: 1

## Summary

The reimplementation exists, compiles, and passes every gate that was
actually run, but byte-level equivalence with the oracle (the pre-reimplementation
file at `44db74c`, which the goldens were supposed to pin) does **not** hold on
several branches that the committed goldens do not cover. Live old-vs-new
comparisons in the dockerized lab (same stub rootfs, same pinned ucode) proved
concrete differences in `diagnose` check statuses, `versions` (crash on
non-JSON input; stale-fallback response), `import_config` error text, and
`status.device` (`null` vs `""`). The `versions` goldens are empty (0 bytes) —
the harness passes them vacuously because the new `versions` throws in the lab
exactly as it did when the goldens were captured. The contract test is also
not wired into `tests/run.sh`/CI (`tests/backend/` is outside the
`tests/test_*.sh` glob), and the plan's helper-probe, scenario matrix, capture
mode, and import side-effect assertions were not implemented.

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 1 | 7 | 0 | 8 |
| Acceptance Criteria | 2 | 2 | 1 | 5 |
| Entities | 2 | 1 | 1 | 4 |
| Contracts | 5 | 3 | 1 | 9 |
| Guidelines | 0 | 0 | 0 | 0 (no AGENTS.md) |

## Task Status

- [x] **Task 1: Baseline — gate tooling, harness, golden capture** - PARTIAL: Dockerfile/driver.uc/rootfs/goldens/test_backend_contract.sh exist and the runner works (29 assertions, 0 failed, after rebuilding `tt-ucode-gate` from scratch — the image was absent). Deviations from the plan: no `ucode-check.sh`, no `stubs/`, no `scenarios/<name>/setup.sh` matrix (plan lists 15 scenarios; only two states are captured: baked rootfs and the privileged healthy state), no `TT_CAPTURE=1` mode, no `harness.uc --helpers` probe. The `versions` goldens (`versions.json`, `versionsrefreshtrue.json`) are 0-byte — the oracle returns a valid object in the same lab, so these goldens are invalid; the assertions pass only because the new method also crashes there (see Issues 1–2).
- [x] **Task 2: Helpers (chunk b)** - PARTIAL: all 12 helpers implemented and contract-shaped (imports, constants, `srand(time())` verified; `vercmp`, `shq`, `tmp_path`, `records`, `routing_status`, `parse_ping` match the oracle line-for-line semantically). The planned `--helpers` unit probe does not exist. Edge deviations: `endpoint_host` on a bare IPv6 without port returns `"2001"` (new) vs the full address (old); `sh`/`sh_out` popen-failure code `127` vs old `-1` (unreachable in practice).
- [x] **Task 3: `status` + `service` + `log` (chunk c)** - PARTIAL: golden states byte-match (baked + healthy, incl. `routing_profile`/`routing_mode`/`vpn_mode` and the exact key order). Deviation: with no routing device, `status.device` is `""` (new) vs `null` (old/plan Task 3 "null when absent") — verified live (see Issue 6). `service`/`log` byte-match and are statically identical on all branches.
- [x] **Task 4: `ping` + `probe` (chunk d)** - PASS: goldens byte-match (`results` envelope, `parse_ping` incl. null timings on loss, no-address error, probe no-device error strings, `'request failed'` fallback) and the code is statically identical to the oracle on every branch.
- [x] **Task 5: `check_domain` + `versions` (chunk e)** - PARTIAL: `check_domain` byte-matches and is statically identical (profile-aware list keys, six reason strings, case-insensitive, empty error). `versions` is not verified (empty goldens) and deviates: it throws on non-JSON curl output and on unparseable cache files (no try/catch, oracle wraps both in try/catch), and its network-failure fallback returns `checked_at = now` and rewrites the cache file while the oracle returns the original `checked_at` and does not rewrite (see Issues 1–3).
- [x] **Task 6: `diagnose` (chunk f)** - PARTIAL: the two captured states byte-match (baked 14 entries incl. the fail-no-device path; healthy 18 entries incl. the warn-only `MTU matches settings` entry). Live old-vs-new comparison in a third state (service disabled, config not applied, no device) shows six check-status deviations: `Enabled` warn→fail, `Running` skip→fail, `Routing rule/table/nft` skip-when-not-applied→always-fail, `Firewall zone` warn→fail, `Tunnel device` fail-when-running→skip, `Traffic goes through the tunnel` warn/skip branches→always fail (see Issue 4).
- [x] **Task 7: `import_config` (chunk g)** - PARTIAL: success paths byte-match (all 12 keys, shape parser, deeplink + file mode; verified in both golden sets). Deviations: no-recognisable-fields returns `{error: 'setup_wizard failed'}` instead of the oracle's `{error: 'setup_wizard produced no recognisable endpoint fields'}` (verified live, Issue 5); whitespace-only text is not rejected (`length(trim(text))` in the oracle vs `length(text)`); the planned runner assertions on stub logs (0600 at wizard-call time, both temp files unlinked, zero `uci` invocations) were not implemented.
- [x] **Task 8: Final gates — full equivalence (chunk h)** - PARTIAL: syntax gate exit 0, negative control exit 255 (when the broken file is created inside the container; note a bind-mounted single file is seen as a directory by this docker setup — the control must run in-container), module-import grep 17/17 fail=0, full harness 29/29, `sh tests/run.sh` all green. Missing: the `TT_CAPTURE=1` re-capture key-diff (no capture mode exists in the runner) and the live ubus comparison (no device available — recorded as a documented deviation, the dockerized goldens remain the substitute oracle, as the plan itself allowed).

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | All 9 methods re-expressed with new code and identical behavior | PARTIAL | Clean-room re-expression verified (only 158/1400 lines identical to the inherited file, all contract-mandated strings/boilerplate; 634 old-only/664 new-only lines). Identical behavior does not hold on the branches listed in Issues 1, 4, 5, 6 (proven live in the lab, old file at `44db74c` vs new). |
| 2 | ucode syntax check passes (ci.yml gate) | MET | `docker run --rm -v "$PWD":/ws -w /ws tt-ucode-gate sh -c '/opt/ucode/build/ucode -L "/opt/ucode/build/*.so" -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel'` → exit 0; negative control `let x = ;` → exit 255 (in-container). Note: in this ucode build `-c` means *compile to bytecode*, and without `-o` it writes a compiled `uc.out` into the working directory — delete it after the gate (not gitignored), and the negative control must write the broken file inside the container (a host file bind-mounted as a single file is seen as a directory by this docker setup). |
| 3 | Module-import check passes (every used module imported) | MET | ci.yml grep loop (lines 122–140): 17 pairs, `fail=0`; used functions (math rand/srand; fs readfile/writefile/popen/access/unlink/mkdir/chmod) all present in the import line. |
| 4 | Response key sets byte-match the contract | PARTIAL | All 29 committed goldens pass (baked + healthy states). Not a byte-match on uncovered states: `status.device` `""` vs `null` (Issue 6); `versions` produces no output at all in the lab (Issue 2); `import_config`/`diagnose` error/status strings differ (Issues 4–5). |
| 5 | `versions` cache behavior (fresh/stale/network-failure) matches | NOT MET | No golden evidence (0-byte goldens, vacuous pass — the new method crashes in the lab). Live comparison shows the oracle returns `{client:"1.1.5", package:"1.0.15-r1", latest:null, …}` while the new method throws on the stub's non-JSON curl output; the stale-fallback response (`checked_at`) and cache-file rewrite also differ (Issues 1–3). |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| rpcd object `luci.trusttunnel` | 9 methods × `{args, call}`; args descriptors match the contract exactly (status {} · service {action:'restart'} · ping {target:''} · probe {} · check_domain {domain:''} · log {lines:100} · diagnose {} · versions {refresh:false} · import_config {text:''}) | top-level `return` object keyed `'luci.trusttunnel'` (verified via driver.uc `require()` — same mechanism rpcd uses) | response keys per method: verified on covered states; deviations on uncovered branches (Issues 1–6) | PARTIAL |
| Records TSV (`settings.tsv`) | `records()`/`first()` parse repeated keys → arrays, skip tab-less lines; `routing_status()` early-outs all-false when the file is absent | consumed read-only; profile keys (`routing_profile.name/mode/vpn_rules/bypass_rules`) resolved | `device: ''` default vs plan's `device: null` | PASS |
| Release cache (`release.json`) | `{tag, checked_at}` written on success; TTL 21600 | freshness basis differs (new: JSON `checked_at`; plan/oracle: file `mtime`); unparseable JSON throws in the new code vs "ignored (try/catch)" per plan D8 | stale-fallback rewrites the file and returns `checked_at=now` vs oracle's no-rewrite + original timestamp | FAIL |
| Secret temp files (`/tmp/.tt-*`) | `write_secret_tmp` = writefile + chmod 0600; `tmp_path` = `%08x%04x` time+rand; unlinked in `import_config` on all paths | `srand(time())` at load; `rand() % 65536` | statically correct (0600, unlink, unpredictable names); not asserted by the runner | PASS |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| `luci.trusttunnel.status` | GET (read) | PARTIAL | Key set/order byte-match on goldens; `device` `""` vs `null` when absent (Issue 6) |
| `luci.trusttunnel.service` | action start/stop/restart/reload | PASS | restart/start/bogus goldens byte-match; `not_running`/`unsupported action` statically identical |
| `luci.trusttunnel.ping` | target optional | PASS | results envelope, null avg on loss, no-address error — identical |
| `luci.trusttunnel.probe` | — | PASS | tunnel/direct ip|error incl. no-device strings — identical |
| `luci.trusttunnel.check_domain` | domain | PASS | profile-aware keys, six reason strings, empty error — identical |
| `luci.trusttunnel.log` | lines | PASS | `logread -e trusttunnel | tail -n N`, trim → `[""]` on empty — identical |
| `luci.trusttunnel.diagnose` | — | PARTIAL | 18-check structure/labels/details/hints byte-match on captured states; six branch statuses deviate (Issue 4) |
| `luci.trusttunnel.versions` | refresh | FAIL | untested (empty goldens); crash on non-JSON; stale-fallback differs (Issues 1–3) |
| `luci.trusttunnel.import_config` | text | PARTIAL | 12-key success byte-matches; unrecognisable-field error text deviates (Issue 5) |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| AGENTS.md code guidelines | N/A | No `AGENTS.md` in the repo; no project guidelines to check. Clean-room rule from the issue/plan verified separately: the new file is new expression (see AC 1 evidence; no `*.old`/`*.bak` copies in the tree). |

## Issues Found

1. **`versions` throws on non-JSON network response and unparseable cache file**
   - Location: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` lines 626 (`json(cached)`) and 648 (`json(r.out)`) — no try/catch.
   - Description: the oracle wraps both `json()` calls in try/catch (old lines ~564–579 and ~592–595). In the lab, the curl stub's non-JSON body makes the new method crash with `Syntax error: Trailing garbage after JSON data` (exit 254, empty stdout); the oracle returns a normal object in the same environment. On a real router this is the captive-portal/proxy-error-page case (exit 0 + HTML) and the corrupted-cache case — the ubus call fails outright instead of degrading to `latest: null` / cache fallback.
   - Impact: acceptance criterion 5 (versions cache behavior) is not met; a live regression vs the oracle.
   - Recommendation: wrap both `json()` calls in try/catch (ignore unparseable input), matching the oracle and plan D8 ("unparseable JSON → ignored (try/catch)").
   - Resolved:
2. **`versions` goldens are empty — the cache matrix is not verified at all**
   - Location: `tests/backend/goldens/versions.json`, `tests/backend/goldens/versionsrefreshtrue.json` (0 bytes) and `tests/backend/test_backend_contract.sh` (`golden_call` maps both to `versions`).
   - Description: the oracle produces `{ "client": "1.1.5", "package": "1.0.15-r1", "latest": null, … }` in the identical lab; an empty golden can only have come from a crash. The runner asserts `"" == ""` — a vacuous pass that would also pass a broken or absent method. Fresh/stale/network-failure/behind-installed/opkg behaviors from the plan's Task 5 Step 4 are unproven.
   - Impact: acceptance criterion 5 has zero evidence; the harness actively hides the crash from Issue 1.
   - Recommendation: capture real versions goldens from the oracle (stub curl returning JSON, controlled cache mtimes per the plan's versions-stale-cache/net-fail/cache-behind scenarios) and re-run; the current implementation will fail until Issue 1 is fixed.
   - Resolved:
3. **`versions` stale-fallback response and cache write differ from the oracle**
   - Location: new lines 661–670 vs old `else if (st)` branch (old ~601–610).
   - Description: on network failure with an existing cache the new code returns `checked_at = now` and rewrites `release.json` with the new timestamp; the oracle returns the original cached `checked_at` and leaves the file untouched. Freshness basis also differs: new uses the JSON `checked_at`, oracle/plan Entities use the file `mtime` (`time() - mtime < 21600`).
   - Impact: byte-level response difference on the stale path (the UI's "checked at" display); TTL accounting shifts by the failure call.
   - Recommendation: match the oracle (report the original `checked_at`, do not rewrite the cache on failure); keep the freshness basis documented (mtime) consistent.
   - Resolved:
4. **`diagnose` check statuses deviate from the oracle on six branches**
   - Location: new lines 471–481 (`Enabled`/`Running`), 491–496 (`Tunnel device`), 525–538 (`Routing rule`/`Routing table`/`nftables table`), 540–545 (`Firewall zone`), 562–579 (`Traffic goes through the tunnel`).
   - Description: live comparison (service disabled, config not applied, no device) shows: `Enabled` disabled → new `fail` vs oracle `warn`; `Running` disabled → new `fail` + hint vs oracle `skip` + no hint (plan Task 6: "fail-if-enabled-else-skip"); rule/table/nft absent → new always `fail` vs oracle `skip` when the config is not applied (issue contract: "skip when config not applied"); `Firewall zone` absent → new `fail` vs oracle `warn`; `Tunnel device` absent while running → new `skip` vs oracle `fail`; traffic via-fail/direct-ok → new `fail` vs oracle `warn`; both fail → new `fail` vs oracle `skip`. The healthy golden only covers the traffic-ok branch; the baked golden only the fail-no-device branch.
   - Impact: the diagnostics page will color/verdict these states differently than before (verdict strings can flip, e.g. warn→fail); the views' DIAG_TEXT maps key off these statuses.
   - Recommendation: restore the oracle statuses per branch (Enabled warn, Running skip-when-disabled, skip-when-not-applied for rule/table/nft, Firewall warn, Tunnel device fail-when-running, traffic warn/skip) and add goldens for at least the disabled and not-applied states.
   - Resolved:
5. **`import_config` unrecognisable-fields error text differs**
   - Location: new lines 788–791 vs old line 760.
   - Description: with a wizard output containing only `custom_sni`, the new code returns `{error: 'setup_wizard failed'}`; the oracle returns `{error: 'setup_wizard produced no recognisable endpoint fields'}` (verified live). Plan Task 7 Step 2 and D7 specify the long text. Also: whitespace-only `text` is not rejected (`length(text)` vs oracle's `length(trim(text))`).
   - Impact: different message in the UI for schema-mismatch imports; contract text mismatch.
   - Recommendation: use the oracle's exact error string for the no-recognisable-fields path and trim-check the empty-text guard.
   - Resolved:
6. **`status.device` is `""` instead of `null` when no device exists**
   - Location: new `routing_status()` init line 190 (`device: ''`) and `status` return line 241; oracle init `device: null` (plan Task 3: "null when absent").
   - Description: live comparison with no `client device` line: new `{ "device": "" }` vs oracle `{ "device": null }`.
   - Impact: byte-level key-set difference on the no-device state (criterion 4); JS views usually treat both as falsy, so impact is likely cosmetic — but it is still a response-shape difference from the pinned oracle.
   - Recommendation: initialize `device: null` in `routing_status()` and keep `status`/`probe`/`diagnose` consistent with the oracle's null/empty semantics.
   - Resolved:
7. **The contract test is not part of `tests/run.sh`/CI and several planned harness pieces are missing**
   - Location: `tests/run.sh` (glob `tests/test_*.sh`), `.github/workflows/ci.yml` line 78 (`sh tests/run.sh`), `tests/backend/`.
   - Description: the plan promised auto-discovery ("needs no registration edit"); the test lives at `tests/backend/test_backend_contract.sh`, which the glob does not match, so CI never runs it. Missing vs the plan: `--helpers` unit probe (Task 2), the 15-scenario matrix (Task 1 Step 4), `TT_CAPTURE=1` re-capture key-diff (Task 8 Step 3), and the import_config stub-log assertions (0600, unlink, no-UCI; Task 7 Step 4).
   - Impact: the backend equivalence harness runs only when invoked manually; the deviation classes in Issues 1–6 went undetected precisely because of the missing scenarios/assertions.
   - Recommendation: move/copy the runner to `tests/test_backend_contract.sh` (or extend the run.sh glob to subdirectories), and implement at least the versions matrix, disabled/not-applied diagnose states, and import-failure cases as goldens.
   - Resolved:
8. **Minor: plan task headers left unchecked; on-device ubus comparison not run**
   - Location: `.sdd/.current/issues/TT-09/plan.md` — all eight `### [ ] Task N` headers are still `[ ]` (the 34 step boxes are `[x]`); plan Task 8 Step 4 (live ubus key-diff) was not executed because no device is available.
   - Description: cosmetic status inconsistency; the live-ubus step is the final oracle-strength link in the plan's chain.
   - Impact: none on behavior; the live comparison remains the only unperformed verification (the dockerized rootfs goldens are the substitute oracle, as the plan permits).
   - Recommendation: tick the task headers when the issue is marked Validated; run the live ubus key-diff on a router with TT-06's init script before closing, or keep the documented deviation note.
   - Resolved:

## Recommendations

1. Fix Issue 1 (wrap `json()` in try/catch) and re-capture real `versions` goldens (Issue 2) — the versions cache acceptance criterion cannot be claimed until then.
2. Restore the oracle statuses in `diagnose` (Issue 4), the `import_config` error text (Issue 5), and `status.device` null semantics (Issue 6); add goldens covering the disabled/not-applied/no-device/import-failure states so these branches are pinned.
3. Wire the backend contract test into `tests/run.sh` (or CI directly) so the harness actually runs in CI (Issue 7).
4. Implement the planned helper probe and the import side-effect assertions, or explicitly mark them out of scope in the plan.
5. Before closing: run the live ubus comparison on a device (plan Task 8 Step 4) and tick the plan's task headers.

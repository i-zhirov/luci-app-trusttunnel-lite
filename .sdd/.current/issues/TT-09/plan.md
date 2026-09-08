# Implementation Plan: TT-09 rpcd ucode backend (clean-room reimplementation)

- **Created**: 2026-09-08
- **Revised**: 2026-09-09 (revision per plan-review attempt 1)
- **Status**: Draft
- **Issue**: `.sdd/.current/issues/TT-09/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation of the 684-line rpcd ucode backend. No code copied from the inherited file — the plan describes the contract only. Chunk by helper groups, `ucode -c` compile-check (ci.yml gate, via docker) after every chunk. Baseline: run the ci.yml ucode syntax command against the current file and capture method outputs as golden fixtures."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
The ucode backend changed; the issue contract was updated. Adjust the
plan:

- **`status`** adds `routing_profile`, `routing_mode`, `vpn_mode` keys
  (from resolved records; `vpn_mode` = 'selective' iff mode 'bypass').
- **`check_domain`** is profile-aware: effective list key =
  `routing_profile.vpn_rules` (profile in bypass mode) /
  `routing_profile.bypass_rules` (profile in vpn mode) / legacy
  `domains.direct`; new reason strings per mode (exact texts in the
  issue contract). The golden captures and the scenario set (Task 1)
  need the three profile cases.
- **`diagnose`** gains the "Routing profile" config check (after the TLS
  host name check; ok/warn with the exact detail/hint strings from the
  issue contract) — the check count is up to 18.
- **`import_config`** parses ALL endpoint fields via a shape-based parser
  (`unquote`/`unlist`/`unbool` helpers): strings (incl. `custom_sni`,
  `client_random`), `upstream_protocol` → `protocol`, booleans → '1'/'0',
  `addresses` + `dns_upstreams` arrays (initial result `{addresses: [],
  dns_upstreams: []}`). The chunk-7 task must be rewritten around the
  shape-based parser, and the harness scenarios extended (every-field
  import, malformed values).
- Everything else (helpers, `versions`, `service`, `ping`, `probe`,
  `log`) unchanged.

**The actualization is authoritative.** Where any other text in this plan
(pre-rebase wording in the Summary, the R1 notes D1–D9, Contracts, File
Structure, or the Tasks) conflicts with the actualized contract, the
actualization and issue TT-09 §Contract win. Every pre-rebase fragment
flagged in the review has been updated in place below: R1/D2/D9, the
Contracts table, the Task 1 scenario matrix, and Tasks 3, 5, 6, 7.

## Summary

Re-express `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (684 lines, GPL-2.0-derived) as an independent implementation written solely from the behavioral contract in issue TT-09 §Contract. The deliverable is one file: the rpcd object `luci.trusttunnel` with exactly 9 methods (`status`, `service`, `ping`, `probe`, `check_domain`, `log`, `versions`, `diagnose`, `import_config`), the 11 helpers (`sh`, `sh_out`, `shq`, `tmp_path`, `write_secret_tmp`, `vercmp`, `uciget`, `records`, `first`, `routing_status`, `parse_ping`, `endpoint_host` — 12 counting `endpoint_host`), the constants, and `srand(time())` initialization. Response key sets are frozen — they are the contract with the JS views (TT-10..TT-12).

Equivalence is proven by an oracle chain, in order of strength:
1. **Golden byte-diff** (primary): a new behavioral test harness (dockerized ucode v0.0.20250529, same build flags as ci.yml) runs every method of the *current* implementation against a stubbed rootfs and captures canonical JSON outputs as committed fixtures; the reimplemented file must reproduce them byte-for-byte.
2. **Syntax gate**: the exact ci.yml ucode step (`ucode -L '<build>/*.so' -c <file>`, plus the `let x = ;` negative control) after every chunk.
3. **Module-import gate**: the ci.yml grep-based cross-check (every module function used must be imported).
4. **Live ubus key-diff** (final, needs a device): same UCI state, old vs new file, `ubus call` each method, diff JSON keys.

Implementation order (per issue): helpers → `status`/`service`/`log` → `ping`/`probe` → `check_domain`/`versions` → `diagnose` → `import_config` → final gates. Every chunk ends with the `ucode -c` compile-check before the next chunk starts.

## Technical Context

- **Language/Version**: ucode v0.0.20250529 (pinned by ci.yml; jow-/ucode), `'use strict';`. The ci.yml gate builds it from source with `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON` (UBUS/UCI/RTNL/NL80211/RESOLV/LOG/DEBUG OFF) and runs `ucode -L '/tmp/ucode/build/*.so' -c <file>`; a `let x = ;` file must fail the same command (negative control). Locally there is no `ucode` binary — docker (`/Users/iliazhirov/.nix-profile/bin/docker`) replicates the gate via the `tt-ucode-gate` image (Task 1 Step 1).
- **Primary Dependencies**:
  - `fs` module (built with `-DFS_SUPPORT=ON`): `popen` (stream with `.read('all')` / `.close()` returning exit code), `readfile`, `writefile`, `access`, `unlink`, `stat` (object with numeric `mtime`), `mkdir`, `chmod`.
  - `math` module (built with `-DMATH_SUPPORT=ON`, declared in `LUCI_DEPENDS` as `+ucode-mod-math`): `rand`, `srand`. `srand(time())` runs at load time; without the import `tmp_path()` throws and the whole backend fails.
  - rpcd plugin contract: rpcd compiles each file under `/usr/share/rpcd/ucode/` and executes it as a program; the **top-level `return` value is the object signature** (verified in rpcd `ucode.c`: `rpc_ucode_script_execute` → `uc_vm_execute(..., &signature)`). Each method is `{ args: <map of name→type hint>, call: function(req) { ... } }`; `req.args` carries the validated arguments; the function's returned object is the ubus reply. rpcd types: `false` → bool, integer → int32 (default), string default.
  - ucode core features relied upon: regex literals with `match`/`replace`, `split`, `substr`, `index`, `length`, `push`, `join`, `wildcard`, `trim`, `lc`, `int`, `sprintf` (`%08x`, `%J` JSON emit), `json()`, `time()`, `try/catch`, optional chaining `?.`, nullish coalescing `??`, `for..in` over arrays/objects/strings, `in` membership operator, top-level `return`.
- **Storage**: `/var/etc/trusttunnel/settings.tsv` (records; regenerated by libexec, read-only here), `/var/cache/trusttunnel/release.json` (versions cache, `{tag, checked_at}`, TTL `RELEASE_TTL = 21600`), `/tmp/.tt-*` secret temp files (0600, unpredictable names), `/var/cache/trusttunnel` directory (created on demand).
- **Testing**: new dockerized harness (see File Structure) + golden JSON fixtures captured from the current implementation; `tests/run.sh` auto-discovers `tests/test_*.sh` (glob loop), so the new runner needs no registration edit and must be self-contained. Existing `tests/lib.sh` conventions (`assert_*`, `TT_TEST_TMP`) are reused.
- **Target Platform**: OpenWrt (apk 25.12 / opkg 22.03–24.10), rpcd with ucode plugin, LuCI 24.10+; ACL `luci-app-trusttunnel` read/write split (`status|ping|probe|check_domain|log|versions|diagnose` read; `service|import_config` write).

## Research

### R1 — Actualized issue contract vs current implementation: verification result

The actualized contract (issue TT-09 §Contract as updated on main 2026-09-09) was checked line-by-line against the current file at commit c43e20a. **No contract violations found** — every constant, helper semantics, method key set (including the profile-aware `status`/`check_domain`/`diagnose`/`import_config` additions), and side effect in the actualized issue matches the code. The following precision notes (description-granularity only, no behavioral conflicts) are frozen by the Task 1 goldens; the current implementation is the byte oracle, the issue text is the summary:

- **D1** `tmp_path()` formats as `/tmp/.tt-<prefix>-%08x%04x` (time, `rand() % 65536` in hex). Issue's `<time>-<rand>` is a shape description; unpredictability and pattern are identical.
- **D2** `diagnose` emits up to **18 possible entries**, not 13 bullets: the issue compresses "Tunnel device (sysfs + MTU, warn if ≠ network.mtu)" into one bullet, but the code emits two entries — `Tunnel device` (ok/fail/skip) and a conditional `MTU matches settings` (warn only when device MTU ≠ `network.mtu`). Exact labels in order: `Endpoint address`, `Credentials`, `TLS host name`, `Routing profile`, `TrustTunnel client`, `tun device`, `Enabled`, `Running`, `Tunnel device`, `MTU matches settings`, `Route attached to the device`, `Tunnel carrier`, `Routing rule`, `Routing table`, `nftables table`, `Firewall zone`, `Endpoint reachable`, `Traffic goes through the tunnel`. The `Routing profile` entry (after `TLS host name`, config group) is ok with detail `pname + ' (' + pmode + ')'` when `routing_profile.name` is set, else warn with detail `'none — legacy full-tunnel mode'` and hint `'Assign a routing profile on the Settings page to control what goes through the tunnel.'`. Group/status/detail/hint semantics per issue; `counts` = `{ok,warn,fail,skip}`, `verdict` = fail if any fail, else warn if any warn, else ok. Healthy legacy base (no profile) = 17 entries (16 ok + the Routing profile warn); healthy with a profile assigned = 17 entries all ok; an MTU mismatch adds an 18th entry.
- **D3** `log`: output is `trim()`'d before `split` — empty `logread` output yields `{lines: [""]}` (single empty string), not `[]`. Preserve.
- **D4** `probe`: on curl failure with empty output, the error text falls back to `'request failed'`.
- **D5** `check_domain`: empty `domain` arg returns `{error: 'domain is required'}` (not enumerated in the issue, part of the surface).
- **D6** `service`: the `start` not-running branch returns literal `code: 1` plus the *action's* `output`; invalid action returns `{error: 'unsupported action'}`; `start` sleeps 1 s then re-checks `running`.
- **D7** `import_config` exact error texts: `configuration text is empty`; `setup_wizard is not installed; reinstall the trusttunnel-client package`; `setup_wizard produced no recognisable endpoint fields`; and `setup_wizard failed` fallback when the panic-noise filter leaves an empty message. Filter drops trimmed-empty lines and lines matching `thread *panicked at*`, `note: *`, `Aborted*`; survivors joined with spaces. The success parser is shape-based over `^ *([a-z0-9_]+) *= *(.*)$` lines: `unquote` for the string fields (incl. `custom_sni`, `client_random`; taken only when non-empty), `upstream_protocol` http2/http3 → `protocol`, `unbool` (`'true'`→`'1'`, `'false'`→`'0'`) for `has_ipv6`/`skip_verification`/`anti_dpi`, `unlist` for `addresses`/`dns_upstreams`, result initialized `{addresses: [], dns_upstreams: []}`; the recognisable-fields test covers `hostname`/`username`/`password`/`certificate`/`addresses` only (e.g. a config with just `custom_sni` set still errors).
- **D8** `versions`: initial values `{client: null, package: null, latest: null, update_available: false, checked_at: null, stale: false, ahead: false}`; cache path is used only when `!refresh && fresh` **and** `vercmp(tag, package) >= 0` — a fresh cache *older than installed* is nulled and a network refetch happens immediately (TTL bypass); cache JSON keys are exactly `{tag, checked_at}`; write failures go to `logger -t trusttunnel`; network failure with an existing cache falls back to it with `stale: true`; `update_available = vercmp(tag, package) > 0`, `ahead = < 0`.
- **D9** Top-level response wrappers: `ping` returns `{results: [...]}`; `service` returns `{code, output}` (or the error variants); `probe` returns `{tunnel: {ip|error}, direct: {ip|error}}`; `status` key order is `enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses, client_installed, routing_profile, routing_mode, vpn_mode`; `versions` key order `client, package, latest, update_available, checked_at, stale, ahead`; `import_config` returns the 12 keys `hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses, dns_upstreams`.

### R2 — Loading semantics for the test harness (verified from rpcd source)

rpcd obtains the object signature from the **top-level `return` value of the program** (`uc_vm_execute`). The harness must mirror this. The ucode CLI's `require()` uses the same mechanism (module value = program's top-level return value; `export` statements are an alternative module-export path — not used by this file). Task 1 contains a 5-minute spike that empirically confirms `require()` returns the object with the dockerized binary; the documented fallback is a test-time transform of a *copy* of the file: `sed '/^return {/,$d'` (the only column-0 `return {` is the final one, at the current file's line 170) and append `export { sh, sh_out, shq, tmp_path, write_secret_tmp, vercmp, uciget, records, first, routing_status, parse_ping, endpoint_host };` — this same transform is also the basis of the Task 2 helper unit probe.

### R3 — CI gate mechanics (ci.yml, lines 103–177)

Two gates concern this file:
1. **ucode module imports**: grep loop over pairs `math:rand/srand/sqrt/pow/abs`, `fs:readfile/writefile/popen/access/unlink/stat/mkdir/chmod/mkstemp/opendir`, `ubus:connect`, `uci:cursor` — fails if a function is *called* but not *imported*. The new file must import exactly the functions it uses (fs: the 9 listed in the issue; math: `rand`, `srand`). Do not import unused names (the check tolerates extra imports, but the issue's import list is the contract).
2. **ucode syntax**: build ucode v0.0.20250529 with the cmake flags above, `ucode -L '<build>/*.so' -c <file>`, then verify the same command rejects `printf 'let x = ;\n'` (negative control). Note `-c` resolves imports at compile time — `math`/`fs` .so must be present via `-L`.

### R4 — Determinism of the golden captures

Every external command the backend runs is reachable either via `PATH` (stubs: `ping`, `curl`, `logread`, `uci`, `apk`, `opkg`, `sleep`, `cat`, `ip`, `nft`) or by absolute path (stubs installed into the container rootfs: `/etc/init.d/trusttunnel`, `/usr/libexec/trusttunnel/routing`, `/opt/trusttunnel_client/trusttunnel_client`, `/opt/trusttunnel_client/setup_wizard`). Sysfs reads go through a fake `cat` that serves fixture values for `/sys/class/net/<dev>/*`. Cache freshness is controlled via `touch -d` on the real `/var/cache/trusttunnel/release.json` (container runs as root). The only volatile response field is `checked_at` (epoch seconds) — the harness normalizes it to `0` on both the actual output and the golden before diffing. Everything else is deterministic, so byte-equality of `%J`-serialized JSON is the assertion.

## Entities

### rpcd object `luci.trusttunnel`

- **Fields**: 9 methods, each `{args, call}`; exported as the top-level `return` value of the file, keyed `'luci.trusttunnel'`.
- **Relationships**: consumed by JS views (TT-10..TT-12) via ubus; ACL `luci-app-trusttunnel` (read: status/ping/probe/check_domain/log/versions/diagnose; write: service/import_config); depends on TT-06's init script surface (`/etc/init.d/trusttunnel running|start|stop|restart|reload` — TT-06 has a plan; if TT-06 changes these verbs the goldens for `status`/`service`/`diagnose` must be re-verified).
- **Validation**: exact response key sets (R1); rpcd argument type hints: `service.action` string default `restart`, `ping.target` string `''`, `check_domain.domain` string `''`, `log.lines` int 100, `versions.refresh` bool false, `import_config.text` string `''`, `status`/`probe`/`diagnose` no args.
- **States**: n/a (stateless between calls; reads live state from filesystem/kernel).

### Records TSV (`/var/etc/trusttunnel/settings.tsv`)

- **Fields**: `section.option ⇥ value` lines; repeated key per list value. Post-rebase the file also carries `routing_profile.name`/`routing_profile.mode` and the profile rule lists (`routing_profile.vpn_rules` for bypass, `routing_profile.bypass_rules` for vpn), resolved by libexec uci-export.
- **Relationships**: produced by libexec `uci-export` (TT-01 scope); consumed by `records()`, `routing_status()` (guard: missing file → early-out with all-false/`device: null`).
- **Validation**: tab-separated; line without tab or empty key skipped.

### Release cache (`/var/cache/trusttunnel/release.json`)

- **Fields**: `{tag: string, checked_at: epoch}`.
- **Validation**: freshness = `time() - mtime < 21600`; cache older than installed package is invalidated (D8); unparseable JSON → ignored (try/catch).

### Secret temp files (`/tmp/.tt-<prefix>-<time>-<rand>`)

- **Fields**: mode 0600 after write; unlinked after use.
- **Validation**: unpredictable names (time + `rand() % 65536`), written via `writefile` + `chmod(0600)` in one helper.

## Contracts

The authoritative contract is issue TT-09 §Contract (imports, constants, helper semantics, all 9 methods with exact response shapes and side effects) as actualized on main 2026-09-09 — it is the spec the implementation is written from, and the plan's clean-room rule forbids consulting the inherited file's text while writing code. Response key sets, frozen:

| Method | Response keys |
| --- | --- |
| `status` | `enabled`, `running`, `device`, `device_up`, `rule`, `table`, `nft`, `endpoint_hostname`, `addresses[]`, `client_installed`, `routing_profile`, `routing_mode`, `vpn_mode` |
| `service` | `{code, output}` · `{code: 1, output, not_running: true}` (start-failed) · `{error}` (invalid action) |
| `ping` | `{results: [{host, sent, received, loss, min, avg, max}]}` · `{error}` (no targets) |
| `probe` | `{tunnel: {ip\|error}, direct: {ip\|error}}` |
| `check_domain` | `{domain, normalized, verdict, reason}` · `{error}` (empty) |
| `log` | `{lines: [...]}` |
| `versions` | `{client, package, latest, update_available, checked_at, stale, ahead}` |
| `diagnose` | `{checks: [{group, label, status, detail, hint}], counts: {ok, warn, fail, skip}, verdict}` |
| `import_config` | `{hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]}` · `{error}` |

Exact values, error texts, and side effects are specified in the issue (plus R1 notes D1–D9). No contract files needed beyond issue.md.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` | Rewrite | The reimplementation: `'use strict';`, fs/math imports, `srand(time())`, constants, helpers, object `luci.trusttunnel` with 9 methods — written from the issue contract only. Built incrementally in Tasks 2–7. |
| `tests/test_backend_contract.sh` | Create | Shell runner: builds/uses the dockerized ucode, sets up scenario rootfs + stubs, runs `harness.uc` per (scenario, method) against the backend under test, diffs normalized output against goldens; `TT_METHODS` filter for chunked runs; `TT_CAPTURE=1` mode writes goldens (Task 1). Auto-discovered by `tests/run.sh`. |
| `tests/backend/Dockerfile` | Create | Gate image `tt-ucode-gate`: `FROM debian:bookworm`; `apt-get update -qq && apt-get install -y -qq build-essential cmake libjson-c-dev pkg-config git`; `git clone --depth 1 -b v0.0.20250529 https://github.com/jow-/ucode /opt/ucode/src`; `cmake -S /opt/ucode/src -B /opt/ucode/build` with the ci.yml flags; `cmake --build /opt/ucode/build -j"$(nproc)"`. The apt layer and the ucode build are baked into the image (docker layer cache) — no gate run re-runs apt-get. |
| `tests/backend/ucode-check.sh` | Create | Docker wrapper replicating the ci.yml ucode step: ensures the `tt-ucode-gate` image exists (`docker build` on first use only), then `-c <file>` mode (syntax gate) and `-x <args>` mode (execute `harness.uc` with the PATH stubs mounted and the rootfs stubs injected at launch), plus the `let x = ;` negative control. |
| `tests/backend/harness.uc` | Create | ucode driver: `require()`s a sandboxed copy of the backend (named `trusttunnel.uc`; spike in Task 1 picks require vs sed-export fallback), calls one method with JSON args and prints `%J` output; `--helpers` mode runs the helper unit assertions (vercmp/endpoint_host/parse_ping/shq/tmp_path/write_secret_tmp/records/first/uciget/routing_status); normalizes `checked_at` → 0. |
| `tests/backend/stubs/` | Create | PATH shims: `ping` (deterministic `-q` summary), `curl` (scenario-controlled exit/body), `logread`, `uci` (logs every invocation; serves `get`), `apk`, `opkg`, `sleep` (instant), `cat` (sysfs fixture translation, passthrough otherwise), `ip`, `nft`. Mounted read-only at `/opt/stubs` and prepended to `PATH` inside the container. |
| `tests/backend/rootfs/` | Create | Absolute-path stubs: `/etc/init.d/trusttunnel`, `/usr/libexec/trusttunnel/routing`, `/opt/trusttunnel_client/trusttunnel_client`, `/opt/trusttunnel_client/setup_wizard` (records `--endpoint_config`/`--settings` paths + modes into a log; creates settings output per scenario; can emit a Rust panic dump). Injection mechanism (Task 1 Step 4): bind-mounted read-only as `/rootfs-stubs` and copied to the absolute targets inside the container with `install -d` + `install -m 0755` in the launch chain before ucode runs. |
| `tests/backend/scenarios/<name>/setup.sh` | Create | One per scenario: writes `settings.tsv` (incl. `routing_profile.name`/`routing_profile.mode` and the profile rule lists in the profile scenarios), fixture files, cache file with controlled mtime, sysfs fixtures; wires stub behavior via scenario config (rootfs stubs are injected by the launch chain, not by setup.sh). Scenarios: `base` (legacy full-tunnel, no routing profile), `bypass-profile`, `vpn-profile`, `service-stopped`, `no-records`, `versions-stale-cache`, `versions-net-fail`, `versions-cache-behind`, `versions-opkg`, `diagnose-mtu-mismatch`, `diagnose-not-applied`, `diagnose-no-device`, `diagnose-degraded`, `import-failures`, `probe-no-device` (matrix finalized in Task 1). |
| `tests/backend/scenarios/<name>/golden/<method>.json` | Create | Captured Task 1 from the current implementation: canonical `%J` output per method per scenario (normalized `checked_at`). Committed fixtures = the oracle. |

## Tasks

Clean-room rule for all tasks: implement from the contract in `issue.md` (and the R1 notes); do not open the inherited file while writing code — it is used only by the Task 1 capture run as a behavior oracle. No `*.old` copies may be kept next to the new file.

### [ ] Task 1: Baseline — gate tooling, harness, golden capture (chunk a)

**Files:**

- Create: `tests/backend/Dockerfile`, `tests/backend/ucode-check.sh`, `tests/backend/harness.uc`, `tests/backend/stubs/*`, `tests/backend/rootfs/*`, `tests/backend/scenarios/*/setup.sh`, `tests/test_backend_contract.sh`

- [ ] **Step 1: Dockerized ucode gate on the current file**

Write `tests/backend/Dockerfile`: `FROM debian:bookworm`; `apt-get update -qq && apt-get install -y -qq build-essential cmake libjson-c-dev pkg-config git`; `git clone --depth 1 -b v0.0.20250529 https://github.com/jow-/ucode /opt/ucode/src`; `cmake -S /opt/ucode/src -B /opt/ucode/build -DCMAKE_BUILD_TYPE=Release -DFS_SUPPORT=ON -DMATH_SUPPORT=ON -DUBUS_SUPPORT=OFF -DUCI_SUPPORT=OFF -DRTNL_SUPPORT=OFF -DNL80211_SUPPORT=OFF -DRESOLV_SUPPORT=OFF -DLOG_SUPPORT=OFF -DDEBUG_SUPPORT=OFF`; `cmake --build /opt/ucode/build -j"$(nproc)"` — the exact ci.yml build, baked into the image. Build the image once: `docker build -t tt-ucode-gate tests/backend/` — the apt layer and the ucode build are cached in the image (docker layer cache), so no later gate run re-runs apt-get or the build; only the first build takes minutes and needs the network. Write `tests/backend/ucode-check.sh`: `docker run --rm -v "$PWD:/src" -w /src tt-ucode-gate /opt/ucode/build/ucode -L "/opt/ucode/build/*.so" -c <file>`.

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0, `ucode syntax ok`.

- [ ] **Step 2: Negative control**

Run: `printf 'let x = ;\n' > /tmp/broken.uc && tests/backend/ucode-check.sh -c /tmp/broken.uc` — Expected: non-zero exit (the gate proves something).

- [ ] **Step 3: Loading spike**

With the built image, copy the backend to a sandbox as `trusttunnel.uc`, and run `docker run --rm -v "$PWD:/src" -w /src tt-ucode-gate /opt/ucode/build/ucode -L "/opt/ucode/build/*.so" -e 'let m = require("./trusttunnel"); print(typeof m, Object.keys(m), "\n");'` from the sandbox. Expected: `object [ "luci.trusttunnel" ]` (module value = top-level return, same mechanism rpcd uses). If require does not capture it, implement the documented fallback in `test_backend_contract.sh`: sandbox copy via `sed '/^return {/,$d'` + append `export { sh, sh_out, shq, tmp_path, write_secret_tmp, vercmp, uciget, records, first, routing_status, parse_ping, endpoint_host };` and load with `require("./trusttunnel")` (module exports object with those functions) — record which path works in a comment at the top of `test_backend_contract.sh`.

- [ ] **Step 4: Harness + scenarios + capture goldens from the CURRENT file**

Write `harness.uc` (modes: `--method <name> --args '<json>'` → `%J` of `obj[name].call({args: JSON.parse(...)})`; `--helpers` → unit probe; normalize `checked_at` to 0), the PATH stubs (`tests/backend/stubs/`, mounted read-only at `/opt/stubs` and prepended to `PATH`), and the rootfs stub injection: `tests/backend/rootfs/` is bind-mounted read-only at `/rootfs-stubs`; the `-x` launch in `ucode-check.sh` runs `install -d /etc/init.d /usr/libexec/trusttunnel /opt/trusttunnel_client && install -m 0755 /rootfs-stubs/init.d-trusttunnel /etc/init.d/trusttunnel && install -m 0755 /rootfs-stubs/routing /usr/libexec/trusttunnel/routing && install -m 0755 /rootfs-stubs/trusttunnel_client /opt/trusttunnel_client/trusttunnel_client && install -m 0755 /rootfs-stubs/setup_wizard /opt/trusttunnel_client/setup_wizard` before invoking ucode (if bind-mount + install is rejected, the documented alternative is `docker cp` into a named container + `docker exec`).

Scenario matrix (each `setup.sh` is written from the issue's method semantics so every branch of every method is covered): `base` — legacy full-tunnel with NO routing profile (`routing_profile.name`/`routing_profile.mode` absent from the TSV): 2 endpoint addresses, hostname/user/pass, mtu=1350, table=880, 2 direct domains, routing status "device up/rule present/table present/nft present/client device tun0", init.d running, client --version 1.0.49, apk line, deterministic ping/curl/logread/nft/ip/sysfs fixtures; `bypass-profile` — same healthy state plus `routing_profile.name`/`routing_profile.mode`=`bypass` and the `routing_profile.vpn_rules` list populated; `vpn-profile` — same plus `routing_profile.mode`=`vpn` and `routing_profile.bypass_rules` populated; then service-stopped, no-records, versions-stale-cache, versions-net-fail, versions-cache-behind, versions-opkg, diagnose-mtu-mismatch, diagnose-not-applied, diagnose-no-device, diagnose-degraded, import-failures, probe-no-device. The two profile scenarios differ from base only in the `routing_profile.*` TSV keys, so `status`/`check_domain`/`diagnose` each get profile-aware goldens while base stays the legacy oracle.

Run (capture mode, against the current file): `TT_CAPTURE=1 tests/test_backend_contract.sh` — Expected: writes `tests/backend/scenarios/<name>/golden/<method>.json` for every (scenario, method) pair; non-empty files; runner then re-runs in verify mode against the same file and reports 100% pass (self-consistency of the harness).

- [ ] **Step 5: Module-import gate on the current file**

Run the ci.yml "ucode module imports" grep loop (lines 110–133) against the current file — Expected: `every module function used is imported`.

**Verification**: gate green on the current file; goldens committed (they are data — the behavioral oracle); `git status` shows only new test files + `.gitignore`. The goldens' contents must not be hand-edited later — any mismatch is a code bug.

### [ ] Task 2: Helpers (chunk b)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (imports, constants, `srand(time())`, all helpers, skeleton `return { 'luci.trusttunnel': {} };`)
- Modify: `tests/backend/harness.uc` (`--helpers` assertions)

- [ ] **Step 1: Write the helper unit assertions from the contract**

In `harness.uc --helpers`, assert: `sh`/`sh_out` merge/redirect semantics via stub `printf` (code from `p.close()`, out strings); `shq` escaping (input `a'b c` → quoted form that a stub round-trips); `tmp_path` shape `/tmp/.tt-<prefix>-…` and non-collision over 100 calls; `write_secret_tmp` returns existing file with mode 0600 (via `stat`); `vercmp` matrix (`1.0.9` vs `1.0.10` → −1; `v1.0.10` vs `1.0.10-r1` → 0; `1.0.10-r1` vs `1.0.10-r2` → 0 after `-rN` strip — per contract both drop suffixes, so equal; `1.1.0` vs `1.0.99` → 1; `abc` vs `1.0.0` → 0 unparseable); `records`/`first` on a fixture TSV (repeated keys → arrays, tab-less lines skipped, missing key → `first` default); `uciget` via stub `uci -q get` (trimmed); `routing_status` on stub output (all four flags + `client device X`, and early-out all-false when the records file is absent); `parse_ping` on a full/partial summary (sent/received/loss rounding, min/avg/max, missing lines keep defaults loss 100 / nulls); `endpoint_host` on `host:443`, `[2001:db8::1]:443`, `2001:db8::1` (no port), plain `host`.

- [ ] **Step 2: Run the helper probe against the CURRENT file**

Run: `tests/backend/ucode-check.sh -x '--helpers'` (exec mode runs the sandboxed backend + harness) — Expected: all helper assertions pass (validates the assertions against the oracle).

- [ ] **Step 3: Implement the helpers in the new file**

Write the new file's prologue (`'use strict';`, fs/math imports exactly per the issue, `srand(time())` at load, the constants verbatim, all 12 helpers) plus the empty-object skeleton — from the issue contract only.

- [ ] **Step 4: Gate + probe on the new file**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0. Then `tests/backend/ucode-check.sh -x '--helpers'` — Expected: all pass.

**Verification**: helpers contractually green on both implementations; syntax gate ok; next chunk starts from a compiling file.

### [ ] Task 3: `status` + `service` + `log` (chunk c)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (add the three methods to the returned object)

- [ ] **Step 1: Failing harness run (TDD)**

Run: `TT_METHODS=status,service,log tests/test_backend_contract.sh` against the new file — Expected: FAIL (methods missing — the skeleton object returns no such method; harness reports missing method / exception).

- [ ] **Step 2: Implement the three methods**

From the contract: `status` — `records()` + `routing_status()` + init.d `running` check, `device` from live `routing_status().device` (null when absent), the full actualized key set and order per R1/D9: `enabled, running, device, device_up, rule, table, nft, endpoint_hostname, addresses[], client_installed, routing_profile, routing_mode, vpn_mode`; `routing_profile`/`routing_mode` from the resolved records (`first(rec, 'routing_profile.name'|'routing_profile.mode', '')` — empty when unassigned); `vpn_mode` = `'selective'` iff `routing_mode == 'bypass'`, else `'general'`; `service` — action validation, init.d dispatch, `start` sleep-1 + re-check with `{code:1, output, not_running:true}` (D6); `log` — `logread -e trusttunnel | tail -n N` with `int(n)`, trim-then-split (D3).

- [ ] **Step 3: Gate**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0.

- [ ] **Step 4: Harness vs goldens**

Run: `TT_METHODS=status,service,log tests/test_backend_contract.sh` — Expected: PASS against `base`, `bypass-profile`, `vpn-profile`, `service-stopped`, `no-records` goldens (status × legacy empty `routing_profile`/`routing_mode` with `vpn_mode` `'general'`; bypass-profile `routing_mode` `'bypass'` with `vpn_mode` `'selective'`; vpn-profile `routing_mode` `'vpn'` with `vpn_mode` `'general'`; plus `enabled`/`running`/`device` variants; service × start/stop/restart/reload/start-not-running/invalid; log × default + custom `lines`).

**Verification**: three methods byte-match the captured goldens; gate green.

### [ ] Task 4: `ping` + `probe` (chunk d)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (add the two methods)

- [ ] **Step 1: Failing harness run**

Run: `TT_METHODS=ping,probe tests/test_backend_contract.sh` — Expected: FAIL (methods missing).

- [ ] **Step 2: Implement the two methods**

From the contract: `ping` — explicit `target` arg else `endpoint_host()` of every `endpoint.address`, `{error: 'no endpoint address configured'}` when empty, `ping -c 4 -W 2 -q <host>` via `sh`, `parse_ping` per result, `{results: [...]}` (D9); `probe` — live device from `routing_status()`, the two error strings when no device, `curl -fsS --max-time 8 [--interface <dev>] https://api.ipify.org` via `sh`, ip on exit 0 else trimmed output or `'request failed'` fallback (D4).

- [ ] **Step 3: Gate**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0.

- [ ] **Step 4: Harness vs goldens**

Run: `TT_METHODS=ping,probe tests/test_backend_contract.sh` — Expected: PASS (ping × explicit-target / from-addresses / no-addresses; probe × base tunnel-ip≠direct-ip / tunnel-failure error / probe-no-device scenario).

**Verification**: byte-match on the captured goldens; gate green.

### [ ] Task 5: `check_domain` + `versions` (chunk e)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (add the two methods)

- [ ] **Step 1: Failing harness run**

Run: `TT_METHODS=check_domain,versions tests/test_backend_contract.sh` — Expected: FAIL (methods missing).

- [ ] **Step 2: Implement the two methods**

From the contract: `check_domain` — empty/blank → `{error: 'domain is required'}`; resolve the effective list key from `records()`: `routing_profile.vpn_rules` when a profile is assigned (`routing_profile.name` non-empty) AND `routing_profile.mode == 'bypass'`, `routing_profile.bypass_rules` when a profile is assigned in vpn mode, else the legacy `domains.direct`; case-insensitive compare (exact or `.<d>`-suffix, both sides lowercased) against that list; `{domain, normalized (lowercased), verdict, reason}` with the exact reason strings per mode:
- bypass mode: in_list → verdict `'tunnel'`, reason `"listed in the profile's VPN rules; the client routes it through the tunnel"`; not in_list → verdict `'direct'`, reason `"the assigned profile is in bypass mode; everything else stays direct"`;
- vpn profile: in_list → verdict `'direct'`, reason `"listed in the profile's bypass rules; the client sends it out directly"`; not in_list → verdict `'tunnel'`, reason `"the assigned profile is in VPN mode; everything else goes through the tunnel"`;
- legacy: in_list → verdict `'direct'`, reason `'listed in the "do not bypass" list; the client sends it out by SNI'`; not in_list → verdict `'tunnel'`, reason `'all LAN traffic goes through the tunnel (full-tunnel mode)'`.
`versions` — initial key set per D8; client version regex `[0-9]+\.[0-9]+\.[0-9]+[^ \t\n]*` on `--version` output; package via `apk list -I luci-app-trusttunnel` regex `luci-app-trusttunnel-([^ \t\n]+)` else `opkg info` `^Version: ([^ \t\n]+)$`; cache logic: `stat` + `time()` freshness, cache-behind-installed invalidation + immediate refetch, `curl -fsS --max-time 15` to `RELEASE_URL`, `json(rr.out)?.tag_name`, `mkdir` ×2 then `writefile` `sprintf('%J', {tag, checked_at})` with `logger -t trusttunnel` on failure, network-failure fallback to cache with `stale: true`; `update_available`/`ahead` from `vercmp`.

- [ ] **Step 3: Gate**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0.

- [ ] **Step 4: Harness vs goldens**

Run: `TT_METHODS=check_domain,versions tests/test_backend_contract.sh` — Expected: PASS (check_domain × bypass-profile in-vpn_rules → `tunnel` / bypass-profile not-listed → `direct` (bypass reason strings); vpn-profile in-bypass_rules → `direct` / vpn-profile not-listed → `tunnel` (vpn reason strings); base legacy in-direct / suffix-match / non-direct with the two legacy reason strings; empty → error; case-variant matching case-insensitively across all three list keys; versions × base fresh-cache, `versions-stale-cache` (curl ok, cache mtime old), `versions-net-fail` (curl fails, cache exists → `stale: true`), `versions-cache-behind` (cache tag < installed → refetch), refresh=true, `versions-opkg` (apk stub empty → opkg path), client-missing variant in `no-records`).

**Verification**: byte-match; cache fresh/stale/network-failure behaviors match (issue acceptance criterion); gate green.

### [ ] Task 6: `diagnose` (chunk f)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (add the method)

- [ ] **Step 1: Failing harness run**

Run: `TT_METHODS=diagnose tests/test_backend_contract.sh` — Expected: FAIL (method missing).

- [ ] **Step 2: Implement the method**

From the contract + D2: the up-to-18-entry check list in exact order, groups config/prereq/service/kernel/network: Endpoint address, Credentials, TLS host name (warn-if-empty), Routing profile (after TLS host name — ok with detail `pname + ' (' + pmode + ')'` when `routing_profile.name` is set, else warn with detail `'none — legacy full-tunnel mode'` and hint `'Assign a routing profile on the Settings page to control what goes through the tunnel.'`), TrustTunnel client, tun device, Enabled, Running (fail-if-enabled-else-skip), Tunnel device (ok/fail-if-running/skip), MTU matches settings (conditional mismatch warn), Route attached via `ip route show table <T>` containing `dev <dev>`, Tunnel carrier via sysfs, rule/table/nft from `routing_status()` with skip-when-not-applied, Firewall zone via `nft list ruleset` containing `trusttunnel`, Endpoint reachable `ping -c 2 -W 2`, Traffic via ipify device-vs-direct with the three-way ok/warn/skip; detail/hint strings per goldens, `counts` and `verdict` aggregation.

- [ ] **Step 3: Gate**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0.

- [ ] **Step 4: Harness vs goldens**

Run: `TT_METHODS=diagnose tests/test_backend_contract.sh` — Expected: PASS (base legacy healthy = 17 entries `{ok:16,warn:1,fail:0,skip:0}` verdict `warn` — the single warn is the Routing profile entry; bypass-profile/vpn-profile healthy = 17 entries `{ok:17,warn:0,fail:0,skip:0}` verdict `ok`; diagnose-mtu-mismatch = 18 entries with the MTU warn added (`{ok:16,warn:2,fail:0,skip:0}` verdict `warn` on the legacy base); diagnose-not-applied with skips; diagnose-no-device; diagnose-degraded combining unreachable endpoint / missing firewall / same-ip traffic fail-warn cases).

**Verification**: byte-match incl. every label/detail/hint string; gate green.

### [ ] Task 7: `import_config` (chunk g)

**Files:**

- Modify: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (add the method)

- [ ] **Step 1: Failing harness run**

Run: `TT_METHODS=import_config tests/test_backend_contract.sh` — Expected: FAIL (method missing).

- [ ] **Step 2: Implement the method**

From the contract + D7: empty text error; missing wizard error; `tt://` prefix (`wildcard(trimmed, 'tt://*')`) → `--deeplink <link> --settings <out>`; else `write_secret_tmp('import-in', text)` → `--endpoint_config <file> --settings <out>`; output `chmod 0600` before read; both temp files unlinked on all paths; failure or empty output → panic-noise filter → `{error: join(" ", survivors)}` or `'setup_wizard failed'`.

Then the shape-based parser over `^ *([a-z0-9_]+) *= *(.*)$` lines, dispatching on the value shape:
- `unquote(v)` (`^"(.*)"$` → inner string, else null) for the string fields `hostname`/`username`/`password`/`certificate`/`custom_sni`/`client_random` — taken only when non-empty;
- `upstream_protocol` — unquoted value `http2`/`http3` stored as `protocol`;
- `unbool(v)` (`'true'` → `'1'`, `'false'` → `'0'`, else null) for `has_ipv6`/`skip_verification`/`anti_dpi`;
- `unlist(v)` (`^\[(.*)\]$` → comma-split, quote-stripped, non-empty entries, else null) for `addresses`/`dns_upstreams`;
- result initialized `{addresses: [], dns_upstreams: []}` so both arrays are always present; section headers/comments/unknown keys skipped; unparseable values for a known key (bad bool, unquoted string, non-http2/3 protocol) simply drop that key;
- all-fields-empty → `{error: 'setup_wizard produced no recognisable endpoint fields'}` — the recognisability test covers `hostname`/`username`/`password`/`certificate`/`addresses` only, so e.g. a config with just `custom_sni` still errors;
- never invokes UCI.

- [ ] **Step 3: Gate**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` — Expected: exit 0.

- [ ] **Step 4: Harness vs goldens + security assertions**

Run: `TT_METHODS=import_config tests/test_backend_contract.sh` — Expected: PASS (deeplink success; file-mode success; every-field import — wizard output carrying all 12 keys (`hostname, username, password, certificate, custom_sni, client_random, protocol, anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]`) byte-matches the golden; malformed-value import — bad boolean dropped, unquoted string skipped, empty-quoted strings skipped, unknown keys ignored, `upstream_protocol` other than http2/http3 dropped, only `custom_sni` set → unrecognisable error; panic-dump failure with filtered message; empty text; missing wizard in a scenario variant; unrecognisable fields). Additional runner assertions from the stub log: the `--endpoint_config` file had mode 0600 at wizard-call time; the settings output file was chmod'ed to 0600; both temp paths no longer exist after the call; `uci` stub log contains no invocations during any import scenario.

**Verification**: byte-match on goldens; security side effects (0600, unlink, no UCI) proven; gate green.

### [ ] Task 8: Final gates — full equivalence (chunk h)

**Files:**

- Modify: none (verification only)

- [ ] **Step 1: Full harness run**

Run: `tests/test_backend_contract.sh` (no `TT_METHODS` filter) — Expected: every scenario × method byte-matches the Task 1 goldens, including the helper probe.

- [ ] **Step 2: Full ci.yml-equivalent gates**

Run: `tests/backend/ucode-check.sh -c packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel` (exit 0), the `let x = ;` negative control (non-zero), and the ci.yml "ucode module imports" grep loop (lines 110–133) against the new file (`every module function used is imported`).

- [ ] **Step 3: Key-diff against baseline**

Re-run `TT_CAPTURE=1 tests/test_backend_contract.sh` into a temp dir and `diff -r` against the committed goldens — Expected: no differences (byte-level proof, independent of the runner's own comparison).

- [ ] **Step 4: Live ubus comparison (requires a device with the TT-06 init script)**

On the device: back up the current file (`cp /usr/share/rpcd/ucode/luci.trusttunnel /tmp/old.uc`), copy the reimplemented file in its place, restart rpcd (`/etc/init.d/rpcd restart`), and for each of the 9 methods run `ubus call luci.trusttunnel <method> '<args>'` capturing JSON; swap back, restart rpcd, and re-call with the same UCI state; then `jq -S` both outputs per method and `diff` — Expected: key sets and values identical (volatile fields `checked_at` normalized; `service`/`import_config` compared on their non-mutating branches or state-restored). If no device is available, record in the issue that the dockerized rootfs goldens are the substitute oracle and mark this step skipped.

- [ ] **Step 5: Repo hygiene + acceptance walk**

Run: `git status --short` and `git diff --stat` — Expected: the backend file replaced in place; no `*.old`/`*.bak` copies; no other tracked files changed except the test files and `.gitignore`. Walk the five issue acceptance criteria: 9 methods re-expressed (harness green), ucode syntax gate (Step 2), module-import check (Step 2), response key sets byte-match (Steps 1/3/4), versions cache behavior matches (Task 5).

**Verification**: all gates green; `git status` clean of stray files; acceptance criteria checked off in the issue.

## Self-Review Notes

- **Issue coverage**: every acceptance criterion maps to a task — syntax gate (Tasks 1, 2–7 step 3, 8 step 2), module imports (Tasks 1 step 5, 8 step 2), response byte-match (Tasks 3–7 step 4, 8 steps 1/3/4) incl. the profile-aware branches (bypass-profile/vpn-profile/legacy scenarios from Task 1 step 4), versions cache behavior (Task 5 step 4). All 9 methods appear in Tasks 3–7. Clean-room rule is stated per task.
- **Actualization propagated**: the actualization is declared authoritative; every pre-rebase fragment (R1/D2/D9, Contracts, Task 1 scenario matrix, Tasks 3/5/6/7) was updated in place — no stale key sets or counts remain (status full key set, check_domain six reason strings, diagnose 17/18-entry counts, import_config 12-key response).
- **No placeholders**: every step names files, commands, and expected outcomes; the one contingency (require-vs-sed loading) has a concrete fallback defined in Task 1 step 3.
- **Out of scope respected**: no UCI/schema/init/JS/packaging changes; bug fixes observed during capture are recorded but not implemented (PRD rule).

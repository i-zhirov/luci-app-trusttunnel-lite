# Per-file review: inheritance depth and rewrite sizing

Companion to `docs/reimplementation-consideration.md`. For every file that
traces to the inherited GPL-2.0 snapshot (commit `64a2d41`, upstream
`NooBiToo/TrustTunnelOpenWrt`), this document records how much of the current
text is still inherited expression, what a clean-room rewrite must re-express,
and how large the rewrite is. Line counts are from the current tree
(2026-09-08).

## Reading the derivation classes

The diff analysis shows one consistent pattern across all inherited files:
the fork **translated comments (Russian → English), deleted list-machinery
features, and added fork-specific features** — but the *code bodies* (function
structure, control flow, awk programs, printf sequences, JS view scaffolding)
were largely **kept in place, edited in place**. Translated comments do not
make a file original; the retained code expression is still a derivative of
the upstream work. The effort columns estimate re-expressing that code.

Effort scale (single author, spec-first, tests as oracle): **S** < 0.5 day,
**M** 0.5–1.5 days, **L** 1.5–3 days. "Contract" = interface facts from the
consideration doc §2 that must be reproduced exactly and are not
copyrightable expression.

---

## A. Package runtime — `packages/luci-app-trusttunnel/`

### 1. `root/usr/libexec/trusttunnel/records.sh` — 40 lines — **S**

- **Inherited text:** the four record accessors (`tt_list`, `tt_get`,
  `tt_bool`, `tt_count`) and their awk parsing. Comments translated only.
- **Already re-expressed:** comments.
- **Rewrite notes:** re-express the awk/shell readers against the TSV format
  contract (`section.option⇥value`, repeated keys for lists, values may
  contain quotes/backslashes but not tabs). Contract: `TT_RECORDS` env,
  function names used by callers (`tt_list/tt_get/tt_bool/tt_count`), the
  `${TT_RECORDS:?}` guard semantics.
- **Verify:** `tests/test_records.sh` (rewritten), full suite.

### 2. `root/usr/libexec/trusttunnel/uci-export` — 56 lines — **S**

- **Inherited text:** `scalar`/`listopt` helpers and the explicit schema loop
  structure. Comments translated; removed `mode`, `lists.*`, `domains.bypass`,
  DNS/list options.
- **Rewrite notes:** re-express the enumeration. Contract: output TSV schema
  (exact key set below), exclusion of `endpoint.certificate`, no `set -u`
  (OpenWrt `/lib/functions.sh` incompatibility). The key set is the canonical
  schema for the init.d classifier test.
- **Verify:** `tests/test_init_apply.sh` schema-completeness check (rewritten),
  byte-compare output against a captured golden TSV.

### 3. `root/usr/libexec/trusttunnel/gen-config` — 115 lines — **S–M**

- **Inherited text:** `esc()`/`array_from_stdin()` awk, `emit_certificate()`,
  the TOML heredoc template and the field plumbing (`tt_get` defaulting,
  `tt_list | array_from_stdin`).
- **Already re-expressed:** comments; removed the extra-exclusions source.
- **Rewrite notes:** re-express TOML escaping, array building, and the
  template. Contract: the emitted `client.toml` — every key/value the client
  parses (`vpn_mode="general"`, `killswitch_enabled=false`,
  `exclusions_tcp_early_ack_enabled=true`, `exclusions_preresolve_enabled=true`,
  `exclusions`, `[endpoint]` fields incl. `certificate = '''…'''` literal,
  `dns_upstreams`, `[listener.tun]` with empty `included_routes`/
  `excluded_routes`, `mtu_size`, `change_system_dns=false`), plus
  `TT_LIBDIR` sourcing and the `die()` behavior on missing credentials.
- **Verify:** `tests/test_gen_config.sh` (rewritten) + byte-diff against
  golden outputs on both fixtures.

### 4. `root/usr/libexec/trusttunnel/routing` — 330 lines — **M–L**

- **Inherited text:** `lan_set()` awk, `common_returns()`, the whole
  `dump_ruleset()` printf sequence, `up` (blackhole/rule/nslookup/nft load),
  `attach`/`detach`/`down`/`status` bodies, `TT_IP`/`TT_NFT` overrides.
  Selective-mode branches deleted; blackhole metric and reattach added.
- **Rewrite notes:** re-express the nft ruleset assembly (printf discipline —
  no heredoc with `$(...)`, no trailing-newline stripping), the ip/nft command
  invocations and ordering. Contract: every kernel name and value in
  consideration §2 (table `inet trusttunnel`, sets `tt_endpoint4/6`,
  prerouting mangle + optional output route hook with `oifname "tun*"`,
  fwmark `0x9527`, table `880`, priority `30820`, blackhole metric `1000`,
  attach metric `1`, private ranges, LAN fallback `br-lan`), subcommand
  surface (`dump|up|attach|reattach|detach|down|status`), `OUT_DIR/device`
  file, `TT_IP`/`TT_NFT`/`TT_LIBDIR` env overrides.
- **Verify:** `tests/test_routing.sh` (rewritten) + byte-diff `routing dump`
  on identical fixtures; live nft 1.1.x syntax check in CI is a bonus.

### 5. `root/etc/init.d/trusttunnel` — 486 lines — **L**

- **Inherited text:** `setup_trust_store()`, `wait_for_time()`,
  `wait_for_wan()`, `regenerate()`, `start_service()`, `stop_service()`,
  `max_ifindex()`/`new_client_devices()`/`attach_client_device()` scaffolding.
  Fork additions: `apply_settings()` smart-reload, `changed_keys`/
  `change_class`/`classify_change`, `_TT_KEEP_ROUTING`, restart override.
- **Rewrite notes:** re-express the whole procd lifecycle and the reload
  classifier. Contract: `USE_PROCD=1`, START=95/STOP=10, instance name
  `trusttunnel`, pidfile `/var/run/trusttunnel.pid`, command
  `<client> -c /var/etc/trusttunnel/client.toml`, env `SSL_CERT_FILE`/
  `SSL_CERT_DIR`, respawn `3600 5 0`, triggers (UCI reload trigger on
  `trusttunnel` + interface trigger `interface.*.up` on `wan`), `$RECORDS`
  atomic regenerate via `.new` + `mv`, umask 077, log tag `trusttunnel`,
  class semantics (noop/reload/restart/restart_full per key, cert mismatch →
  ≥ restart).
- **Verify:** `tests/test_init_apply.sh` + `test_init_reload.sh` (already
  original, keep; they double as the behavioral spec) + `sh -n`.

### 6. `root/etc/uci-defaults/40-luci-trusttunnel` — 165 lines — **M**

- **Inherited text:** zone creation block (`uci add firewall zone`, options,
  `tun+` list, forwarding, commit/reload). Fork additions: duplicate-zone
  dedup and `tt0`→`tun+` migration.
- **Rewrite notes:** re-express idempotent zone/forwarding management and the
  dedup pass. Contract: zone `name=trusttunnel` (input/forward REJECT, output
  ACCEPT, masq=1, mtu_fix=1, device `tun+`), forwarding `src=lan
  dest=trusttunnel`, `/etc/init.d/trusttunnel enable`, cache clear
  (`/var/cache/trusttunnel/release.json`), LuCI cache clear.
- **Verify:** shellcheck, `sh -n`, rootfs install test in release.yml.

### 7. `root/etc/hotplug.d/net/40-trusttunnel` — 47 lines — **S**

- **Inherited text:** the whole event pipeline (ACTION filter, tun_flags
  marker, IFF_PERSIST 0x800 check, RECORDS/running guards, device-file guard,
  `routing attach` call). Comments translated only.
- **Rewrite notes:** re-express the guard chain. Contract: net `add` events
  only; `$INTERFACE`/`$DEVICENAME`; the exact sysfs checks; the recorded-device
  guard; the attach command and log line.
- **Verify:** shellcheck, `sh -n`; behavior via rootfs/CI smoke test.

### 8. `root/etc/config/trusttunnel` — 24 lines — **S**

- **Status:** functional defaults; list-related options deleted, retained
  lines unchanged (schema data, not expression).
- **Rewrite notes:** re-create from the UCI schema contract (consideration §2).
  Effectively dictated by the code that reads it; the rewrite is a
  transcription exercise, not a creative one.
- **Verify:** uci export diff against golden; tests.

### 9. `root/usr/share/rpcd/ucode/luci.trusttunnel` — 684 lines — **L**

- **Inherited text:** helpers (`sh`, `sh_out`, `shq`, `tmp_path`,
  `write_secret_tmp`, `vercmp`, `uciget`, `records`, `parse_ping`,
  `endpoint_host`), `status`/`service`/`ping`/`probe` method bodies. Deleted:
  catalog/set_size/list machinery. Added: `versions` with disk cache,
  `import_config`, `check_domain`, `diagnose`, `routing_status`.
- **Rewrite notes:** re-express the rpcd object and every helper against the
  method contract (inputs/outputs/side effects per the functional inventory).
  Contract: object `luci.trusttunnel`, the 9 methods and their exact result
  shapes (keys the JS views rely on), `srand(time())` init, `math`/`fs`
  imports, paths, `RELEASE_URL`, `VERSION_CACHE`, `RELEASE_TTL=21600`,
  log/cache file behaviors, panic-noise filtering in `import_config`.
- **Verify:** rewritten tests + ucode `-c` syntax check in ci.yml + JS view
  integration (RPC shapes must not change — the JS side depends on them).

### 10. JS views — `htdocs/luci-static/resources/view/trusttunnel/`

- **`status.js`** — 259 lines — **M**: inherited `verdict()` logic, RPC
  declarations, polling loop, facts/versions tables; list fields deleted.
  Re-express verdict rules (4 states), the 10 s polls, the versions table
  states (unavailable/available/ahead/up-to-date/stale). Contract: RPC method
  names + response keys, button actions, translations keys.
- **`settings.js`** — 256 lines — **M**: inherited `form.Map` tab structure
  and field definitions; list/catalog tabs deleted; import flow and validators
  are fork work. Re-express field definitions (each option per contract),
  the import modal flow (pending `uci.save()`, reload), the direct-list
  validator regex semantics. Contract: UCI section/option names, the
  `import_config` RPC, the 8 `dns_upstream` presets, defaults.
- **`diagnostics.js`** — 376 lines — **M–L**: inherited page scaffolding,
  verdict word/counts banner, group rendering; diagnose/ping/probe/check_domain
  tool flows are fork work. Re-express grouping/order (config → prereq →
  service → kernel → network), fail/warn-first rendering, toggle, the
  `DIAG_TEXT` mapping. Contract: RPC method names + response shapes
  (`checks[{group,label,status,detail,hint}]`, counts, verdict; ping table;
  probe rows; check_domain normalized/verdict/reason).
- **Verify:** ci.yml JS syntax + LuCI require checks; manual LuCI pass.

### 11. `po/ru/trusttunnel.po` — 549 lines — **M**

- **Inherited text:** the Russian `msgstr` translations for all retained
  `msgid`s (translation text is creative expression and is the most
  "visible" inherited content).
- **Rewrite notes:** produce a new Russian translation file for the retained
  strings — re-translate rather than reuse `msgstr` lines. Contract: `msgid`
  keys must match the new JS/backend strings exactly; plural forms header
  (`nplurals=3` Russian) stays.
- **Verify:** `msgfmt`/LuCI i18n build; string-key consistency check against
  the views (ci.yml style).

### 12. `Makefile` — 89 lines — **S–M**

- **Inherited text:** `PKG_*` block, `LUCI_*` block, conffiles declaration
  pattern, `Build/Compile` chmod workaround (fork comment). Version-from-tag
  logic is fork work.
- **Rewrite notes:** re-express the package metadata block. Contract:
  `PKG_NAME`, `PKG_VERSION` derivation (tag-based, fallback), `PKG_RELEASE:=1`,
  `LUCI_DEPENDS` (incl. `+trusttunnel-client`, `+ucode-mod-math`),
  `LUCI_PKGARCH:=all`, conffiles **before** `include luci.mk`, `Build/Compile`
  chmod set, `PKG_LICENSE` (new value after the license flip).
- **Verify:** SDK build in ci.yml/release.yml.

### 13. `root/usr/share/rpcd/acl.d/luci-app-trusttunnel.json` — 19 lines — **S**

- **Status:** 1-line diff (read/write split of the method lists). Functional
  data. Re-create from contract: read `[status,ping,probe,check_domain,log,
  versions,diagnose]`, write `[service,import_config]`, uci `[trusttunnel]`.

### 14. `root/usr/share/luci/menu.d/luci-app-trusttunnel.json` — 23 lines — **S**

- **Status:** byte-identical to upstream. Functional data dictated by the LuCI
  menu contract (paths, titles, order 40/10/20/30, acl/uci depends). Re-create
  verbatim-equivalent from the contract; nothing creative to re-express.

---

## B. Install / uninstall / repo

### 15. `install.sh` — 263 lines — **M–L**

- **Inherited text:** the original opkg-era installer's skeleton (`say`/`die`,
  `/etc/openwrt_release` sourcing, opkg feed/key setup, install sequence).
  Fork work: apk repository path, PM detection, arch allowlist, `was_running`
  restore, tripwire.
- **Rewrite notes:** re-express as one installer over both package managers.
  Contract: `TT_REPO_URL` default, key URLs, `/etc/apk/keys/trusttunnel.pub`,
  `/etc/apk/repositories.d/trusttunnel.list`, `src/gz trusttunnel` line in
  `/etc/opkg/customfeeds.conf`, usign fingerprint copy, `uname -m` allowlist,
  package set (`kmod-tun ip-full curl ca-bundle` + `luci-app-trusttunnel` +
  optional `luci-i18n-trusttunnel-ru`), rpcd restart, service state restore.
- **Verify:** shellcheck; the release.yml rootfs install tests execute this
  exact flow (apk key install parity noted in the workflow).

### 16. `uninstall.sh` — 310 lines — **keep (original)**

- Entirely fork-written; no upstream ancestor. Keep as-is.

### 17. `packages/trusttunnel-client/Makefile` — 114 lines — **keep (original)**

- Fork-written vendor wrapper; `PKG_LICENSE:=Apache-2.0` refers to the vendor
  binary (confirmed: `TrustTunnel/TrustTunnelClient` is Apache-2.0). Keep.

### 18. `repo-site/*`, `key-build.pub`, `opkg-key.pub` — **keep (original)**

---

## C. CI workflows — `.github/workflows/`

### 19. `ci.yml` — 233 lines — **M**

- **Inherited text:** the original CI skeleton (SDK build job, artifact
  collection). Fork work: executable-bit check, tag-vs-previous-tag check,
  unit tests, shellcheck matrix, init `sh -n`, ucode build+`-c` (with negative
  control), JSON/JS/LuCI require checks.
- **Rewrite notes:** re-express as the project's own pipeline spec. Workflow
  YAML is functional configuration with thin expression; the rewrite is mostly
  a re-typing exercise against the documented steps.

### 20. `release.yml` — 577 lines — **M**

- **Inherited text:** original release flow skeleton (SDK build, artifact
  upload). Fork work: apk repo signing (`apk mkndx`/`adbsign`), opkg index via
  `ipkg-make-index.sh` + field filtering + usign, verification rootfs
  installs, Pages site assembly, single-writer publishing, per-arch client
  matrix.
- **Rewrite notes:** same as ci.yml — re-express from the workflow spec.
  Contract: matrix arch lists (20 apk / 19 ipk), repo layout
  (`site/apk/<arch>/packages.adb`, `site/opkg/Packages[.gz/.sig]`), secret
  names, pinned container digests, Pages URL.

---

## D. Tests and fixtures

Inherited tests are derivative text (assertions are functional facts, the
surrounding test code is inherited expression). Keep the *assertions*, rewrite
the *text*; the fork-written tests are the model to follow.

| File | Lines | Diff vs inherited | Effort | Notes |
|---|---|---|---|---|
| `tests/run.sh` | 25 | 4/4 | S | re-express runner (per-test `mktemp -d`, `TT_TEST_TMP`, stdin closed) |
| `tests/lib.sh` | 54 | 2/2 | S | re-express assert helpers + counters (`assert_eq`, `assert_contains`, `assert_exit`, `tt_test_summary`) |
| `tests/test_harness.sh` | 20 | 2/2 | S | re-express harness self-test (positive+negative) |
| `tests/test_records.sh` | 25 | 1/1 | S | re-express accessor semantics checks |
| `tests/test_gen_config.sh` | 65 | 13/13 | S | re-express toml assertions (fixed fields, absence of invented keys, escaping, PEM, exit 1) |
| `tests/test_routing.sh` | 162 | 91/115 | M | re-express dump/up/attach/detach/down assertions incl. no-blackhole and line-break hygiene |
| `tests/fixtures/records/minimal.tsv`, `full.tsv` | 6/21 | 0/2, 0/11 | S | re-derive from the records contract (data, not expression) |
| `tests/test_init_apply.sh` | 234 | new | keep | fork-written; also the schema-completeness oracle |
| `tests/test_init_reload.sh` | 274 | new | keep | fork-written; the apply_settings behavioral spec |

---

## E. Docs and meta

### 21. `README.md` — 258 lines — **S–M**

- Heavily rewritten already (860 changed lines vs the inherited ~940-line
  original; current file is 258 lines). Residual derived prose is small but
  present (architecture description, comparison table). Re-express the
  remaining paragraphs from the behavior spec; the document also needs a new
  license/independence statement at flip time.

### 22. `LICENSE` — **replace at flip time**

- Upstream's copy of the GPL-2.0 text; byte-identical. Replace with the chosen
  license's text when the tree is clean.

### 23. `.gitattributes`, `.gitignore` — **keep**

- Trivial functional config; no meaningful expression; do not constrain
  licensing.

---

## Summary and sequencing

| Effort | Files |
|---|---|
| **S** (9) | records.sh, uci-export, hotplug, config defaults, acl.d, menu.d, run.sh, lib.sh, test_harness/test_records/test_gen_config, fixtures |
| **M** (10) | gen-config, uci-defaults, status.js, settings.js, po, Makefile, ci.yml, release.yml, test_routing.sh, README.md |
| **L** (3) | routing, init.d, ucode backend, diagnostics.js (M–L) |

Total: roughly **10–14 focused working days** for the full rewrite including
test rewrites and verification, with the three L items (~2,100 lines) being
the critical path.

Recommended commit sequence (each green on ci.yml before the next):

1. records.sh, uci-export, gen-config, routing + rewritten tests/fixtures
   (byte-diff golden outputs old vs new)
2. init.d, uci-defaults, hotplug (test_init_apply/reload stay as oracles)
3. ucode backend (RPC shapes frozen by the JS contract)
4. JS views + po (translation re-authored)
5. Makefile, config, acl.d, menu.d, install.sh
6. ci.yml, release.yml, README.md
7. License flip (LICENSE, PKG_LICENSE, SPDX headers, README independence note)
   — the only commit that changes licensing terms.

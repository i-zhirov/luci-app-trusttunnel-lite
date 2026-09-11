# Reimplementation consideration

Status: **consideration** (analysis, not yet a plan)
Branch: `consider-reimplementation`
Date: 2026-09-08

## Purpose

This project was started as a fork of
[`NooBiToo/TrustTunnelOpenWrt`](https://github.com/NooBiToo/TrustTunnelOpenWrt)
(GPL-2.0, upstream author Эрлан Капаров). It has diverged considerably, will
not be merged back, and should be considered an independent project. This
document considers a **functionally identical independent reimplementation**
of the inherited code, to give the project independence and freedom in the
choice of license.

This is an engineering analysis, not legal advice.

## 1. Current licensing situation

### 1.1 Provenance

The entire repository traces back to one inherited snapshot — commit
`64a2d41` (the upstream project at fork time). The fork then made ~55 commits
(46 up to the merge-base `b4416f8`, 9 after). A diff against `64a2d41`
classifies every file currently in the tree:

| Status | Files |
|---|---|
| **Byte-identical to upstream** (2 files) | `LICENSE` (GPL-2.0 text), `packages/luci-app-trusttunnel/root/usr/share/luci/menu.d/luci-app-trusttunnel.json` |
| **Inherited but modified — still GPL-2.0 derivative** (~4,900 lines) | `init.d` (486), ucode rpcd backend (684), 3 JS views (891), `routing` (330), `install.sh` (263), `release.yml` (577), `ci.yml` (233), `.po` translation (549), `uci-defaults` (165), `gen-config` (115), Makefile, `uci-export`, `records.sh`, hotplug, config defaults, 2 JSON manifests, `README.md`, inherited tests (`test_routing.sh`, `test_gen_config.sh`, `test_records.sh`, `test_harness.sh`, `lib.sh`, `run.sh`, TSV fixtures) |
| **Already original to this project** | `packages/trusttunnel-client/Makefile` (Apache-2.0 vendor wrapper), `uninstall.sh`, `tests/test_init_apply.sh`, `tests/test_init_reload.sh`, `repo-site/*`, `key-build.pub`, `opkg-key.pub` |
| **Deleted from the tree** | all list-machinery (`fetch-lists`, `gen-lists`, `normalize`, `warm-sets`) and their tests |

### 1.2 Why there is no license freedom today

GPL-2.0 §2 makes every modified upstream file a derivative work; the whole
package must be distributed under GPL-2.0, and only the upstream copyright
holder(s) could agree to a relicense. `PKG_LICENSE:=GPL-2.0-only` in the
Makefile is a declaration of that constraint, not a choice. A "heavily
rewritten" file is *still* a derivative work — incremental editing never
creates a new copyright.

### 1.3 What reimplementation achieves

Replacing the inherited expression with new, original expression written by
this project's author creates a new copyright in the new code, so the project
may license it however it chooses (GPL-2.0 by choice, GPL-3.0, MIT/Apache-2.0,
dual, …). Function and interfaces are not protected by copyright — only
expression is — so a behaviorally identical program with new expression is a
genuinely independent work.

## 2. The interface contract ("functionally identical" means this)

These externally visible names and values are interoperability facts (dictated
by LuCI, the Apache-2.0 client binary, and the kernel). A reimplementation
must — and may — reproduce them exactly:

- **UCI**: `/etc/config/trusttunnel`, sections `main` / `endpoint` / `network`
  / `domains` with all options and defaults.
- **Records**: TSV `section.option⇥value` at `/var/etc/trusttunnel/settings.tsv`;
  `endpoint.certificate` excluded (separate `endpoint.pem`).
- **Generated client config**: `/var/etc/trusttunnel/client.toml` schema (must
  match what the client parses: `vpn_mode = "general"`, `killswitch_enabled =
  false`, empty `included_routes`/`excluded_routes`, `mtu_size`, …).
- **rpcd**: object `luci.trusttunnel`, methods `status`, `service`, `ping`,
  `probe`, `check_domain`, `log`, `versions`, `diagnose`, `import_config`;
  ACL `luci-app-trusttunnel` with the read/write method split.
- **Menu**: `admin/services/trusttunnel` → `{status,settings,diagnostics}`.
- **Kernel**: nft table `inet trusttunnel`, sets `tt_endpoint4`/`tt_endpoint6`,
  fwmark `0x9527`, table `880`, rule priority `30820`, blackhole metric `1000`,
  attached route metric `1`, private ranges (10/8, 127/8, 169.254/16,
  172.16/12, 192.168/16, 224/4, 240/4; ::1/128, fc00::/7, fe80::/10, ff00::/8).
- **Firewall**: zone `trusttunnel` (`tun+`, input/forward REJECT, output
  ACCEPT, masq=1, mtu_fix=1), forwarding `lan → trusttunnel`.
- **Paths**: `/opt/trusttunnel_client/{trusttunnel_client,setup_wizard}`,
  `/usr/libexec/trusttunnel/{uci-export,records.sh,gen-config,routing}`,
  `/etc/init.d/trusttunnel` (START=95, STOP=10, respawn `3600 5 0`, pidfile
  `/var/run/trusttunnel.pid`), `/etc/hotplug.d/net/40-trusttunnel`,
  `/var/cache/trusttunnel/release.json` (TTL 21600 s).
- **Update check**: GitHub API `…/releases/latest` of this repo; cache path and
  TTL as above.
- **Install/uninstall**: repo URLs
  `https://i-zhirov.github.io/trusttunnel-openwrt/apk/<arch>/packages.adb` and
  `/opkg`; key files `/etc/apk/keys/trusttunnel.pub`,
  `/etc/apk/repositories.d/trusttunnel.list`, `/etc/opkg/customfeeds.conf` line
  `src/gz trusttunnel <url>/opkg`, `/etc/opkg/keys/{trusttunnel.pub,<fingerprint>}`.
- **Log tag**: `trusttunnel` (all `logger` calls and `logread -e trusttunnel`).

Everything else — internal structure, algorithm arrangement, comments, naming
beyond these names — is free to be re-expressed.

## 3. Recommended methodology (clean-room)

1. **Spec first.** Write a behavior specification from *observed behavior*
   only: run the scripts (`gen-config`, `routing dump`, `uci-export`), read
   their outputs, use the README's documented behavior, and the existing tests
   as a behavioral oracle.
2. **Implement fresh, per component, from the spec** — not by transforming the
   old file. Do not open the inherited file while writing its replacement; the
   point is new expression, not a mechanical pass.
3. **Rewrite the inherited tests too** — assertions are functional facts, but
   the test *text* is also derivative. Keep the assertions; write new test
   code against the same harness conventions.
4. **Verify by behavior, not by diff** — the tests, shellcheck, `sh -n`,
   ucode `-c`, JSON/JS syntax checks, and the CI rootfs install/run
   verifications are the equivalence proof.
5. **Flip the license last**, in one commit, after the tree is clean.

### 3.1 Suggested order

Small commits, dependency-driven, each independently verifiable:

1. `records.sh` → `uci-export` → `gen-config` → `routing`
   (self-contained, heavily covered by tests)
2. `init.d` → `uci-defaults` → hotplug (the service lifecycle)
3. ucode rpcd backend (largest single item, 684 lines)
4. JS views (`status.js`, `settings.js`, `diagnostics.js`) + `.po` translation
   (new translation text)
5. `Makefile`, config defaults, `menu.d`/`acl.d` JSON (re-created from the
   contract — the content is dictated by LuCI)
6. `install.sh`; CI workflows (mostly new already); `README.md` (rewrite the
   remaining derived prose)
7. License flip: replace `LICENSE`, update `PKG_LICENSE`/SPDX headers, state
   independence in the README

**Files to keep untouched**: `trusttunnel-client/Makefile`, `uninstall.sh`,
`test_init_apply.sh`/`test_init_reload.sh`, `repo-site/*`, keys,
`.gitattributes`/`.gitignore`.

## 4. Verification strategy

The existing pipeline already provides most of it: `tests/run.sh` (unit),
shellcheck, ucode/JSON/JS syntax checks in `ci.yml`, and the release
workflow's rootfs install tests (apk on 25.12, opkg on 22.03/23.05/24.10) plus
`trusttunnel_client --version` execution. Add a **deterministic-output
comparison** during the transition: run old vs new `gen-config` / `routing
dump` / `uci-export` on identical fixtures and diff outputs byte-for-byte —
cheap, and the strongest equivalence evidence.

## 5. Caveats

- **Git history** will still contain the GPL-2.0 text. That is lawful (GPL
  code remains distributable under GPL) and does not constrain the new tree,
  but for zero ambiguity the final step can be a fresh history (orphan branch
  or new repo) with one initial commit of the reimplemented code.
- **The `LICENSE` file** is upstream's copy of the GPL-2.0 text — replace it
  with the chosen license's text.
- **Not legal advice.** A clean-room rewrite substantially de-risks
  re-licensing; documenting the process (spec → implementation → verification)
  strengthens it further.
- **Ecosystem friction**: the official OpenWrt feed's LuCI policy favors
  AGPL-3.0 for apps; a permissive choice (MIT/Apache-2.0) would conflict
  there. For this project's own repo it does not matter. The client binary
  and its `client.toml` contract are Apache-2.0 — keeping the TOML schema
  byte-identical is both legally safe and practically required.

## 6. Verdict

The reimplementation is clearly feasible and well-scoped: ~5,000 lines of
derivative code across ~25 files, most of it small shell/JSON, with three
substantial items (ucode backend, init.d, JS views). The project is already
~60% original by composition, the interface contract is well understood and
documented, and the existing test/CI infrastructure doubles as the
functional-equivalence oracle.

## 7. Reference: full functional inventory

See the companion per-file review (`docs/reimplementation-file-review.md`)
for the file-by-file inheritance depth, rewrite sizing, and the recommended
commit sequence.

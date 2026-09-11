# PRD: Independent reimplementation of inherited code

- **Created**: 2026-09-08
- **Status**: Draft
- **Model**: tokenguard/deepseek-v4-flash
- **Input**: "Consider functionally identical independent reimplementation of inherited code to provide independence and freedom in choice of license" + the follow-up "Turn the recommended 7-step sequence into an executable plan with per-file issues"

## Problem Statement

The project started as a fork of
[`NooBiToo/TrustTunnelOpenWrt`](https://github.com/NooBiToo/TrustTunnelOpenWrt)
(GPL-2.0) and has diverged considerably: it is now a full-tunnel-only
package with its own repository, installer, CI, and release pipeline. Yet
nearly every file in the tree still derives from the GPL-2.0 upstream work
(comments translated, features trimmed, edits made in place — but the code
expression is inherited). GPL-2.0 copyleft therefore binds the whole project:
it can only be distributed under GPL-2.0, and no one except the upstream
copyright holder could agree to a relicense. The project has no freedom to
choose its own license, which blocks independence as a standalone project.

The analysis of what is inherited vs. original, and the reimplementation
methodology, is recorded in `docs/reimplementation-consideration.md` and
`docs/reimplementation-file-review.md`.

## Solution

Replace every inherited (GPL-2.0-derived) file with a functionally identical
independent reimplementation written by this project's author — new
expression written against a behavioral specification, not a transformation
of the inherited text. After the reimplementation the tree contains no
upstream-derived expression, the project can be licensed however its author
chooses, and the license flip becomes the final, single, deliberate commit.

When the feature is complete:

- Every component behaves exactly as today: same UCI schema, same generated
  `client.toml`, same kernel/firewall names, same rpcd interface, same
  installer behavior, same tests green, same CI gates.
- The only remaining inherited file, the GPL-2.0 `LICENSE`, is replaced by
  the chosen license.
- The git history still contains the GPL-2.0 text (lawful; not constraining
  the new tree), and an optional fresh-history step removes even that.

## Assumptions

- "Functionally identical" means: byte-identical externally visible behavior
  and interface contract (see Key Entities), not byte-identical source.
- The author (i-zhirov) writes the reimplementation; no third-party clean-room
  team is needed. The legal effect comes from the new text being original
  expression, documented via the spec → implementation → verification trail.
- The existing tests and CI checks are the equivalence oracle. Tests whose
  text is inherited are rewritten in the same clean-room manner; tests
  written by this project (`test_init_apply.sh`, `test_init_reload.sh`) are
  kept as-is.
- The chosen new license is not fixed by this PRD; the flip task makes it a
  single-reviewable change. Recommended candidates are documented in the
  consideration doc.
- The following files are already original and are NOT reimplemented:
  `packages/trusttunnel-client/Makefile`, `uninstall.sh`,
  `tests/test_init_apply.sh`, `tests/test_init_reload.sh`, `repo-site/*`,
  `key-build.pub`, `opkg-key.pub`, `.gitattributes`, `.gitignore`.

## User Stories

### User Story 1 - Core libexec reimplemented (Priority: P1)

As a maintainer, I want the four libexec scripts (`records.sh`, `uci-export`,
`gen-config`, `routing`) reimplemented with new expression and identical
behavior, so that the lowest layer of the package is independent before
anything that depends on it changes.

**Why this priority**: Everything else (init.d, rpcd backend, tests) depends
on these four; they are small and heavily covered by tests.

**Acceptance Scenarios**:

1. **Given** the current fixtures, **When** the new `uci-export`/`gen-config`/
   `routing dump` run, **Then** their outputs byte-match the outputs of the
   inherited implementations on identical inputs.
2. **Given** the rewritten unit tests, **When** `sh tests/run.sh` runs,
   **Then** all assertions pass.
3. **Given** a missing `TT_RECORDS` or missing credentials, **When** the
   scripts run, **Then** they fail with the same clear diagnostics as today.

* * *

### User Story 2 - Service lifecycle reimplemented (Priority: P1)

As a maintainer, I want the procd service, the first-boot firewall setup and
the hotplug route-reattach reimplemented with new expression and identical
behavior, so that the runtime behavior of the package is independent.

**Why this priority**: The service is the heart of the package; the
fork-written `test_init_apply.sh`/`test_init_reload.sh` already specify its
behavior precisely and stay as the oracle.

**Acceptance Scenarios**:

1. **Given** the fork-written init tests, **When** they run against the new
   init script, **Then** every scenario passes unchanged.
2. **Given** a router with duplicate `trusttunnel` firewall zones, **When**
   uci-defaults runs, **Then** duplicates are collapsed exactly as today.
3. **Given** a client tun device (re)created by the client, **When** the
   hotplug event fires, **Then** the route is attached with the same guards.

* * *

### User Story 3 - rpcd backend and LuCI UI reimplemented (Priority: P1)

As a maintainer, I want the ucode backend and the three JS views plus the
Russian translation reimplemented with new expression and identical RPC
contracts and UI behavior, so that the user-facing surface is independent.

**Why this priority**: Largest files; their RPC shapes are the contract
between backend and views and must stay stable.

**Acceptance Scenarios**:

1. **Given** the same UCI state, **When** each `luci.trusttunnel` method is
   called, **Then** the response keys and semantics match the inventory in
   `docs/reimplementation-file-review.md` §9.
2. **Given** the three views, **When** loaded in LuCI, **Then** they render
   the same pages with the same fields, verdicts and tool flows.
3. **Given** the retained `msgid`s, **When** the new `.po` is compiled,
   **Then** every string has a new Russian translation and the file passes
   `msgfmt`.

* * *

### User Story 4 - Packaging, installer and CI reimplemented (Priority: P2)

As a maintainer, I want the Makefile, config defaults, ACL/menu JSON,
`install.sh` and both workflows reimplemented with new expression and
identical behavior, so that the distribution pipeline is independent.

**Why this priority**: These are functional configuration with thin
expression; they matter for independence but carry low reimplementation risk.

**Acceptance Scenarios**:

1. **Given** the same repository state, **When** the SDK builds the package,
   **Then** artifacts match the tag-derived version and install correctly on
   apk and opkg targets.
2. **Given** a router, **When** `install.sh` runs, **Then** the exact same
   repo files, keys, and service state transitions happen as today.
3. **Given** the CI workflows, **When** they run, **Then** all gates
   (executable bits, shellcheck, ucode/JS/JSON syntax, tests, rootfs install)
   pass identically.

* * *

### User Story 5 - License flip (Priority: P2)

As the project owner, I want to relicense the project to the chosen license
in a single commit after the tree is clean, so that the project is
independent and license-free in its choices.

**Why this priority**: The whole point of the reimplementation; must be last.

**Acceptance Scenarios**:

1. **Given** no inherited expression left in the tree, **When** the flip
   commit lands, **Then** `LICENSE`, `PKG_LICENSE`, and any SPDX headers
   state the new license.
2. **Given** the flip commit, **When** a reviewer greps the tree for
   upstream-derived text, **Then** nothing matches (except the retained git
   history).

## Key Entities

### UCI config `trusttunnel`

- **Attributes**: sections `main` (`enabled`, `log_level`), `endpoint`
  (`hostname`, `username`, `password`, `protocol`, `anti_dpi`,
  `post_quantum`, `skip_verification`, `certificate`, `has_ipv6`,
  `custom_sni`, `client_random`, `routing_profile`, `address`[],
  `dns_upstream`[]), `routing_profile` (anonymous sections: `name`,
  `mode` `vpn|bypass`, `vpn_rules`[], `bypass_rules`[]), `network` (`mtu`,
  `table`, `fwmark`, `blackhole_on_down`, `include_router_traffic`,
  `lan_devices`), `domains` (`direct`[] — legacy fallback); defaults per
  current `/etc/config/trusttunnel`.
- **Validation**: consumed by `uci-export` (which resolves the ASSIGNED
  profile by name into `routing_profile.*` records), init.d, rpcd
  backend, JS views.
- **States**: n/a (config data).

### Records TSV (`/var/etc/trusttunnel/settings.tsv`)

- **Attributes**: lines `section.option⇥value`; repeated key per list value;
  `endpoint.certificate` excluded (separate `endpoint.pem`); the assigned
  routing profile appears under the canonical `routing_profile.{name,
  mode,vpn_rules,bypass_rules}` prefix (resolved by uci-export).
- **Validation**: values may contain quotes/backslashes but not tabs.
- **States**: regenerated atomically via `.new` + `mv` by `regenerate()`.

### Generated `client.toml`

- **Attributes**: `loglevel`, `vpn_mode` (`"general"` or `"selective"`
  from the assigned profile: bypass-mode profile → selective, vpn-mode or
  unassigned → general), `killswitch_enabled=false`,
  `exclusions_tcp_early_ack_enabled=true`, `exclusions_preresolve_enabled=true`,
  `exclusions[]` (profile rules or the legacy direct list),
  `[endpoint]` (`hostname`, `addresses[]`, `has_ipv6`, `username`,
  `password`, `custom_sni`, `client_random`, `skip_verification`,
  `certificate='''…'''`, `upstream_protocol`, `anti_dpi`,
  `dns_upstreams[]`), `[listener.tun]` (`included_routes=[]`,
  `excluded_routes=[]`, `mtu_size`, `change_system_dns=false`).
- **Validation**: must parse by the Apache-2.0 client binary; field order and
  values byte-identical to today.

### Routing profiles

- **Attributes**: named sections (`routing_profile`) with `mode`
  (`vpn` — tunnel everything except the bypass rules; `bypass` — tunnel
  only the VPN rules) and two rule lists (`vpn_rules`, `bypass_rules`);
  rules accept a domain, `*.domain`, an IP address, `IP:port`, or a CIDR
  range. `endpoint.routing_profile` names the assigned profile; a stale
  reference falls back to the legacy behavior.
- **Validation**: profile names unique; applied client-side (vpn_mode +
  exclusions in client.toml), no kernel changes.
- **States**: seeded as `Default` (vpn) by uci-defaults (with
  `domains.direct` migration on upgrade) and by install.sh's immediate
  uci-defaults run.

### Kernel routing state

- **Attributes**: nft table `inet trusttunnel` (sets `tt_endpoint4/6`),
  fwmark `0x9527`, table `880`, rule priority `30820`, blackhole metric
  `1000`, attached route metric `1`, private ranges, LAN fallback `br-lan`.
- **States**: up → attach → detach → down; blackhole holds traffic while the
  device is down.

### rpcd object `luci.trusttunnel`

- **Attributes**: methods `status`, `service`, `ping`, `probe`,
  `check_domain`, `log`, `versions`, `diagnose`, `import_config`; ACL
  `luci-app-trusttunnel` read/write split; exact response key sets per
  method.
- **Validation**: response shapes are the JS views' contract.

## Module Design

### Test harness (`tests/`)

- **Responsibility**: run each `test_*.sh` in a fresh `mktemp -d`, count
  assertions, fail the suite on any failure.
- **Interface**: `tests/run.sh`, `tests/lib.sh` (`assert_eq`,
  `assert_contains`, `assert_exit`, `tt_test_summary`), `TT_TEST_TMP`.
- **Tested**: yes (self-test in `test_harness.sh`).

### Libexec core (`/usr/libexec/trusttunnel/`)

- **Responsibility**: records accessors, UCI→TSV export, TOML generation,
  routing/nft/ip management.
- **Interface**: `records.sh` sourced (`TT_RECORDS`), `uci-export` (stdout
  TSV), `gen-config <records> [pem]` (stdout TOML), `routing
  dump|up|attach|reattach|detach|down|status` with `TT_IP`/`TT_NFT`
  overrides.
- **Tested**: yes (rewritten unit tests + golden byte-diffs).

### Service lifecycle

- **Responsibility**: procd service, first-boot firewall zone, hotplug
  route reattach, smart reload classification.
- **Interface**: `/etc/init.d/trusttunnel` (START=95/STOP=10, procd, triggers,
  `apply_settings` classes), `/etc/uci-defaults/40-luci-trusttunnel`,
  `/etc/hotplug.d/net/40-trusttunnel`.
- **Tested**: yes (`test_init_apply.sh`, `test_init_reload.sh` as oracles;
  shellcheck/`sh -n`).

### rpcd backend and UI

- **Responsibility**: all 9 RPC methods; three LuCI views; Russian
  translation.
- **Interface**: object `luci.trusttunnel`; views at
  `htdocs/luci-static/resources/view/trusttunnel/{status,settings,diagnostics}.js`;
  menu `admin/services/trusttunnel/*`; `.po` with `nplurals=3` header.
- **Tested**: yes (ucode `-c`, JS/JSON syntax, LuCI require checks; manual
  LuCI pass).

### Packaging, installer, CI

- **Responsibility**: build metadata, repo/installer behavior, CI gates and
  release pipeline.
- **Interface**: `Makefile` (tag-derived version, conffiles before
  `include luci.mk`), `install.sh` (`TT_REPO_URL`, apk/opkg paths),
  `.github/workflows/{ci,release}.yml`.
- **Tested**: yes (SDK builds, rootfs install tests).

## Implementation Decisions

- Clean-room method: spec first, implement from the spec, never transform
  the inherited file; the issues' contract sections are the spec.
- Order of work: harness → libexec core → service lifecycle → backend → UI →
  packaging/installer/CI → license flip; each step green on CI before the
  next.
- Verification: rewritten unit tests + golden byte-diff (old vs new
  deterministic outputs) + existing CI gates; fork-written init tests stay
  as the oracle.
- `LICENSE` and the git history keep the GPL-2.0 text; only the current
  tree's files are replaced; fresh-history (orphan) step is optional and
  out of scope unless requested.
- Every issue ends with a `git status` check that the old file is not
  accidentally kept alongside the new one (no `*.old`, no diffs of old vs
  new committed).

## Testing Decisions

- Behavior tests over golden outputs: `uci-export` TSV, `gen-config` TOML,
  `routing dump` ruleset — byte-diff old vs new before deleting the old
  implementation.
- The rewritten unit tests keep the existing harness conventions
  (`assert_*`, `TT_TEST_TMP`, fixtures) but with new test text.
- CI gates are the regression net: executable bits, shellcheck, `sh -n`,
  ucode build + `-c` (with negative control), JSON/JS syntax, LuCI require
  checks, rootfs installs (apk 25.12 / opkg 22.03–24.10).
- Manual verification checklist per component (service start/stop/reload on
  a device, LuCI pages, import flow) documented in the relevant plans.

## Out of Scope

- New features or behavior changes of any kind (including fixing bugs found
  along the way — note them, do not fix them in this effort).
- Changes to the files already original to the project (`trusttunnel-client`
  Makefile, `uninstall.sh`, fork-written tests, `repo-site/*`, keys).
- The TrustTunnel client binary itself (Apache-2.0 vendor; wrapper untouched).
- Merging anything back to the upstream project.
- Submitting to the official OpenWrt feed.
- The optional fresh-history (orphan/repo-restart) step — separately decided
  after the flip.
- Choosing the final license — the flip issue defines the process, the
  choice is a separate decision.

## Open Questions

| Question | Owner | Resolution Path |
| --- | --- | --- |
| Which license to flip to? | i-zhirov | Decide before the flip issue is implemented; candidates documented in `docs/reimplementation-consideration.md` §5 |
| Fresh history (orphan branch / new repo) or keep the existing history? | i-zhirov | Decide after the flip; not part of this PRD's tasks |

## Success Criteria

### Measurable Outcomes

- **SC-001**: Zero inherited files remain in the current tree: the only
  files with upstream lineage are `LICENSE` (replaced at flip) and the git
  history.
- **SC-002**: `sh tests/run.sh` passes with 100% of assertions green after
  each issue.
- **SC-003**: Golden byte-diff (old vs new) shows identical output for
  `uci-export`, `gen-config`, and `routing dump` on the shared fixtures.
- **SC-004**: All CI gates pass on the final branch state, including the
  rootfs install tests on apk (25.12) and opkg (22.03/23.05/24.10).
- **SC-005**: The flip commit changes only licensing metadata and the
  `LICENSE` file, and a reviewer finds no upstream-derived text in the tree.

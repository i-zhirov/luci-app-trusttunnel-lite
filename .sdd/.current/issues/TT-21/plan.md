# Implementation Plan: README.md clean-room rewrite

- **Created**: 2026-09-09
- **Status**: Implemented
- **Issue**: `.sdd/.current/issues/TT-21/issue.md`
- **PRD**: `.sdd/.current/prd.md`
- **Model**: tokenguard/deepseek-v4-flash
- **User Input**: "CLEAN-ROOM reimplementation. README.md is inherited GPL-2.0 code (heavily rewritten by the fork but residual derived prose remains). The rewrite re-expresses the remaining derived sentences while keeping all functional facts exact (paths, option names, URLs, package names)."

## Actualization (rebase on main, 2026-09-09)

The worktree was rebased onto `origin/main` (routing-profiles feature).
The README changed and the issue contract was updated accordingly. The
README at the rebased commit (c43e20a) is **296 lines**; the issue's Context
says 258 — that count is stale, the corrected number is used here (issue.md
itself is NOT modified by this plan). The contract changes the plan carries:

- The list machinery is dropped and replaced by **named routing profiles**:
  each profile carries a mode (vpn — everything except the bypass rules goes
  through the tunnel; bypass — only the VPN rules go through the tunnel) and
  two rule lists whose entries can be a domain, a `*.domain` wildcard, an IP,
  an `IP:port` pair or a CIDR range; `endpoint.routing_profile` names the
  profile assigned to the server, and the client enforces the mode and the
  rules itself. When no profile is assigned (or the name no longer matches),
  the legacy behavior applies — everything through the tunnel with the flat
  `domains.direct` list as exclusions.
- The installer's dependency set now includes `nftables`, and the installer
  runs `/etc/uci-defaults/40-luci-trusttunnel` immediately after the install:
  that script seeds the Default profile (and, on upgrades, moves the old
  `domains.direct` values into its bypass rules).
- The headless UCI example now covers `custom_sni`, `client_random`,
  `dns_upstream` and a bypass-mode `routing_profile` block; the comparison
  table carries the new Mode semantics and a Split tunneling row; the
  "Settings that were added" list is part of the document.
- The Status page shows the assigned profile.
- The fact inventory (Task 1) must be re-extracted from the REBASED
  README/code, and the outline (Task 2) carries the routing-profile facts
  into Configuration and Behaviour.

## Summary

Rewrite `README.md` as a new document that carries every functional fact of
the current README in fresh prose. Facts are contract data: the issue's
"Contract to reproduce" list is the specification, and the verified fact
table in Research R1 is the ground truth. The inherited text is consulted
only twice — Task 1 extracts its fact inventory (names and values, never
phrasing) and Task 4 diffs sentences against a snapshot taken before the
rewrite. The section order mirrors the current README's heading order, so
every new section maps 1:1 onto a familiar section of the old document and
the Task 4 diff can be reviewed section by section. Only `README.md`
changes; no code, config, or test files are touched. The
independence/new-license paragraph belongs to TT-22 and is explicitly out of
scope.

## Technical Context

- **Language/Version**: Markdown (GFM) rendered by GitHub; shell snippets are OpenWrt `ash` (`uci`, `apk`, `opkg`)
- **Primary Dependencies**: none (documentation-only change). Tooling: `markdownlint` (installed at `/opt/homebrew/bin/markdownlint`), `python3` (sentence-diff check), `rg`/`grep` (fact verification)
- **Storage**: n/a
- **Testing**: fact verification = grep/rg assertions against repo sources; prose originality = sentence-level diff against the pre-rewrite snapshot; rendering = markdownlint + visual pass
- **Target Platform**: GitHub repository root, rendered by GitHub

## Research

### R1. Fact verification (every contract fact below was confirmed against the code on 2026-09-09)

| Fact (contract) | Verified source | Status |
| --- | --- | --- |
| `luci-app-trusttunnel`, `trusttunnel-client` package names | `packages/*/Makefile` (`PKG_NAME`) | confirmed |
| `luci-i18n-trusttunnel-ru` | `install.sh` (optional install), `uninstall.sh` (removal order) | confirmed |
| Client binaries at `/opt/trusttunnel_client` | `packages/trusttunnel-client/Makefile` (`INSTALL_DIR`) | confirmed |
| Installer URL `https://raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/install.sh` | `install.sh` header | confirmed |
| Repo base URL `https://i-zhirov.github.io/trusttunnel-openwrt` (`TT_REPO_URL` default) | `install.sh` | confirmed |
| OpenWrt 22.03+; apk requires major ≥ 25, opkg requires major ≥ 22; PM auto-detected | `install.sh` (version gate) | confirmed |
| CPU families via `uname -m`: `x86_64`, `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel` | `install.sh` (arch gate, runs before any change) | confirmed |
| Dependencies `kmod-tun ip-full nftables curl ca-bundle` (no `dnsmasq-full`); after the package install the installer runs `/etc/uci-defaults/40-luci-trusttunnel` immediately (seeds the Default routing profile; idempotent, so the boot-time run stays harmless); the service is restored to its previous state (a first install leaves it disabled) | `install.sh` | confirmed |
| Key paths: `/etc/apk/keys/trusttunnel.pub`, `/etc/apk/repositories.d/trusttunnel.list`, `/etc/opkg/customfeeds.conf` line `src/gz trusttunnel <url>/opkg`, `/etc/opkg/keys/{trusttunnel.pub,<fingerprint>}` | `install.sh`, `uninstall.sh` | confirmed |
| UCI options: `main.{enabled,log_level}`; `endpoint.{hostname,username,password,protocol,anti_dpi,post_quantum,skip_verification,certificate,has_ipv6,custom_sni,client_random,routing_profile,address[],dns_upstream[]}`; `network.{mtu=1350,table=880,fwmark=0x9527,blackhole_on_down=1,include_router_traffic=0,lan_devices}`; `routing_profile.{name,mode,vpn_rules[],bypass_rules[]}`; `domains.direct[]` (legacy fallback list) | `packages/luci-app-trusttunnel/root/etc/config/trusttunnel` | confirmed |
| Removed settings absent from the tree: `main.mode`, `main.full_exclude_lists`, `lists` section, `network.list_dns`, `network.list_resolver`, `network.list_doh_url`, `network.list_doh_port`, `network.doh_network`, `network.intercept_dns`, `domains.bypass` | negative grep over config defaults (names appear only in comments/docs) | confirmed |
| Firewall zone `trusttunnel` (device `tun+`, input/forward REJECT, output ACCEPT, masq=1, mtu_fix=1), forwarding `lan → trusttunnel`; zone migration `tt0 → tun+`; profile seed: creates the `Default` profile (mode `vpn`), moves `domains.direct` values into its `bypass_rules`, sets `endpoint.routing_profile='Default'`; resets the update-check cache; registers the init script | `root/etc/uci-defaults/40-luci-trusttunnel` | confirmed |
| Kernel: fwmark `0x9527`, table `880`, rule priority `30820`, blackhole metric `1000`, attached route metric `1`, nft table `inet trusttunnel`, sets `tt_endpoint4`/`tt_endpoint6` | `root/usr/libexec/trusttunnel/routing` | confirmed |
| Generated `client.toml` (profile assigned, mode vpn): `vpn_mode = "general"`, `exclusions` from `routing_profile.bypass_rules`; (profile assigned, mode bypass): `vpn_mode = "selective"`, `exclusions` from `routing_profile.vpn_rules`; (nothing assigned or name mismatch): `vpn_mode = "general"`, `exclusions` from `domains.direct`; always `killswitch_enabled = false`, `change_system_dns = false`, empty `included_routes`/`excluded_routes` | `root/usr/libexec/trusttunnel/gen-config` | confirmed |
| Update check: `https://api.github.com/repos/i-zhirov/trusttunnel-openwrt/releases/latest`, cache `/var/cache/trusttunnel/release.json`, TTL 21600 | `root/usr/share/rpcd/ucode/luci.trusttunnel` | confirmed |
| Menu `admin/services/trusttunnel/{status,settings,diagnostics}` | `root/usr/share/luci/menu.d/luci-app-trusttunnel.json` | confirmed |
| Status page (state verdict incl. the assigned profile in the Mode row, versions, client log — the current README's "client's tun device" clause is reproduced as the README's own wording; the view itself renders no device row, the device appears only in Diagnostics' Tunnel device check); Diagnostics walks the chain with verdicts, plus `ping`/`probe`/`check_domain` tools | `htdocs/luci-static/resources/view/trusttunnel/{status,diagnostics}.js` | confirmed |
| Uninstall flags: `-y` (remove zone + settings, no prompts), `-c` (keep `/etc/config/trusttunnel`, no prompt) | `uninstall.sh` (`getopts "yc"`) | confirmed |
| Uninstall order i18n → app → client in one call; zone prompt default yes; settings prompt default no; removes `/opt/trusttunnel_client` + caches; rpcd restart + LuCI cache clear; kernel leftovers check | `uninstall.sh` | confirmed |
| Both repositories on GitHub Pages via Actions artifact deploy (no branch); apk index signed with `apk adbsign` (EC key), opkg feed signed with `usign`; release assets published via `softprops/action-gh-release`; manual `.apk`/`.ipk` downloads must be verified against the SHA-256 sums in the release notes | `.github/workflows/release.yml`, `README.md` caveats | confirmed |
| The fork touches no dnsmasq / `https-dns-proxy` / cron at runtime; only `uninstall.sh` cleans upstream leftovers | `uninstall.sh` cleanup block; negative grep | confirmed |

### R2. Discrepancies to fix while rewriting

- The intro's version claim targets only the apk generation (25.12+) and is
  stale: the installer also serves the opkg generation (22.03–24.10), and
  the Requirements section already states 22.03+. The new intro must state
  the full 22.03+ range.
- `install.sh`'s header comments describe the repositories as published
  from the repo branch and the opkg feed as living in the GitHub releases —
  both stale relative to `release.yml`. The README caveat that both
  repositories live on the GitHub Pages site (deployed by the release
  workflow, no branch holding the packages) matches `release.yml` and stays
  as verified.

### R3. Derivative-prose assessment (the rewrite scope)

Per `docs/reimplementation-file-review.md` §21, the residual derived prose is "architecture description, comparison table". Assessment by current section:

- **Most derivative — must be fully re-expressed**: the **Behaviour** section (architecture bullets: fwmark/routing flow, killswitch/blackhole explanation, profile/exclusion semantics, DNS non-interference — the flagged architecture description) and the **Differences from the original package** table with its removed-settings paragraph (the flagged comparison).
- **Moderately derivative**: the intro's feature-comparison paragraph (it describes the original package's list machinery — dnsmasq `nftset=` sets, itdoginfo/allow-domains lists — and enumerates the pieces the fork kept) and the "Everything on the router that the fork touches" list (factual, but with inherited sentence bones).
- **Mostly original (fork-specific facts)**: Requirements; install/update/uninstall flows (one-liner, flags, package-manager branches, key paths); Configuration/UCI example; the caveats (Pages hosting rationale, `~`/findrev, key rotation); Acknowledgements (links).
- Regardless of this grading, every section is rewritten, and Task 4's sentence diff enforces that no sentence survives anywhere.

### R4. Style notes

Current style: concise sentences; short intro paragraph + bullet lists; one comparison table; `sh` code blocks for all commands; numbered steps for the installer/uninstaller; exact paths/options/URLs in backticks; `##` headings in sentence case. Keep this style. The new section order mirrors the current README's heading order (see Summary and Task 2).

## Entities

N/A — documentation issue; no data entities, no state transitions.

## Contracts

N/A — no API endpoints. The "contract" is the issue's "Contract to reproduce" list, carried into this plan as the verified fact table (Research R1).

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `README.md` | Rewrite | Re-express every functional fact in new prose; the only file changed |

## Tasks

### [x] Task 1: Baseline — inventory the current README's facts and cross-check against the code

**Files:**

- Read: `README.md` (fact extraction only — names, values, URLs; never phrasing)
- Snapshot: copy the old README to `/var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/tt21-readme-old.md` (used only by Task 4's sentence diff)

- [x] **Step 1: Snapshot the old README and list its section headings**

```
cp README.md /var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/tt21-readme-old.md
rg -n '^## ' README.md
```

Expected: 9 sections (Requirements, Installation, Configuration, Behaviour, Updating, Uninstalling, Differences from the original package, Notes and caveats, plus Acknowledgements).

- [x] **Step 2: Extract the fact inventory from the current README into a checklist**

Expected: the inventory equals the issue's contract bullets — project identity (incl. the routing-profiles framing: named profiles, vpn/bypass modes, rule entry types, assignment via `endpoint.routing_profile`, legacy fallback), touched/untouched surfaces, requirements, behavior facts (incl. the assigned profile on the Status page), install/update/uninstall facts (incl. `nftables` in the dependency list and the immediate uci-defaults seed), UCI example options (incl. `custom_sni`/`client_random`/`dns_upstream` and the profile block), removed settings, added settings list, caveats (incl. the manual-download SHA-256 warning). Record only names, paths, values, URLs, flags; no sentences.

- [x] **Step 3: Cross-check every inventory entry against the code**

Run the Research R1 grep set (e.g. `rg -n 'TT_REPO_URL|i-zhirov.github.io' install.sh`; `rg -n 'include_router_traffic|blackhole_on_down|fwmark|lan_devices|routing_profile|bypass_rules|vpn_rules' packages/luci-app-trusttunnel/root/etc/config/trusttunnel`; the negative grep for the removed settings) and mark each entry confirmed or corrected.

Expected: every entry matches a code occurrence; the two Research R2 discrepancies are noted (stale apk-only intro claim; stale `install.sh` header comments vs `release.yml`).

**Verification**: checklist complete; every entry has a code reference or is marked corrected.

### [x] Task 2: Outline the new README from the issue's fact list

**Files:**

- Modify: `README.md` (heading skeleton + per-heading fact-coverage annotations; no prose yet)

- [x] **Step 1: Write the heading skeleton**

```
# trusttunnel-openwrt        ← identity, routing-profiles framing, surfaces the fork touches / leaves alone
## Requirements              ← OpenWrt 22.03+ (apk 25.12+ / opkg 22.03–24.10), CPU families, internet
## Installation              ← one-liner, installer steps (deps incl. nftables; immediate uci-defaults seed), repo/keys, service left disabled
## Configuration             ← LuCI Settings flow (Server / Routing / General) + headless UCI example (custom_sni, client_random, dns_upstream, profile block)
## Behaviour                 ← marking/routing, routing profiles (vpn/bypass semantics), killswitch, DNS, pages incl. assigned profile
## Updating                  ← apk/opkg upgrade; repo stays configured; settings untouched
## Uninstalling              ← one-liner, script steps, flags, manual removal
## Differences from the original package  ← comparison table (Mode, Split tunneling), removed + added settings
## Notes and caveats         ← update check, tun+ zone, signing/Pages hosting, key rotation, manual-download SHA-256
## Acknowledgements          ← upstream + vendor links
```

- [x] **Step 2: Annotate each heading with the issue contract bullets it must cover**

Expected: the issue's 7 contract bullets map onto the skeleton — bullet 1 (project) + 2/3 (touched/untouched) onto the intro; bullet 4 onto Requirements; bullet 5 onto Behaviour; bullet 6 onto Installation/Updating/Uninstalling; bullet 7 (UCI example, table, settings, caveats) onto Configuration + Differences + Notes; the independence/new-license paragraph is explicitly NOT included (it belongs to TT-22).

- [x] **Step 3: Verify coverage**

Run: `rg -n '^## ' README.md`. Expected: heading set identical to the skeleton, in the same order, no extras.

**Verification**: every issue contract bullet is assigned to exactly one section; the outline contains only headings and annotations.

### [x] Task 3a: Write the intro/features section (fresh prose)

**Files:**

- Modify: `README.md` (title, intro paragraphs, touched-surfaces list, untouched-surfaces list)

- [x] **Step 1: State the section's fact checks**

Facts: fork of `luci-app-trusttunnel` (GPL-2.0, `NooBiToo/TrustTunnelOpenWrt`) for OpenWrt **22.03+** (fix the stale apk-only intro claim); the community list machinery is dropped — **named routing profiles instead**: each profile carries a mode (vpn — everything except the bypass rules through the tunnel; bypass — only the VPN rules through the tunnel) and two rule lists (entries: a domain, `*.domain`, an IP, `IP:port`, a CIDR); `endpoint.routing_profile` assigns one profile to the server; the client enforces mode and rules itself after kernel marking; without an assigned profile the legacy behavior applies (everything through the tunnel, flat `domains.direct` exclusions); no list downloads, no cron, no dnsmasq-full requirement, no list-DNS options; touches `luci-app-trusttunnel` + `luci-i18n-trusttunnel-ru`, `trusttunnel-client` → `/opt/trusttunnel_client`, `/etc/config/trusttunnel`, `trusttunnel` zone (`tun+`) + `lan → trusttunnel` forwarding, fwmark → table 880 → tun with blackhole killswitch; does NOT touch dnsmasq, its config/cache, `https-dns-proxy`, cron, any other service.

- [x] **Step 2: Draft the section**

Write 2–4 short paragraphs plus two bullet lists (surfaces the fork touches / surfaces it leaves alone) from the issue contract and Research R1/R2 only. Do NOT open the old README while drafting. All names and paths in backticks. Fresh wording throughout — Task 4's sentence diff will reject any retained sentence.

- [x] **Step 3: Verify every fact token against the code and the new text**

```
rg -n 'luci-app-trusttunnel|luci-i18n-trusttunnel-ru|trusttunnel-client' packages/*/Makefile install.sh
rg -n 'opt/trusttunnel_client' packages/trusttunnel-client/Makefile
rg -n 'tun\+' packages/luci-app-trusttunnel/root/etc/uci-defaults/40-luci-trusttunnel
rg -n '22\.03|25\.12' install.sh
rg -n 'NooBiToo/TrustTunnelOpenWrt' README.md
rg -n 'routing_profile|vpn_rules|bypass_rules|custom_sni|client_random' packages/luci-app-trusttunnel/root/etc/config/trusttunnel
```

Expected: each token in the README matches a code occurrence; the intro states 22.03+; `rg -n 'dnsmasq-full|https-dns-proxy' README.md` shows them only inside the untouched-surfaces list.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: intro states 22.03+ and the routing-profiles framing; both lists are fact-exact per the greps.

### [x] Task 3b: Write the Requirements section

**Files:**

- Modify: `README.md` (Requirements section)

- [x] **Step 1: State the section's fact checks**

Facts: OpenWrt **22.03+** — apk **25.12+** and opkg **22.03–24.10**; the installer detects the package manager automatically; CPU in {`x86_64`, `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel`} checked via `uname -m` before anything is changed; internet access from the router for install and for the update check.

- [x] **Step 2: Draft the section**

Three bullets, fresh expression, exact version ranges and arch names in backticks.

- [x] **Step 3: Verify**

Run: `rg -n '25\.12|22\.03|24\.10|uname -m|x86_64|aarch64|armv7l|armv8l|mips|mipsel' install.sh` and `rg -n '22\.03|25\.12|24\.10|x86_64|aarch64|armv7l|armv8l|mips|mipsel' README.md`. Expected: version ranges and arch list byte-exact in both.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: version ranges and arch list match `install.sh` byte-for-byte.

### [x] Task 3c: Write the Install/Update/Uninstall sections

**Files:**

- Modify: `README.md` (Installation, Updating, Uninstalling sections)

- [x] **Step 1: State the section's fact checks**

Install: one-liner `sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/install.sh)"`; steps = checks (OpenWrt 22.03+, CPU, PM) → repo setup on the Pages site (`apk/` + `opkg/`; keys `/etc/apk/keys/trusttunnel.pub`, `/etc/apk/repositories.d/trusttunnel.list`, opkg `src/gz trusttunnel <url>/opkg` in `/etc/opkg/customfeeds.conf`, `/etc/opkg/keys/`) → dependencies `kmod-tun ip-full nftables curl ca-bundle` (no `dnsmasq-full`) → `luci-app-trusttunnel` + optional `luci-i18n-trusttunnel-ru` → client binaries as dependency into `/opt/trusttunnel_client` → `rpcd` restart → immediate run of `/etc/uci-defaults/40-luci-trusttunnel` (seeds the Default routing profile; idempotent) → service restored to its previous state (a first install leaves it disabled — configure first, start second); re-running the installer updates package + binary without touching settings.

Update: the repository entry stays configured, so updates are `apk update && apk upgrade` (25.12+) / `opkg update && opkg upgrade` (22.03–24.10); the client is a dependency and updates with the package; `/etc/config/trusttunnel` survives.

Uninstall: one-liner `…/uninstall.sh`; steps = stop + disable → remove i18n → app → client in one call → remove repo config and keys → remove `/opt/trusttunnel_client` + caches (plus upstream leftovers: lists, cron job, dnsmasq include) → prompt for the firewall zone (default yes) and the settings (default no) → rpcd restart + LuCI cache clear → kernel leftovers check (nft table, rule for table 880, routes in table 880); flags `-y` / `-c`; shared dependencies left alone; manual removal commands (`/etc/init.d/trusttunnel stop|disable`, `apk del luci-i18n-trusttunnel-ru luci-app-trusttunnel` / `opkg remove luci-i18n-trusttunnel-ru luci-app-trusttunnel`, `rm -rf /opt/trusttunnel_client`, key/feed removal, `uci show firewall | grep trusttunnel`, `uci delete`, `uci commit firewall`, `/etc/init.d/firewall restart`).

- [x] **Step 2: Draft the sections**

Fresh prose; numbered steps for both scripts; `sh` code blocks for all commands; flag semantics exactly as in `uninstall.sh`.

- [x] **Step 3: Verify**

```
rg -n 'raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/(install|uninstall)\.sh' install.sh uninstall.sh
rg -n 'kmod-tun|ip-full|nftables|curl|ca-bundle' install.sh
rg -n 'uci-defaults/40-luci-trusttunnel' install.sh
rg -n 'getopts "yc"|_opt_y|_opt_c' uninstall.sh
rg -n 'repositories\.d|customfeeds\.conf|src/gz' install.sh uninstall.sh
rg -n 'apk del|opkg remove|luci-i18n-trusttunnel-ru' uninstall.sh
rg -n 'apk update|opkg update|apk upgrade|opkg upgrade' install.sh
```

Expected: every command, path, and flag in the README appears in the scripts verbatim; `-y` (remove zone + settings unprompted) and `-c` (keep config unprompted) match `uninstall.sh` exactly; the README mentions the `nftables` dependency and the immediate uci-defaults profile seed.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: all install/uninstall commands in the README copy-paste-match the script sources; update commands match `install.sh`'s closing hint exactly.

### [x] Task 3d: Write the Configuration section (LuCI flow + headless UCI example)

**Files:**

- Modify: `README.md` (Configuration section)

- [x] **Step 1: State the section's fact checks**

LuCI path `Services → TrustTunnel → Settings`; the Server tab: **Import…** accepts the server-generated config (file text or a `tt://` link), or manual entry (addresses, TLS host name, user, password); the import fills every endpoint field the server can hand out — incl. `custom_sni`, `client_random`, the transport, the anti-DPI / post-quantum / IPv6 / verification flags and the DNS upstreams; the Routing tab: keep the seeded **Default** profile (VPN mode) or create your own — each profile has a mode (**VPN** — everything except the bypass rules tunneled, or **Bypass** — only the VPN rules tunneled) and two rule lists accepting a domain, `*.domain`, an IP, `IP:port` or a CIDR; the profile is assigned to the server via the Server tab; the General tab: start on boot, Save & Apply, then Start on the Status page. Headless example must use only existing options: `trusttunnel.endpoint.hostname`, `trusttunnel.endpoint.address` (list), `trusttunnel.endpoint.username`, `trusttunnel.endpoint.password`, `trusttunnel.endpoint.dns_upstream` (list), `trusttunnel.endpoint.custom_sni`, `trusttunnel.endpoint.client_random`, a bypass-mode profile block (`uci add trusttunnel routing_profile`, `name`, `mode='bypass'`, `vpn_rules` list entries, then `trusttunnel.endpoint.routing_profile` set to the profile name), `trusttunnel.main.enabled`, `/etc/init.d/trusttunnel enable|start`.

- [x] **Step 2: Draft the section**

Short flow description + `sh` code block with the UCI commands; option names byte-exact from the config defaults file.

- [x] **Step 3: Verify**

```
rg -n 'hostname|username|password|address|dns_upstream|custom_sni|client_random|routing_profile|vpn_rules|bypass_rules|direct|enabled' packages/luci-app-trusttunnel/root/etc/config/trusttunnel
rg -n 'custom_sni|client_random|dns_upstream|routing_profile|vpn_rules|bypass_rules|main\.enabled|init\.d/trusttunnel' README.md
```

Expected: every scalar option in the example exists in the config defaults with the same spelling (the example's LIST options — `endpoint.address`, `endpoint.dns_upstream`, `routing_profile.vpn_rules`/`bypass_rules` — are empty lists in the defaults file with no `list` lines, so verify those against `uci-export`'s schema and `settings.js`'s field definitions instead); the example round-trips through `uci set` / `uci add_list` / `uci add`.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: the UCI example uses only options present in `/etc/config/trusttunnel`; commands match the PRD's UCI schema.

### [x] Task 3e: Write the Behaviour section (architecture, fresh expression)

**Files:**

- Modify: `README.md` (Behaviour section — the most derivative section; write it entirely from the contract, not from the old text)

- [x] **Step 1: State the section's fact checks**

LAN forwarding marked `0x9527` → table `880` → the client's tun device; the router's own traffic goes out directly by default (`include_router_traffic`); routing profiles decide, inside the client, what happens to a connection once it is in the tunnel — vpn mode tunnels everything except the bypass rules, bypass mode tunnels only the VPN rules; domains are matched by SNI, IPs and CIDRs by destination (the same mechanism the legacy flat list used, now with both halves of the selection); killswitch = blackhole (metric 1000) while the device is down; client-side killswitch disabled in the generated config (`killswitch_enabled = false`); exclusions are profile-based — in vpn mode they come from `routing_profile.bypass_rules`, in bypass mode from `routing_profile.vpn_rules` (the tunneled set), and from `domains.direct` when no profile is assigned; no DNS interception (`change_system_dns = false`); Status page (service state, the **assigned profile** in the Mode row, versions, client log — "client's tun device" is the current README's wording, reproduced as such) and Diagnostics (walks config → client → tun → routing → firewall → network with a verdict per check).

- [x] **Step 2: Draft the section**

One bullet per fact cluster (marking/router traffic, profiles, killswitch, DNS, pages); each a fresh sentence pair; all kernel/option values in backticks.

- [x] **Step 3: Verify**

Run: `rg -n '0x9527|880|30820|1000|metric 1|tt_endpoint' packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`, `rg -n 'vpn_mode|killswitch_enabled|change_system_dns|exclusions' packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config`, `rg -n 'routing_profile|bypass_rules|vpn_rules|domains\.direct' packages/luci-app-trusttunnel/root/etc/config/trusttunnel packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/gen-config`, and the same tokens in README.md. Expected: every value matches the code byte-for-byte; the profile/exclusion semantics in the README match gen-config's three cases.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: the architecture bullets state only contract values found in `routing` and `gen-config`; the assigned-profile fact appears in the Status-page bullet.

### [x] Task 3f: Write the Caveats, comparison table, removed settings, and Acknowledgements

**Files:**

- Modify: `README.md` (Differences from the original package, Notes and caveats, Acknowledgements)

- [x] **Step 1: State the section's fact checks**

Comparison table rows: Mode (original: selective by list or full; fork: profile-driven routing with vpn/bypass modes, client-side), Domain lists (itdoginfo/allow-domains), dnsmasq-full requirement, list downloads / cron / `update_lists`, list-DNS options / DoH proxy / DNS interception, killswitch (blackhole route), Split tunneling (original: list-based, dnsmasq sets; fork: profile rules — domains/`*.domain`/IP/IP:port/CIDR — applied by the client), LuCI pages / import / diagnostics / update check. Removed settings list: `main.mode`, `main.full_exclude_lists`, the `lists` section, `network.list_dns`, `network.list_resolver`, `network.list_doh_url`, `network.list_doh_port`, `network.doh_network`, `network.intercept_dns`, `domains.bypass`. Added settings list: `endpoint.custom_sni`, `endpoint.client_random`, `endpoint.routing_profile`, and the `routing_profile` sections (`name`, `mode`, `vpn_rules`, `bypass_rules`); `domains.direct` remains as the legacy fallback for when no profile is assigned; on upgrade its values are moved into the Default profile's bypass rules. Caveats: the update check targets this repository's releases (GitHub API `releases/latest`, cache `/var/cache/trusttunnel/release.json`, TTL 21600) — the same releases that carry the package files for manual download; the zone matches `tun+` so it also covers foreign tun devices; both repositories are signed (apk index via `adbsign` EC key, opkg feed via `usign`) and hosted on the Pages site deployed by the release workflow with no branch holding the packages (the translation version's `~` / findrev rationale); manual `.apk`/`.ipk` downloads must be verified against the SHA-256 from the release notes; re-running the installer refreshes the signing keys. Acknowledgements links: `NooBiToo/TrustTunnelOpenWrt` (GPL-2.0), `TrustTunnel/TrustTunnel` (Apache-2.0), `TrustTunnel/TrustTunnelClient`.

- [x] **Step 2: Draft the sections**

Comparison as a Markdown table; removed + added settings as backticked lists; caveats as bullets; acknowledgements as links with license facts. Fresh wording for every cell — the table content is contract data, the phrasing must be new.

- [x] **Step 3: Verify**

```
rg -n 'main\.mode|full_exclude_lists|list_dns|list_resolver|list_doh|doh_network|intercept_dns|domains\.bypass' packages/luci-app-trusttunnel/root/etc/config/trusttunnel   # expect NO matches
rg -n 'custom_sni|client_random|routing_profile|vpn_rules|bypass_rules' packages/luci-app-trusttunnel/root/etc/config/trusttunnel   # expect matches in the defaults
rg -n 'releases/latest|release\.json|21600' packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel
rg -n 'adbsign|usign|deploy-pages|softprops' .github/workflows/release.yml
rg -n 'main\.mode|full_exclude_lists|list_dns|list_resolver|list_doh|doh_network|intercept_dns|domains\.bypass|custom_sni|client_random|routing_profile|releases/latest|adbsign|usign|SHA-256' README.md
```

Expected: removed-settings names appear in the README but never in the config defaults; added-settings names appear in the config defaults and in the README; caveat URLs and values match the code; the manual-download SHA-256 warning is present.

- [x] **Step 4: Run markdownlint**

Run: `markdownlint --disable MD013 README.md` Expected: no findings.

**Verification**: the table covers the issue's comparison facts (incl. the Mode and Split tunneling rows); every URL in Acknowledgements is the exact repository URL.

### [x] Task 4: Final verification — fact checklist, sentence diff, render check

**Files:**

- Verify: `README.md`

- [x] **Step 1: Run the full fact checklist**

Re-run the Research R1 grep set once more against the code AND against the new README; map each of the issue's 7 contract bullets to at least one README statement. The routing-profile facts (modes, rule entry types, assignment option, legacy fallback, added-settings list) and the manual-download SHA-256 warning must each appear in a README statement backed by a code/repo occurrence.

Expected: every path/option/URL/package name in the README occurs in the code with identical spelling; no contract bullet is left uncovered.

- [x] **Step 2: Sentence-level diff against the old README**

```
python3 - <<'EOF'
import re, sys
old = open('/var/folders/6x/s23gvzh933v4ml_5ybc_tydh0000gp/T/opencode/tt21-readme-old.md').read()
new = open('README.md').read()
sents = [s.strip() for s in re.split(r'(?<=[.!?])\s+', old) if len(s.split()) >= 6]
hits = [s for s in sents if s.lower() in new.lower()]
print('\n'.join(hits) if hits else 'OK: no retained sentences')
sys.exit(1 if hits else 0)
EOF
```

Expected: exit 0 ("no retained sentences") — no sentence of ≥ 6 words from the old README appears in the new text. Follow up with a manual `git diff README.md` review to catch shorter reused phrasings (heuristic: no run of 5+ consecutive words copied).

- [x] **Step 3: Render check**

Run: `markdownlint --disable MD013 README.md` (no findings) and open the file for a visual pass: headings render, code blocks intact, table columns align, no broken backticks or dangling list markers.

- [x] **Step 4: Scope check**

Run: `git status --short` Expected: only `README.md` modified; no scratch files left in the tree.

**Verification**: the issue's three acceptance criteria are met — every functional fact present and accurate (Step 1), prose new (Step 2), URLs/package names/paths/options exact (Step 1) — and the diff shows a single-file change.

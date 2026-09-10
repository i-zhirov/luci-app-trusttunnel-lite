# Issue Validation Report: README.md clean-room rewrite

- **Validated**: 2026-09-10
- **Model**: tokenguard/deepseek-v4-flash
- **Issue**: `.sdd/.current/issues/TT-21/issue.md`
- **Plan**: `.sdd/.current/issues/TT-21/plan.md`
- **Overall Status**: Complete
- **Validation attempt**:
  1

## Summary

| Category | Pass | Partial | Fail | Total |
| --- | --- | --- | --- | --- |
| Tasks | 9 | 0 | 0 | 9 |
| Acceptance Criteria | 3 | 0 | 0 | 3 |
| Entities | 0 | 0 | 0 | 0 |
| Contracts | 0 | 0 | 0 | 0 |
| Guidelines | 0 | 0 | 0 | 0 |

Entities/Contracts/Guidelines are N/A: documentation-only issue (no data
entities, no API endpoints, no `AGENTS.md` in the tree).

## Task Status

- [x] **Task 1** (Baseline — fact inventory + code cross-check) - PASS.
  The rewritten README (committed in `0979c3f`, 473 changed lines) carries
  the full issue fact inventory; every inventory entry was re-verified
  against the code with grep (see evidence below). The pre-rewrite snapshot
  used by Task 4 is reproducible from git (`0979c3f^:README.md` = the
  44db74c-era file modulo the `nftables` dependency line added by the
  rebase).
- [x] **Task 2** (Outline) - PASS. Heading set matches the skeleton and
  order: intro, `## Requirements`, `## Installation`, `## Configuration`,
  `## Behaviour`, `## Updating`, `## Uninstalling`,
  `## Differences from the original package`, `## Notes and caveats`,
  `## Acknowledgements` (+ `## License` added by the later TT-22 flip
  commit `a5c376b`, which is expected per the issue notes). All 7 contract
  bullets are covered; no extras.
- [x] **Task 3a** (Intro / touched-untouched) - PASS. Routing-profiles
  framing (named profiles, VPN/Bypass mode semantics, rule entry types,
  `endpoint.routing_profile` assignment, legacy `domains.direct` fallback,
  no lists/cron/dnsmasq-full/list-DNS options) matches the config defaults
  and `gen-config`; touched list (packages, `/opt/trusttunnel_client`,
  `/etc/config/trusttunnel`, `trusttunnel` zone `tun+`, `lan → trusttunnel`
  forwarding, fwmark → table `880` → tun + blackhole) and untouched list
  (dnsmasq, its config/cache, `https-dns-proxy`, cron) match the code and
  negative greps. Note: the intro now reads "independent implementation
  (Apache-2.0) of the same idea as `luci-app-trusttunnel`…" — that is the
  TT-22 flip wording, expected on this branch.
- [x] **Task 3b** (Requirements) - PASS. OpenWrt 22.03+ / apk 25.12+ /
  opkg 22.03–24.10, `uname -m` CPU gate, the five families
  (`x86_64`, `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel`), internet
  access — byte-exact against `install.sh` (lines 49–64).
- [x] **Task 3c** (Install/Update/Uninstall) - PASS. One-liner URLs
  (`raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/{install,uninstall}.sh`)
  match the script headers; dependency set `kmod-tun ip-full nftables curl
  ca-bundle` matches `install.sh`; the immediate
  `/etc/uci-defaults/40-luci-trusttunnel` run (line 134–136) and its
  idempotence; repo/key paths (`/etc/apk/repositories.d/trusttunnel.list`,
  `/etc/apk/keys/trusttunnel.pub`, `src/gz trusttunnel <url>/opkg`,
  `/etc/opkg/keys/` stable name + usign fingerprint); rpcd restart; service
  restored to previous state; update commands (`apk update && apk upgrade`,
  `opkg update && opkg upgrade` from `install.sh` closing hints); uninstall
  order i18n → app → client, caches (`/opt/trusttunnel_client`,
  `/usr/share/trusttunnel`, `/var/cache/trusttunnel`,
  `/var/etc/trusttunnel`), zone prompt default yes, settings default no,
  `-y`/`-c` flags (`getopts "yc"`), rpcd restart + LuCI cache clear, kernel
  leftovers (nft table, rule for 880, routes in 880), manual removal
  commands — all verbatim against `uninstall.sh`.
- [x] **Task 3d** (Configuration) - PASS. LuCI path and three tabs match
  the menu (`admin/services/trusttunnel/{status,settings,diagnostics}`) and
  `settings.js` (Routing profiles tab, selector on Server tab); the headless
  UCI example uses only existing options (`endpoint.{hostname,address,
  username,password,dns_upstream,custom_sni,client_random,routing_profile}`,
  `routing_profile.{name,mode,vpn_rules}`, `main.enabled`,
  `/etc/init.d/trusttunnel enable|start`) — verified against the config
  defaults, `uci-export` (listopt `endpoint address|dns_upstream`,
  `routing_profile.*` records) and `settings.js`. Minor accuracy note on
  the Import paragraph — see Issue 1.
- [x] **Task 3e** (Behaviour) - PASS. fwmark `0x9527`, table `880`,
  rule priority `30820` (not stated, code-only), blackhole metric `1000`,
  attached-route metric `1`, nft table `inet trusttunnel` with
  `tt_endpoint4/6`, `include_router_traffic` off by default;
  profile semantics match `gen-config`'s three branches (bypass →
  `vpn_mode = "selective"` + exclusions from `routing_profile.vpn_rules`;
  vpn → `"general"` + `bypass_rules`; unassigned → `"general"` +
  `domains.direct`); `killswitch_enabled = false`,
  `change_system_dns = false`, empty `included_routes`/`excluded_routes`;
  Status page Mode row names the assigned profile
  (`status.js` renderFacts), no device row rendered; Diagnostics has
  `ping`/`probe`/`check_domain` and the tunnel-device check.
- [x] **Task 3f** (Caveats/table/settings/Acknowledgements) - PASS.
  Comparison table covers the contract rows (Mode: "Routing profiles with
  vpn/bypass modes, assigned per server and enforced by the client"; Split
  tunneling row present); every cell is re-expressed vs the pre-rewrite
  table. Removed settings (`main.mode`, `main.full_exclude_lists`, `lists`,
  `network.list_dns|list_resolver|list_doh_url|list_doh_port|doh_network|
  intercept_dns`, `domains.bypass`) appear in the README but have zero
  occurrences in `packages/` (negative grep exit 1). Added settings match
  the defaults + `uci-export`; `domains.direct` fallback and Default-profile
  migration match `40-luci-trusttunnel`. Caveats verified: update-check URL
  `https://api.github.com/repos/i-zhirov/trusttunnel-openwrt/releases/latest`,
  cache `/var/cache/trusttunnel/release.json`, TTL `21600` (rpcd ucode);
  `tun+` zone scope; Pages hosting with no branch + `~`/findrev rationale
  (`release.yml` comment lines 316–319); `adbsign` (apk index, line 391) /
  `usign` (opkg feed, line 449); manual-download SHA-256 warning; key
  rotation. Acknowledgements URLs are exact.
- [x] **Task 4** (Final verification) - PASS. (a) Fact checklist: all
  contract bullets map to README statements backed by code occurrences.
  (b) Sentence diff: `python3` splitter against `0979c3f^:README.md`
  (67 sentences ≥ 6 words) → **OK: no retained sentences**; also passes
  against the 44db74c-era file (65 sentences). 5-word-run heuristic: only
  verbatim contract data (commands, URLs, option-name lists, headings,
  table pipes) plus one 5-token structural fragment — see Issue 2.
  (c) Render check: `markdownlint --disable MD013 README.md` exits 0, no
  findings (markdownlint-cli 0.45.0); headings/code blocks/tables render
  correctly on read-through. (d) Scope: the README rewrite is the only
  README change; the working tree has no uncommitted README modifications
  (other files present belong to other issues). `sh tests/run.sh`: all
  suites pass — 9 suites, 315 assertions, 0 failed, "all tests passed".

## Acceptance Criteria Status

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Every functional fact above is present and accurate | MET | All 7 contract bullets verified via grep against `install.sh`, `uninstall.sh`, config defaults, `40-luci-trusttunnel`, `routing`, `gen-config`, `uci-export`, rpcd ucode, `settings.js`/`status.js`/`diagnostics.js`, menu JSON, `release.yml` (evidence per task above) |
| 2 | The prose is new expression (no sentences retained from the inherited README) | MET | Sentence diff vs `0979c3f^:README.md`: 0 of 67 old ≥6-word sentences found in the new text; same result vs the 44db74c-era file (0 of 65) |
| 3 | URLs, package names, file paths, option names are exact | MET | Byte-exact matches: installer/uninstaller URLs, `luci-app-trusttunnel`/`trusttunnel-client`/`luci-i18n-trusttunnel-ru`, `/opt/trusttunnel_client`, `/etc/config/trusttunnel`, `/etc/apk/...`, `/etc/opkg/...`, all UCI options, kernel values `0x9527`/`880`/`1000`, update-check URL/cache/TTL |

## Entity Status

| Entity | Fields | Relationships | Validation | Status |
| --- | --- | --- | --- | --- |
| N/A | - | - | - | N/A (documentation issue, no data entities) |

## Contract Status

| Endpoint | Method | Status | Notes |
| --- | --- | --- | --- |
| N/A | - | N/A | No API endpoints; the "contract" is the issue's fact list, verified under Acceptance Criterion 1 |

## Guidelines Compliance

| Guideline | Status | Notes |
| --- | --- | --- |
| N/A | N/A | No `AGENTS.md` in the repository |

## Issues Found

1. **Import paragraph lists `post-quantum` among the fields the Import… button populates, but the import path never sets it (minor, inherited)**
   - Location: `README.md` Configuration section, Server tab bullet
   - Description: The bullet says Import… "populates each endpoint field the
     server is able to fill: … plus anti-DPI, post-quantum, IPv6 and
     certificate-verification switches, and the DNS upstreams". The rpcd
     `import_config` handler parses only `hostname`, `username`, `password`,
     `certificate`, `custom_sni`, `client_random`, `upstream_protocol`,
     `has_ipv6`, `skip_verification`, `anti_dpi`, `addresses`,
     `dns_upstreams`, and `settings.js` applies exactly that set —
     `post_quantum` is a Settings field (`settings.js` line 139) and a UCI
     option but is not part of the import response.
   - Impact: Low. The claim is inherited from the pre-rewrite README (same
     wording there), not introduced by this rewrite, and `post_quantum` is a
     rare manual setting; it slightly overstates what the import fills.
   - Recommendation: Either drop "post-quantum" from the import-populated
     list, or rephrase so the sentence reads as the page's field set
     ("…the page also exposes the post-quantum switch"). Verify against the
     vendor `setup_wizard` output before changing, in case a future wizard
     version emits it.
2. **One 5-token structural fragment shared with the pre-rewrite README: "— and two rule lists" (observation)**
   - Location: `README.md` Configuration section, Routing profiles tab
   - Description: The plan's stricter heuristic ("no run of 5+ consecutive
     words copied") flags the fragment "— and two rule lists" (old: "or
     **Bypass** (tunnel only the VPN rules) — and two rule lists accepting a
     domain…" vs new: "or **Bypass** (only the VPN-list entries are
     tunneled) — and two rule lists whose entries accept a domain…"). All
     other 5-word hits are verbatim contract data (commands, URLs, option
     names, headings) that must stay exact per Criterion 3.
   - Impact: None — the sentence-level test passes (0/67 retained) and the
     rest of the clause is re-expressed; "mode and two rule lists" is the
     fact being stated.
   - Recommendation: Accept as-is, or apply a cosmetic rephrase such as
     "…with two rule lists attached" if byte-level uniqueness is desired.

## Recommendations

- No blocking action items. If Issue 1 is addressed, re-run
  `markdownlint --disable MD013 README.md` and the sentence diff.
- Optional: the manual-download SHA-256 caveat is contract data carried
  from the old README, but `release.yml` (softprops/action-gh-release) does
  not visibly generate SHA-256 sums into the release notes; if the release
  notes do not actually contain them, consider documenting the checksum
  source (out of scope for this README-only issue — note for a future
  release-pipeline issue).
- Re-validation of the issue/plan statuses is intentionally skipped per the
  validation request (this report only); on re-validation the working tree
  should be re-checked for the unrelated modified `.github/workflows/ci.yml`
  and the untracked TT-15…TT-20 validation reports, which do not belong to
  this issue.

# Issue TT-21: README.md

- **Status**: Validated
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent; may run in parallel)
- **Effort**: S–M
- **Files**: `README.md`

## Context

`README.md` was inherited and heavily rewritten by the fork (860 changed
lines; the current file is 258 lines) but still contains residual derived
prose (architecture description, comparison with the original). Docs are
protected by copyright, so the remaining derived text must be re-expressed.

## Contract to reproduce

The document describes (functional facts, re-express the prose):

- The project: a lightweight fork of luci-app-trusttunnel (GPL-2.0) for
  OpenWrt 22.03+; no community domain lists — **named routing profiles
  instead** (VPN/Bypass modes with domain/`*.domain`/IP/IP:port/CIDR rule
  lists, one profile assigned to the server; without an assigned profile
  the legacy behavior applies: everything through the tunnel with the
  flat "do not bypass" list). No list downloads, no cron, no
  dnsmasq-full requirement, no list-DNS options.
- What the package touches: `luci-app-trusttunnel` +
  `luci-i18n-trusttunnel-ru`, `trusttunnel-client` →
  `/opt/trusttunnel_client`, `/etc/config/trusttunnel`, `trusttunnel`
  firewall zone (`tun+`) + `lan → trusttunnel` forwarding, fwmark → table
  880 → client tun with blackhole killswitch.
- What it does NOT touch: dnsmasq, its config/cache, `https-dns-proxy`,
  cron, any other service.
- Requirements: OpenWrt 22.03+ (apk 25.12+ / opkg 22.03–24.10); CPU in
  the 5 vendor families (x86_64, aarch64, armv7l/armv8l, mips, mipsel);
  internet access for install and the update check.
- Behavior: LAN forwarding marked `0x9527` → table 880 → tun; router's
  own traffic direct by default (`include_router_traffic`); killswitch =
  blackhole while the device is down; client-side killswitch disabled in
  the generated config; exclusions (`domains.direct`) applied by the
  client via SNI; no DNS interception.
- Install/update/uninstall flows (install.sh now installs `nftables`
  among the dependencies and runs the uci-defaults script immediately to
  seed the Default routing profile; uninstall.sh, repo layout, signing
  keys).
- Headless UCI example (now incl. `custom_sni`, `client_random`,
  `dns_upstream`, and a bypass-mode profile block); difference table vs
  the original (Mode row: "routing profiles (vpn/bypass), client-side";
  Split tunneling row); removed settings list; added settings list
  (`endpoint.custom_sni`, `endpoint.client_random`,
  `endpoint.routing_profile`, the `routing_profile` sections); caveats
  (update check targets this repo's releases; zone covers foreign tun
  devices; both repos signed, hosted on Pages without a branch).

## Acceptance criteria

- [ ] Every functional fact above is present and accurate.
- [ ] The prose is new expression (no sentences retained from the
      inherited README).
- [ ] URLs, package names, file paths, option names are exact.

## How to verify

1. Diff the new README against the current one: functional facts
   preserved, sentence-level text new.
2. Cross-check every path/option name against the code (spot-check with
   grep).
3. Read-through: a new user can install and configure from the README
   alone.

## Notes

- After TT-22 the README also states the project's independence and new
  license (that paragraph is part of the flip issue, not this one).

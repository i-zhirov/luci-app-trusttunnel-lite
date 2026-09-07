# luci-app-trusttunnel-lite

A lightweight fork of
[luci-app-trusttunnel](https://github.com/NooBiToo/TrustTunnelOpenWrt)
(GPL-2.0) for OpenWrt 25.12+ (apk).

**Full-tunnel only, no domain lists.** The original package routes *selected*
domains into the tunnel using dnsmasq `nftset=` sets and community lists from
itdoginfo/allow-domains. This fork removes the entire list machinery —
no lists, no list downloads, no cron, no dnsmasq-full requirement, no
list-DNS options — and keeps the rest: the TrustTunnel client as a procd
service, **all LAN traffic through the tunnel**, the firewall-level killswitch
(blackhole route), "do not bypass" exclusions, and the LuCI interface
(Status / Settings / Diagnostics).

Everything on the router that the fork touches:

- `luci-app-trusttunnel-lite` (+ `luci-i18n-trusttunnel-lite-ru` translation)
- `trusttunnel-client` — the official TrustTunnel client binaries, installed
  as a dependency of the LuCI package into `/opt/trusttunnel_client`
- `/etc/config/trusttunnel` — your settings (survives package updates)
- a `trusttunnel` firewall zone (`tun+`) with a `lan → trusttunnel` forwarding
  rule, created on install
- routing: fwmark rule → table 880 → client's tun device, with a blackhole
  killswitch

What the fork does **not** touch: dnsmasq, its config, its cache, the
`https-dns-proxy` package, cron, or any other service.

## Requirements

- OpenWrt **22.03 or newer** — both package-manager generations: **25.12+**
  (apk) and **22.03 – 24.10** (opkg). The installer detects the package
  manager automatically. 21.02 and older are not supported (their rpcd
  cannot run this package's ucode backend).
- CPU in {`x86_64`, `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel`} — the
  TrustTunnel client ships prebuilt binaries only for these. The installer
  checks `uname -m` before installing anything, so an unsupported device
  fails cleanly, before anything is changed.
- Internet access from the router (GitHub must be reachable for install and
  for the update check).

## Installation

One command on the router:

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
```

What the installer does:

1. Checks that this is OpenWrt 22.03+ with a supported CPU and either `apk`
   (25.12+) or `opkg` (22.03–24.10).
2. Sets up the package repository — a signed apk repository (`apk/`
   subdirectory) and a signed opkg repository (`opkg/` subdirectory) on
   the GitHub Pages site, deployed by the release workflow — and installs
   the corresponding public signing key.
3. Installs dependencies: `kmod-tun`, `ip-full`, `curl`, `ca-bundle`
   (no `dnsmasq-full` — the fork does not need nftset in dnsmasq).
4. Installs `luci-app-trusttunnel-lite` and the translation package from
   the repository.
5. The client binaries install automatically as a dependency
   (`trusttunnel-client`) into `/opt/trusttunnel_client`.
6. Restarts `rpcd` so LuCI sees the new backend.

The repository entry stays configured on the router, so package updates are
a plain `apk update && apk upgrade` (25.12+) or `opkg update && opkg upgrade`
(22.03–24.10) — no need to re-run the installer: the client binary is a
dependency of the package and updates with it.

The service is left **disabled** after installation, on purpose: configure
first, start second. Re-running the installer updates the package and the
binary without touching your settings.

## Configuration

Open **LuCI → Services → TrustTunnel → Settings**:

1. **Server** — press **Import…** and paste the config your server generated
   (config file text or a `tt://` link), or fill in addresses, TLS host name,
   user and password by hand.
2. **Exclusions** (optional) — domains, IPs or CIDRs that always go out
   directly, bypassing the tunnel ("do not bypass").
3. **General** — turn on **Start on boot**, **Save & Apply**, then press
   **Start** on the Status page.

Headless (UCI):

```sh
uci set trusttunnel.endpoint.hostname='vpn.example.com'
uci add_list trusttunnel.endpoint.address='203.0.113.10:443'
uci set trusttunnel.endpoint.username='alice'
uci set trusttunnel.endpoint.password='secret'
uci add_list trusttunnel.domains.direct='bank.example'
uci set trusttunnel.main.enabled='1'
uci commit trusttunnel
/etc/init.d/trusttunnel enable
/etc/init.d/trusttunnel start
```

## Behaviour

- **All forwarded LAN traffic** is marked (fwmark `0x9527`) and routed via
  table 880 through the client's tun device. The router's own traffic goes
  out directly by default (enable "Route the router's own traffic too" to
  change that).
- **Killswitch:** while the tunnel device is down, marked traffic falls into
  a blackhole route — dropped, not leaked to the provider. The client's own
  (application-level) killswitch is disabled in the generated config so the
  two do not fight over the firewall.
- **Exclusions** are applied by the client itself, by SNI, after kernel
  marking.
- **DNS:** the fork does not intercept or redirect DNS. LAN clients keep
  using the router's resolver as configured in OpenWrt; the tunnel carries
  the traffic itself.
- **Status page** shows the service state, the client's tun device, the
  version of everything, and the client log. **Diagnostics** walks the whole
  chain (config → client → tun → routing → firewall → network) with a
  verdict and a hint for every check.

## Updating

The installer leaves the package repository configured on the router, so
package updates are the standard package-manager commands:

```sh
# apk (25.12+):
apk update && apk upgrade
# opkg (22.03–24.10):
opkg update && opkg upgrade
```

The client binary is a dependency of the package (`trusttunnel-client`),
so it is updated by the same commands. Settings in `/etc/config/trusttunnel`
are left untouched.

## Uninstalling

One command on the router:

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/uninstall.sh)"
```

What the script does:

1. Stops the service and disables it (removes the autostart link).
2. Removes both packages in a single call — `apk del` on 25.12+,
   `opkg remove` on 22.03–24.10 (the i18n package is removed first,
   because it depends on the main one).
3. Removes the repository configuration the installer left behind: the apk
   repositories.d entry and signing key, or the opkg feed line and feed key.
4. Removes the client binary from `/opt/trusttunnel_client`, the cached
   data and — if they survived from the original package — the lists, the
   cron job and the dnsmasq include.
5. Offers to remove the `trusttunnel` firewall zone and forwarding rule
   (default: yes) and the settings in `/etc/config/trusttunnel`
   (default: no — a reinstall then keeps your configuration).
6. Restarts `rpcd` and clears the LuCI caches so the menu and pages
   forget the removed package, then checks that no table, rule or route
   is left in the kernel.

Flags:

- `-y` — answer yes to every question: remove the firewall zone and the
  settings too;
- `-c` — keep `/etc/config/trusttunnel`, do not ask.

The dependencies (`kmod-tun`, `ip-full`, `curl`, `ca-bundle`) are left
alone — they are shared and may be needed by other packages.

If you prefer to uninstall by hand, step by step:

```sh
/etc/init.d/trusttunnel stop
/etc/init.d/trusttunnel disable

# The i18n package must be in the SAME call (it depends on the main one).
# apk (25.12+):
apk del luci-i18n-trusttunnel-lite-ru luci-app-trusttunnel-lite
# opkg (22.03-24.10) — the i18n package must be listed FIRST:
opkg remove luci-i18n-trusttunnel-lite-ru luci-app-trusttunnel-lite

rm -rf /opt/trusttunnel_client

# The repository entry and the signing keys left by the installer:
# apk (25.12+):
rm -f /etc/apk/repositories.d/trusttunnel.list /etc/apk/keys/trusttunnel.pub
# opkg (22.03-24.10) — the feed key is named by its fingerprint:
sed -i '/^src\/gz trusttunnel /d' /etc/opkg/customfeeds.conf
rm -f /etc/opkg/keys/trusttunnel.pub
```

The `trusttunnel` firewall zone and the `lan → trusttunnel` forwarding rule
remain in `/etc/config/firewall` — remove them by hand:

```sh
uci show firewall | grep trusttunnel
uci delete firewall.<zone_section>
uci delete firewall.<forwarding_section>
uci commit firewall
/etc/init.d/firewall restart
```

Settings in `/etc/config/trusttunnel` remain after removing the package;
delete the file if you do not want them.

## Differences from the original package

| | original | this fork |
|---|---|---|
| Mode | selective (by list) or full | **full only** |
| Domain lists (itdoginfo/allow-domains) | yes | **no** |
| dnsmasq-full requirement | yes (for selective) | **no** |
| List downloads / cron / update_lists | yes | **no** |
| List-DNS options, DoH proxy, DNS interception | yes | **no** |
| Killswitch (blackhole route) | yes | **yes** |
| "Do not bypass" exclusions | yes | **yes** (only place for exclusions) |
| LuCI pages, import, diagnostics, update check | yes | **yes** (trimmed) |

Settings that were removed: `main.mode`, `main.full_exclude_lists`, the whole
`lists` section, `network.list_dns`, `network.list_resolver`,
`network.list_doh_url`, `network.list_doh_port`, `network.doh_network`,
`network.intercept_dns`, `domains.bypass`.

## Notes and caveats

- The update check on the Status page targets this repository's releases —
  the same GitHub releases that carry the package files for manual download.
- The firewall zone matches `tun+`, so it also covers other VPNs' tun
  devices if you run more than one.
- The client binary comes from the official TrustTunnel installer; the
  packages are installed from the signed repositories (the apk index is
  signed with an EC key, the opkg feed with usign — both verified against
  the public keys the installer installs). If you download `.apk`/`.ipk`
  files manually, verify the SHA-256 from the release notes.
- Both repositories live on this project's GitHub Pages site, deployed
  directly by the release workflow (no branch holds the packages): the
  translation package's version contains a `~` (LuCI's findrev format),
  GitHub release asset names cannot contain `~`, and apk reconstructs
  package file names from the version verbatim. Pages serves file names
  byte-identically, so the site serves the indexes and the packages
  unchanged — and the opkg repository shares the same location for
  consistency.
- Re-running the installer refreshes the signing keys, so a key rotation
  only requires re-running it once on each router; existing installations
  keep working (`apk update`/`opkg update` verify against the keys already
  installed).

## Acknowledgements

- [NooBiToo/TrustTunnelOpenWrt](https://github.com/NooBiToo/TrustTunnelOpenWrt)
  — the original package this fork is derived from (GPL-2.0)
- [TrustTunnel/TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) — the
  protocol, server and client (Apache-2.0)
- [TrustTunnel/TrustTunnelClient](https://github.com/TrustTunnel/TrustTunnelClient)
  — the vendor client and its installer

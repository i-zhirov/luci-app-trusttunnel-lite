# trusttunnel-openwrt

TrustTunnel client daemon for OpenWrt routers: it runs the tunnel, exposes
a LuCI control page and delivers the tunnel to the LAN. It targets OpenWrt
**22.03 and newer**.

The package is built around **named routing profiles**:

- Each profile carries a **mode** and two rule lists.
- **VPN mode** sends everything through the tunnel except the entries in the
  bypass list; **Bypass mode** sends only the entries in the VPN list through
  the tunnel.
- Rule entries accept a plain domain, a `*.domain` wildcard, an IP address,
  an `IP:port` pair, or a CIDR range.
- One profile is assigned to the server via `endpoint.routing_profile`, and
  the client itself enforces the mode and the rule lists once the traffic has
  been marked into the tunnel.
- With no profile assigned (or a name that no longer matches any profile),
  the previous behavior takes over: everything goes into the tunnel, and the
  flat `domains.direct` list is applied as the exclusions.

**Everything on the router that this package touches:**

- `luci-app-trusttunnel` plus the optional `luci-i18n-trusttunnel-ru` language
  package;
- `trusttunnel-client` and its binaries under `/opt/trusttunnel_client`;
- the `/etc/config/trusttunnel` configuration file;
- a firewall zone named `trusttunnel` (bound to the `tun+` device wildcard)
  together with the forwarding rule `lan → trusttunnel`;
- the routing chain fwmark → table `880` → the client's tun device, backed by
  a blackhole killswitch.

**Everything on the router that this package does NOT touch:** dnsmasq, its
config and cache, `https-dns-proxy`, cron, and nothing else on the router is
affected.

## Requirements

- **OpenWrt 22.03 or newer**: `apk`-based systems need 25.12+, `opkg`-based
  systems 22.03–24.10. The script figures out which package manager is in
  use.
- **CPU**: one of the five families the vendor builds for — `x86_64`,
  `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel`. The installer probes
  `uname -m` first and aborts before anything changes on unsupported
  hardware.
- **Internet access from the router**: needed once at install time, and
  again whenever the Status page runs its update check.

## Installation

Run the installer:

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/install.sh)"
```

The script then:

1. Checks the environment — OpenWrt 22.03+, the CPU family, the package
   manager. The architecture gate runs before anything is changed.
2. Points the package manager at the signed repositories served from the
   GitHub Pages site of this project (`apk/` for 25.12+, `opkg/` for
   22.03–24.10): the apk branch writes
   `/etc/apk/repositories.d/trusttunnel.list` and
   `/etc/apk/keys/trusttunnel.pub`; the opkg branch appends a
   `src/gz trusttunnel <url>/opkg` line to `/etc/opkg/customfeeds.conf` and
   copies the feed key into `/etc/opkg/keys/` (under the stable name and
   the usign fingerprint).
3. Installs the required packages `kmod-tun ip-full nftables curl
   ca-bundle`.
4. Installs `luci-app-trusttunnel` and, on request,
   `luci-i18n-trusttunnel-ru`; `trusttunnel-client` comes along as a
   dependency, with its binaries in `/opt/trusttunnel_client`.
5. Restarts `rpcd` so the new backend code is loaded.
6. Runs `/etc/uci-defaults/40-luci-trusttunnel` immediately: the script
   creates the firewall zone, the `lan → trusttunnel` forwarding, and seeds
   the Default routing profile and the init script registration. It is
   idempotent, so the same run at the next boot changes nothing.
7. Returns the service to its previous state — a first install leaves it
   disabled. Configure the endpoint first, then start the service.

Run the installer again to pull a newer package and client binary and to
refresh the signing keys; `/etc/config/trusttunnel` is left alone.

## Configuration

Open **Services → TrustTunnel → Settings** in LuCI. The page has three
tabs:

- **Server**: the endpoint the client dials. The **Import…** button takes
  what your server produces — the text of a config file, or a `tt://` link —
  and populates each endpoint field the server is able to fill: addresses,
  the TLS host name, credentials, the transport, `custom_sni`,
  `client_random`, plus anti-DPI, IPv6 and certificate-verification
  switches, and the DNS upstreams. Everything can also be typed by hand.
- **Routing profiles**: the Default profile (VPN mode) is already seeded
  here. Every profile gets a mode — **VPN** (everything is tunneled except
  the bypass-list entries) or **Bypass** (only the VPN-list entries are
  tunneled) — and two rule lists whose entries accept a domain, a `*.domain`
  wildcard, an IP address, an `IP:port` pair or a CIDR range. The profile is
  assigned to the server with the routing-profile selector on the Server
  tab.
- **General**: the "start on boot" flag. After Save & Apply, start the
  service with the Start button on the Status page.

The same configuration headless, over UCI:

```sh
uci set trusttunnel.endpoint.hostname='tt.example.net'
uci add_list trusttunnel.endpoint.address='198.51.100.7:443'
uci set trusttunnel.endpoint.username='router'
uci set trusttunnel.endpoint.password='change-me'
uci add_list trusttunnel.endpoint.dns_upstream='1.1.1.1'
uci set trusttunnel.endpoint.custom_sni='tt.example.net'
uci set trusttunnel.endpoint.client_random='0a1b2c'
uci add trusttunnel routing_profile
uci set trusttunnel.@routing_profile[-1].name='Direct'
uci set trusttunnel.@routing_profile[-1].mode='bypass'
uci add_list trusttunnel.@routing_profile[-1].vpn_rules='*.example.com'
uci add_list trusttunnel.@routing_profile[-1].vpn_rules='192.0.2.0/24'
uci set trusttunnel.endpoint.routing_profile='Direct'
uci set trusttunnel.main.enabled='1'
uci commit trusttunnel
/etc/init.d/trusttunnel enable
/etc/init.d/trusttunnel start
```

The routing-profile block is optional: without it (or with a name that
matches no profile), the client falls back to the legacy `domains.direct`
list.

## Behaviour

- **Marking and routing.** LAN traffic forwarded into the `trusttunnel`
  zone is marked with fwmark `0x9527`; a policy rule sends marked packets
  to table `880`, whose default route leads to the client's tun device.
  Traffic originating on the router itself is not marked by default
  (`include_router_traffic` is off); it leaves through the ordinary default
  route.
- **Routing profiles.** Inside the tunnel the client itself decides where
  each connection goes. VPN mode keeps everything in the tunnel except the
  entries in the bypass list; Bypass mode puts only the VPN-list entries
  into the tunnel. Domain entries are matched by SNI, while IP addresses
  and CIDR ranges match on the destination — the same matching the legacy
  flat list performed, but now both halves of the selection are explicit
  rules.
- **Killswitch.** Whenever the tun interface is down, the blackhole route
  (metric `1000`) in table `880` swallows marked traffic. The generated
  config turns the client's own killswitch off (`killswitch_enabled =
  false`); the routing table does the protecting.
- **Exclusions.** The `exclusions` list in the generated `client.toml` is
  profile-based: with a VPN-mode profile it comes from
  `routing_profile.bypass_rules`, with a Bypass-mode profile from
  `routing_profile.vpn_rules` (the tunneled set), and from `domains.direct`
  whenever nothing is assigned.
- **DNS.** Nothing intercepts or rewrites DNS: the generated config sets
  `change_system_dns = false`, and the router's resolver keeps serving the
  LAN.
- **LuCI pages.** The Status page presents the service state, the package
  and client versions, the client log, and a Mode row that names the
  assigned routing profile and which half of its rules goes through the
  tunnel. It renders no device row — the client's tun device is inspected
  in Diagnostics, whose Tunnel device check reports it. Diagnostics walks
  the chain from configuration over the client and the tunnel device to
  routing, firewall and network, with a verdict per check, and offers
  `ping`, `probe` and `check_domain` tools.

## Updating

The repository entry installed by the setup script remains, so keeping the
package current is a plain package-manager call:

```sh
apk update && apk upgrade   # OpenWrt 25.12+
opkg update && opkg upgrade # OpenWrt 22.03–24.10
```

`trusttunnel-client` is a hard dependency of the LuCI app, so the binary
updates together with the package, and `/etc/config/trusttunnel` survives
untouched.

## Uninstalling

Run the uninstaller:

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/trusttunnel-openwrt/main/uninstall.sh)"
```

The script then:

1. Halts the service and disables its auto-start.
2. Removes the packages in one call — `luci-i18n-trusttunnel-ru`,
   `luci-app-trusttunnel`, `trusttunnel-client` (for opkg the dependents
   must come first in the list).
3. Tears down the repository configuration and the signing keys the
   installer put in place.
4. Removes the client binaries and the caches (`/opt/trusttunnel_client`,
   `/usr/share/trusttunnel`, `/var/cache/trusttunnel`,
   `/var/etc/trusttunnel`) and cleans the leftovers of earlier versions
   of the package: the stored lists, the `update_lists` cron line, and any
   leftover dnsmasq include.
5. Prompts whether to remove the firewall zone (default: yes) and for the
   settings file (default: no — a reinstall keeps it).
6. Restarts `rpcd`; the LuCI caches are wiped.
7. Checks the kernel for leftovers — the nft table, the rule for table
   `880`, routes in table `880`; anything still present means the service
   did not stop cleanly and a reboot will clear it.

Flags: `-y` answers every question with yes, removing the zone and the
settings unprompted; `-c` keeps `/etc/config/trusttunnel` without asking.
Shared dependencies (`kmod-tun`, `ip-full`, `nftables`, `curl`,
`ca-bundle`) stay installed on purpose.

Removing by hand works as well:

```sh
/etc/init.d/trusttunnel stop
/etc/init.d/trusttunnel disable
apk del luci-i18n-trusttunnel-ru luci-app-trusttunnel
# on 22.03–24.10: opkg remove luci-i18n-trusttunnel-ru luci-app-trusttunnel
rm -rf /opt/trusttunnel_client
# remove the feed entry and the installed keys (paths above)
uci show firewall | grep trusttunnel
uci delete firewall.@zone[1]   # the section numbers from the listing
uci delete firewall.@forwarding[1]
uci commit firewall
/etc/init.d/firewall restart
```

## Notes and caveats

- **Update check.** The Status page compares the installed version against
  this repository's latest release
  (`https://api.github.com/repos/i-zhirov/trusttunnel-openwrt/releases/latest`),
  caching the answer in `/var/cache/trusttunnel/release.json` for 21600
  seconds. The same releases also host the installable files.
- **Firewall zone.** Because the zone binds the `tun+` wildcard, tun
  devices created by other software fall under it too.
- **Repositories and signing.** Both repositories are served from the
  GitHub Pages site of this project
  (`https://i-zhirov.github.io/trusttunnel-openwrt`), not from the GitHub
  releases: the ru translation package carries `~` in its version (LuCI's
  findrev scheme), a character GitHub replaces in release asset names,
  while Pages serves file names byte-identically. The release workflow
  publishes the site straight from CI; no branch ever holds the packages.
  Signing: `adbsign` (EC key) for the apk index, `usign` for the opkg
  feed.
- **Manual downloads.** A `.apk` or `.ipk` fetched from the release assets
  must be checked against the SHA-256 sums in the release notes.
- **Key rotation.** The signing keys rotate; run the installer once more to
  refresh the copies on the router.

## Acknowledgements

- [`NooBiToo/TrustTunnelOpenWrt`](https://github.com/NooBiToo/TrustTunnelOpenWrt)
  — the upstream LuCI package that inspired this implementation
- [`TrustTunnel/TrustTunnel`](https://github.com/TrustTunnel/TrustTunnel)
  — the server component (Apache-2.0)
- [`TrustTunnel/TrustTunnelClient`](https://github.com/TrustTunnel/TrustTunnelClient)
  — the client binary (Apache-2.0)

## License

Apache-2.0 (see `LICENSE`).

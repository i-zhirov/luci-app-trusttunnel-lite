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
- `/opt/trusttunnel_client` — the official TrustTunnel client binaries
- `/etc/config/trusttunnel` — your settings (survives package updates)
- a `trusttunnel` firewall zone (`tun+`) with a `lan → trusttunnel` forwarding
  rule, created on install
- routing: fwmark rule → table 880 → client's tun device, with a blackhole
  killswitch

What the fork does **not** touch: dnsmasq, its config, its cache, the
`https-dns-proxy` package, cron, or any other service.

## Requirements

- OpenWrt **25.12 or newer** (apk package manager). opkg-based releases are
  not supported.
- CPU in {`x86_64`, `aarch64`, `armv7l`/`armv8l`, `mips`, `mipsel`} — the
  TrustTunnel client ships prebuilt binaries only for these. The installer
  checks `uname -m` before installing anything. The Xiaomi Mi Router 3G
  (MT7621, `mipsel`) is supported.
- Internet access from the router (GitHub must be reachable for install and
  for the update check).

## Installation

One command on the router:

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
```

> The repository is currently **private**, and the installer talks to the
> GitHub releases API unauthenticated — so the one-liner (and the update
> check on the Status page) only works once the repository is made public.
> Until then, download the `.apk` from the releases page manually.

What the installer does:

1. Checks that this is OpenWrt 25.12+ with `apk` and a supported CPU.
2. Installs dependencies: `kmod-tun`, `ip-full`, `curl`, `ca-bundle`
   (no `dnsmasq-full` — the fork does not need nftset in dnsmasq).
3. Downloads `luci-app-trusttunnel-lite-*.apk` from the latest release and
   installs it.
4. Installs the client binary with TrustTunnel's own installer into
   `/opt/trusttunnel_client`.
5. Restarts `rpcd` so LuCI sees the new backend.

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

Re-run the installer. It stops the service if it is running, replaces the
package and the client binary, and starts the service back up. Settings in
`/etc/config/trusttunnel` are left untouched.

## Uninstalling

```sh
/etc/init.d/trusttunnel stop
/etc/init.d/trusttunnel disable

# The i18n package must be in the SAME apk del call (it depends on the main one).
apk del luci-i18n-trusttunnel-lite-ru luci-app-trusttunnel-lite

rm -rf /opt/trusttunnel_client
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
  it needs the repository to be public, same as the installer.
- The firewall zone matches `tun+`, so it also covers other VPNs' tun
  devices if you run more than one.
- The client binary comes from the official TrustTunnel installer; the
  package is installed with `apk add --allow-untrusted` like the original —
  verify the SHA-256 from the release notes if you download `.apk` files
  manually.

## Acknowledgements

- [NooBiToo/TrustTunnelOpenWrt](https://github.com/NooBiToo/TrustTunnelOpenWrt)
  — the original package this fork is derived from (GPL-2.0)
- [TrustTunnel/TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) — the
  protocol, server and client (Apache-2.0)
- [TrustTunnel/TrustTunnelClient](https://github.com/TrustTunnel/TrustTunnelClient)
  — the vendor client and its installer

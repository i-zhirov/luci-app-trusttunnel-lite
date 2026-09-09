# Issue TT-09: rpcd ucode backend

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-06 (service lifecycle semantics)
- **Effort**: L
- **Files**: `packages/luci-app-trusttunnel/root/usr/share/rpcd/ucode/luci.trusttunnel`

## Context

The rpcd backend is the largest single file (684 lines). It was inherited;
helpers (`sh`, `sh_out`, `shq`, `tmp_path`, `write_secret_tmp`, `vercmp`,
`uciget`, `records`, `parse_ping`, `endpoint_host`) and the
`status`/`service`/`ping`/`probe` method bodies are inherited expression
with translated comments; the list/catalog machinery was deleted and
`versions` (disk cache), `import_config`, `check_domain`, `diagnose`,
`routing_status` are fork work. The response key sets are the contract
with the JS views (TT-10..TT-12) and MUST NOT change.

## Contract to reproduce

- `'use strict';`; imports from `fs` (popen, readfile, writefile, access,
  unlink, stat, mkdir, chmod) and `math` (`rand`, `srand`) — `srand(time())`
  at load. The `math` import is required (the module is in `LUCI_DEPENDS`
  as `+ucode-mod-math`; without it `tmp_path()` throws).
- Constants: `LIBDIR=/usr/libexec/trusttunnel`, `OUTDIR=/var/etc/trusttunnel`,
  `RECORDS=$OUTDIR/settings.tsv`, `CLIENT=/opt/trusttunnel_client/trusttunnel_client`,
  `RELEASE_URL='https://api.github.com/repos/i-zhirov/trusttunnel-openwrt/releases/latest'`,
  `VERSION_CACHE=/var/cache/trusttunnel/release.json`, `RELEASE_TTL=21600`.
- Helpers: `sh(cmd)` (popen with stderr merged → `{code, out}`), `sh_out(cmd)`
  (stdout only), `shq(s)` (shell single-quote escaping), `tmp_path(prefix)`
  (unpredictable `/tmp/.tt-<prefix>-<time>-<rand>` name), `write_secret_tmp`
  (write + chmod 0600), `vercmp(a,b)` (numeric components; strip `v`/`-rN`;
  >0 newer, <0 older, 0 equal/unparseable), `records()` (TSV → key→array
  map), `first()`, `uciget(path)` (`uci -q get`), `routing_status()` (parses
  `routing status` lines: `device up`, `rule present`, `table present`,
  `nft present`, `client device X`), `parse_ping()` (ping `-q` summary),
  `endpoint_host()` (host from `host:port` / `[v6]:port`).
- Methods (exact names, args, response keys, side effects):
  1. `status` → `{enabled, running, device, device_up, rule, table, nft,
     endpoint_hostname, addresses[], client_installed, routing_profile,
     routing_mode, vpn_mode}`. `routing_profile`/`routing_mode` come from
     the resolved records (`routing_profile.name`/`routing_profile.mode`,
     empty when unassigned); `vpn_mode` is `'selective'` when
     `routing_mode == 'bypass'`, else `'general'` (added on main
     2026-09-09).
  2. `service` (arg `action` ∈ start|stop|restart|reload, default restart)
     → runs `/etc/init.d/trusttunnel <action>`; for `start` additionally
     sleeps 1 s and re-checks `running`; not running → `{code:1, output,
     not_running:true}`; else `{code, output}`; invalid action →
     `{error:'unsupported action'}`.
  3. `ping` (arg `target` optional) → pings target or the host of every
     `endpoint.address`; returns `{results: [{host, sent, received, loss,
     min, avg, max}]}` (note the top-level `results` envelope — the views
     read `res.results`); `avg` is `null` on 100% loss; no addresses →
     `{error:'no endpoint address configured'}`. Command: `ping -c 4 -W 2
     -q <host>`.
  4. `probe` → requires a live client device, else `{tunnel:{error:'the
     client has not created a tunnel device yet'}, direct:{error:'not
     attempted'}}`; `curl -fsS --max-time 8 --interface <dev>
     https://api.ipify.org` and plain `curl -fsS --max-time 8
     https://api.ipify.org`; returns `{tunnel:{ip|error},
     direct:{ip|error}}`.
  5. `check_domain` (arg `domain`) → profile-aware (added on main
     2026-09-09): the effective list key is `routing_profile.vpn_rules`
     when a profile is assigned AND its mode is `bypass`,
     `routing_profile.bypass_rules` when a profile is assigned in vpn
     mode, else the legacy `domains.direct`. Case-insensitive compare
     (exact or `.<domain>` suffix). Returns `{domain, normalized
     (lowercased), verdict:'direct'|'tunnel', reason}` with the exact
     reason strings: bypass mode → in_list ? "listed in the profile's VPN
     rules; the client routes it through the tunnel" : "the assigned
     profile is in bypass mode; everything else stays direct"; vpn
     profile → in_list ? "listed in the profile's bypass rules; the
     client sends it out directly" : "the assigned profile is in VPN
     mode; everything else goes through the tunnel"; legacy → as before
     ('listed in the "do not bypass" list; the client sends it out by
     SNI' / 'all LAN traffic goes through the tunnel (full-tunnel
     mode)'). Empty domain → `{error: …}` (the view renders it
     defensively).
  6. `log` (arg `lines`, default 100) → `logread -e trusttunnel | tail -n
     N`; returns `{lines: [...]}`.
  7. `diagnose` → `{checks:[{group,label,status,detail,hint}],
     counts:{ok,warn,fail,skip}, verdict}`; status ∈ ok|warn|fail|skip,
     group ∈ config|prereq|service|kernel|network; up to 17 checks (the
     "Tunnel device" bullet below is two checks — device + MTU-match warn;
     the MTU check is skipped when the device is absent). Check list and
     order (labels must match what the views' DIAG_TEXT map expects —
     e.g. "Route attached to the device", not abbreviations): Endpoint
     address, Credentials, TLS host name (warn if empty), Routing profile
     (added on main 2026-09-09: ok with `pname + ' (' + pmode + ')'`
     detail when `routing_profile.name` is set, warn with detail
     'none — legacy full-tunnel mode' and hint 'Assign a routing profile
     on the Settings page to control what goes through the tunnel.'
     otherwise); TrustTunnel
     client (access + `--version` parse), tun device (`/dev/net/tun`);
     Enabled, Running; Tunnel device (sysfs), MTU matches settings (warn
     if sysfs MTU ≠ `network.mtu`), Route attached to the device (`ip
     route show table <T>` contains `dev <dev>`), Tunnel carrier (sysfs),
     Routing rule/table/nft (from `routing_status`, skip when config not
     applied), Firewall zone (grep `nft list ruleset` for `trusttunnel`);
     Endpoint reachable (`ping -c 2 -W 2`), Traffic goes through the
     tunnel (ipify via device vs direct).
  8. `versions` (arg `refresh`, default false) → `{client, package,
     latest, update_available, checked_at, stale, ahead}`; client via
     `--version`; package via `apk list -I luci-app-trusttunnel` (regex
     `luci-app-trusttunnel-<ver>`) else `opkg info luci-app-trusttunnel`
     (`Version:` line); latest from `VERSION_CACHE` when fresh (< TTL) and
     not older than installed, else `curl -fsS --max-time 15` to
     `RELEASE_URL`, parse `tag_name`, write cache (mkdir
     `/var/cache/trusttunnel`; failures via `logger -t trusttunnel`); on
     network failure fall back to cache with `stale:true`;
     `update_available` = vercmp(tag, package) > 0; `ahead` = < 0.
  9. `import_config` (arg `text`) → requires
     `/opt/trusttunnel_client/setup_wizard`; `tt://` prefix →
     `setup_wizard --mode non-interactive --deeplink <link> --settings
     <out>`; else write text to a secret temp file (0600) and run
     `setup_wizard --mode non-interactive --endpoint_config <file>
     --settings <out>`; output file chmod 0600, read, both temp files
     unlinked; parse EVERY endpoint field the server can hand out (added
     on main 2026-09-09 — losing a field is not cosmetics: anti-scan
     servers reject clients without the matching `client_random` prefix):
     shape-based parser over `key = value` lines — quoted strings
     (`hostname`, `username`, `password`, `certificate`, `custom_sni`,
     `client_random`, taken only when non-empty), `upstream_protocol`
     (http2/http3 → `protocol`), booleans (`has_ipv6`, `skip_verification`,
     `anti_dpi` → `'1'`/`'0'`), arrays (`addresses`, `dns_upstreams` →
     `{addresses: [], dns_upstreams: []}` initial result). On failure
     filter Rust panic noise (`thread *panicked at*`, `note: *`,
     `Aborted*`) and return `{error}`. Returns `{hostname, username,
     password, certificate, custom_sni, client_random, protocol,
     anti_dpi, has_ipv6, skip_verification, addresses[], dns_upstreams[]}`;
     never touches UCI (the UI applies via `uci.save`).
- Object exported as `luci.trusttunnel`.

## Acceptance criteria

- [ ] All 9 methods re-expressed with new code and identical behavior.
- [ ] ucode syntax check passes (ci.yml gate: build ucode with
      `-DFS_SUPPORT=ON -DMATH_SUPPORT=ON`, `ucode -L ... -c`).
- [ ] Module-import check passes (every used module imported).
- [ ] Response key sets byte-match the contract above (compare against the
      current implementation's responses on a live router or via captured
      JSON fixtures).
- [ ] `versions` cache behavior (fresh/stale/network-failure) matches.

## How to verify

1. `ucode -c` syntax gate (as in ci.yml).
2. On a device/rootfs: call each method via `ubus call luci.trusttunnel
   <method>` and diff the JSON keys against the current implementation's
   output for the same UCI state.
3. Manual LuCI pass after TT-10..TT-12.

## Notes

- The JS views depend on these key sets — change nothing in the response
  shapes; internal re-expression is free.
- Do NOT copy the inherited file; write from this contract.

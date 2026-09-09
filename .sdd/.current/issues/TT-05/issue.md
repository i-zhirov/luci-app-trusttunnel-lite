# Issue TT-05: routing (nft/ip management)

- **Status**: Implemented
- **PRD**: `../../prd.md`
- **Blocked by**: TT-02
- **Effort**: M–L
- **Files**: `packages/luci-app-trusttunnel/root/usr/libexec/trusttunnel/routing`,
  `tests/test_routing.sh`

## Context

`routing` is the largest libexec script, inherited from upstream; the fork
deleted the selective-mode branches, added the blackhole metric and
reattach, and translated comments — but the `dump_ruleset()` printf
sequence, the `lan_set()` awk, and the `up`/`attach`/`detach`/`down`/
`status` bodies are inherited expression. Its nft ruleset and ip commands
are the package's kernel contract.

## Contract to reproduce

- Usage: `routing dump|up|attach|reattach|detach|down|status <records-file>
  [out-dir] [device]`; env overrides `TT_IP` (default `ip`), `TT_NFT`
  (default `nft`), `TT_LIBDIR`; sources `records.sh`.
- Reads via records: `network.table` (880), `network.fwmark` (0x9527),
  `network.include_router_traffic` (0), `network.blackhole_on_down` (1),
  `network.mtu` (1350 — coerced to numeric, junk → 1350),
  `network.lan_devices` (fallback: `uci -q get network.lan.device`, then
  `br-lan`).
- Constants: rule priority `30820`; private v4 ranges 10/8, 127/8,
  169.254/16, 172.16/12, 192.168/16, 224/4, 240/4; private v6 ::1/128,
  fc00::/7, fe80::/10, ff00::/8; device-name file `$OUT_DIR/device`.
- `dump <records>`: prints the full ruleset to stdout, idempotent
  (empty `table inet trusttunnel { }` + `delete table` first). Sets
  `tt_endpoint4` (ipv4_addr, interval) and `tt_endpoint6` (ipv6_addr,
  interval). Chain `prerouting` (`type filter hook prerouting priority
  mangle; policy accept;`): `iifname != <lan set> return` (the `br-lan`
  fallback makes this effectively unconditional), `ip daddr @tt_endpoint4
  return`, `ip6 daddr @tt_endpoint6 return`, private-range returns, then
  `meta mark set <fwmark>`. With `include_router_traffic=1` an `output`
  chain (`type route hook output priority mangle; policy accept;`)
  starting with `oifname "tun*" return`. NO `tt_bypass` sets, NO dstnat.
  Ruleset built with successive `printf` calls (no heredoc with `$(...)`
  — command substitution strips trailing newlines and nft rejects the
  file). NOTE: in `dump` mode `network.lan_devices` is NOT consulted via
  the `uci` fallback — empty value goes straight to `br-lan`.
- `up <records> <outdir>`: blackhole route first when enabled (`ip route
  replace blackhole default table <T> metric 1000`, v4+v6); fwmark rule
  only if absent (grep guard against substring match of the table
  number): `ip rule add fwmark <MARK> table <T> priority 30820` (v4+v6);
  resolve endpoint hosts via `nslookup` into a temp file (busybox answer
  format `Address: x.x.x.x`, IPv6 colons preserved); load ruleset via a
  single `nft -f -` transaction; then `nft add element inet trusttunnel
  tt_endpoint{4,6}` per resolved address (v6 classified by colon). No
  device creation, no route attach.
- `attach <records> <outdir> <device>`: empty device name → stderr
  message + exit 1; validate the device exists (`ip link show dev`, else
  exit 1); then `ip route replace default dev <dev> table <T> metric 1`
  (v4 FATAL on failure, v6 best-effort); write the device name to
  `$OUT_DIR/device`; log. Metric 1 beats the blackhole (1000).
- `reattach <records> <outdir>`: attach by the recorded device name
  (validated live), no-op when none.
- `detach <records> <outdir>`: delete `ip route del default table <T>
  metric 1` (v4+v6, best-effort); remove the device file; keep blackhole
  and nft.
- `down <records>`: `nft delete table inet trusttunnel`; `ip rule del
  fwmark <MARK> table <T> priority 30820` (v4+v6); `ip route flush table
  <T>` (v4+v6); remove device file; does NOT delete the client's device.
- `status <records> <outdir>`: lines `device up|device down` (per recorded
  device's sysfs carrier), `client device <name>` (only when the recorded
  device exists and is live per `ip link show`), `rule present|absent`,
  `table present|absent`, `nft present|absent`.
- Unknown subcommand → exit 1. Executable bit `100755`. (`network.mtu` is
  read and coerced for parity but not consumed by any subcommand —
  vestigial; keep the read.)

## Acceptance criteria

- [ ] `tests/test_routing.sh` rewritten from this contract and green:
      dump content (sets, prerouting mangle, iifname set, endpoint
      returns, private ranges, mark line, no output chain by default,
      output chain + `oifname "tun*"` when router traffic on, no
      tt_bypass, no dstnat), line-break hygiene (no statement glued after
      a `return`, closing brace on its own line), `up` (blackhole +
      rules via stubbed `ip`, single `nft -f -` transaction, no
      tuntap/link set), `attach`/`detach`/`down` (route replace/del,
      device file), no-blackhole variant, unknown subcommand exit 1.
- [ ] Golden byte-diff: old vs new `routing dump` identical on both
      record fixtures.
- [ ] `shellcheck -s sh` clean.

## How to verify

1. `sh tests/run.sh` — `test_routing.sh` green.
2. Golden diff `routing dump` (old vs new) on the fixtures.
3. On a device or rootfs: `routing up` → `status` shows rule/table/nft
   present → attach/detach cycle → `down` cleans everything (blackhole
   gone, rules gone).

## Notes

- The printf-discipline (no heredoc-with-substitution) is a hard
  requirement: it exists because nft rejects the glued file. Re-express
  it any way that preserves byte-identical output.

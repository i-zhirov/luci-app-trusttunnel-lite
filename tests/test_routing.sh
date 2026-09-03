#!/bin/sh
. "$(dirname "$0")/lib.sh"

R=packages/luci-app-trusttunnel-lite/root/usr/libexec/trusttunnel/routing

cat > "$TT_TEST_TMP/up.tsv" <<'EOF'
network.fwmark	0x9527
network.lan_devices	br-lan br-guest
network.include_router_traffic	0
EOF

cat > "$TT_TEST_TMP/router.tsv" <<'EOF'
network.fwmark	0x9527
network.lan_devices	br-lan
network.include_router_traffic	1
EOF

dump="$(sh "$R" dump "$TT_TEST_TMP/up.tsv")"
dump_router="$(sh "$R" dump "$TT_TEST_TMP/router.tsv")"

assert_contains "$dump" "table inet trusttunnel {" "declares its own table"
assert_contains "$dump" "delete table inet trusttunnel" "recreates the table idempotently"
assert_contains "$dump" "set tt_endpoint4 { type ipv4_addr; flags interval; }" "endpoint v4 set"
assert_contains "$dump" "set tt_endpoint6 { type ipv6_addr; flags interval; }" "endpoint v6 set"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'tt_bypass')" "no bypass sets in a fork without lists"
assert_contains "$dump" "type filter hook prerouting priority mangle" "prerouting mangle chain"
assert_contains "$dump" 'iifname != { "br-lan", "br-guest" } return' "limits to lan devices"
assert_contains "$dump" "ip daddr @tt_endpoint4 return" "never tunnels traffic to the endpoint"
assert_contains "$dump" "ip6 daddr @tt_endpoint6 return" "same for ipv6 endpoints"
assert_contains "$dump" "192.168.0.0/16" "excludes private destinations"
assert_contains "$dump" "fc00::/7" "excludes ipv6 private destinations"

# The single mode is everything-through-VPN: everything that reaches the rule
# is marked.
assert_contains "$dump" "meta mark set 0x9527" "marks everything"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c '@tt_bypass')" "does not consult any bypass set"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'hook output')" "no output chain unless requested"
assert_contains "$dump_router" "type route hook output priority mangle" "router traffic chain when requested"
assert_contains "$dump_router" 'oifname "tun*" return' "skips traffic already leaving into the tunnel"

# There is no DNS interception in the fork at all: in no mode.
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'dstnat')" "no dns redirect chains"

assert_exit 1 "rejects an unknown subcommand" sh "$R" bogus "$TT_TEST_TMP/up.tsv"

# `up` and `down` change the kernel state, so they are tested via stubs:
# TT_IP and TT_NFT exist for exactly that. We log argv and verify the actual
# command set — otherwise the killswitch route, the ip rule priority and the
# teardown order would remain checked only by reading, and that is the
# riskiest untested code in the project.
stub="$TT_TEST_TMP/bin"
mkdir -p "$stub"
LOG="$TT_TEST_TMP/cmd.log"
cat > "$stub/ip" <<'IPSTUB'
#!/bin/sh
printf 'ip %s\n' "$*" >> "$TT_CMD_LOG"
# link show MUST succeed: attach and client_device use it to check that the
# client device exists, and a failure here would drop the attach. The stub
# used to return 1 so that `up` would take the device-creation branch — that
# branch no longer exists, the client creates the device.
exit 0
IPSTUB
cat > "$stub/nft" <<'NFTSTUB'
#!/bin/sh
printf 'nft %s\n' "$*" >> "$TT_CMD_LOG"

# stdin is read ONLY by `nft -f -`. An unconditional `cat` is impossible: nft
# is also called without a pipe (`nft delete table …`), and then `cat` waits
# for input forever — the test suite would hang instead of failing, and a
# hang is not diagnosable.
if [ "$1" = "-f" ] && [ "$2" = "-" ]; then
	_batch=$(mktemp)
	cat > "$_batch"
	cat "$_batch" >> "${TT_NFT_STDIN:-/dev/null}"
	rm -f "$_batch"
fi
exit 0
NFTSTUB
chmod +x "$stub/ip" "$stub/nft"
export TT_CMD_LOG="$LOG"

: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" up "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP/nowhere" >/dev/null 2>&1
up_log="$(cat "$LOG")"
# The device is no longer ours: the client creates it. Previously `ip tuntap
# add` was asserted here — now it is the opposite: up must create nothing.
# The reason for the change: the client schema has no device_name/use_existing
# keys, it always makes its own device, and the one we created was left
# without a carrier — the route pointed into a dead interface and marked
# traffic was dropped.
assert_eq "0" "$(grep -c 'tuntap add' "$LOG")" "up does not create a tun device"
assert_eq "0" "$(grep -c 'link set dev' "$LOG")" "up does not touch a device"
# There must be no default route at this stage either: there is nothing to
# attach to yet, and until the client device appears the blackhole holds the
# traffic.
assert_eq "0" "$(grep -c 'route replace default' "$LOG")" "up installs no default route yet"
assert_contains "$up_log" "ip route replace blackhole default table 880 metric 1000" "up installs the killswitch blackhole route"
assert_contains "$up_log" "ip rule add fwmark 0x9527 table 880 priority 30820" "up installs the fwmark rule"
assert_contains "$up_log" "ip -6 rule add fwmark 0x9527 table 880 priority 30820" "up installs the ipv6 fwmark rule"

# The rules are loaded in a single transaction.
NFT_IN="$TT_TEST_TMP/nft.stdin"
: > "$LOG"; : > "$NFT_IN"
TT_NFT_STDIN="$NFT_IN" TT_IP="$stub/ip" TT_NFT="$stub/nft" \
	sh "$R" up "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP/nowhere" >/dev/null 2>&1
fed="$(cat "$NFT_IN")"
assert_contains "$fed" "table inet trusttunnel {" "ruleset is fed to nft"
assert_contains "$fed" "meta mark set 0x9527" "the mark rule is in the fed ruleset"

# attach is a separate operation that installs the route onto the client device.
: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" attach "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP" tun7 >/dev/null 2>&1
attach_log="$(cat "$LOG")"
assert_contains "$attach_log" "ip route replace default dev tun7 table 880 metric 1" "attach installs the default route via the client device"
assert_eq "tun7" "$(cat "$TT_TEST_TMP/device" 2>/dev/null)" "attach records the client device name"

# metric 1 against the blackhole at 1000: the client route MUST outweigh the
# killswitch, otherwise the attach gives nothing.
assert_contains "$attach_log" "table 880 metric 1" "attach uses a metric above the blackhole"

# detach removes the route but NOT the blackhole: while the service counts as
# running, marked traffic must not leak into the main table.
: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" detach "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP" >/dev/null 2>&1
detach_log="$(cat "$LOG")"
assert_contains "$detach_log" "ip route del default table 880 metric 1" "detach removes the default route"
assert_eq "0" "$(printf '%s\n' "$detach_log" | grep -c 'blackhole')" "detach leaves the blackhole in place"
assert_eq "1" "$([ -f "$TT_TEST_TMP/device" ] && echo 0 || echo 1)" "detach removes the recorded device name"

: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" down "$TT_TEST_TMP/up.tsv" >/dev/null 2>&1
down_log="$(cat "$LOG")"
assert_contains "$down_log" "nft delete table inet trusttunnel" "down removes the nft table"
assert_contains "$down_log" "ip rule del fwmark 0x9527 table 880 priority 30820" "down removes the fwmark rule"
assert_contains "$down_log" "ip route flush table 880" "down flushes the routing table"
# The client device is NOT deleted — it is not ours.
assert_eq "0" "$(grep -c 'link del' "$LOG")" "down does not delete the client device"
# The teardown goes in reverse order: nft first, routes only after, otherwise
# the rules would reference an already removed table.
assert_eq "0" "$(printf '%s\n' "$down_log" | awk '/ip route flush table/{seen_rt=NR} /nft delete table/{seen_nft=NR} END{print (seen_nft && seen_rt && seen_nft < seen_rt) ? 0 : 1}')" \
	"down tears the nft table down before the routes"

# Without the killswitch no blackhole route must be installed.
cat > "$TT_TEST_TMP/nobh.tsv" <<'EOF'
network.fwmark	0x9527
network.lan_devices	br-lan
network.blackhole_on_down	0
EOF
: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" up "$TT_TEST_TMP/nobh.tsv" "$TT_TEST_TMP/nowhere" >/dev/null 2>&1
assert_eq "0" "$(grep -c 'blackhole' "$LOG")" "no blackhole route when the killswitch is disabled"

# Every rule must sit on its own line. Substring asserts do not catch this:
# when two rules are glued into one line all expected substrings remain in
# place while nftables rejects the whole file. So we check exactly what a
# substring check cannot see.
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'return[[:space:]]\+[a-z]')" \
	"no statement shares a line with a return verdict"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'mark set.*}')" \
	"a chain's closing brace is on its own line"

tt_test_summary

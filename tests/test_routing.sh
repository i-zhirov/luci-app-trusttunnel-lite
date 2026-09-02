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

# Единственный режим — всё через VPN: маркируется всё, что дошло до правила.
assert_contains "$dump" "meta mark set 0x9527" "marks everything"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c '@tt_bypass')" "does not consult any bypass set"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'hook output')" "no output chain unless requested"
assert_contains "$dump_router" "type route hook output priority mangle" "router traffic chain when requested"
assert_contains "$dump_router" 'oifname "tun*" return' "skips traffic already leaving into the tunnel"

# Перехвата DNS в fork нет вовсе: ни в каком режиме.
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'dstnat')" "no dns redirect chains"

assert_exit 1 "rejects an unknown subcommand" sh "$R" bogus "$TT_TEST_TMP/up.tsv"

# `up` и `down` меняют состояние ядра, поэтому проверяются через заглушки:
# TT_IP и TT_NFT для этого и существуют. Логируем argv и сверяем сам набор
# команд — иначе killswitch-маршрут, приоритет ip rule и порядок разборки
# остаются проверенными только чтением, а это самый рискованный непокрытый
# код в проекте.
stub="$TT_TEST_TMP/bin"
mkdir -p "$stub"
LOG="$TT_TEST_TMP/cmd.log"
cat > "$stub/ip" <<'IPSTUB'
#!/bin/sh
printf 'ip %s\n' "$*" >> "$TT_CMD_LOG"
# link show ОБЯЗАН завершаться успешно: attach и client_device проверяют им,
# что устройство клиента существует, и отказ здесь ронял бы привязку. Раньше
# стаб возвращал 1, чтобы `up` пошёл по ветке создания устройства, — этой ветки
# больше нет, устройство создаёт клиент.
exit 0
IPSTUB
cat > "$stub/nft" <<'NFTSTUB'
#!/bin/sh
printf 'nft %s\n' "$*" >> "$TT_CMD_LOG"

# stdin читается ТОЛЬКО у `nft -f -`. Безусловный `cat` нельзя: nft вызывается
# и без конвейера (`nft delete table …`), и тогда `cat` ждёт ввода вечно —
# тестовый набор подвисает вместо того чтобы упасть, а зависание не
# диагностируется.
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
# Устройство больше НЕ наше: его создаёт клиент. Раньше здесь проверялось
# `ip tuntap add` — теперь наоборот, проверяется, что up ничего не создаёт.
# Причина смены: ключей device_name/use_existing в схеме клиента не существует,
# он всегда делает своё устройство, а созданное нами оставалось без носителя —
# маршрут указывал в мёртвый интерфейс и помеченный трафик отбрасывался.
assert_eq "0" "$(grep -c 'tuntap add' "$LOG")" "up does not create a tun device"
assert_eq "0" "$(grep -c 'link set dev' "$LOG")" "up does not touch a device"
# Маршрута по умолчанию на этом этапе тоже быть не должно: привязываться пока
# не к чему, и до появления устройства клиента трафик держит blackhole.
assert_eq "0" "$(grep -c 'route replace default' "$LOG")" "up installs no default route yet"
assert_contains "$up_log" "ip route replace blackhole default table 880 metric 1000" "up installs the killswitch blackhole route"
assert_contains "$up_log" "ip rule add fwmark 0x9527 table 880 priority 30820" "up installs the fwmark rule"
assert_contains "$up_log" "ip -6 rule add fwmark 0x9527 table 880 priority 30820" "up installs the ipv6 fwmark rule"

# Правила загружаются одной транзакцией.
NFT_IN="$TT_TEST_TMP/nft.stdin"
: > "$LOG"; : > "$NFT_IN"
TT_NFT_STDIN="$NFT_IN" TT_IP="$stub/ip" TT_NFT="$stub/nft" \
	sh "$R" up "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP/nowhere" >/dev/null 2>&1
fed="$(cat "$NFT_IN")"
assert_contains "$fed" "table inet trusttunnel {" "ruleset is fed to nft"
assert_contains "$fed" "meta mark set 0x9527" "the mark rule is in the fed ruleset"

# attach — отдельная операция, которая и ставит маршрут, на устройство клиента.
: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" attach "$TT_TEST_TMP/up.tsv" "$TT_TEST_TMP" tun7 >/dev/null 2>&1
attach_log="$(cat "$LOG")"
assert_contains "$attach_log" "ip route replace default dev tun7 table 880 metric 1" "attach installs the default route via the client device"
assert_eq "tun7" "$(cat "$TT_TEST_TMP/device" 2>/dev/null)" "attach records the client device name"

# metric 1 против blackhole на 1000: маршрут клиента ОБЯЗАН перекрывать
# killswitch, иначе привязка не даёт ничего.
assert_contains "$attach_log" "table 880 metric 1" "attach uses a metric above the blackhole"

# detach снимает маршрут, но НЕ blackhole: пока служба считается работающей,
# помеченный трафик не должен уходить в основную таблицу.
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
# Устройство клиента НЕ удаляем — оно не наше.
assert_eq "0" "$(grep -c 'link del' "$LOG")" "down does not delete the client device"
# Разборка идёт в обратном порядке: сначала nft, только потом маршруты, иначе
# правила ссылались бы на уже снятую таблицу.
assert_eq "0" "$(printf '%s\n' "$down_log" | awk '/ip route flush table/{seen_rt=NR} /nft delete table/{seen_nft=NR} END{print (seen_nft && seen_rt && seen_nft < seen_rt) ? 0 : 1}')" \
	"down tears the nft table down before the routes"

# Без killswitch маршрут blackhole ставиться не должен.
cat > "$TT_TEST_TMP/nobh.tsv" <<'EOF'
network.fwmark	0x9527
network.lan_devices	br-lan
network.blackhole_on_down	0
EOF
: > "$LOG"
TT_IP="$stub/ip" TT_NFT="$stub/nft" sh "$R" up "$TT_TEST_TMP/nobh.tsv" "$TT_TEST_TMP/nowhere" >/dev/null 2>&1
assert_eq "0" "$(grep -c 'blackhole' "$LOG")" "no blackhole route when the killswitch is disabled"

# Каждое правило обязано стоять на своей строке. Ассерты на подстроки этого не
# ловят: при склейке двух правил в одну строку все ожидаемые подстроки остаются
# на месте, а nftables отвергает файл целиком. Поэтому проверяем именно то, что
# подстрочная проверка увидеть не может.
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'return[[:space:]]\+[a-z]')" \
	"no statement shares a line with a return verdict"
assert_eq "0" "$(printf '%s\n' "$dump" | grep -c 'mark set.*}')" \
	"a chain's closing brace is on its own line"

tt_test_summary

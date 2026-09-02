#!/bin/sh
# Выбор минимального действия при применении настроек.
#
# ЗАЧЕМ. Save & Apply приходит в reload_service, а тот раньше всегда звал
# restart: любая правка — хоть одна строка в domains.direct — убивала клиента
# и рвала туннель на несколько секунд. Между stop и start при этом исчезала и
# nft-таблица, так что помеченный трафик LAN успевал уйти НАПРЯМУЮ. Оба
# следствия не нужны: клиент читает client.toml только при запуске, поэтому
# правка, которая до client.toml не доходит, не требует его перезапуска вовсе.
#
# Классификатор решает, что именно требуется, и вся его ценность — в
# консервативности. Ошибка в сторону «дороже» стоит лишний перезапуск, ошибка
# в сторону «дешевле» означает молча непримененную настройку, а такой отказ
# невозможно диагностировать: интерфейс показывает новое значение, а работает
# старое. Поэтому неизвестный ключ обязан давать самое полное действие, а не
# самое дешёвое, и на это здесь есть отдельная проверка.
. "$(dirname "$0")/lib.sh"

INIT="packages/luci-app-trusttunnel-lite/root/etc/init.d/trusttunnel"
UCI_EXPORT="packages/luci-app-trusttunnel-lite/root/usr/libexec/trusttunnel/uci-export"

sandbox="$TT_TEST_TMP/sandbox"
mkdir -p "$sandbox"

# На верхнем уровне init-скрипт только присваивает переменные и определяет
# функции, поэтому подключается без /etc/rc.common, procd и UCI.
# shellcheck disable=SC1090
. "$INIT"

# --- changed_keys -------------------------------------------------------------

old="$sandbox/old.tsv"
new="$sandbox/new.tsv"

cat > "$old" <<'EOF'
main.enabled	1
endpoint.hostname	a.example
domains.direct	bank.example
EOF

# Отсутствие изменений проверяется через classify_change ниже: пустой вывод
# changed_keys неотличим от невызванной функции, и такой ассерт зелен даже
# когда реализации нет вовсе.
#
# Добавленный элемент списка исключений. Ключ в records повторяется, поэтому
# сравнение обязано считать вхождения, а не искать ключ: при простом сравнении
# множеств строк добавление второго значения к уже существующему ключу
# потерялось бы.
cp "$old" "$new"
printf 'domains.direct\tbank2.example\n' >> "$new"
assert_eq "domains.direct" "$(changed_keys "$old" "$new")" \
	"добавленный элемент списка виден"

# Удалённый элемент. Направление diff'а симметрично: пропажу надо замечать
# так же, как появление, иначе снятая галочка не применялась бы.
cp "$old" "$new"
grep -v 'bank.example' "$old" > "$new"
assert_eq "domains.direct" "$(changed_keys "$old" "$new")" \
	"удалённый элемент списка виден"

cp "$old" "$new"
sed -i 's/a.example/b.example/' "$new"
assert_eq "endpoint.hostname" "$(changed_keys "$old" "$new")" \
	"изменённое скалярное значение видно"

cp "$old" "$new"
sed -i 's/a.example/b.example/' "$new"
printf 'network.mtu\t1400\n' >> "$new"
assert_eq "endpoint.hostname network.mtu" \
	"$(changed_keys "$old" "$new" | tr '\n' ' ' | sed 's/ $//')" \
	"несколько изменений перечисляются без повторов"

# --- change_class -------------------------------------------------------------

assert_eq "reload" "$(change_class network.lan_devices)" \
	"список LAN-интерфейсов пересобирает только nft"
assert_eq "reload" "$(change_class network.blackhole_on_down)" \
	"killswitch пересобирает только nft"
assert_eq "reload" "$(change_class network.include_router_traffic)" \
	"трафик роутера пересобирает только nft"

assert_eq "restart" "$(change_class domains.direct)" \
	"исключения уходят в client.toml — нужен перезапуск клиента"
assert_eq "restart" "$(change_class endpoint.hostname)" \
	"адрес сервера требует перезапуска клиента"
assert_eq "restart" "$(change_class endpoint.password)" \
	"пароль требует перезапуска клиента"
assert_eq "restart" "$(change_class endpoint.certificate)" \
	"сертификат требует перезапуска клиента"
assert_eq "restart" "$(change_class network.mtu)" \
	"MTU уходит в client.toml"
assert_eq "restart" "$(change_class main.log_level)" \
	"уровень журнала уходит в client.toml"

# Полный перезапуск с настоящим routing down нужен там, где иначе осталась бы
# висеть прежняя таблица маршрутизации или прежнее правило по отметке.
assert_eq "restart_full" "$(change_class network.table)" \
	"смена номера таблицы обязана снять прежнюю"
assert_eq "restart_full" "$(change_class network.fwmark)" \
	"смена отметки обязана снять прежнее правило"
assert_eq "restart_full" "$(change_class main.enabled)" \
	"выключение службы обязано снять маршрутизацию"

# Главная проверка консервативности: незнакомый ключ даёт то же поведение,
# какое было до появления классификатора.
assert_eq "restart_full" "$(change_class network.something_new)" \
	"незнакомый ключ даёт полное применение, а не дешёвое"
assert_eq "restart_full" "$(change_class totally.unknown)" \
	"незнакомая секция тоже"

# --- classify_change: итог по всем изменениям --------------------------------

cp "$old" "$new"
assert_eq "noop" "$(classify_change "$old" "$new")" \
	"без изменений — ничего не делаем"

cp "$old" "$new"
printf 'domains.direct\tbank2.example\n' >> "$new"
assert_eq "restart" "$(classify_change "$old" "$new")" \
	"только исключения — перезапуск клиента без разборки маршрутизации"

# Итог — максимум по всем изменившимся ключам, а не первый или последний:
# дешёвая правка рядом с дорогой не должна её обесценивать.
cp "$old" "$new"
printf 'domains.direct\tbank2.example\n' >> "$new"
sed -i 's/a.example/b.example/' "$new"
assert_eq "restart" "$(classify_change "$old" "$new")" \
	"исключения вместе с адресом сервера — перезапуск"

cp "$old" "$new"
printf 'domains.direct\tbank2.example\n' >> "$new"
printf 'network.table\t881\n' >> "$new"
assert_eq "restart_full" "$(classify_change "$old" "$new")" \
	"смена таблицы перекрывает всё остальное"

# --- Полнота классификатора ---------------------------------------------------

# Каждый ключ схемы обязан быть перечислен в change_class ЯВНО. Без этой
# проверки новый ключ в uci-export молча попадал бы в ветку «незнакомый» и
# получал полный перезапуск: настройка применялась бы, но обещанная
# бесшовность тихо исчезла бы для всех, кто правит эту настройку.
#
# Истина берётся из самого uci-export, поэтому проверка не разъезжается со
# схемой. Разбор устроен так: `scalar <секция> "$o"` внутри `for o in ...`
# даёт по ключу на слово цикла, `listopt <секция> <опция>` — один ключ.
schema_keys() {
	awk '
		# Однострочный цикл: `for o in a b c; do scalar <секция> "$o"; done`.
		# Ветка обязана стоять ПЕРЕД общей: та съедает строку целиком по
		# `next`, и без этой проверки все ключи main.* и обе опции
		# автообновления выпадали из разбора молча — проверка полноты
		# оставалась зелёной, не проверяя их.
		/^for o in .*scalar/ {
			line = $0
			sub(/^for o in[ \t]+/, "", line)
			idx = index(line, ";")
			opts = substr(line, 1, idx - 1)
			rest = substr(line, idx)
			sec = ""
			n = split(rest, r, /[ \t]+/)
			for (i = 1; i <= n; i++) if (r[i] == "scalar") sec = r[i + 1]
			m = split(opts, a, /[ \t]+/)
			for (i = 1; i <= m; i++) if (a[i] != "") print sec "." a[i]
			next
		}
		# Многострочный: опции копятся до строки со `scalar`.
		/^for o in/ {
			# Слова цикла собираются до `;` или `do`, тело может стоять
			# как на этой же строке, так и ниже после переноса `\`.
			opts = ""
			for (i = 4; i <= NF; i++) {
				if ($i == ";" || $i == "do" || $i == ";do") break
				if ($i == "\\") continue
				opts = opts " " $i
			}
			collecting = 1
			buf = opts
			next
		}
		collecting && /^\t\t/ {
			# Продолжение списка опций на следующей строке.
			line = $0
			gsub(/\\/, "", line)
			buf = buf " " line
			next
		}
		collecting && /scalar/ {
			sec = ""
			for (i = 1; i <= NF; i++) if ($i == "scalar") sec = $(i + 1)
			n = split(buf, a, /[ \t]+/)
			for (i = 1; i <= n; i++) if (a[i] != "" && a[i] != "do") print sec "." a[i]
			collecting = 0
			next
		}
		/^listopt / { print $2 "." $3 }
	' "$UCI_EXPORT" | sed 's/;$//' | sort -u
}

keys=$(schema_keys)
count=$(printf '%s\n' "$keys" | grep -c .)

# Контроль самого разбора: если он сломается и вернёт пустоту или горстку
# ключей, проверка полноты станет зелёной, ничего не проверяя. Схема на
# момент написания — 19 ключей; порог заведомо ниже, чтобы не падать от
# честного добавления или удаления одного, но выше того, что даёт разбор с
# потерянной веткой однострочных циклов.
if [ "$count" -lt 15 ]; then
	_tt_fail "разбор схемы uci-export нашёл только $count ключей — он сломан"
else
	_tt_pass "разбор схемы uci-export дал $count ключей"
fi

missing=""
for k in $keys; do
	# certificate в records не попадает намеренно (PEM многострочный), но
	# классифицировать его всё равно нужно — apply_settings сверяет его
	# отдельным файлом.
	if [ "$(change_class "$k")" = "restart_full" ] \
			&& [ "$k" != "network.table" ] \
			&& [ "$k" != "network.fwmark" ] \
			&& [ "$k" != "main.enabled" ]; then
		missing="$missing $k"
	fi
done
assert_eq "" "$missing" \
	"каждый ключ схемы классифицирован явно, ни один не свалился в ветку незнакомых"

tt_test_summary

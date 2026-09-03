#!/bin/sh
# Удаление luci-app-trusttunnel-lite для OpenWrt 25.12+.
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/uninstall.sh)"
#
# Останавливает службу, снимает её с автозапуска, удаляет оба пакета одним
# вызовом apk (языковой зависит от основного), бинарник клиента и кэши,
# перезапускает rpcd и чистит кэши LuCI, чтобы меню и страницы забыли
# удалённый пакет. В конце проверяет, что в ядре не осталось таблицы, правила
# и маршрутов.
#
# Форк не пишет ни в cron, ни в конфиг dnsmasq, но скрипт всё равно вычищает
# их следы: они остаются от исходного luci-app-trusttunnel, если он стоял на
# роутере до форка.
#
# Зона фаервола и /etc/config/trusttunnel удаляются только после
# подтверждения: первая — потому что о ней apk не знает и она может быть
# нужна (например, при временном сносе), второе — потому что файл объявлен
# conffiles и переустановка без него теряет настройки. Зависимости (kmod-tun,
# ip-full, curl, ca-bundle) не трогаются вовсе: они общие и могут
# использоваться другими пакетами — apk сам снимет те, что после удаления не
# нужны больше никому.
#
# Флаги:
#   -y — не задавать вопросов: удалить и зону фаервола, и настройки;
#   -c — оставить /etc/config/trusttunnel, не спрашивая.
set -e

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# Спрашивает да/нет и возвращает 0 для «да». Без терминала (запуск
# конвейером, из cron) read даёт пустую строку, и под `set -e` код возврата
# read оборвал бы скрипт — поэтому при сбое read берётся ответ по умолчанию,
# как в install.sh.
confirm() { # $1 — вопрос, $2 — ответ по умолчанию (y или n)
	_def=$2
	printf '%s [%s] ' "$1" "$_def"
	if read -r _answer; then
		case "$_answer" in
			y|Y) return 0 ;;
			n|N) return 1 ;;
			*)   [ "$_def" = "y" ] ;;
		esac
	else
		[ "$_def" = "y" ]
	fi
}

_opt_y=0
_opt_c=0
while getopts "yc" _o; do
	case "$_o" in
		y) _opt_y=1 ;;
		c) _opt_c=1 ;;
		*) die "usage: uninstall.sh [-y] [-c]" ;;
	esac
done
shift $((OPTIND - 1))

# --- Проверки окружения -------------------------------------------------------
[ -f /etc/openwrt_release ] || die "this script is for OpenWrt only"

# --- Служба -------------------------------------------------------------------
# Останавливается ДО удаления пакета: apk уберёт init-скрипт, и после этого
# остановить уже работающий клиент будет нечем. `disable` снимает ссылку
# /etc/rc.d/S95trusttunnel, которую повесил uci-defaults при установке.
if [ -x /etc/init.d/trusttunnel ]; then
	say "== Stopping and disabling the service"
	/etc/init.d/trusttunnel stop >/dev/null 2>&1 || true
	/etc/init.d/trusttunnel disable >/dev/null 2>&1 || true
else
	say "== The service is not installed"
fi

# --- Пакеты -------------------------------------------------------------------
say "== Removing the packages"
_pkgs=""
# `apk info -e` — «установлен ли пакет» — работает одинаково в apk-tools v2 и v3.
apk info -e luci-app-trusttunnel-lite >/dev/null 2>&1 && _pkgs="$_pkgs luci-app-trusttunnel-lite"
apk info -e luci-i18n-trusttunnel-lite-ru >/dev/null 2>&1 && _pkgs="$_pkgs luci-i18n-trusttunnel-lite-ru"
if [ -n "$_pkgs" ]; then
	# Оба пакета одним вызовом: языковой зависит от основного, и apk del
	# основного в одиночку молча ничего не удалит — «not removed due to».
	# shellcheck disable=SC2086
	apk del $_pkgs
else
	say "   no trusttunnel packages are installed"
fi

# --- Бинарь клиента и данные --------------------------------------------------
say "== Removing the client binaries and cached data"
_removed=0
for _d in /opt/trusttunnel_client /usr/share/trusttunnel /var/cache/trusttunnel /var/etc/trusttunnel; do
	if [ -e "$_d" ]; then
		rm -rf "$_d"
		say "   removed $_d"
		_removed=1
	fi
done
# /usr/share/trusttunnel форк не создаёт: каталог остался от исходного пакета
# со списками и состоянием DoH-захвата, и его тоже надо убрать.
[ "$_removed" = "1" ] || say "   nothing to remove"

# --- Cron ---------------------------------------------------------------------
# Форк cron-задание не заводит вовсе; строка могла остаться от исходного
# пакета. Шаблон покрывает и старую (update_lists), и новую
# (update_lists_cron) форму.
say "== Cleaning the cron job"
if [ -f /etc/crontabs/root ] && grep -q 'trusttunnel update_lists' /etc/crontabs/root; then
	sed -i '/trusttunnel update_lists/d' /etc/crontabs/root
	/etc/init.d/cron restart >/dev/null 2>&1 || true
	say "   cron job removed"
else
	say "   no cron job found"
fi

# --- Остатки dnsmasq ----------------------------------------------------------
# Форк конфиг в dnsmasq не публикует; файл мог остаться от исходного пакета.
# Штатный stop снимает копию конфига из conf-dir dnsmasq и перезапускает его.
# Эта страховка — на случай, когда служба не останавливалась: init-скрипт уже
# удалён прошлым заходом, а конфиг остался указывать на исчезнувший nftset.
_dnsmasq=$(ls /tmp/dnsmasq.*.d/trusttunnel.conf 2>/dev/null) || true
if [ -n "$_dnsmasq" ]; then
	say "== Removing the dnsmasq include left behind"
	# shellcheck disable=SC2086
	rm -f $_dnsmasq
	/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
fi

# --- Фаервол ------------------------------------------------------------------
# Зону и правило forwarding в /etc/config/firewall apk не знает — их добавлял
# uci-defaults при установке. Ищем по имени зоны и по dest правила, как они
# и создаются. Библиотека OpenWrt, на машине линтера отсутствует.
# shellcheck disable=SC1091
. /lib/functions.sh

_zones=""
_fwds=""
# Вызов через config_foreach, присваивание через config_get — линтер
# статически этого не видит.
# shellcheck disable=SC2329,SC2317,SC2154
find_zone() {
	config_get _n "$1" name
	[ "$_n" = "trusttunnel" ] || return 0
	_zones="$_zones $1"
}
# shellcheck disable=SC2329,SC2317,SC2154
find_fwd() {
	config_get _d "$1" dest
	[ "$_d" = "trusttunnel" ] || return 0
	_fwds="$_fwds $1"
}
config_load firewall
config_foreach find_zone zone
config_foreach find_fwd forwarding

if [ -n "$_zones$_fwds" ]; then
	say "== Firewall"
	if [ "$_opt_y" = "1" ] || confirm "Remove the trusttunnel firewall zone and forwarding rule?" y; then
		for _z in $_zones; do
			# shellcheck disable=SC2086
			uci delete "firewall.$_z"
		done
		for _f in $_fwds; do
			# shellcheck disable=SC2086
			uci delete "firewall.$_f"
		done
		uci commit firewall
		/etc/init.d/firewall reload >/dev/null 2>&1 || true
		say "   zone and forwarding rule removed"
	else
		say "   keeping the zone and the forwarding rule"
	fi
fi

# --- Настройки ----------------------------------------------------------------
if [ -f /etc/config/trusttunnel ]; then
	say "== Settings"
	if [ "$_opt_y" = "1" ]; then
		rm -f /etc/config/trusttunnel
		say "   /etc/config/trusttunnel removed"
	elif [ "$_opt_c" = "1" ]; then
		say "   keeping /etc/config/trusttunnel"
	elif confirm "Remove /etc/config/trusttunnel? (it survives a reinstall)" n; then
		rm -f /etc/config/trusttunnel
		say "   /etc/config/trusttunnel removed"
	else
		say "   keeping /etc/config/trusttunnel"
	fi
fi

# --- LuCI ---------------------------------------------------------------------
# Бэкенд rpcd держит пакетный ucode в памяти: без перезапуска меню и страницы
# продолжат показывать уже удалённый раздел. Кэши чистим, чтобы не тянули
# старый индекс, — как это делает uci-defaults при установке.
say "== Refreshing LuCI"
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

# --- Ядро ---------------------------------------------------------------------
say "== Checking for kernel leftovers"
_clean=1
if command -v nft >/dev/null 2>&1 && nft list table inet trusttunnel >/dev/null 2>&1; then
	say "   warning: nft table 'inet trusttunnel' still exists — the service did not stop cleanly, a reboot will clear it"
	_clean=0
fi
if command -v ip >/dev/null 2>&1 && ip rule show 2>/dev/null | grep -q 'lookup 880'; then
	say "   warning: ip rule for table 880 still present — a reboot will clear it"
	_clean=0
fi
if command -v ip >/dev/null 2>&1 && ip route show table 880 2>/dev/null | grep -q .; then
	say "   warning: routes in table 880 still present — a reboot will clear it"
	_clean=0
fi
[ "$_clean" = "1" ] && say "   kernel is clean"

say ""
say "== Done"
say "The packages, the client, the caches and the firewall zone are gone."
say "Shared dependencies are not removed on purpose; apk drops on its own only"
say "the ones that nothing else depends on."

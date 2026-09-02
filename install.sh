#!/bin/sh
# Установщик luci-app-trusttunnel-lite для OpenWrt 25.12+.
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
set -e

REPO="${TT_REPO:-i-zhirov/luci-app-trusttunnel-lite}"
CLIENT_DIR=/opt/trusttunnel_client
CLIENT_INSTALLER=https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/refs/heads/master/scripts/install.sh

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- Проверки окружения -------------------------------------------------------
[ -f /etc/openwrt_release ] || die "this script is for OpenWrt only"
# Файл существует только на роутере, линтеру его не видно.
# shellcheck disable=SC1091
. /etc/openwrt_release

major=$(printf '%s' "$DISTRIB_RELEASE" | cut -d. -f1)
case "$major" in
	[0-9]*) [ "$major" -ge 25 ] || die "OpenWrt 25.12 or newer is required (found $DISTRIB_RELEASE)" ;;
	*)      say "warning: cannot parse release '$DISTRIB_RELEASE', continuing" ;;
esac

command -v apk >/dev/null 2>&1 || die "apk not found; this package targets OpenWrt 25.12+"

# Архитектура проверяется здесь, ДО установки чего бы то ни было: раньше эта
# проверка стояла после установки пакета luci-app-trusttunnel-lite и клиента, и
# неподдерживаемая платформа обнаруживалась уже после того как в системе
# появлялась запись в меню LuCI и служба без работающего бинарника клиента —
# то есть отказ оставлял после себя мёртвый огрызок установки вместо чистого
# выхода.
say "== Checking architecture"
# Проверяется `uname -m`, а НЕ `apk --print-arch`. Это принципиально: сам пакет
# архитектурно-независим (PKGARCH:=all, внутри только скрипты), а ограничение
# идёт от бинарника клиента, который ставит установщик вендора — и он выбирает
# сборку именно по `uname -m`. Это разные пространства имён, и расхождение не
# теоретическое: пакетные цели OpenWrt `arm_*` включают устройства на ARMv5 и
# ARMv6 (arm_arm926ej-s, arm_xscale, arm_arm1176jzf-s_vfp), где `uname -m`
# отдаёт armv5tel или armv6l, а вендор принимает только armv7l и armv8l.
# Прежняя проверка по `arm_*` такие роутеры ПРОПУСКАЛА, пакет ставился, и
# отказ приходил уже от вендора — то есть после установки, оставляя пункт в
# меню и службу без клиента.
#
# Список сверен с scripts/install.sh вендора: принимаются x86_64, armv7,
# aarch64, mips, mipsel. Порядок байт для mips вендор определяет сам, поэтому
# здесь достаточно пропустить оба варианта.
arch=$(uname -m 2>/dev/null)
case "$arch" in
	x86_64|x86-64|x64|amd64) say "   CPU: x86_64" ;;
	aarch64|arm64)           say "   CPU: aarch64" ;;
	armv7l|armv8l)           say "   CPU: armv7" ;;
	mips|mipsel)             say "   CPU: $arch (endianness is resolved by the vendor installer)" ;;
	*) die "unsupported CPU '$arch'; the TrustTunnel client ships only for x86_64, aarch64, armv7, mips and mipsel — this covers most modern routers, but not ARMv5/ARMv6, mips64, riscv64 or powerpc devices" ;;
esac

say "== Installing dependencies"
apk update
apk add kmod-tun ip-full curl ca-bundle

# --- Пакет --------------------------------------------------------------------
say "== Fetching the latest package release"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" > "$tmp/release.json" \
	|| die "cannot reach the GitHub API for $REPO"

# Аргумент подставляется в выражение sed БЕЗ экранирования регекс-метасимволов,
# поэтому безопасен только для тех буквальных строк, которыми эта функция
# вызывается ниже ('luci-app-trusttunnel-lite', 'luci-i18n-trusttunnel-lite') —
# не для произвольного ввода.
pick_asset() {
	sed -n 's/.*"browser_download_url": *"\([^"]*'"$1"'[^"]*\.apk\)".*/\1/p' \
		"$tmp/release.json" | head -n1
}

url=$(pick_asset 'luci-app-trusttunnel-lite')
[ -n "$url" ] || die "cannot find a luci-app-trusttunnel-lite .apk in the latest release of $REPO"

# luci.mk собирает из po/ru ОТДЕЛЬНЫЙ пакет luci-i18n-trusttunnel-lite-ru. Без
# него интерфейс остаётся англоязычным, хотя перевод в репозитории есть,
# поэтому его тоже надо забрать. Имя выводится из LUCI_BASENAME, то есть из
# имени каталога пакета.
i18n_url=$(pick_asset 'luci-i18n-trusttunnel-lite')

say "   $url"
curl -fsSL -o "$tmp/pkg.apk" "$url" || die "failed to download $url"
if [ -n "$i18n_url" ]; then
	say "   $i18n_url"
	# Отказ НЕ фатален, как и отказ установки этого пакета ниже: релиз без
	# перевода — ухудшенный, а не сломанный, и прерывать из-за него уже
	# скачанный основной пакет неправильно.
	curl -fsSL -o "$tmp/i18n.apk" "$i18n_url" \
		|| { rm -f "$tmp/i18n.apk"; say "warning: could not download the translation package; the interface will be English"; }
else
	say "   note: no translation package in this release; the interface will be English"
fi

# Служба останавливается перед подменой файлов: иначе работающий клиент
# продолжит крутить старую конфигурацию.
# Запомнить, работала ли служба: в конце её надо вернуть в прежнее состояние.
# Просто запускать в конце нельзя — на ПЕРВОЙ установке служба стартовать не
# должна, endpoint ещё не настроен. Просто не запускать тоже нельзя: тогда
# пользователь с работающим туннелем обновляется и остаётся без туннеля до
# ручного вмешательства, потому что `apk add` наш сервис не поднимает.
was_running=0
if [ -x /etc/init.d/trusttunnel ]; then
	/etc/init.d/trusttunnel running >/dev/null 2>&1 && was_running=1
	say "== Stopping the running service"
	/etc/init.d/trusttunnel stop || true
fi

say "== Installing the package"
apk add --allow-untrusted "$tmp/pkg.apk"
if [ -f "$tmp/i18n.apk" ]; then
	apk add --allow-untrusted "$tmp/i18n.apk" \
		|| say "warning: the translation package failed to install; the interface will be English"
fi

# --- Бинарь клиента -----------------------------------------------------------
# $arch уже проверен и напечатан выше, до установки чего бы то ни было.
say "== Installing the TrustTunnel client binary"
mkdir -p "$CLIENT_DIR"
# Флаг -a y обязателен. Скрипт вендора задаёт вопросы чтением из /dev/tty, и
# один из них — «убедитесь, что клиент остановлен, продолжать?» — возникает
# при ПОВТОРНОЙ установке, то есть на обычном пути обновления. Без флага
# установщик там повиснет, а в неинтерактивном окружении (запуск из скрипта
# или из cron) чтение из /dev/tty ещё и недоступно вовсе. Ответ «да» здесь
# правдив: службу мы остановили выше, до подмены бинарника.
curl -fsSL "$CLIENT_INSTALLER" | sh -s - -a y -o "$CLIENT_DIR"
[ -x "$CLIENT_DIR/trusttunnel_client" ] || die "client binary was not installed"

say "== Restarting LuCI backend"
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

# Вернуть службу в прежнее состояние. Запускаем только если она РАБОТАЛА до
# установки: `apk add` наш сервис не поднимает, поэтому без этого пользователь
# с работающим туннелем обновляется и остаётся без туннеля. Безусловный запуск
# тоже неверен — на первой установке endpoint ещё не настроен.
if [ "$was_running" = "1" ]; then
	say "== Starting the service back up"
	/etc/init.d/trusttunnel start \
		|| say "warning: the service did not start; see 'logread -e trusttunnel'"
fi

say ""
say "== Done"
say ""
say "Open LuCI: Services -> TrustTunnel -> Settings"
say "Fill in the endpoint (or import the config your server generated),"
say "add \"do not bypass\" exclusions if you need any, then enable the service."

#!/bin/sh
# Uninstall of luci-app-trusttunnel-lite for OpenWrt 25.12+.
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/uninstall.sh)"
#
# Stops the service, removes it from auto-start, deletes both packages in
# one apk call (the language package depends on the main one), the client
# binary and the caches, restarts rpcd and clears the LuCI caches so the
# menu and the pages forget the removed package. At the end it checks that
# no table, rule or routes remain in the kernel.
#
# The fork writes nothing into cron or the dnsmasq config, but the script
# still cleans their traces: they remain from the original
# luci-app-trusttunnel if it was installed on the router before the fork.
#
# The firewall zone and /etc/config/trusttunnel are removed only after
# confirmation: the former because apk knows nothing about it and it may
# be needed (e.g. during a temporary teardown), the latter because the
# file is declared in conffiles and a reinstall without it loses the
# settings. Dependencies (kmod-tun, ip-full, curl, ca-bundle) are not
# touched at all: they are shared and may be used by other packages — apk
# itself removes the ones nobody needs after the removal.
#
# Flags:
#   -y — ask no questions: remove both the firewall zone and the settings;
#   -c — keep /etc/config/trusttunnel without asking.
set -e

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# Asks yes/no and returns 0 for "yes". Without a terminal (pipeline run,
# cron) read yields an empty line, and under `set -e` the read's exit code
# would abort the script — so on a read failure the default answer is
# taken, as in install.sh.
confirm() { # $1 — the question, $2 — the default answer (y or n)
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

# --- Environment checks -------------------------------------------------------
[ -f /etc/openwrt_release ] || die "this script is for OpenWrt only"

# --- Service ------------------------------------------------------------------
# Stopped BEFORE the package is removed: apk will take the init script
# away, and after that there would be nothing to stop the running client
# with. `disable` removes the /etc/rc.d/S95trusttunnel link that
# uci-defaults created at install.
if [ -x /etc/init.d/trusttunnel ]; then
	say "== Stopping and disabling the service"
	/etc/init.d/trusttunnel stop >/dev/null 2>&1 || true
	/etc/init.d/trusttunnel disable >/dev/null 2>&1 || true
else
	say "== The service is not installed"
fi

# --- Packages -----------------------------------------------------------------
say "== Removing the packages"
_pkgs=""
# `apk info -e` — "is the package installed" — works the same in apk-tools
# v2 and v3.
apk info -e luci-app-trusttunnel-lite >/dev/null 2>&1 && _pkgs="$_pkgs luci-app-trusttunnel-lite"
apk info -e luci-i18n-trusttunnel-lite-ru >/dev/null 2>&1 && _pkgs="$_pkgs luci-i18n-trusttunnel-lite-ru"
if [ -n "$_pkgs" ]; then
	# Both packages in one call: the language package depends on the main
	# one, and apk del of the main one alone would silently delete
	# nothing — "not removed due to".
	# shellcheck disable=SC2086
	apk del $_pkgs
else
	say "   no trusttunnel packages are installed"
fi

# --- Client binary and data ---------------------------------------------------
say "== Removing the client binaries and cached data"
_removed=0
for _d in /opt/trusttunnel_client /usr/share/trusttunnel /var/cache/trusttunnel /var/etc/trusttunnel; do
	if [ -e "$_d" ]; then
		rm -rf "$_d"
		say "   removed $_d"
		_removed=1
	fi
done
# /usr/share/trusttunnel is not created by the fork: the directory remained
# from the original package with the lists and the DoH-takeover state, and
# it has to go too.
[ "$_removed" = "1" ] || say "   nothing to remove"

# --- Cron ---------------------------------------------------------------------
# The fork does not create a cron job at all; the line may remain from the
# original package. The pattern covers both the old (update_lists) and the
# new (update_lists_cron) form.
say "== Cleaning the cron job"
if [ -f /etc/crontabs/root ] && grep -q 'trusttunnel update_lists' /etc/crontabs/root; then
	sed -i '/trusttunnel update_lists/d' /etc/crontabs/root
	/etc/init.d/cron restart >/dev/null 2>&1 || true
	say "   cron job removed"
else
	say "   no cron job found"
fi

# --- dnsmasq leftovers --------------------------------------------------------
# The fork does not publish a config into dnsmasq; the file may remain
# from the original package. A regular stop removes the config copy from
# dnsmasq's conf-dir and restarts it. This safety net is for the case when
# the service was not stopped: the init script was already deleted by the
# previous pass, while the config kept pointing at the vanished nftset.
_dnsmasq=$(ls /tmp/dnsmasq.*.d/trusttunnel.conf 2>/dev/null) || true
if [ -n "$_dnsmasq" ]; then
	say "== Removing the dnsmasq include left behind"
	# shellcheck disable=SC2086
	rm -f $_dnsmasq
	/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
fi

# --- Firewall -----------------------------------------------------------------
# apk knows nothing about the zone and the forwarding rule in
# /etc/config/firewall — uci-defaults added them at install. They are
# looked up by the zone name and by the rule's dest, exactly as they are
# created. OpenWrt library, absent on the linter's machine.
# shellcheck disable=SC1091
. /lib/functions.sh

_zones=""
_fwds=""
# Called via config_foreach, assigned via config_get — the linter does not
# see this statically.
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

# --- Settings ----------------------------------------------------------------
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
# The rpcd backend keeps the package's ucode in memory: without a restart
# the menu and the pages keep showing the already-removed section. The
# caches are cleared so they do not drag the old index along — the same
# thing uci-defaults does at install.
say "== Refreshing LuCI"
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

# --- Kernel -------------------------------------------------------------------
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

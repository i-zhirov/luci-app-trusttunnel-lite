#!/bin/sh
# Installer for luci-app-trusttunnel-lite for OpenWrt 22.03+.
# Both branches are supported: apk (25.12+) and opkg (22.03-24.10); the package
# manager and the artifact format are detected automatically.
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
set -e

REPO="${TT_REPO:-i-zhirov/luci-app-trusttunnel-lite}"
CLIENT_DIR=/opt/trusttunnel_client
CLIENT_INSTALLER=https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/refs/heads/master/scripts/install.sh

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- Environment checks ----------------------------------------------------
[ -f /etc/openwrt_release ] || die "this script is for OpenWrt only"
# The file exists only on a router; the linter cannot see it.
# shellcheck disable=SC1091
. /etc/openwrt_release

# One installer for both OpenWrt branches: apk (25.12+) and opkg (22.03-24.10).
# Below, $PM selects the commands and $ext the artifact extension of the
# release (.apk on apk branches, .ipk on opkg branches).
PM=""
command -v apk >/dev/null 2>&1 && PM=apk
[ -n "$PM" ] || { command -v opkg >/dev/null 2>&1 && PM=opkg; }
[ -n "$PM" ] || die "neither apk nor opkg found; unsupported OpenWrt variant"
ext=apk; [ "$PM" = "opkg" ] && ext=ipk

major=$(printf '%s' "$DISTRIB_RELEASE" | cut -d. -f1)
case "$major" in
	[0-9]*)
		case "$PM" in
			apk)  [ "$major" -ge 25 ] || die "apk requires OpenWrt 25.12 or newer (found $DISTRIB_RELEASE)" ;;
			opkg) [ "$major" -ge 22 ] || die "opkg requires OpenWrt 22.03 or newer (found $DISTRIB_RELEASE)" ;;
		esac
		;;
	*) say "warning: cannot parse release '$DISTRIB_RELEASE', continuing" ;;
esac

# The architecture is checked here, BEFORE anything is installed: the check
# used to run after installing the luci-app-trusttunnel-lite package and
# the client, so an unsupported platform was only discovered after a LuCI
# menu entry and a service without a working client binary had appeared in
# the system — the failure left a dead stub of an installation behind
# instead of exiting cleanly.
say "== Checking architecture"
# `uname -m` is checked, NOT `apk --print-arch`. This is fundamental: the
# package itself is architecture-independent (PKGARCH:=all, scripts only),
# while the constraint comes from the client binary installed by the vendor
# installer — which picks its build exactly by `uname -m`. These are
# different namespaces, and the divergence is not theoretical: the OpenWrt
# package targets `arm_*` include ARMv5 and ARMv6 devices
# (arm_arm926ej-s, arm_xscale, arm_arm1176jzf-s_vfp), where `uname -m`
# reports armv5tel or armv6l, while the vendor accepts only armv7l and
# armv8l. The former `arm_*` check let such routers THROUGH, the package
# installed, and the refusal came from the vendor — after installation,
# leaving a menu entry and a service without a client.
#
# The list is cross-checked against the vendor's scripts/install.sh:
# x86_64, armv7, aarch64, mips, mipsel are accepted. The mips byte order
# is resolved by the vendor itself, so passing both variants here is
# enough.
arch=$(uname -m 2>/dev/null)
case "$arch" in
	x86_64|x86-64|x64|amd64) say "   CPU: x86_64" ;;
	aarch64|arm64)           say "   CPU: aarch64" ;;
	armv7l|armv8l)           say "   CPU: armv7" ;;
	mips|mipsel)             say "   CPU: $arch (endianness is resolved by the vendor installer)" ;;
	*) die "unsupported CPU '$arch'; the TrustTunnel client ships only for x86_64, aarch64, armv7, mips and mipsel — this covers most modern routers, but not ARMv5/ARMv6, mips64, riscv64 or powerpc devices" ;;
esac

say "== Installing dependencies"
if [ "$PM" = "apk" ]; then
	apk update
	apk add kmod-tun ip-full curl ca-bundle
else
	opkg update
	opkg install kmod-tun ip-full curl ca-bundle
fi

# --- Package ------------------------------------------------------------------
say "== Fetching the latest package release"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" > "$tmp/release.json" \
	|| die "cannot reach the GitHub API for $REPO"

# The argument is substituted into the sed expression WITHOUT escaping
# regex metacharacters, so it is only safe for the literal strings this
# function is called with below ('luci-app-trusttunnel-lite',
# 'luci-i18n-trusttunnel-lite', 'apk', 'ipk') — not for arbitrary input.
pick_asset() { # $1 — package name substring, $2 — extension (apk|ipk)
	sed -n 's/.*"browser_download_url": *"\([^"]*'"$1"'[^"]*\.'"$2"'\)".*/\1/p' \
		"$tmp/release.json" | head -n1
}

url=$(pick_asset 'luci-app-trusttunnel-lite' "$ext")
[ -n "$url" ] || die "cannot find a luci-app-trusttunnel-lite .$ext in the latest release of $REPO"

# luci.mk builds a SEPARATE luci-i18n-trusttunnel-lite-ru package from
# po/ru. Without it the UI stays English even though the translation exists
# in the repository, so it has to be picked up too. The name derives from
# LUCI_BASENAME, i.e. from the package directory name.
i18n_url=$(pick_asset 'luci-i18n-trusttunnel-lite' "$ext")

say "   $url"
curl -fsSL -o "$tmp/pkg.$ext" "$url" || die "failed to download $url"
if [ -n "$i18n_url" ]; then
	say "   $i18n_url"
	# The failure is NOT fatal, same as the failure of installing this
	# package below: a release without a translation is degraded, not
	# broken, and aborting the already-downloaded main package because of
	# it would be wrong.
	curl -fsSL -o "$tmp/i18n.$ext" "$i18n_url" \
		|| { rm -f "$tmp/i18n.$ext"; say "warning: could not download the translation package; the interface will be English"; }
else
	say "   note: no translation package in this release; the interface will be English"
fi

# The service is stopped before the files are replaced: otherwise the
# running client keeps spinning the old configuration.
# Remember whether the service was running: it must be restored to its
# previous state at the end. Simply starting it at the end is wrong — on
# the FIRST install the service must not start, the endpoint is not
# configured yet. Simply not starting it is also wrong: then a user with a
# working tunnel updates and stays without a tunnel until manual
# intervention, because neither apk nor opkg brings our service up.
was_running=0
if [ -x /etc/init.d/trusttunnel ]; then
	/etc/init.d/trusttunnel running >/dev/null 2>&1 && was_running=1
	say "== Stopping the running service"
	/etc/init.d/trusttunnel stop || true
fi

say "== Installing the package"
if [ "$PM" = "apk" ]; then
	apk add --allow-untrusted "$tmp/pkg.apk"
	if [ -f "$tmp/i18n.apk" ]; then
		apk add --allow-untrusted "$tmp/i18n.apk" \
			|| say "warning: the translation package failed to install; the interface will be English"
	fi
else
	# A local .ipk does not pass signature verification (opkg only checks
	# packages from feeds), so no --force-* flags are needed.
	opkg install "$tmp/pkg.ipk"
	if [ -f "$tmp/i18n.ipk" ]; then
		opkg install "$tmp/i18n.ipk" \
			|| say "warning: the translation package failed to install; the interface will be English"
	fi
fi

# --- Client binary -----------------------------------------------------------
# $arch has already been checked and printed above, before anything was
# installed.
say "== Installing the TrustTunnel client binary"
mkdir -p "$CLIENT_DIR"
# The -a y flag is mandatory. The vendor script asks questions by reading
# from /dev/tty, and one of them — "make sure the client is stopped,
# continue?" — arises on a RE-install, i.e. on the ordinary update path.
# Without the flag the installer hangs there, and in a non-interactive
# environment (run from a script or cron) reading from /dev/tty is not
# available at all. Answering "yes" here is truthful: we stopped the
# service above, before replacing the binary.
curl -fsSL "$CLIENT_INSTALLER" | sh -s - -a y -o "$CLIENT_DIR"
[ -x "$CLIENT_DIR/trusttunnel_client" ] || die "client binary was not installed"

say "== Restarting LuCI backend"
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

# Restore the service to its previous state. Start only if it was RUNNING
# before the install: `apk add` does not bring our service up, so without
# this a user with a working tunnel updates and stays without a tunnel. An
# unconditional start is wrong too — on the first install the endpoint is
# not configured yet.
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

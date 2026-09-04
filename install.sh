#!/bin/sh
# Installer for luci-app-trusttunnel-lite for OpenWrt 22.03+.
#
# Installs from the package repositories hosted on this project's GitHub
# Pages site (published from the repo branch): a signed apk repository
# (apk/ subdirectory) on 25.12+, a signed opkg repository (opkg/
# subdirectory) on 22.03-24.10. The package manager is detected
# automatically. The repository stays configured on the router after the
# install, so later updates are a plain `apk update && apk upgrade` (or
# `opkg update && opkg upgrade`) — re-running the installer is only needed
# for the client binary.
#
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
#
# Environment overrides:
#   TT_REPO_URL — repository base URL; apk fetches <url>/apk/packages.adb
#                 from it and opkg appends /Packages.gz to <url>/opkg
#                 (default: the GitHub Pages site of this repository —
#                 useful for a fork, a mirror or a test server)
set -e

REPO_URL="${TT_REPO_URL:-https://i-zhirov.github.io/luci-app-trusttunnel-lite}"
# The public halves of the two signing keys travel next to the repositories
# they secure (key-build.pub signs the apk index packages.adb, opkg-key.pub
# signs the opkg index Packages.gz) and are fetched from the same URLs. The
# private halves exist only as GitHub Actions secrets.
KEY_URL="$REPO_URL/apk/key-build.pub"
OPKG_KEY_URL="$REPO_URL/opkg/opkg-key.pub"
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
# Below, $PM selects the commands and the repository layout the branch uses.
PM=""
command -v apk >/dev/null 2>&1 && PM=apk
[ -n "$PM" ] || { command -v opkg >/dev/null 2>&1 && PM=opkg; }
[ -n "$PM" ] || die "neither apk nor opkg found; unsupported OpenWrt variant"

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

# --- Package repository ------------------------------------------------------
# install.sh used to download the .apk/.ipk files from the latest GitHub
# release and hand them to the package manager directly. Now the packages
# are served as real repositories — the signed apk-repo branch for apk, the
# signed opkg feed in the GitHub releases for opkg — and the package manager
# talks to them as such. The entry stays configured after the install, which
# is what makes `apk update && apk upgrade` / `opkg update && opkg upgrade`
# work for later versions.
say "== Setting up the package repository"
if [ "$PM" = "apk" ]; then
	# apk refuses an index with an UNTRUSTED signature, so the public half
	# of the key that signs packages.adb must be installed before the first
	# `apk update`. The private half lives only as a GitHub Actions secret
	# and never reaches the router. The key is stable across releases; on
	# rotation, re-running the installer refreshes it.
	#
	# The repository URL must name the index file explicitly: a URL that
	# ends in /packages.adb is fetched as-is, while a bare directory URL
	# makes apk look for <url>/<arch>/APKINDEX.tar.gz (Alpine's layout).
	# OpenWrt's own feeds are written the same way.
	mkdir -p /etc/apk/keys
	# wget (busybox wget / uclient-fetch) is used on purpose, not curl:
	# this runs BEFORE the dependencies are installed, and wget is the one
	# tool the one-liner that fetched this script already required.
	wget -q -O /etc/apk/keys/trusttunnel.pub "$KEY_URL" \
		|| die "cannot fetch the repository signing key from $KEY_URL"
	mkdir -p /etc/apk/repositories.d
	printf '%s/apk/packages.adb\n' "$REPO_URL" > /etc/apk/repositories.d/trusttunnel.list
	say "   repository: $REPO_URL/apk/packages.adb"
	say "   key:        /etc/apk/keys/trusttunnel.pub"
else
	# opkg appends /Packages.gz to the feed URL, so the URL must NOT name
	# the index file (unlike the apk entry above).
	#
	# opkg verifies feed signatures on stock OpenWrt (/etc/opkg.conf has
	# check_signature and the default verify program is opkg-key), so the
	# feed is signed with usign and the public key is installed into
	# /etc/opkg/keys/<fingerprint> — the same arrangement as the official
	# feeds.
	_feed=/etc/opkg/customfeeds.conf
	if grep -q '^src/gz trusttunnel ' "$_feed" 2>/dev/null; then
		say "   feed line already present in $_feed"
	else
		[ -f "$_feed" ] || touch "$_feed"
		printf 'src/gz trusttunnel %s/opkg\n' "$REPO_URL" >> "$_feed"
		say "   feed: $REPO_URL/opkg ($_feed)"
	fi
	# The opkg public key is committed to the repository as opkg-key.pub.
	# Its file name in /etc/opkg/keys must be the usign key fingerprint:
	# usign -P (which opkg-key runs) only matches key files whose name IS
	# the fingerprint. usign is part of the base system — opkg-key itself
	# calls it.
	#
	# A copy under the stable name trusttunnel.pub is kept alongside the
	# fingerprint-named one: uninstall.sh uses it as a handle to find and
	# remove the key without knowing the fingerprint in advance.
	mkdir -p /etc/opkg/keys
	wget -q -O /etc/opkg/keys/trusttunnel.pub "$OPKG_KEY_URL" \
		|| die "cannot fetch the feed signing key from $OPKG_KEY_URL"
	command -v usign >/dev/null 2>&1 \
		|| die "usign not found; cannot install the feed signing key"
	_fp=$(usign -F -p /etc/opkg/keys/trusttunnel.pub 2>/dev/null) \
		|| die "cannot read the fingerprint of the feed signing key"
	cp /etc/opkg/keys/trusttunnel.pub "/etc/opkg/keys/$_fp"
	say "   feed key: /etc/opkg/keys/$_fp"
fi

say "== Updating package indexes"
if [ "$PM" = "apk" ]; then
	apk update
else
	opkg update
fi

say "== Installing dependencies"
if [ "$PM" = "apk" ]; then
	apk add kmod-tun ip-full curl ca-bundle
else
	opkg install kmod-tun ip-full curl ca-bundle
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
	apk add luci-app-trusttunnel-lite \
		|| die "failed to install luci-app-trusttunnel-lite from $REPO_URL/apk"
	# The translation package is optional: a release without it (or with a
	# failed install) leaves the interface English, which is degraded but
	# not broken — the main package must not be rolled back because of it.
	apk add luci-i18n-trusttunnel-lite-ru \
		|| say "warning: the translation package failed to install; the interface will be English"
else
	opkg install luci-app-trusttunnel-lite \
		|| die "failed to install luci-app-trusttunnel-lite from $REPO_URL"
	opkg install luci-i18n-trusttunnel-lite-ru \
		|| say "warning: the translation package failed to install; the interface will be English"
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
#
# The vendor script runs with `set -u` and reads $USER to decide whether
# it is root. In a non-login environment (cron, ssh without a session)
# the variable is unset and the script dies with "USER: parameter not
# set". We ARE root here — the script dies on the check that would prove
# it, so the value is exported explicitly.
USER="${USER:-root}"
export USER
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
say "The repository stays configured on this router:"
if [ "$PM" = "apk" ]; then
	say "   apk update && apk upgrade   # to update the package later"
else
	say "   opkg update && opkg upgrade # to update the package later"
fi
say "Open LuCI: Services -> TrustTunnel -> Settings"
say "Fill in the endpoint (or import the config your server generated),"
say "add \"do not bypass\" exclusions if you need any, then enable the service."

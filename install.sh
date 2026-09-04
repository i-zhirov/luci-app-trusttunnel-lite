#!/bin/sh
# Installer for luci-app-trusttunnel-lite for OpenWrt 22.03+.
#
# Installs from the package repositories hosted on this project's GitHub
# Pages site (published from the repo branch): a signed apk repository
# (apk/<arch>/ subdirectories, one per device architecture) on 25.12+, a
# signed opkg repository (opkg/ subdirectory) on 22.03-24.10. The package
# manager is detected automatically. The repository stays configured on the
# router after the install, so later updates are a plain `apk update && apk
# upgrade` (or `opkg update && opkg upgrade`) — the client binary is a
# dependency of the package (trusttunnel-client) and updates with it, so
# re-running the installer is only needed to refresh the signing keys.
#
#   sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
#
# Environment overrides:
#   TT_REPO_URL — repository base URL; apk fetches
#                 <url>/apk/<arch>/packages.adb from it and opkg appends
#                 /Packages.gz to <url>/opkg (default: the GitHub Pages
#                 site of this repository — useful for a fork, a mirror or
#                 a test server)
set -e

REPO_URL="${TT_REPO_URL:-https://i-zhirov.github.io/luci-app-trusttunnel-lite}"
# The public halves of the two signing keys travel next to the repositories
# they secure (key-build.pub signs the apk index packages.adb, opkg-key.pub
# signs the opkg index Packages.gz) and are fetched from the same URLs. The
# private halves exist only as GitHub Actions secrets.
KEY_URL="$REPO_URL/apk/key-build.pub"
OPKG_KEY_URL="$REPO_URL/opkg/opkg-key.pub"

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
# `uname -m` is checked, NOT `apk --print-arch`/`opkg print-architecture`.
# This is fundamental: the constraint comes from the trusttunnel-client
# package, which is built only for the vendor's five CPU families — and the
# vendor's family is what `uname -m` reports, while the package-manager
# arch is the fine-grained OpenWrt SUBTARGET arch (aarch64_cortex-a53,
# arm_cortex-a7_neon-vfpv4, ...). The divergence is not theoretical: the
# OpenWrt `arm_*` targets include ARMv5 and ARMv6 devices
# (arm_arm926ej-s, arm_xscale, arm_arm1176jzf-s_vfp), where `uname -m`
# reports armv5tel or armv6l, while the vendor accepts only armv7l and
# armv8l. An `arm_*` check would let such routers THROUGH — the package
# manager would then fail later, after the repository was configured, with
# a bare "cannot satisfy the dependency" error.
#
# The list is cross-checked against the vendor's scripts/install.sh and the
# VENDOR_ARCH mapping in packages/trusttunnel-client/Makefile: x86_64,
# armv7, aarch64, mips, mipsel are accepted. The mips byte order is
# resolved by the build itself (mips_* vs mipsel_* subtargets pick the
# matching vendor tarball), so passing both variants here is enough.
arch=$(uname -m 2>/dev/null)
case "$arch" in
	x86_64|x86-64|x64|amd64) say "   CPU: x86_64" ;;
	aarch64|arm64)           say "   CPU: aarch64" ;;
	armv7l|armv8l)           say "   CPU: armv7" ;;
	mips|mipsel)             say "   CPU: $arch (the package is built per endianness)" ;;
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
	# The repositories are PER-ARCHITECTURE: apk matches the package arch
	# against the device's own arch byte-for-byte (verified: a package of a
	# sibling arch is refused with "error: uninstallable"), so every
	# subtarget arch has its own directory, mirroring the official OpenWrt
	# layout. The URL must name the index file explicitly: a URL that ends
	# in /packages.adb is fetched as-is, while a bare directory URL makes
	# apk look for <url>/<arch>/APKINDEX.tar.gz (Alpine's layout).
	mkdir -p /etc/apk/keys
	# wget (busybox wget / uclient-fetch) is used on purpose, not curl:
	# this runs BEFORE the dependencies are installed, and wget is the one
	# tool the one-liner that fetched this script already required.
	wget -q -O /etc/apk/keys/trusttunnel.pub "$KEY_URL" \
		|| die "cannot fetch the repository signing key from $KEY_URL"
	# The device's own apk arch: apk --print-arch. The CPU check above has
	# already ensured the family is supported, and every subtarget arch of
	# the supported families is built, so the directory exists.
	_apk_arch=$(apk --print-arch 2>/dev/null) \
		|| die "cannot determine the apk architecture"
	mkdir -p /etc/apk/repositories.d
	printf '%s/apk/%s/packages.adb\n' "$REPO_URL" "$_apk_arch" \
		> /etc/apk/repositories.d/trusttunnel.list
	say "   repository: $REPO_URL/apk/$_apk_arch/packages.adb"
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
# The client binaries are a hard dependency of the package
# (+trusttunnel-client), so the package manager installs them into
# /opt/trusttunnel_client as part of this step — and updates them with the
# same `apk upgrade` / `opkg upgrade` that updates the LuCI app.
if [ "$PM" = "apk" ]; then
	apk add luci-app-trusttunnel-lite \
		|| die "failed to install luci-app-trusttunnel-lite from $REPO_URL/apk/$_apk_arch"
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
# A tripwire for the case where the repository lacks an arch-specific
# client build: the package manager would normally refuse the whole
# install, but if it ever gets through, the tunnel would silently not work.
if [ "$PM" = "apk" ]; then
	apk info -e trusttunnel-client >/dev/null 2>&1 \
		|| die "trusttunnel-client is not installed; the repository may lack a build for this architecture"
else
	opkg list-installed 2>/dev/null | grep -q '^trusttunnel-client ' \
		|| die "trusttunnel-client is not installed; the repository may lack a build for this architecture"
fi

# --- Client binary -----------------------------------------------------------
# The client used to be installed by piping the vendor's install.sh into
# sh — an unpinned `master` fetch with no checksum. Since the fork's
# packages gained the trusttunnel-client dependency, the package manager
# handles the binary: it is pinned by version and hash at build time
# (packages/trusttunnel-client/Makefile), installed with the package, and
# updated by `apk upgrade` / `opkg upgrade` together with the LuCI app.
# Nothing else is needed here — the binaries are already in
# /opt/trusttunnel_client after the install step above.

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
	say "   apk update && apk upgrade   # updates the package and the client"
else
	say "   opkg update && opkg upgrade # updates the package and the client"
fi
say "Open LuCI: Services -> TrustTunnel -> Settings"
say "Fill in the endpoint (or import the config your server generated),"
say "add \"do not bypass\" exclusions if you need any, then enable the service."

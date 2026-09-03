# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk

# Lightweight fork of luci-app-trusttunnel (NooBiToo/TrustTunnelOpenWrt):
# full-tunnel only, no domain lists, no dnsmasq/nftset machinery.
PKG_NAME:=luci-app-trusttunnel-lite
# Version inherited from the original package: the first fork release should be
# tagged v1.0.10 or higher, otherwise the update check will show "a newer
# version than the latest release is installed".
PKG_VERSION:=1.0.10
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=TrustTunnelOpenWrt contributors

LUCI_TITLE:=LuCI support for TrustTunnel (full tunnel)
LUCI_DESCRIPTION:=Runs the TrustTunnel client on OpenWrt and routes LAN \
	traffic through the tunnel with a killswitch and a LuCI interface.
LUCI_DEPENDS:=+luci-base +kmod-tun +ip-full +curl +ca-bundle +ucode-mod-math
# Otherwise luci.mk would substitute the address of LuCI itself, and `apk info`
# would send for support to the wrong place.
LUCI_URL:=https://github.com/i-zhirov/luci-app-trusttunnel-lite
LUCI_PKGARCH:=all

# Without this declaration a package update will OVERWRITE
# /etc/config/trusttunnel with defaults, i.e. destroy the server address, the
# password, the certificate and the selected lists, and disable the service.
# Files under /etc/config do NOT become protected automatically. Verified on a
# live OpenWrt: apk keeps a per-package list of protected files — for the stock
# dnsmasq-full it is /lib/apk/packages/dnsmasq-full.conffiles, where
# /etc/config/dhcp is listed together with its checksum.
#
# The block must come BEFORE `include luci.mk`, and this is not a matter of
# style. The last line of luci.mk calls BuildPackage, which captures the list by
# immediate assignment: `KEEP_$(1):=$(strip $(call Package/$(1)/conffiles))` in
# include/package-pack.mk. include substitutes text in place, so the capture
# happens before the parser reaches a declaration written afterwards — and the
# list freezes empty. A declaration that looks present but does not work is
# worse than its absence. The stock luci-app-amule and luci-app-alwaysonline do
# the same.
define Package/luci-app-trusttunnel-lite/conffiles
/etc/config/trusttunnel
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

# Executable bits are set EXPLICITLY rather than taken from the repository.
#
# luci.mk copies the root/ directory with `cp -pR`, i.e. it keeps the
# permissions of the source files. Development was done on Windows, where the
# file system has no executable bit, so git recorded all scripts as 100644 —
# and the init script and generators that cannot be run went into the built
# .apk. On the router this looked like: the service "does not start" with NOT A
# SINGLE line in the log, because procd cannot execute the file. There is
# almost nothing to diagnose.
#
# The defect survived to a release because on the bench I uploaded files via
# scp and did chmod +x by hand every time — my own habit was hiding it.
#
# The modes in the git index are fixed too, but they cannot be relied on alone:
# they are lost when downloading a zip archive, when transferring through a
# file system without permissions, and when working on Windows for anyone who
# rebuilds the package.
define Build/Compile
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/40-luci-trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/hotplug.d/net/40-trusttunnel
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/gen-config
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/routing
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/uci-export
	# records.sh is sourced with `.`, it does not need to be executable.
	chmod 0644 $(PKG_BUILD_DIR)/root/usr/libexec/trusttunnel/records.sh
endef

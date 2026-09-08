# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk

# Prebuilt TrustTunnel client binaries, packaged per CPU FAMILY.
#
# The vendor (TrustTunnel/TrustTunnelClient) ships ONE tarball per CPU
# family — x86_64, aarch64, armv7, mips, mipsel — not per OpenWrt target,
# so the same tarball serves every subtarget whose CPU belongs to the
# family. The binaries are statically linked (verified with `file`: no
# glibc dependency), which is what makes them run on OpenWrt's musl at all,
# and they are built for the family's lowest common denominator, so one
# binary genuinely runs on every subtarget of the family.
#
# The package is therefore built ONCE per family and labeled with the
# FAMILY arch (PKG_PKGARCH below) instead of the OpenWrt subtarget arch
# (aarch64_cortex-a53, arm_cortex-a7_neon-vfpv4, ...). apk and opkg match
# the package arch against the device's arch byte-for-byte, so the labels
# are made acceptable on the device by install.sh, which appends the family
# name to /etc/apk/arch (apk's documented "additional architectures
# specify compatible packages which are considered for installation" —
# apk(8)) and to /etc/opkg/arch.conf (opkg's arch priority list). Both
# mechanisms were verified on the real rootfs images: an x86_64 device
# with "aarch64" added to /etc/apk/arch installs an aarch64-labeled
# package, and the same holds for opkg with "arch aarch64 5" in
# arch.conf.
PKG_NAME:=trusttunnel-client
# The version is the VENDOR release, tracked here explicitly. On a vendor
# release, bump it together with the per-family PKG_HASH values below (the
# release API publishes the digests of every asset).
PKG_VERSION:=1.1.5
PKG_RELEASE:=1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=TrustTunnelOpenWrt contributors

# VENDOR_ARCH: the vendor's tarball name for this subtarget's CPU family.
# The mapping must REJECT the subtargets the vendor does not ship:
# ARMv5/ARMv6 (arm_arm926ej-s, arm_xscale, arm_fa526, ...), mips64
# (mips64_octeonplus), riscv64, powerpc, i386, loongarch64. The mips*
# patterns deliberately require the underscore: mips64_* must not match.
# The $(strip) is not decoration: backslash-newline continuations inside a
# function call become SPACES, so without it the value would be
# " aarch64" for every non-x86_64 family — and the space lands in
# PKG_SOURCE, PKG_BUILD_DIR and PKG_HASH, breaking the download and the
# build (verified on the aarch64_generic SDK).
VENDOR_ARCH := $(strip \
	$(if $(filter x86_64,$(ARCH)),x86_64, \
	$(if $(filter aarch64%,$(ARCH)),aarch64, \
	$(if $(filter arm_cortex-%,$(ARCH)),armv7, \
	$(if $(filter mips_%,$(ARCH)),mips, \
	$(if $(filter mipsel_%,$(ARCH)),mipsel,))))))
ifeq ($(VENDOR_ARCH),)
# The metadata scan (DUMP context) is target-independent and has no $(ARCH),
# so the error must only fire for a real build: without this guard the scan
# would fail and the package would silently vanish from the configuration.
ifneq ($(DUMP),1)
$(error trusttunnel-client: no vendor build for OpenWrt arch '$(ARCH)' (vendor ships only x86_64, aarch64, armv7, mips, mipsel))
endif
endif

# The package arch label is the FAMILY name (x86_64, aarch64, armv7, mips,
# mipsel) — one build per family, installable on every subtarget of the
# family once install.sh adds the family to the device's arch list. This is
# what makes the release matrix 5 archs per branch instead of ~35.
# PKGARCH (not PKG_PKGARCH) is the variable the packaging reads: it goes
# into the apk metadata (`apk mkpkg --info arch:$(PKGARCH)`), the ipk
# control file's Architecture field and the ipk file name. It must be set
# INSIDE the Package define: Package/Default overwrites it with the SDK's
# ARCH_PACKAGES when BuildPackage evaluates the defaults first.
PKG_SOURCE := trusttunnel_client-v$(PKG_VERSION)-linux-$(VENDOR_ARCH).tar.gz
PKG_SOURCE_URL := https://github.com/TrustTunnel/TrustTunnelClient/releases/download/v$(PKG_VERSION)
# SHA-256 of each family tarball, taken from the release's asset digests
# and verified locally against the downloaded files. The $(strip) is
# required for the same reason as in VENDOR_ARCH above: a leading or
# trailing space in PKG_HASH makes download.pl reject the checksum as
# unrecognized.
PKG_HASH := $(strip \
	$(if $(filter x86_64,$(VENDOR_ARCH)),759557812e7a280183f720e373b374f3fccb95758532cf8a94bea903dec2ca96, \
	$(if $(filter aarch64,$(VENDOR_ARCH)),db17e4e2f9712de269b8e3196491324487fe9077c223e50b602668d888b5e81f, \
	$(if $(filter armv7,$(VENDOR_ARCH)),c361557e88b9d9edbd5bf280c85c7e3cc3038928ed5559225cc59a010730cc8d, \
	$(if $(filter mips,$(VENDOR_ARCH)),49988f84687f73a88bef5c1732ac953f961414c0427fd30353a918c4990da1d2, \
	$(if $(filter mipsel,$(VENDOR_ARCH)),9d78643ab330d8ea5450fc25f38921b637f7f3701419528fc08d07eee074ba93,))))))

# The archive's single top-level directory is named after the SOURCE
# (trusttunnel_client-v$(PKG_VERSION)-linux-$(VENDOR_ARCH)), not after the
# package, and the unpack goes to that directory. PKG_BUILD_DIR therefore
# points at the extraction directory — the standard idiom for tarballs with
# a foreign top-level name. The override must come BEFORE package.mk is
# included: its `PKG_BUILD_DIR ?=` default and STAMP_BUILT (an immediate
# assignment) both capture the value at include time.
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_SOURCE:%.tar.gz=%)

# A plain (non-LuCI) package must include package.mk explicitly: LuCI
# packages get it transitively from luci.mk, this one does not.
include $(INCLUDE_DIR)/package.mk

define Build/Compile
	# Prebuilt binaries; nothing to compile.
endef

define Package/trusttunnel-client
	SECTION:=net
	CATEGORY:=Network
	TITLE:=TrustTunnel client binaries
	URL:=https://github.com/TrustTunnel/TrustTunnelClient
	# Statically linked: no dependencies.
	DEPENDS:=
	# The family arch label (see the comment above PKG_SOURCE). Set here,
	# not as a global: Package/Default runs first and would overwrite a
	# global value with the SDK's own ARCH_PACKAGES.
	PKGARCH:=$(VENDOR_ARCH)
endef

# The binaries install to /opt/trusttunnel_client, the path the LuCI backend
# and the init script already hardcode. Installing to the same path also
# takes over cleanly from a previous script-based install (install.sh used
# to fetch the same files with the vendor's own installer).
define Package/trusttunnel-client/install
	$(INSTALL_DIR) $(1)/opt/trusttunnel_client
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/trusttunnel_client $(1)/opt/trusttunnel_client/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/setup_wizard $(1)/opt/trusttunnel_client/
	# The .sig files and the LICENSE travel with the binaries: the vendor
	# signs every release (see the vendor's VERIFY_RELEASES.md) and the
	# public key is published on keys.openpgp.org, so a user can verify
	# what they run. PKG_HASH already pins the tarball; the signatures are
	# carried for transparency, not relied upon.
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/trusttunnel_client.sig $(1)/opt/trusttunnel_client/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/setup_wizard.sig $(1)/opt/trusttunnel_client/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/opt/trusttunnel_client/
endef

$(eval $(call BuildPackage,trusttunnel-client))

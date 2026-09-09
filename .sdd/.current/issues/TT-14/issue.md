# Issue TT-14: package Makefile

- **Status**: Approved
- **PRD**: `../../prd.md`
- **Blocked by**: none (independent; may run in parallel)
- **Effort**: S–M
- **Files**: `packages/luci-app-trusttunnel/Makefile`

## Context

The package Makefile was inherited (the `PKG_*`/`LUCI_*` metadata block
and the conffiles-before-`include luci.mk` pattern are inherited; the
tag-derived version logic and comments are fork work). It declares the
package and its build behavior.

## Contract to reproduce

- `# SPDX-License-Identifier: GPL-2.0-only` — replaced at the license flip
  (TT-22); keep as-is for now.
- `include $(TOPDIR)/rules.mk`.
- `PKG_NAME:=luci-app-trusttunnel`.
- `PKG_VERSION` derived at build time: `git describe --tags --abbrev=0`
  with the leading `v` stripped; fallback `1.0.13` when not on a tag
  (keep the fallback equal to the last released version; release.yml
  asserts tag builds carry the tag's version).
- `PKG_RELEASE:=1`; `PKG_LICENSE:=GPL-2.0-only` (flip later);
  `PKG_MAINTAINER:=TrustTunnelOpenWrt contributors`.
- `LUCI_TITLE:=LuCI support for TrustTunnel (full tunnel)`;
  `LUCI_DESCRIPTION` (runs the client, routes LAN traffic through the
  tunnel with a killswitch and a LuCI interface).
- `LUCI_DEPENDS:=+trusttunnel-client +luci-base +ip-full +nftables +curl
  +ucode-mod-math` (changed on main 2026-09-09: `kmod-tun` and
  `ca-bundle` moved to `trusttunnel-client`'s own `DEPENDS` — the app
  gets them transitively and must NOT repeat them; `+nftables` added —
  `nft` is called directly by `routing` and the diagnostics).
- `LUCI_URL:=https://github.com/i-zhirov/trusttunnel-openwrt`;
  `LUCI_PKGARCH:=all`.
- The dependency declarations are guarded by `tests/test_deps.sh`
  (original fork test added on main 2026-09-09 — NOT rewritten): it
  asserts the app declares trusttunnel-client/luci-base/ip-full/nftables/
  curl/ucode-mod-math, the client declares kmod-tun/ca-bundle, the app
  does NOT repeat them, the real scripts invoke the binaries, and
  install.sh's apk/opkg add lists match.
- `Package/luci-app-trusttunnel/conffiles` declaring
  `/etc/config/trusttunnel` — the block MUST be placed BEFORE
  `include luci.mk` (luci.mk's `BuildPackage` captures the conffiles list
  by immediate assignment; a declaration after the include freezes the
  list empty and updates would overwrite user settings).
- `Build/Compile` (placed AFTER `include luci.mk` — luci.mk defines its own
  empty `Build/Compile` that would clobber an earlier definition)
  explicitly `chmod 0755` the init script, uci-defaults, hotplug,
  `gen-config`, `routing`, `uci-export` (`records.sh` stays 0644
  — sourced, not executed). This is the workaround for the git index
  losing the executable bit.

## Acceptance criteria

- [ ] SDK build (22.03 + 25.12, x86-64) produces
      `luci-app-trusttunnel-<tag>-r1.apk` / `luci-app-trusttunnel_<tag>_all.ipk`
      with the tag-derived version.
- [ ] Conffiles ordering is preserved (verify the built package's
      `.conffiles` lists `/etc/config/trusttunnel`).
- [ ] `chmod` workaround present (files land with the right modes in the
      .ipk/.apk).
- [ ] Depends list matches the contract.

## How to verify

1. Local SDK build for both package managers (or rely on the CI gate once
   TT-19 lands).
2. Inspect the built package metadata: `apk info -a` / `opkg info`.
3. Install into a rootfs and confirm `/etc/config/trusttunnel` survives
   a package upgrade.

## Notes

- This Makefile is a thin declarative file; the rewrite is a
  re-expression of the metadata, not a behavioral change.

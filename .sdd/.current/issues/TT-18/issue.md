# Issue TT-18: install.sh

- **Status**: Planned
- **PRD**: `../../prd.md`
- **Blocked by**: TT-14 (package metadata the installer installs)
- **Effort**: M–L
- **Files**: `install.sh`

## Context

`install.sh` was inherited from the upstream opkg-era installer and heavily
rewritten by the fork (apk support, PM detection, arch allowlist, Pages
repo layout, service-state restore) — but the skeleton (environment
checks, opkg feed/key setup, install sequence) is still inherited
expression.

## Contract to reproduce

- `#!/bin/sh`; `set -e`; `say()`/`die()` helpers.
- Environment override `TT_REPO_URL` (default
  `https://i-zhirov.github.io/trusttunnel-openwrt`); key URLs derived:
  `<url>/apk/key-build.pub`, `<url>/opkg/opkg-key.pub`.
- OpenWrt-only check: `/etc/openwrt_release` must exist (sourced).
- PM detection: `apk` (requires major version ≥ 25) else `opkg` (requires
  major ≥ 22); neither → die.
- CPU check via `uname -m` ∈ {x86_64/x86-64/x64/amd64, aarch64/arm64,
  armv7l/armv8l, mips, mipsel}; anything else (ARMv5/6, mips64, riscv64,
  powerpc, i386…) → die BEFORE any changes.
- Repository setup:
  - apk: fetch `<url>/apk/key-build.pub` to `/etc/apk/keys/trusttunnel.pub`
    via wget; `apk --print-arch`; write `<url>/apk/<arch>/packages.adb`
    into `/etc/apk/repositories.d/trusttunnel.list`.
  - opkg: append `src/gz trusttunnel <url>/opkg` to
    `/etc/opkg/customfeeds.conf` (idempotent); fetch
    `<url>/opkg/opkg-key.pub` to `/etc/opkg/keys/trusttunnel.pub`; compute
    the usign fingerprint and copy to `/etc/opkg/keys/<fingerprint>` —
    BOTH copies are kept (the stable-name copy is `uninstall.sh`'s
    removal handle and the release pipeline creates both).
- `apk update` / `opkg update`; install `kmod-tun ip-full nftables curl
  ca-bundle` (nftables added on main 2026-09-09; kmod-tun and ca-bundle
  are runtime deps of the client binaries, the rest serve the app).
- Remember `was_running` (`/etc/init.d/trusttunnel running`); stop the
  service if installed.
- Install `luci-app-trusttunnel`, then optional `luci-i18n-trusttunnel-ru`
  (warning on failure, not fatal); tripwire check that
  `trusttunnel-client` is installed.
- `rpcd restart`; then run the uci-defaults script IMMEDIATELY (added on
  main 2026-09-09 — the routing-profile seed and the domains.direct
  migration belong to this install/update, not the next boot): if
  `-x /etc/uci-defaults/40-luci-trusttunnel`, run it silenced, with a
  warning fallback message when it fails ("warning: the default routing
  profile was not created; run /etc/uci-defaults/40-luci-trusttunnel
  manually"); then if `was_running=1`, start the service back up.
  Service stays disabled on first install. The repo entry persists
  intentionally for future `apk upgrade`/`opkg upgrade`.
- Executable bit `100755`; shellcheck-clean (`-s sh`).

## Acceptance criteria

- [ ] Fresh install on apk (25.12) and opkg (22.03/23.05/24.10) rootfs
      images installs the package set, leaves the service disabled, and
      configures the repo/keys exactly as today.
- [ ] Unsupported CPU dies early with a clear message, changing nothing.
- [ ] Reinstall preserves a running service (was_running restore).
- [ ] The release.yml verification steps (which mirror this script) pass.
- [ ] `shellcheck -s sh` clean.

## How to verify

1. `shellcheck -s sh`.
2. Run against the release workflow's rootfs images (apk 25.12, opkg
   23.05/24.10) and diff the resulting `/etc/apk/keys`,
   `/etc/apk/repositories.d`, `/etc/opkg/customfeeds.conf`,
   `/etc/opkg/keys` state against the current script's behavior.
3. Negative: stub `uname -m` to `riscv64` → dies before any writes.

## Notes

- The install/uninstall pair shares the repo-layout contract (URLs, key
  file names, `src/gz trusttunnel` line); `uninstall.sh` is original and
  NOT rewritten — the two must stay consistent, so implement against the
  same contract text.

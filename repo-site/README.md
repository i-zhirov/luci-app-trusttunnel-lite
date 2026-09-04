# luci-app-trusttunnel-lite — package repositories

This site hosts the package repositories that
[install.sh](https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)
configures on the router:

- [apk/](apk/) — the apk repository for OpenWrt 25.12+ (apk): the `.apk`
  packages, the signed index `packages.adb` and `key-build.pub`.
  Repository URL for the router:
  `https://i-zhirov.github.io/luci-app-trusttunnel-lite/apk/packages.adb`
- [opkg/](opkg/) — the opkg repository for OpenWrt 22.03–24.10 (opkg):
  the `.ipk` packages, the signed index `Packages` / `Packages.gz` /
  `Packages.sig` and `opkg-key.pub`.
  Feed URL for the router:
  `https://i-zhirov.github.io/luci-app-trusttunnel-lite/opkg`

Currently serving the packages from the `__TAG__` release.

The GitHub
[releases](https://github.com/i-zhirov/luci-app-trusttunnel-lite/releases)
carry the same package files for manual download.

## Installing

```sh
sh -c "$(wget -O - https://raw.githubusercontent.com/i-zhirov/luci-app-trusttunnel-lite/main/install.sh)"
```

## Updating

Package updates are the standard package-manager commands:

```sh
# apk (25.12+):
apk update && apk upgrade
# opkg (22.03–24.10):
opkg update && opkg upgrade
```

Re-running the installer refreshes the client binary and the signing keys.

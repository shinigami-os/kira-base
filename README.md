# kira-base
> Minimal bootstrap layer for Kira Linux.

Builds the core root filesystem from source against musl libc. Produces a minimal initramfs containing only what is needed to reach a shell and run flux, nothing more. All higher-level packages (shell, networking, desktop, services) are flux-managed and installed at system-install time by `kira-installer`.

## Architecture

kira-base follows a strict **core vs flux-managed** boundary:

**Core (this repo : never flux-managed):**
- musl libc, BusyBox (static), runit, flux, eudev, dhcpcd binary, curl (static) + CA bundle
- Minimal `runit/1`/`runit/2` stage scripts
- Core runit services: eudev, getty-tty1, udev-input-trigger, i915 (oneshot), syslog, console

**Flux-managed (installed by kira-installer, not this repo):**
- Shell: `zsh`, `zsh-plugins`, `kira-branding`
- Seat/login: `kira-seat`, `kira-login`
- Networking: `kira-net`
- Session bus: `kira-session-bus`
- Desktop: `kira-desktop-swayFX`

## Stack

| Component | Package | Version |
|---|---|---|
| libc | musl | 1.2.6 |
| Init | runit | 2.3.1 |
| Userland | BusyBox (static) | 1.37.0 |
| Device management | eudev | 3.2.14 |
| DHCP | dhcpcd | 10.3.2 (binary only : service via kira-net) |
| TLS | LibreSSL | 4.3.1 |
| Package manager | flux | 26.06 |

## Build

Requires: `gcc`, `make`, `wget`, `git`, `cpio`, `gzip`, `gperf`, `pkg-config`, `libmount-dev`

Clone the Shinigami kernel alongside this repo first:

```sh
git clone https://github.com/shinigami-os/shinigami ../shinigami
```

Copy the Kira project minisign public key into `config/etc/flux/flux.pub` before building.

Then build:

```sh
make          # builds minimal core sysroot + initramfs
make qemu     # boots in QEMU (drops to BusyBox shell : expected)
```

To rebuild without re-downloading sources:

```sh
make soft-clean && make
```

> **Note:** The initramfs produced here boots to a bare BusyBox shell with flux available. This is intentional : it's the bootstrap layer only. To get a usable system, use `kira-installer` to produce a live ISO and run the installer.

## Repository Layout

```
kira-base/
  Makefile              build system (core packages only : no TIER, no packages.stamp)
  runit/                stage scripts: 1 (early boot), 2 (supervision), 3 (shutdown)
  services/             core runit service directories (/etc/sv/)
    console/            serial console
    eudev/              device management
    getty-tty1/         tty1 login -> zsh-login -> sway autostart (on desktop tier)
    i915/               oneshot: modprobe i915 (desktop tier only, checks /etc/kira-tier)
    syslog/             system logging
    udev-input-trigger/ oneshot: sets ID_INPUT_* properties via udevadm test
  config/
    etc/
      flux/             flux default config and public key
      default/grub      GRUB cmdline defaults (rdinit=init)
    busybox.config      BusyBox build config
  build/                GITIGNORED: sources, stamps, sysroot, initramfs
```

## Boot Sequence

```
kernel → runit-init (PID 1)
  └── stage 1: mount proc/sys/dev/shm, set hostname, loopback, flux-bootstrap
  └── stage 2: runsvdir /etc/sv
       ├── eudev               device management
       ├── i915                modprobe i915 (desktop tier only)
       ├── udev-input-trigger  set ID_INPUT_* on input devices (oneshot)
       ├── getty-tty1          -> zsh-login -> kira-start-swayFX (desktop) or /bin/sh (server)
       └── [flux-managed services installed by kira-installer]
  └── stage 3: shutdown cleanup
```

## Tier detection

`/etc/kira-tier` contains either `server` or `desktop`, written by `kira-installer` at install time (and written into the live ISO environment by `kira-installer`'s Makefile). Core services that behave differently per tier (currently only `i915`) read this file directly — no build-time branching.

## Versioning

Same release-based scheme as `flux`: `YY.MM`, optionally `-N` for a hotfix release in that month (`26.06`, then `26.06-1`). `KIRA_BASE_VERSION` in the Makefile is the single source of truth; it gets baked into every built sysroot as `/etc/kira-release` (`KIRA_BASE_VERSION=26.06`). 

**Updating an installed system: `flux base-update`.** Unlike flux (a single binary, atomically replaceable) kira-base ships musl, BusyBox, and runit : things every running process and PID 1 itself depend on continuously, so it can't rebuild itself from source on an installed system (no cross-toolchain or kernel tree there) or hot-swap its core the way flux hot-swaps its own binary. Instead:
- `make` here produces `build/rootfs.tar.gz` (the full sysroot) and `build/initramfs.cpio.gz`.
- `scripts/push-base-release.sh <version>` signs both with minisign and pushes them to `cache.oxoghost.dev` alongside the package cache.
- `sysroot.stamp` also writes `/etc/kira-update-manifest` into the sysroot, classifying every core file as `live` (safe to replace immediately : musl, BusyBox, curl, the CA bundle, the bootstrap `dhcpcd`), `restart:<service>` (replaced then that service restarted; e.g. `eudev`), or `boot` (replaced on disk but only takes effect next reboot : `runit-init`/`runsvdir`/`runsv`/`sv`/`chpst`/`svlogd`, the `runit/1,2,3` stage scripts, since they're already running and a file replace doesn't change what's in memory).
- On an installed Kira system, `flux update` checks `kira-base`'s tags against `/etc/kira-release` and tells you to run `flux base-update` if there's a newer one (never runs it automatically). `flux base-update` downloads, verifies, and applies the manifest, including the new initramfs, then reports whether a reboot is needed.

This relies on the minimal-initramfs + `switch_root` boot model (`runit/1-initramfs`: a tiny busybox-only initramfs that mounts the real root and switches into it) being in place, since that's what makes the initramfs a small, cleanly-swappable artifact separate from the running system.

## License

GPL-2.0

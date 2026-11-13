# kira-base
> Minimal bootstrap layer for Kira Linux.

Builds the core root filesystem from source against musl libc. Produces a minimal initramfs containing only what is needed to reach a shell and run flux, nothing more. All higher-level packages (shell, networking, desktop, services) are flux-managed and installed at system-install time by `kira-installer`.

## Architecture

kira-base follows a strict **core vs flux-managed** boundary:

**Core (this repo : never flux-managed):**
- musl libc, BusyBox (static), runit, flux, eudev, dhcpcd binary, curl (static) + CA bundle
- Minimal `runit/1`/`runit/2` stage scripts
- Core runit services: eudev, eudev-trigger, udev-input-trigger, getty-tty1, syslog, console

**Flux-managed (installed by kira-installer, not this repo):**
- Shell: `zsh`, `zsh-plugins`, `kira-branding`
- Seat/login (server tier): `kira-seat`, `kira-login`
- Login manager (desktop tier): `kira-greetd`, which is `greetd` + `cage` hosting a Quickshell login screen (a qylock theme), with the eww Kira Login as its fallback
- Networking: `kira-net` (NetworkManager, with wpa_supplicant as its Wi-Fi backend)
- Session bus: `kira-session-bus`
- Desktop: `kira-the-line` (Kira's own), `kira-desktop-sleex`

## Stack

| Component | Package | Version |
|---|---|---|
| libc | musl | 1.2.6 |
| Init | runit | 2.3.1 |
| Userland | BusyBox (static) | 1.38.0 |
| Device management | eudev | 3.2.14 |
| Module autoload | kmod (libkmod only, built for eudev) | 34.2 |
| DHCP | dhcpcd | 10.5.2 (binary only : service via kira-net) |
| TLS | LibreSSL | 4.3.1 |
| Package manager | flux | cloned fresh from the `flux` repo's default branch at build time, always the latest commit |

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

> **Note:** The initramfs produced here boots to a bare BusyBox shell with flux available. This is intentional : it's the bootstrap layer only. To get a usable system, use `kira-installer`, whose one ISO boots straight into the installer.

## Repository Layout

```
kira-base/
  Makefile              build system (core packages only : no TIER, no packages.stamp)
  runit/                stage scripts: 1 (early boot), 2 (supervision), 3 (shutdown)
  services/             core runit service directories (/etc/sv/)
    console/            serial console
    eudev/              device management
    eudev-trigger/      oneshot: udevadm trigger --action=add + settle (coldplug at boot)
    udev-input-trigger/ oneshot: sets ID_INPUT_* properties via udevadm test
    getty-tty1/         baseline tty1 login (server tier; desktop tier disables this via greetd's post-install)
    syslog/             system logging
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
       ├── eudev-trigger       udevadm trigger --action=add + settle (oneshot, coldplug)
       ├── udev-input-trigger  set ID_INPUT_* on input devices (oneshot)
       ├── getty-tty1          baseline tty1 login (disabled by greetd on desktop tier)
       └── [flux-managed services installed by kira-installer: greetd, dbus, polkitd,
            NetworkManager, elogind, seatd, etc.]
  └── stage 3: shutdown cleanup
```

The oneshot services (`eudev-trigger`, `udev-input-trigger`) end their `run` script with `touch <service>/down` and then `sv d <service>`. The `sv d` is what keeps them down: runit only reads `down` when it starts a service, so without it the service is restarted as soon as it exits (for `eudev-trigger` that meant a full device coldplug every second or so).

Historical note: an earlier revision shipped a dedicated `i915` oneshot service to work around the Intel graphics driver not loading at boot. The real cause was `udevadm trigger` defaulting to `--action=change` (which never fires kmod-load rules); fixing that in `eudev-trigger` (now using `--action=add`) made the dedicated service redundant, and it was removed. That alone wasn't the whole story though: eudev was still being built with `--disable-kmod` (no libkmod in the cross sysroot), so it had no kmod-load rule to fire regardless of trigger action. `runit/1`'s explicit `modprobe` list for keyboard/NIC/GPU/wifi/bluetooth drivers was the interim workaround for that. eudev now builds libkmod itself first and links against it (`--enable-kmod`), so coldplugged hardware gets a real driver automatically; the explicit list stays as a safety net for now rather than being removed sight unseen.

## Tier detection

`/etc/kira-tier` contains `server`, `desktop-the-line` or `desktop-sleex` on an installed system, written by the installer from the system you picked. No core service in this repo reads it : the tier only matters to flux-managed packages/services installed by the installer (e.g. whether `greetd` and a DE package get installed at all).

## Versioning

Same release-based scheme as `flux`: `YY.MM`, optionally `-N` for a hotfix release in that month (e.g. current: `26.11-1`). `KIRA_BASE_VERSION` in the Makefile is the single source of truth; it gets baked into every built sysroot as `/etc/kira-release` (`KIRA_BASE_VERSION=26.11-1`).

**Updating an installed system: `flux sys upgrade base`.** Unlike flux (a single binary, atomically replaceable) kira-base ships musl, BusyBox, and runit : things every running process and PID 1 itself depend on continuously, so it can't rebuild itself from source on an installed system (no cross-toolchain or kernel tree there) or hot-swap its core the way flux hot-swaps its own binary. Instead:
- `make` here produces `build/rootfs.tar.xz` (the full sysroot) and `build/initramfs.cpio.gz`.
- `sysroot.stamp` also writes `/etc/kira-update-manifest` into the sysroot, classifying every core file as `live` (safe to replace immediately : musl, BusyBox, curl, the CA bundle, the bootstrap `dhcpcd`), `restart:<service>` (replaced then that service restarted; e.g. `eudev`), or `boot` (replaced on disk but only takes effect next reboot : `runit-init`/`runsvdir`/`runsv`/`sv`/`chpst`/`svlogd`, the `runit/1,2,3` stage scripts, since they're already running and a file replace doesn't change what's in memory).
- On an installed Kira system, `flux sys check` checks `kira-base`'s tags against `/etc/kira-release` and tells you to run `flux sys upgrade base` if there's a newer one (never runs it automatically). `flux sys upgrade base` downloads, verifies, and applies the manifest, including the new initramfs, then reports whether a reboot is needed.

The initramfs hands over to the program named by `init=` on the kernel command line (the last one wins, like in the kernel) and to `/sbin/runit-init` when there is none or it is missing from the new root, so `init=/bin/sh` works as a repair shell and tools that wrap init (such as kokuin's `kokuin-init`) can sit in front of runit.

This relies on the minimal-initramfs + `switch_root` boot model (`runit/1-initramfs`: a tiny busybox-only initramfs that mounts the real root and switches into it) being in place, since that's what makes the initramfs a small, cleanly-swappable artifact separate from the running system.

## Build notes

The Makefile carries no comments; the reasons for its less obvious steps are here.

- **`ssp.stamp`.** Kira's gcc always asks the linker for `libssp_nonshared`, which the `musl-gcc` wrapper cannot find (it only searches the sysroot). The stamp adds an empty stub to the link path, outside the sysroot. Every component built with the wrapper depends on it.
- **eudev and libkmod.** libtool would link the host's `/usr/lib/libkmod.so` (built against OpenSSL 3) through kmod's `.la` file, so the eudev step removes that file first and eudev links the sysroot's own libkmod. eudev's own modules are only autoloaded because of this (see the comment in `runit/1`).
- **polkit's PAM file.** Without `/etc/pam.d/polkit-1`, PAM falls back to `/etc/pam.d/other`, which Kira does not have, and every polkit authentication failed (pkexec, the desktop's password dialogs).
- **File ownership.** Files made by plain `cp` and `printf` in the sysroot step belong to whoever ran make, and `--numeric-owner` would bake that uid into the image, where it becomes whichever user has the same uid on the booting machine. Everything is normalized to root at the end, and `/etc/shadow` keeps the image's own `shadow` group, by number (a bare `shadow` would resolve against the build host's group file, and `unix_chkpwd` could not read `/etc/shadow` on the installed system).
- **The initramfs modules.** The storage controllers (AHCI, virtio-blk) and the CD-ROM layer are modules, and the initramfs has no udev, so it loads them itself; without them the live boot cannot see a SATA or virtio disk, only what is built into the kernel (NVMe).
- **`/sbin/init`.** It points at runit's `runit-init`. BusyBox's `init` applet would otherwise be what the kernel, and tools that wrap init such as kokuin's `kokuin-init`, start by default. `runit/1` repairs the link on systems installed before this.

## License

GPL-2.0

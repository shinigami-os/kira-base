# kira-base
> Base system for Kira Linux.

Build scripts, runit init stages, service definitions, and core system configuration for the Kira Linux base layer. Builds a complete root filesystem from source against musl libc.

## Stack

| Component | Package | Version |
|-----------|---------|---------|
| libc | musl | 1.2.6 |
| Init | runit | 2.3.1 |
| Userland | BusyBox (static) | 1.37.0 |
| Device management | eudev | 3.2.14 |
| DHCP | dhcpcd | 10.3.2 |
| TLS | LibreSSL | 4.3.1 |
| Remote access | OpenSSH | 10.3p1 |
| Shell | ZSH | 5.9 |
| Package manager | flux | — |

## Build

Requires: `gcc`, `make`, `wget`, `git`, `cpio`, `gzip`, `gperf`, `pkg-config`, `libmount-dev`

Clone the Shinigami kernel and flux alongside this repo first:

```sh
git clone https://github.com/shinigami-os/shinigami ../shinigami
git clone https://github.com/shinigami-os/flux ../flux
```

Copy the Kira project minisign public key into `config/etc/flux/flux.pub` before building.

Then build:

```sh
make                          # builds sysroot
sudo make build/stamps/packages.stamp  # installs flux packages (requires root)
make build/initramfs.cpio.gz  # packages initramfs
make qemu                     # boots
```

SSH into the running system:

```sh
ssh -o StrictHostKeyChecking=no root@localhost -p 2222
```

To rebuild without re-downloading sources:

```sh
make soft-clean && make
```

## Repository Layout

```
kira-base/
  Makefile          build system
  runit/            stage scripts: 1 (early boot), 2 (supervision), 3 (shutdown)
  services/         runit service directories (/etc/sv/)
  config/
    etc/            static config files installed to /etc/
      flux/         flux default config
      zsh/            ZSH default config (zshrc, p10k.zsh)
      ssh/            sshd config
    busybox.config  BusyBox build config
  build/            GITIGNORED: sources, stamps, sysroot, initramfs
```

## Boot Sequence

```
kernel → runit-init (PID 1)
  └── stage 1: mount proc/sys/dev, set hostname, loopback
  └── stage 2: runsvdir /etc/sv
       ├── eudev      device management
       ├── dhcpcd     DHCP on eth0
       └── sshd       remote access
  └── stage 3: shutdown cleanup
```

## License

GPL-2.0
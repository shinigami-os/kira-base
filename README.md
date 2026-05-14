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

## Build

Requires: `gcc`, `make`, `wget`, `git`, `cpio`, `gzip`, `gperf`, `pkg-config`, `libmount-dev`

Clone the Shinigami kernel alongside this repo first:

```sh
git clone https://github.com/shinigami-os/shinigami ../shinigami
```

Then build:

```sh
make          # build full sysroot
make initramfs  # package as initramfs
make qemu     # boot in QEMU
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
    zsh/            ZSH default config (zshrc, p10k.zsh)
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
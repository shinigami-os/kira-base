#!/bin/sh
# flux-bootstrap.sh - Register sysroot packages in flux database on first boot
# Idempotent: skips packages already registered.

FLUX_DB=/var/lib/flux/installed
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

register() {
    local name=$1
    local version=$2
    local dir="$FLUX_DB/$name"

    [ -d "$dir" ] && return 0

    mkdir -p "$dir"
    cat > "$dir/info" << EOF
name = $name
version = $version
install_date = $DATE
auto_installed = 0
EOF
    touch "$dir/files"
}

# Core system
register musl          1.2.6
register busybox       1.37.0
register runit         2.3.1
register eudev         3.2.14
register dhcpcd        10.3.2
register zlib          1.3.2
register libressl      4.3.1
register openssh       10.3p1
register ncurses       6.6
register zsh           5.9
register curl          8.20.0
register zstd          1.5.7
register libsodium     1.0.20
register minisign      0.12
register flux          0.1.0
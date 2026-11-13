#!/bin/sh
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

register musl       @MUSL_V@
register busybox    @BUSYBOX_V@
register runit      @RUNIT_V@
register eudev      @EUDEV_V@
register dhcpcd     @DHCPCD_V@
register zlib       @ZLIB_V@
register libressl   @LIBRESSL_V@
register curl       @CURL_V@
register zstd       @ZSTD_V@
register libsodium  @LIBSODIUM_V@
register minisign   @MINISIGN_V@
register flux       @FLUX_V@
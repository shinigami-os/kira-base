SYSROOT = $(CURDIR)/build/sysroot
INITRAMFS_ROOT = $(CURDIR)/build/initramfs-root
KERNEL_VERSION := $(shell [ -f ../shinigami/include/config/kernel.release ] && cat ../shinigami/include/config/kernel.release || echo "unknown")
# release-based, matches flux's scheme: YY.MM, optionally -N for a hotfix. Tag the repo with the same string.
KIRA_BASE_VERSION = 26.06-1
SOURCE_DIR = build/sources
MUSL_V = 1.2.6
BUSYBOX_V = 1.37.0
RUNIT_V = 2.3.1
EUDEV_V = 3.2.14
DHCPCD_V = 10.3.2
ZLIB_V = 1.3.2
LIBRESSL_V = 4.3.1
CURL_V = 8.20.0
ZSTD_V = 1.5.7
MINISIGN_V = 0.12
LIBSODIUM_V = 1.0.20
CA_CERTIFICATES_V = 2026-05-14
# you need to clone shinigami first (clone it in the parent directory of this Makefile), from https://github.com/shinigami-os/shinigami
SHINIGAMI = $(CURDIR)/../shinigami

MUSL_CC = $(SYSROOT)/usr/bin/musl-gcc

DOWNLOADS = \
	build/sources/musl-$(MUSL_V).tar.gz \
	build/sources/busybox-$(BUSYBOX_V).tar.bz2 \
	build/sources/runit-$(RUNIT_V).tar.gz

SYSROOT_BASE = proc sys dev dev/pts etc etc/runit etc/sv bin sbin usr usr/bin usr/lib usr/include lib var var/run var/log home root tmp run run/udev lib/udev var/lib/dhcpcd usr/sbin var/empty etc/ssh etc/skel etc/flux var/lib/flux var/lib/flux/installed var/cache/flux etc/ssl/certs var/lib/polkit-1 run/dbus var/run/dbus run/user dev/shm
.PHONY: all clean build sysroot sources initramfs qemu soft-clean

all: build/initramfs.cpio.gz build/rootfs.tar.gz

clean:
	rm -rf build

soft-clean:
	rm -rf build/stamps build/initramfs.cpio.gz build/initramfs-root build/rootfs.tar.gz
	sudo rm -rf $(SYSROOT)

#! Directories
build/stamps/:
	mkdir -p build/stamps

build/sources/:
	mkdir -p build/sources

build/sysroot/:
	mkdir -p $(SYSROOT)
	mkdir -p $(SYSROOT)/etc/runit
	mkdir -p $(SYSROOT)/etc/sv

#! Downloads
build/sources/musl-$(MUSL_V).tar.gz: | build/sources/
	wget -O $@ https://musl.libc.org/releases/musl-$(MUSL_V).tar.gz

build/sources/runit-$(RUNIT_V).tar.gz: | build/sources/
	wget -O $@ http://smarden.org/runit/runit-$(RUNIT_V).tar.gz

build/sources/busybox-$(BUSYBOX_V).tar.bz2: | build/sources/
	wget -O $@ https://busybox.net/downloads/busybox-$(BUSYBOX_V).tar.bz2

build/sources/eudev-$(EUDEV_V).tar.gz: | build/sources/
	wget -O $@ https://github.com/eudev-project/eudev/releases/download/v$(EUDEV_V)/eudev-$(EUDEV_V).tar.gz

build/sources/dhcpcd-$(DHCPCD_V).tar.xz: | build/sources/
	wget -O $@ https://github.com/NetworkConfiguration/dhcpcd/releases/download/v$(DHCPCD_V)/dhcpcd-$(DHCPCD_V).tar.xz

build/sources/zlib-$(ZLIB_V).tar.gz: | build/sources/
	wget -O $@ https://github.com/madler/zlib/releases/download/v$(ZLIB_V)/zlib-$(ZLIB_V).tar.gz

build/sources/libressl-$(LIBRESSL_V).tar.gz: | build/sources/
	wget -O $@ https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$(LIBRESSL_V).tar.gz

build/sources/flux/: | build/sources/
	git clone --depth=1 https://github.com/shinigami-os/flux $@

build/sources/curl-$(CURL_V).tar.gz: | build/sources/
	wget -O $@ https://curl.se/download/curl-$(CURL_V).tar.gz

build/sources/zstd-$(ZSTD_V).tar.gz: | build/sources/
	wget -O $@ https://github.com/facebook/zstd/releases/download/v$(ZSTD_V)/zstd-$(ZSTD_V).tar.gz

build/sources/libsodium-$(LIBSODIUM_V).tar.gz: | build/sources/
	wget -O $@ https://download.libsodium.org/libsodium/releases/libsodium-$(LIBSODIUM_V).tar.gz

build/sources/minisign-$(MINISIGN_V).tar.gz: | build/sources/
	wget -O $@ https://github.com/jedisct1/minisign/archive/refs/tags/$(MINISIGN_V).tar.gz

build/sources/ca-certificates-$(CA_CERTIFICATES_V).pem: | build/sources/
	wget -O $@ https://curl.se/ca/cacert-$(CA_CERTIFICATES_V).pem



#! Extracts
build/sources/musl-$(MUSL_V)/: build/sources/musl-$(MUSL_V).tar.gz
	tar xzf $< -C build/sources

build/sources/busybox-$(BUSYBOX_V)/: build/sources/busybox-$(BUSYBOX_V).tar.bz2
	tar xjf $< -C build/sources

build/sources/runit-$(RUNIT_V)/: build/sources/runit-$(RUNIT_V).tar.gz
	tar xzf $< -C build/sources
	mv build/sources/admin/runit-$(RUNIT_V) build/sources/runit-$(RUNIT_V)
	rm -rf build/sources/admin

build/sources/eudev-$(EUDEV_V)/: build/sources/eudev-$(EUDEV_V).tar.gz
	tar xzf $< -C build/sources

build/sources/dhcpcd-$(DHCPCD_V)/: build/sources/dhcpcd-$(DHCPCD_V).tar.xz
	tar xJf $< -C build/sources

build/sources/zlib-$(ZLIB_V)/: build/sources/zlib-$(ZLIB_V).tar.gz
	tar xzf $< -C build/sources

build/sources/libressl-$(LIBRESSL_V)/: build/sources/libressl-$(LIBRESSL_V).tar.gz
	tar xzf $< -C build/sources

build/sources/curl-$(CURL_V)/: build/sources/curl-$(CURL_V).tar.gz
	tar xzf $< -C build/sources

build/sources/zstd-$(ZSTD_V)/: build/sources/zstd-$(ZSTD_V).tar.gz
	tar xzf $< -C build/sources

build/sources/libsodium-$(LIBSODIUM_V)/: build/sources/libsodium-$(LIBSODIUM_V).tar.gz
	tar xzf $< -C build/sources

build/sources/minisign-$(MINISIGN_V)/: build/sources/minisign-$(MINISIGN_V).tar.gz
	tar xzf $< -C build/sources


#! Compile
build/stamps/musl.stamp: build/sources/musl-$(MUSL_V)/ | build/stamps/
	cd $(<D) && \
	./configure --prefix=$(SYSROOT)/usr --syslibdir=$(SYSROOT)/lib && \
	make && \
	make install
	sed -i 's|-dynamic-linker $(SYSROOT)/lib/ld-musl-x86_64.so.1|-dynamic-linker /lib/ld-musl-x86_64.so.1|' $(SYSROOT)/usr/lib/musl-gcc.specs
	ln -sf ../usr/lib/libc.so $(SYSROOT)/lib/ld-musl-x86_64.so.1

	touch $@

build/stamps/busybox.stamp: build/sources/busybox-$(BUSYBOX_V)/ build/stamps/kernel-headers.stamp | build/stamps/
	cp $(CURDIR)/config/busybox.config $(<D)/.config
	cd $(<D) && \
	make CC=$(MUSL_CC) && \
	make install CC=$(MUSL_CC) CONFIG_PREFIX=$(SYSROOT)
	
	touch $@

build/stamps/runit.stamp: build/sources/runit-$(RUNIT_V)/ | build/stamps/
	echo "$(MUSL_CC)" > $(<D)/src/conf-cc
	echo "$(MUSL_CC)" > $(<D)/src/conf-ld
	cd $(<D)/src && make -j$(nproc)
	install -m 755 \
		$(<D)/src/runit \
		$(<D)/src/runit-init \
		$(<D)/src/sv \
		$(<D)/src/chpst \
		$(<D)/src/runsv \
		$(<D)/src/runsvdir \
		$(<D)/src/svlogd \
		$(SYSROOT)/sbin/
	
	touch $@

build/stamps/eudev.stamp: build/sources/eudev-$(EUDEV_V)/ build/stamps/musl.stamp | build/stamps/
	cd $(<D) && \
	./configure \
		--host=x86_64-linux-musl \
		--prefix=/usr \
		--sysconfdir=/etc \
		--with-rootrundir=/run/udev \
		--disable-manpages \
		--disable-hwdb \
		--disable-blkid \
		--disable-selinux \
		--disable-kmod \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/lib -L$(SYSROOT)/usr/lib" && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)
	find $(SYSROOT) -type l | while read link; do \
		target=$$(readlink "$$link"); \
		case "$$target" in \
			$(SYSROOT)/*) \
				newtarget=$${target#$(SYSROOT)}; \
				ln -sf "$$newtarget" "$$link"; \
				;; \
		esac; \
	done

	touch $@

build/stamps/dhcpcd.stamp: build/sources/dhcpcd-$(DHCPCD_V)/ build/stamps/eudev.stamp | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--sysconfdir=/etc \
		--dbdir=/var/lib/dhcpcd \
		--libexecdir=/usr/lib/dhcpcd \
		--runstatedir=/run \
		--without-dev \
		--host=x86_64-linux-musl \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/lib -L$(SYSROOT)/usr/lib" && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)

	touch $@

build/stamps/zlib.stamp: build/sources/zlib-$(ZLIB_V)/ | build/stamps/
	cd $(<D) && \
	CC=$(MUSL_CC) ./configure --prefix=/usr && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)

	touch $@

build/stamps/libressl.stamp: build/sources/libressl-$(LIBRESSL_V)/ | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/lib -L$(SYSROOT)/usr/lib" && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)
	rm -f $(SYSROOT)/usr/lib/libssl.la \
		$(SYSROOT)/usr/lib/libcrypto.la \
		$(SYSROOT)/usr/lib/libtls.la
	
	touch $@

build/stamps/curl.stamp: build/sources/curl-$(CURL_V)/ build/stamps/musl.stamp build/stamps/zlib.stamp build/stamps/libressl.stamp build/sources/ca-certificates-$(CA_CERTIFICATES_V).pem | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		--with-openssl=$(SYSROOT)/usr \
		--with-zlib=$(SYSROOT)/usr \
		--with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
		--without-libpsl \
		--without-brotli \
		--without-nghttp2 \
		--disable-ldap \
		--disable-shared \
		--enable-static \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/usr/lib" && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)

	mkdir -p $(SYSROOT)/etc/ssl/certs
	cp build/sources/ca-certificates-$(CA_CERTIFICATES_V).pem $(SYSROOT)/etc/ssl/certs/ca-certificates.crt
	
	touch $@

build/stamps/libsodium.stamp: build/sources/libsodium-$(LIBSODIUM_V)/ build/stamps/musl.stamp | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		--disable-shared \
		--enable-static \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/usr/lib" && \
	make -j$(nproc) && \
	make install DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/minisign.stamp: build/sources/minisign-$(MINISIGN_V)/ build/stamps/libsodium.stamp build/stamps/musl.stamp | build/stamps/
	mkdir -p $(<D)/build
	cd $(<D)/build && cmake \
		-DCMAKE_C_COMPILER=$(MUSL_CC) \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DSODIUM_INCLUDE_DIR=$(SYSROOT)/usr/include \
		-DSODIUM_LIBRARY=$(SYSROOT)/usr/lib/libsodium.a \
		.. && \
	make -j$(nproc) && make install DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/zstd.stamp: build/sources/zstd-$(ZSTD_V)/ build/stamps/musl.stamp | build/stamps/
	cd $(<D) && \
	make -j$(nproc) CC=$(MUSL_CC) PREFIX=/usr && \
	make install PREFIX=/usr DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/flux.stamp: build/sources/flux/ build/stamps/musl.stamp | build/stamps/
	make -j$(nproc) CC=$(MUSL_CC) -C $(<D)
	install -Dm755 $(<D)/build/flux $(SYSROOT)/usr/bin/flux
	touch $@

build/stamps/sysroot.stamp: build/stamps/musl.stamp build/stamps/busybox.stamp build/stamps/runit.stamp build/stamps/eudev.stamp build/stamps/dhcpcd.stamp build/stamps/flux.stamp build/stamps/curl.stamp build/stamps/libsodium.stamp build/stamps/minisign.stamp build/stamps/zstd.stamp scripts/flux-bootstrap.sh scripts/fetch runit/1 runit/2 runit/3 $(wildcard config/etc/*) $(wildcard config/etc/**/*) $(wildcard config/lib/modules/**/*) | build/sysroot/
	mkdir -p $(addprefix $(SYSROOT)/, $(SYSROOT_BASE))
	chmod 700 $(SYSROOT)/root
	chmod 1777 $(SYSROOT)/tmp
	chmod 755 $(SYSROOT)/run
	chmod 755 $(SYSROOT)/var/empty

	install -m 755 runit/1 runit/2 runit/3 $(SYSROOT)/etc/runit
	cp -a services/* $(SYSROOT)/etc/sv
	rm -f $(SYSROOT)/etc/sv/*/down
	cp -r config/etc/* $(SYSROOT)/etc/
	cp -r config/lib/* $(SYSROOT)/lib/
	cp -Pf \
		/opt/musl-cross/x86_64-linux-musl/lib/libgcc_s.so \
		/opt/musl-cross/x86_64-linux-musl/lib/libgcc_s.so.1 \
		/opt/musl-cross/x86_64-linux-musl/lib/libstdc++.so \
		/opt/musl-cross/x86_64-linux-musl/lib/libstdc++.so.6 \
		/opt/musl-cross/x86_64-linux-musl/lib/libstdc++.so.6.0.28 \
		$(SYSROOT)/usr/lib/
	$(MAKE) -C $(SHINIGAMI) LLVM=1 -j$(nproc)
	sudo $(MAKE) -C $(SHINIGAMI) LLVM=1 INSTALL_MOD_PATH=$(SYSROOT) modules_install
	sudo /sbin/depmod -b $(SYSROOT) $(KERNEL_VERSION)
	mkdir -p $(SYSROOT)/etc/ssl/certs
	mkdir -p $(SYSROOT)/run/dbus
	mkdir -p $(SYSROOT)/var/run/dbus
	install -m 755 scripts/flux-bootstrap.sh $(SYSROOT)/usr/bin/flux-bootstrap.sh
	install -m 755 scripts/fetch $(SYSROOT)/usr/bin/fetch
	chmod 600 $(SYSROOT)/etc/shadow
	chmod +x $(SYSROOT)/etc/runit/*
	chmod +x $(SYSROOT)/etc/sv/*/run
	chmod +x $(SYSROOT)/etc/sv/*/finish 2>/dev/null || true
	touch $(SYSROOT)/var/log/lastlog
	touch $(SYSROOT)/var/log/wtmp
	touch $(SYSROOT)/run/utmp
	printf '/bin/sh\n' > $(SYSROOT)/etc/shells
	mkdir -p $(SYSROOT)/run/user
	chmod 755 $(SYSROOT)/run/user
	printf 'KIRA_BASE_VERSION=%s\n' "$(KIRA_BASE_VERSION)" > $(SYSROOT)/etc/kira-release
	printf 'live /lib/libc.so\nlive /bin/busybox\nlive /usr/bin/curl\nlive /etc/ssl/certs/ca-certificates.crt\nlive /usr/sbin/dhcpcd\nrestart:eudev /usr/sbin/udevd\nboot /sbin/runit\nboot /sbin/runit-init\nboot /sbin/sv\nboot /sbin/chpst\nboot /sbin/runsv\nboot /sbin/runsvdir\nboot /sbin/svlogd\nboot /etc/runit/1\nboot /etc/runit/2\nboot /etc/runit/3\n' > $(SYSROOT)/etc/kira-update-manifest

	touch $@

build/stamps/kernel-headers.stamp: | build/stamps/
	make -j$(nproc) -C $(SHINIGAMI) headers_install INSTALL_HDR_PATH=$(SYSROOT)/usr
	touch $@

#! Targets
build/initramfs.cpio.gz: build/stamps/sysroot.stamp runit/1-initramfs | build/
	rm -rf $(INITRAMFS_ROOT)
	mkdir -p $(INITRAMFS_ROOT)/bin \
			$(INITRAMFS_ROOT)/sbin \
	        $(INITRAMFS_ROOT)/lib \
	        $(INITRAMFS_ROOT)/proc \
	        $(INITRAMFS_ROOT)/sys \
	        $(INITRAMFS_ROOT)/dev \
	        $(INITRAMFS_ROOT)/newroot
	mkdir -p $(INITRAMFS_ROOT)/cdrom
	cp $(SYSROOT)/lib/ld-musl-x86_64.so.1 $(INITRAMFS_ROOT)/lib/
	cp $(SYSROOT)/bin/busybox $(INITRAMFS_ROOT)/bin/busybox
	for cmd in sh cat grep tr cut sleep mkdir basename tar; do \
		ln -sf busybox $(INITRAMFS_ROOT)/bin/$$cmd; \
	done
	ln -sf ../bin/busybox $(INITRAMFS_ROOT)/sbin/mount
	ln -sf ../bin/busybox $(INITRAMFS_ROOT)/sbin/umount
	ln -sf ../bin/busybox $(INITRAMFS_ROOT)/sbin/switch_root
	cp runit/1-initramfs $(INITRAMFS_ROOT)/init
	chmod +x $(INITRAMFS_ROOT)/init
	cd $(INITRAMFS_ROOT) && find . | cpio -oH newc --owner root:root | gzip > ../initramfs.cpio.gz

build/rootfs.tar.gz: build/stamps/sysroot.stamp | build/
	@echo "[kira-base] packaging root filesystem..."
	tar -czpf $@ --numeric-owner -C $(SYSROOT) .

qemu: build/initramfs.cpio.gz
	qemu-system-x86_64 \
		-kernel $(SHINIGAMI)/arch/x86/boot/bzImage \
		-initrd build/initramfs.cpio.gz \
		-append "console=ttyS0 rdinit=/init" \
		-nographic \
		-m 512M \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device e1000,netdev=net0

SYSROOT = $(CURDIR)/build/sysroot
SOURCE_DIR = build/sources
MUSL_V = 1.2.6
BUSYBOX_V = 1.37.0
RUNIT_V = 2.3.1
EUDEV_V = 3.2.14
DHCPCD_V = 10.3.2
ZLIB_V = 1.3.2
LIBRESSL_V = 4.3.1
OPENSSH_V = 10.3p1
NCURSES_V = 6.6
ZSH_V = 5.9
CURL_V = 8.20.0
ZSTD_V = 1.5.7
MINISIGN_V = 0.12
LIBSODIUM_V = 1.0.20
# you need to clone shinigami first (clone it in the parent directory of this Makefile), from https://github.com/shinigami-os/shinigami
SHINIGAMI = $(CURDIR)/../shinigami

MUSL_CC = $(SYSROOT)/bin/musl-gcc

DOWNLOADS = \
	build/sources/musl-$(MUSL_V).tar.gz \
	build/sources/busybox-$(BUSYBOX_V).tar.bz2 \
	build/sources/runit-$(RUNIT_V).tar.gz

SYSROOT_BASE = proc sys dev dev/pts etc etc/runit etc/sv bin sbin usr usr/bin usr/lib usr/include lib var var/log var/run home root tmp run run/udev lib/udev var/lib/dhcpcd usr/sbin var/empty etc/ssh etc/skel etc/flux var/lib/flux var/lib/flux/installed var/cache/flux etc/ssl/certs

.PHONY: all clean build sysroot sources initramfs qemu soft-clean

all: build/stamps/sysroot.stamp

clean:
	rm -rf build

soft-clean:
	rm -rf build/stamps build/initramfs.cpio.gz

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

build/sources/openssh-$(OPENSSH_V).tar.gz: | build/sources/
	wget -O $@ https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$(OPENSSH_V).tar.gz

build/sources/ncurses-$(NCURSES_V).tar.gz: | build/sources/
	wget -O $@ https://ftp.gnu.org/gnu/ncurses/ncurses-$(NCURSES_V).tar.gz

build/sources/zsh-$(ZSH_V).tar.xz: | build/sources/
	wget -O $@ https://sourceforge.net/projects/zsh/files/zsh/$(ZSH_V)/zsh-$(ZSH_V).tar.xz

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

build/sources/openssh-$(OPENSSH_V)/: build/sources/openssh-$(OPENSSH_V).tar.gz
	tar xzf $< -C build/sources

build/sources/ncurses-$(NCURSES_V)/: build/sources/ncurses-$(NCURSES_V).tar.gz
	tar xzf $< -C build/sources

build/sources/zsh-$(ZSH_V)/: build/sources/zsh-$(ZSH_V).tar.xz
	tar xJf $< -C build/sources

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
	./configure --prefix=$(SYSROOT) --syslibdir=$(SYSROOT)/lib && \
	make && \
	make install
	sed -i 's|-dynamic-linker $(SYSROOT)/lib/ld-musl-x86_64.so.1|-dynamic-linker /lib/ld-musl-x86_64.so.1|' $(SYSROOT)/lib/musl-gcc.specs
	ln -sf libc.so $(SYSROOT)/lib/ld-musl-x86_64.so.1

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
	cd $(<D)/src && make
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
		CFLAGS="-I$(SYSROOT)/include" \
		LDFLAGS="-L$(SYSROOT)/lib" && \
	make && \
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
		CFLAGS="-I$(SYSROOT)/include -I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/lib -L$(SYSROOT)/usr/lib" && \
	make && \
	make install DESTDIR=$(SYSROOT)

	touch $@

build/stamps/zlib.stamp: build/sources/zlib-$(ZLIB_V)/ | build/stamps/
	cd $(<D) && \
	CC=$(MUSL_CC) ./configure --prefix=/usr && \
	make && \
	make install DESTDIR=$(SYSROOT)

	touch $@

build/stamps/libressl.stamp: build/sources/libressl-$(LIBRESSL_V)/ | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/include -I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/lib -L$(SYSROOT)/usr/lib" && \
	make && \
	make install DESTDIR=$(SYSROOT)
	rm -f $(SYSROOT)/usr/lib/libssl.la \
		$(SYSROOT)/usr/lib/libcrypto.la \
		$(SYSROOT)/usr/lib/libtls.la
	
	touch $@

build/stamps/openssh.stamp: build/sources/openssh-$(OPENSSH_V)/ build/stamps/musl.stamp build/stamps/zlib.stamp build/stamps/libressl.stamp | build/stamps/
	cd $(<D) && \
	./configure \
		--host=x86_64-linux-musl \
		--prefix=/usr \
		--sysconfdir=/etc/ssh \
		--with-privsep-path=/var/empty \
		--with-ssl-dir=$(SYSROOT)/usr \
		--with-zlib=$(SYSROOT)/usr \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/usr/lib" && \
	make && \
	make install DESTDIR=$(SYSROOT)

	touch $@

build/stamps/ncurses.stamp: build/sources/ncurses-$(NCURSES_V)/ build/stamps/musl.stamp | build/stamps/
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		--with-shared \
		--enable-widec \
		--without-tests \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include" \
		LDFLAGS="-L$(SYSROOT)/usr/lib" && \
	make && \
	make install DESTDIR=$(SYSROOT)
	ln -sf libncursesw.so $(SYSROOT)/usr/lib/libncurses.so
	ln -sf libncursesw.so $(SYSROOT)/usr/lib/libtinfo.so
	printf '#pragma once\n#include <ncurses.h>\n' > $(SYSROOT)/usr/include/termcap.h
	
	touch $@

build/stamps/zsh.stamp: build/sources/zsh-$(ZSH_V)/ build/stamps/musl.stamp build/stamps/ncurses.stamp | build/stamps/
	sed -i 's/^static char \*boolcodes\[\]/const char *const boolcodes[]/' $(<D)/Src/Modules/termcap.c
	sed -i 's/^static const char \*const boolcodes\[\]/const char *const boolcodes[]/' $(<D)/Src/Modules/termcap.c
	sed -i '/#include.*zsh\.mdh/a #include <termcap.h>' $(<D)/Src/prompt.c
	rm -f $(<D)/config.cache
	cp /usr/share/misc/config.sub $(<D)/config.sub
	cp /usr/share/misc/config.guess $(<D)/config.guess
	cd $(<D) && \
	./configure \
		--prefix=/usr \
		--host=x86_64-linux-musl \
		--sysconfdir=/etc/zsh \
		--with-term-lib=ncursesw \
		--disable-gdbm \
		--disable-pcre \
		--enable-dynamic \
		CC=$(MUSL_CC) \
		CFLAGS="-I$(SYSROOT)/usr/include -DNCURSES_WIDECHAR=1" \
		LDFLAGS="-L$(SYSROOT)/usr/lib" \
		LIBS="-lncursesw -ldl"
	sed -i 's|/\* #undef HAVE_TERM_H \*/|#define HAVE_TERM_H 1|' $(<D)/config.h
	sed -i 's|/\* #undef ZSH_HAVE_TERM_H \*/|#define ZSH_HAVE_TERM_H 1|' $(<D)/config.h
	sed -i 's|/\* #undef HAVE_TERMCAP_H \*/|#define HAVE_TERMCAP_H 1|' $(<D)/config.h
	sed -i 's|/\* #undef HAVE_TGOTO \*/|#define HAVE_TGOTO 1|' $(<D)/config.h
	sed -i 's|/\* #undef DYNAMIC \*/|#define DYNAMIC 1|' $(<D)/config.h
	sed -i 's|/\* The extension used for dynamically loaded modules\. \*/|/* The extension used for dynamically loaded modules. */\n#define MODULE_EXT ".so"|' $(<D)/config.h
	sed -i '/name=zsh\/main\|name=zsh\/db\/gdbm/!s/link=static/link=dynamic/g' $(<D)/config.modules
	sed -i '/name=zsh\/db\/gdbm/!s/link=no auto=yes load=no/link=dynamic auto=yes load=yes/g' $(<D)/config.modules
	cd $(<D) && make && make install DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/zsh-plugins.stamp: | build/stamps/ build/sources/
	mkdir -p $(SYSROOT)/usr/share/zsh/plugins
	wget -O build/sources/zsh-autosuggestions.tar.gz https://github.com/zsh-users/zsh-autosuggestions/archive/refs/tags/v0.7.1.tar.gz
	tar xzf build/sources/zsh-autosuggestions.tar.gz -C build/sources
	mv build/sources/zsh-autosuggestions-0.7.1 $(SYSROOT)/usr/share/zsh/plugins/zsh-autosuggestions

	wget -O build/sources/zsh-syntax-highlighting.tar.gz https://github.com/zsh-users/zsh-syntax-highlighting/archive/refs/tags/0.8.0.tar.gz
	tar xzf build/sources/zsh-syntax-highlighting.tar.gz -C build/sources
	mv build/sources/zsh-syntax-highlighting-0.8.0 $(SYSROOT)/usr/share/zsh/plugins/zsh-syntax-highlighting

	wget -O build/sources/powerlevel10k.tar.gz https://github.com/romkatv/powerlevel10k/archive/refs/tags/v1.20.0.tar.gz
	tar xzf build/sources/powerlevel10k.tar.gz -C build/sources
	mv build/sources/powerlevel10k-1.20.0 $(SYSROOT)/usr/share/zsh/plugins/powerlevel10k

	mkdir -p $(SYSROOT)/usr/share/zsh/plugins/git
	wget -O $(SYSROOT)/usr/share/zsh/plugins/git/git.plugin.zsh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/git/git.plugin.zsh

	touch $@

build/stamps/curl.stamp: build/sources/curl-$(CURL_V)/ build/stamps/musl.stamp build/stamps/zlib.stamp build/stamps/libressl.stamp | build/stamps/
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
	make && \
	make install DESTDIR=$(SYSROOT)
	
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
	make && \
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
	make && make install DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/zstd.stamp: build/sources/zstd-$(ZSTD_V)/ build/stamps/musl.stamp | build/stamps/
	cd $(<D) && \
	make CC=$(MUSL_CC) PREFIX=/usr && \
	make install PREFIX=/usr DESTDIR=$(SYSROOT)
	
	touch $@

build/stamps/flux.stamp: build/sources/flux/ build/stamps/musl.stamp | build/stamps/
	make CC=$(MUSL_CC) -C $(<D)
	install -Dm755 $(<D)/build/flux $(SYSROOT)/usr/bin/flux
	touch $@

build/stamps/sysroot.stamp: build/stamps/musl.stamp build/stamps/busybox.stamp build/stamps/runit.stamp build/stamps/eudev.stamp build/stamps/dhcpcd.stamp build/stamps/openssh.stamp build/stamps/zsh.stamp build/stamps/zsh-plugins.stamp build/stamps/flux.stamp build/stamps/curl.stamp build/stamps/libsodium.stamp build/stamps/minisign.stamp build/stamps/zstd.stamp scripts/flux-bootstrap.sh runit/1 runit/2 runit/3 $(wildcard services/*/run) $(wildcard config/etc/*) | build/sysroot/
	mkdir -p $(addprefix $(SYSROOT)/, $(SYSROOT_BASE))
	chmod 700 $(SYSROOT)/root
	chmod 1777 $(SYSROOT)/tmp
	chmod 755 $(SYSROOT)/run
	chmod 755 $(SYSROOT)/var/empty
	
	install -m 755 runit/1 runit/2 runit/3 $(SYSROOT)/etc/runit
	cp -a services/* $(SYSROOT)/etc/sv
	cp -r config/etc/* $(SYSROOT)/etc/
	mkdir -p $(SYSROOT)/etc/ssl/certs
	cp /etc/ssl/certs/ca-certificates.crt $(SYSROOT)/etc/ssl/certs/
	install -m 644 config/zsh/zshrc $(SYSROOT)/root/.zshrc
	install -m 644 config/zsh/p10k.zsh $(SYSROOT)/root/.p10k.zsh
	install -m 644 config/zsh/zshrc $(SYSROOT)/etc/skel/.zshrc
	install -m 644 config/zsh/p10k.zsh $(SYSROOT)/etc/skel/.p10k.zsh
	install -m 755 scripts/flux-bootstrap.sh $(SYSROOT)/usr/bin/flux-bootstrap.sh
	chmod 600 $(SYSROOT)/etc/shadow
	chmod +x $(SYSROOT)/etc/runit/*
	chmod +x $(SYSROOT)/usr/bin/*
	chmod +x $(SYSROOT)/etc/sv/*/run
	chmod +x $(SYSROOT)/etc/sv/*/finish 2>/dev/null || true
	touch $(SYSROOT)/var/log/lastlog
	touch $(SYSROOT)/var/log/wtmp

	touch $@

build/stamps/kernel-headers.stamp: | build/stamps/
	make -C $(SHINIGAMI) headers_install INSTALL_HDR_PATH=$(SYSROOT)
	touch $@

#! Targets
build/initramfs.cpio.gz: build/stamps/sysroot.stamp
	cd $(SYSROOT) && find . | cpio -oH newc --owner root:root | gzip > $(CURDIR)/build/initramfs.cpio.gz

qemu: build/initramfs.cpio.gz
	qemu-system-x86_64 \
		-kernel $(SHINIGAMI)/arch/x86/boot/bzImage \
		-initrd build/initramfs.cpio.gz \
		-append "console=ttyS0 rdinit=/sbin/runit-init" \
		-nographic \
		-m 8G \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device e1000,netdev=net0

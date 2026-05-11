SYSROOT = $(CURDIR)/build/sysroot
SOURCE_DIR = build/sources
MUSL_V = 1.2.6
BUSYBOX_V = 1.37.0
RUNIT_V = 2.3.1
EUDEV_V = 3.2.14
DHCPCD_V = 10.3.2
# you need to clone shinigami first (clone it in the parent directory of this Makefile), from https://github.com/shinigami-os/shinigami
SHINIGAMI = $(CURDIR)/../shinigami

MUSL_CC = $(SYSROOT)/bin/musl-gcc

DOWNLOADS = \
	build/sources/musl-$(MUSL_V).tar.gz \
	build/sources/busybox-$(BUSYBOX_V).tar.bz2 \
	build/sources/runit-$(RUNIT_V).tar.gz

SYSROOT_BASE = proc sys dev dev/pts etc etc/runit etc/sv bin sbin usr usr/bin usr/lib usr/include lib var var/log var/run home root tmp run run/udev lib/udev var/lib/dhcpcd usr/sbin

.PHONY: all clean build sysroot sources initramfs qemu

all: build/stamps/sysroot.stamp

clean:
	rm -rf build

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

build/stamps/sysroot.stamp: build/stamps/musl.stamp build/stamps/busybox.stamp build/stamps/runit.stamp build/stamps/eudev.stamp build/stamps/dhcpcd.stamp runit/1 runit/2 runit/3 $(wildcard services/*/run) $(wildcard config/etc/*) | build/sysroot/
	mkdir -p $(addprefix $(SYSROOT)/, $(SYSROOT_BASE))
	chmod 700 $(SYSROOT)/root
	chmod 1777 $(SYSROOT)/tmp
	chmod 755 $(SYSROOT)/run
	
	install -m 755 runit/1 runit/2 runit/3 $(SYSROOT)/etc/runit
	cp -a services/* $(SYSROOT)/etc/sv
	cp -r config/etc/* $(SYSROOT)/etc/
	chmod 600 $(SYSROOT)/etc/shadow
	chmod +x $(SYSROOT)/etc/runit/*
	chmod +x $(SYSROOT)/etc/sv/*/run
	chmod +x $(SYSROOT)/etc/sv/*/finish 2>/dev/null || true

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
		-m 512M

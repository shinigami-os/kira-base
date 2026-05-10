SYSROOT = $(CURDIR)/build/sysroot
SOURCE_DIR = build/sources
MUSL_V = 1.2.6
BUSYBOX_V = 1.37.0
RUNIT_V = 2.3.1
SHINIGAMI = ../shinigami # you need to clone shinigami first (clone it in the parent directory of this Makefile), from https://github.com/shinigami-os/shinigami

MUSL_CC = $(SYSROOT)/bin/musl-gcc

DOWNLOADS = \
	build/sources/musl-$(MUSL_V).tar.gz \
	build/sources/busybox-$(BUSYBOX_V).tar.bz2 \
	build/sources/runit-$(RUNIT_V).tar.gz

RUNIT_SRC = src/runit src/runit-init src/sv src/chpst src/runsv src/runsvdir src/svlogd

SYSROOT_BASE = proc sys dev dev/pts etc bin usr usr/bin usr/lib usr/include lib var var/log var/run home root tmp run

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


#! Extracts
build/sources/musl-$(MUSL_V)/: build/sources/musl-$(MUSL_V).tar.gz
	tar xzf $< -C build/sources

build/sources/busybox-$(BUSYBOX_V)/: build/sources/busybox-$(BUSYBOX_V).tar.bz2
	tar xjf $< -C build/sources

build/sources/runit-$(RUNIT_V)/: build/sources/runit-$(RUNIT_V).tar.gz
	tar xzf $< -C build/sources
	mv build/sources/admin/runit-$(RUNIT_V) build/sources/runit-$(RUNIT_V)
	rm -rf build/sources/admin


#! Compile
build/stamps/musl.stamp: build/sources/musl-$(MUSL_V)/ | build/stamps/
	cd $(<D) && \
	./configure --prefix=$(SYSROOT) --syslibdir=$(SYSROOT)/lib && \
	make && \
	make install

	touch $@

build/stamps/busybox.stamp: build/sources/busybox-$(BUSYBOX_V)/ | build/stamps/
	cd $(<D) && \
	make defconfig CC=$(MUSL_CC) && \
	make CC=$(MUSL_CC) && \
	make install CC=$(MUSL_CC) CONFIG_PREFIX=$(SYSROOT)

	touch $@

build/stamps/runit.stamp: build/sources/runit-$(RUNIT_V)/ | build/stamps/
	cd $(<D) && \
	echo "$(MUSL_CC)" > src/conf-cc && \
	echo "$(MUSL_CC)" > src/conf-ld && \
	make && \
	mkdir -p $(SYSROOT)/sbin/ && \
	install -m 755 $(RUNIT_SRC) $(SYSROOT)/sbin/

	touch $@

build/stamps/sysroot.stamp: build/stamps/musl.stamp build/stamps/busybox.stamp build/stamps/runit.stamp | build/sysroot/
	mkdir -p $(addprefix $(SYSROOT)/, $(SYSROOT_BASE))
	chmod 700 $(SYSROOT)/root
	chmod 1777 $(SYSROOT)/tmp
	chmod 755 $(SYSROOT)/run
	
	install -m 755 runit/1 runit/2 runit/3 $(SYSROOT)/etc/runit
	cp -a services/* $(SYSROOT)/etc/sv
	chmod +x $(SYSROOT)/etc/runit/*
	chmod +x $(SYSROOT)/etc/sv/*/run

	touch $@

initramfs: build/stamps/sysroot.stamp
	cd $(SYSROOT) && find . | cpio -oH newc | gzip > ../../initramfs.cpio.gz

qemu: build/initramfs.cpio.gz
	qemu-system-x86_64 \
		-kernel $(SHINIGAMI)/arch/x86/boot/bzImage \
		-initrd build/initramfs.cpio.gz \
		-append "console=ttyS0 rdinit=/sbin/runit-init" \
		-nographic \
		-m 512M
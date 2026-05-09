SYSROOT = build/sysroot
SOURCE_DIR = build/sources
MUSL_V = 1.2.6
BUSYBOX_V = 1.37.0
RUNIT_V = 2.3.1

MUSL_CC = $(SYSROOT)/bin/musl-gcc

DOWNLOADS = \
	build/sources/musl-$(MUSL_V).tar.gz \
	build/sources/busybox-$(BUSYBOX_V).tar.bz2 \
	build/sources/runit-$(RUNIT_V).tar.gz

.PHONY: all clean build sysroot sources 

clean:
	rm -rf build

all: build/stamps/sysroot.stamp

#! Directories
build/stamps/:
	mkdir -p build/stamps

build/sources/:
	mkdir -p build/sources

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
	install -m 755 src/runit src/runit-init src/sv src/chpst src/runsv src/runsvdir src/svlogd $(SYSROOT)/sbin/

	touch $@

build/stamps/sysroot.stamp: build/stamps/musl.stamp build/stamps/busybox.stamp build/stamps/runit.stamp
	# install config, runit stages, services
	touch $@
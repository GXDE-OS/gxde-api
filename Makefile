PREFIX = /usr
GOBUILD_DIR = gobuild
GOPKG_PREFIX = pkg.deepin.io/dde/api
GOPATH_DIR = gopath
GO111MODULE = off
GOSITE_DIR = ${PREFIX}/share/gocode
GOPATH="/usr/share/gocode-gxde/:/usr/share/gocode/:${CURDIR}/${GOPATH_DIR}"
libdir = /lib
SYSTEMD_LIB_DIR = ${libdir}
SYSTEMD_SERVICE_DIR = ${SYSTEMD_LIB_DIR}/systemd/system/
GOBUILD = env GOPATH="${CURDIR}/${GOBUILD_DIR}:${GOPATH}" go build

LIBRARIES = \
    thumbnails \
    themes \
    theme_thumb\
    dxinput \
    drandr \
    soundutils \
    lang_info \
    i18n_dependent \
    session \
    language_support \
	userenv \
    powersupply

BINARIES =  \
    device \
    graphic \
    locale-helper \
    lunar-calendar \
    thumbnailer \
    hans2pinyin \
    cursor-helper \
    gtk-thumbnailer \
    sound-theme-player \
    deepin-shutdown-sound \
    dde-open \
	adjust-grub-theme \
    image-blur \
    image-blur-helper

all: build-binary build-dev ts-to-policy

prepare:
	@if [ ! -d ${GOBUILD_DIR}/src/${GOPKG_PREFIX} ]; then \
		mkdir -p ${GOBUILD_DIR}/src/$(dir ${GOPKG_PREFIX}); \
		ln -sf ../../../.. ${GOBUILD_DIR}/src/${GOPKG_PREFIX}; \
	fi

ts:
	deepin-policy-ts-convert policy2ts misc/polkit-action/com.deepin.api.locale-helper.policy.in misc/ts/com.deepin.api.locale-helper.policy
	deepin-policy-ts-convert policy2ts misc/polkit-action/com.deepin.api.device.unblock-bluetooth-devices.policy.in misc/ts/com.deepin.api.device.unblock-bluetooth-devices.policy

ts-to-policy:
	deepin-policy-ts-convert ts2policy misc/polkit-action/com.deepin.api.locale-helper.policy.in misc/ts/com.deepin.api.locale-helper.policy misc/polkit-action/com.deepin.api.locale-helper.policy
	deepin-policy-ts-convert ts2policy misc/polkit-action/com.deepin.api.device.unblock-bluetooth-devices.policy.in misc/ts/com.deepin.api.device.unblock-bluetooth-devices.policy misc/polkit-action/com.deepin.api.device.unblock-bluetooth-devices.policy

out/bin/%:
	${GOBUILD} -o $@  ${GOPKG_PREFIX}/${@F}

# Install go packages
build-dep:
	go get github.com/disintegration/imaging
	go get gopkg.in/check.v1
	go get github.com/linuxdeepin/go-x11-client

build-binary: prepare $(addprefix out/bin/, ${BINARIES})

install-binary:
	mkdir -pv ${DESTDIR}${PREFIX}${libdir}/deepin-api
	cp out/bin/* ${DESTDIR}${PREFIX}${libdir}/deepin-api/

	mkdir -pv ${DESTDIR}${PREFIX}/bin
	cp out/bin/dde-open ${DESTDIR}${PREFIX}/bin
	rm ${DESTDIR}${PREFIX}${libdir}/deepin-api/dde-open

	mkdir -pv ${DESTDIR}${PREFIX}/share/dbus-1/system.d
	cp misc/conf/*.conf ${DESTDIR}${PREFIX}/share/dbus-1/system.d/

	mkdir -pv ${DESTDIR}${PREFIX}/share/dbus-1/services
	cp -v misc/services/*.service ${DESTDIR}${PREFIX}/share/dbus-1/services/

	mkdir -pv ${DESTDIR}${PREFIX}/share/dbus-1/system-services
	cp -v misc/system-services/*.service ${DESTDIR}${PREFIX}/share/dbus-1/system-services/

	mkdir -pv ${DESTDIR}${PREFIX}/share/polkit-1/actions
	cp misc/polkit-action/*.policy ${DESTDIR}${PREFIX}/share/polkit-1/actions/

	mkdir -pv ${DESTDIR}/var/lib/polkit-1/localauthority/10-vendor.d
	cp misc/polkit-localauthority/*.pkla ${DESTDIR}/var/lib/polkit-1/localauthority/10-vendor.d/

	mkdir -pv ${DESTDIR}${PREFIX}/share/gxde-api
	cp -R misc/data ${DESTDIR}${PREFIX}/share/gxde-api

	mkdir -pv ${DESTDIR}${SYSTEMD_SERVICE_DIR}
	cp -R misc/systemd/system/*.service ${DESTDIR}${SYSTEMD_SERVICE_DIR}

	mkdir -pv ${DESTDIR}${PREFIX}/share/icons/hicolor
	cp -R misc/icons/* ${DESTDIR}${PREFIX}/share/icons/hicolor

	mkdir -pv ${DESTDIR}/boot/grub/themes/deepin-fallback
	cp -R misc/grub-theme-fallback/* ${DESTDIR}/boot/grub/themes/deepin-fallback
	cp misc/data/grub-themes/deepin/background.origin.jpg ${DESTDIR}/boot/grub/themes/deepin-fallback/background.jpg

build-dev: prepare
	${GOBUILD} $(addprefix ${GOPKG_PREFIX}/, ${LIBRARIES})

install/lib/%:
	mkdir -pv ${DESTDIR}${GOSITE_DIR}/src/${GOPKG_PREFIX}
	cp -R ${CURDIR}/${GOBUILD_DIR}/src/${GOPKG_PREFIX}/${@F} ${DESTDIR}${GOSITE_DIR}/src/${GOPKG_PREFIX}

install-dev: ${addprefix install/lib/, ${LIBRARIES}}

install: install-binary install-dev

clean:
	rm -rf out/bin gobuild out obj-x86_64-linux-gnu/

rebuild: clean build

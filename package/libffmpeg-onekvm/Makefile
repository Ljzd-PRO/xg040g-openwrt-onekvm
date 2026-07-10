include $(TOPDIR)/rules.mk

PKG_NAME:=ffmpeg-onekvm
PKG_VERSION:=6.1.4
PKG_RELEASE:=1

PKG_SOURCE:=ffmpeg-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://ffmpeg.org/releases/
PKG_HASH:=a231e3d5742c44b1cdaebfb98ad7b6200d12763e0b6db9e1e2c5891f2c083a18
PKG_BUILD_DIR:=$(BUILD_DIR)/ffmpeg-$(PKG_VERSION)

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-2.0-or-later LGPL-2.1-or-later LGPL-3.0-or-later
PKG_LICENSE_FILES:=COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 COPYING.LGPLv3
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1
PKG_CONFIG_DEPENDS:=CONFIG_BUILD_PATENTED

include $(INCLUDE_DIR)/package.mk

define Package/libffmpeg-onekvm
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Focused FFmpeg runtime for One-KVM software encoding
  URL:=https://ffmpeg.org/
  DEPENDS:=+libatomic +libpthread +libstdcpp +libvpx +libx264 +libx265 @BUILD_PATENTED
  CONFLICTS:=libffmpeg-mini libffmpeg-full libffmpeg-custom libffmpeg-audio-dec
endef

define Package/libffmpeg-onekvm/description
  FFmpeg avcodec/avutil shared libraries with only the MJPEG decoder and the
  libx264, libx265, libvpx VP8 and libvpx VP9 software encoders enabled. It
  intentionally contains no RKMPP or other hardware acceleration backend.
endef

REAL_CPU_TYPE:=$(call qstrip,$(firstword $(subst +, ,$(CONFIG_CPU_TYPE))))

FFMPEG_CONFIGURE:= \
	CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) $(FPIC)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	./configure \
	--enable-cross-compile \
	--cross-prefix="$(TARGET_CROSS)" \
	--arch="$(ARCH)" \
	$(if $(REAL_CPU_TYPE),--cpu=$(REAL_CPU_TYPE),) \
	--target-os=linux \
	--prefix=/usr \
	--pkg-config=pkg-config \
	--enable-shared \
	--disable-static \
	--enable-pthreads \
	--enable-small \
	--enable-gpl \
	--enable-version3 \
	--enable-libx264 \
	--enable-libx265 \
	--enable-libvpx \
	--enable-neon \
	--enable-vfp \
	--disable-runtime-cpudetect \
	--disable-programs \
	--disable-doc \
	--disable-debug \
	--disable-network \
	--disable-avdevice \
	--disable-avfilter \
	--disable-avformat \
	--disable-swresample \
	--disable-swscale \
	--disable-postproc \
	--disable-hwaccels \
	--disable-indevs \
	--disable-outdevs \
	--disable-muxers \
	--disable-demuxers \
	--disable-protocols \
	--disable-filters \
	--disable-decoders \
	--enable-decoder=mjpeg \
	--disable-encoders \
	--enable-encoder=libx264 \
	--enable-encoder=libx265 \
	--enable-encoder=libvpx_vp8 \
	--enable-encoder=libvpx_vp9 \
	--disable-parsers \
	--enable-parser=h264 \
	--enable-parser=hevc \
	--enable-parser=vp8 \
	--enable-parser=vp9 \
	--disable-bsfs \
	--enable-bsf=h264_mp4toannexb \
	--enable-bsf=hevc_mp4toannexb

define Build/Configure
	(cd $(PKG_BUILD_DIR); $(FFMPEG_CONFIGURE))
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		DESTDIR="$(PKG_INSTALL_DIR)" \
		all install
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_CPPFLAGS) \
		-I$(PKG_INSTALL_DIR)/usr/include \
		-L$(PKG_INSTALL_DIR)/usr/lib \
		-Wl,-rpath-link,$(PKG_INSTALL_DIR)/usr/lib \
		-Wl,-rpath-link,$(STAGING_DIR)/usr/lib \
		-o $(PKG_BUILD_DIR)/one-kvm-codec-check \
		./src/one-kvm-codec-check.c \
		$(TARGET_LDFLAGS) -lavcodec -lavutil -lx264 -lx265 -lvpx -lstdc++ -lm -lpthread
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/libavcodec $(1)/usr/include/
	$(CP) $(PKG_INSTALL_DIR)/usr/include/libavutil $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libavcodec.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libavutil.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/libavcodec.pc $(1)/usr/lib/pkgconfig/
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/libavutil.pc $(1)/usr/lib/pkgconfig/
endef

define Package/libffmpeg-onekvm/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libavcodec.so.* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libavutil.so.* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/one-kvm-codec-check $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,libffmpeg-onekvm))

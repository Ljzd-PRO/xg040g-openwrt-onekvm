include $(TOPDIR)/rules.mk

PKG_NAME:=libyuv
PKG_VERSION:=2026.06.16
PKG_RELEASE:=1

PKG_SOURCE_VERSION:=957f295ea946cbbd13fcfc46e7066f2efa801233
PKG_SOURCE:=$(PKG_NAME)-$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/lemenkov/libyuv/tar.gz/$(PKG_SOURCE_VERSION)?
PKG_HASH:=570581a689634f5332a76780f70a1a140285d4cecb16d6b9f6b3637cc2711120
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_SOURCE_VERSION)

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/libyuv
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=YUV conversion and scaling library for One-KVM
  URL:=https://chromium.googlesource.com/libyuv/libyuv/
  DEPENDS:=+libjpeg-turbo +libstdcpp
endef

define Package/libyuv/description
  A pinned shared libyuv build used by One-KVM for capture-frame conversion,
  scaling, rotation and MJPEG conversion on XG-040G-MD.
endef

CMAKE_OPTIONS += \
	-DUNIT_TEST=OFF \
	-DJPEG_FOUND=TRUE \
	-DJPEG_INCLUDE_DIR=$(STAGING_DIR)/usr/include \
	-DJPEG_LIBRARY=$(STAGING_DIR)/usr/lib/libjpeg.so

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/libyuv $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libyuv.{a,so*} $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(INSTALL_DATA) ./files/libyuv.pc $(1)/usr/lib/pkgconfig/libyuv.pc
endef

define Package/libyuv/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libyuv.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libyuv))

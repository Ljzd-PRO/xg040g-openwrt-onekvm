include $(TOPDIR)/rules.mk

PKG_NAME:=x265
PKG_VERSION:=3.4
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/videolan/x265/tar.gz/refs/tags/$(PKG_VERSION)?
PKG_HASH:=544d147bf146f8994a7bf8521ed878c93067ea1c7c6e93ab602389be3117eaaf

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

CMAKE_SOURCE_SUBDIR:=source
CMAKE_BINARY_SUBDIR:=source/build-openwrt

define Package/libx265
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=H.265/HEVC encoder library for One-KVM
  URL:=https://www.videolan.org/developers/x265.html
  DEPENDS:=+libstdcpp +libpthread @BUILD_PATENTED
endef

define Package/libx265/description
  Pinned x265 3.4 shared library used by the One-KVM software H.265 encoder.
endef

CMAKE_OPTIONS += \
	-DENABLE_SHARED=ON \
	-DENABLE_CLI=OFF \
	-DENABLE_PIC=ON \
	-DENABLE_ASSEMBLY=ON \
	-DHIGH_BIT_DEPTH=OFF \
	-DMAIN12=OFF \
	-DENABLE_NEON_DOTPROD=OFF \
	-DENABLE_NEON_I8MM=OFF \
	-DENABLE_SVE=OFF \
	-DENABLE_SVE2=OFF \
	-DENABLE_SVE2_BITPERM=OFF

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/include/x265*.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libx265.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/x265.pc $(1)/usr/lib/pkgconfig/
endef

define Package/libx265/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libx265.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libx265))

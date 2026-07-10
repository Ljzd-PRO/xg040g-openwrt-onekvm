include $(TOPDIR)/rules.mk

PKG_NAME:=easytier-core
PKG_VERSION:=2.4.5
PKG_RELEASE:=1

PKG_SOURCE:=easytier-linux-aarch64-v$(PKG_VERSION).zip
PKG_SOURCE_URL:=https://github.com/EasyTier/EasyTier/releases/download/v$(PKG_VERSION)/
PKG_HASH:=df08c842f2ab2b8e9922f13c686a1d0f5a5219775cfdabb3e4a8599c6772201f
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_UNPACK:=rm -rf $(PKG_BUILD_DIR); mkdir -p $(PKG_BUILD_DIR); unzip -q $(DL_DIR)/$(PKG_SOURCE) -d $(PKG_BUILD_DIR)

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=LGPL-3.0-only
PKG_LICENSE_FILES:=COPYING
PKGARCH:=aarch64_cortex-a53
PKG_BUILD_PARALLEL:=1

RSTRIP:=:
STRIP:=:

include $(INCLUDE_DIR)/package.mk

EASYTIER_BINARY:=$(PKG_BUILD_DIR)/easytier-linux-aarch64/easytier-core
EASYTIER_BINARY_HASH:=88fd4f8ec30b0766251578cdc82631eddc3710d6dd913547224a4afc34693d36

define Package/easytier-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=EasyTier core for One-KVM
  URL:=https://github.com/EasyTier/EasyTier
  DEPENDS:=@aarch64 +kmod-tun
endef

define Package/easytier-core/description
  Pinned upstream EasyTier AArch64 static core binary used by One-KVM for
  optional peer-to-peer networking. The CLI and Web variants are omitted.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) ./files/COPYING $(PKG_BUILD_DIR)/COPYING
	echo "$(EASYTIER_BINARY_HASH)  $(EASYTIER_BINARY)" | sha256sum -c -
	LC_ALL=C file $(EASYTIER_BINARY) | grep -q 'ELF 64-bit LSB executable, ARM aarch64'
	LC_ALL=C file $(EASYTIER_BINARY) | grep -q 'statically linked'
	readelf -h $(EASYTIER_BINARY) | grep -q 'Machine:.*AArch64'
	! readelf -l $(EASYTIER_BINARY) | grep -q 'Requesting program interpreter'
endef

define Build/Compile
endef

define Package/easytier-core/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(EASYTIER_BINARY) $(1)/usr/bin/easytier-core
	$(INSTALL_DIR) $(1)/usr/share/licenses/easytier-core
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/COPYING $(1)/usr/share/licenses/easytier-core/COPYING
endef

$(eval $(call BuildPackage,easytier-core))

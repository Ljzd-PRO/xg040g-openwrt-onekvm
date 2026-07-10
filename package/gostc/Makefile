include $(TOPDIR)/rules.mk

PKG_NAME:=gostc
PKG_VERSION:=2.0.9
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)_linux_arm64_v8.0.tar.gz
PKG_SOURCE_URL:=https://github.com/SianHH/gostc-open/releases/download/v$(PKG_VERSION)/
PKG_HASH:=2a100487a4f3ccd27ad82132c4f8e6ac253c9696428f0d3fd4c53170e1c3682e
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_UNPACK:=rm -rf $(PKG_BUILD_DIR); mkdir -p $(PKG_BUILD_DIR); tar -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=Apache-2.0 AND LicenseRef-GOSTC-Commons-Clause
PKG_LICENSE_FILES:=LICENSE
PKGARCH:=aarch64_cortex-a53
PKG_BUILD_PARALLEL:=1

RSTRIP:=:
STRIP:=:

include $(INCLUDE_DIR)/package.mk

GOSTC_BINARY_HASH:=5d8ab3176d096a899604377f9a1f9b15a64b537fd4d3698dac4d49001960d4b6

define Package/gostc
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Remote access
  TITLE:=GOSTC client for One-KVM
  URL:=https://github.com/SianHH/gostc-open
  DEPENDS:=@aarch64
endef

define Package/gostc/description
  Pinned upstream GOSTC AArch64 static binary used by One-KVM for optional
  remote access. Its upstream license adds a non-commercial Commons Clause.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	echo "$(GOSTC_BINARY_HASH)  $(PKG_BUILD_DIR)/gostc" | sha256sum -c -
	LC_ALL=C file $(PKG_BUILD_DIR)/gostc | grep -q 'ELF 64-bit LSB executable, ARM aarch64'
	LC_ALL=C file $(PKG_BUILD_DIR)/gostc | grep -q 'statically linked'
	readelf -h $(PKG_BUILD_DIR)/gostc | grep -q 'Machine:.*AArch64'
	! readelf -l $(PKG_BUILD_DIR)/gostc | grep -q 'Requesting program interpreter'
endef

define Build/Compile
endef

define Package/gostc/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/gostc $(1)/usr/bin/gostc
	$(INSTALL_DIR) $(1)/usr/share/licenses/gostc
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/licenses/gostc/LICENSE
endef

$(eval $(call BuildPackage,gostc))

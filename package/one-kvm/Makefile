include $(TOPDIR)/rules.mk

PKG_NAME:=one-kvm
PKG_VERSION:=0.2.3
PKG_RELEASE:=2

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=
PKG_HASH:=74b90415bbd17803aa8d9a06b6f2c0ee91bdfe4407931c6c4cac037575e0a41f
PKG_SOURCE_SUBDIR:=One-KVM-260626
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

export PKG_CONFIG_ALLOW_CROSS:=1
export PKG_CONFIG_SYSROOT_DIR:=$(STAGING_DIR)
export PKG_CONFIG_PATH:=$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig
export LIBCLANG_PATH:=/usr/lib/llvm-18/lib
export BINDGEN_EXTRA_CLANG_ARGS:=--target=aarch64-openwrt-linux-musl --sysroot=$(TOOLCHAIN_DIR) -isystem$(TOOLCHAIN_DIR)/include -isystem$(STAGING_DIR)/usr/include
export ONE_KVM_LIBYUV_STUB:=1
export ONE_KVM_DISABLE_RKMPP:=1
export CARGO_NET_RETRY:=10
export CARGO_HTTP_TIMEOUT:=600
export CARGO_HTTP_MULTIPLEXING:=false
export CXX:=$(TARGET_CXX_NOCACHE)

define Package/one-kvm
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Remote access
  TITLE:=One-KVM IP-KVM server for XG-040G-MD
  URL:=https://github.com/mofeng-git/One-KVM
  DEPENDS:=$(RUST_ARCH_DEPENDS) +libstdcpp +libv4l +libffmpeg-mini +libjpeg-turbo +libudev-zero +libdrm
endef

define Package/one-kvm/description
  One-KVM Rust IP-KVM server packaged for the XG-040G-MD host-only route.
  This build is intended for UVC/MS2109 video capture and CH9329 serial HID.
endef

define Package/one-kvm/conffiles
/etc/config/one-kvm
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) ./files/Cargo.lock $(PKG_BUILD_DIR)/Cargo.lock
endef

define Build/Compile
	cd $(PKG_BUILD_DIR)/web && npm ci --no-audit --no-fund && npm run build
	$(call Build/Compile/Cargo)
endef

define Package/one-kvm/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/one-kvm $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/one-kvm.config $(1)/etc/config/one-kvm

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/one-kvm.init $(1)/etc/init.d/one-kvm

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/one-kvm-hwcheck $(1)/usr/sbin/one-kvm-hwcheck
endef

$(eval $(call BuildPackage,one-kvm))

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-airoha-an7581-oc
PKG_VERSION:=1.0.0
PKG_RELEASE:=2
PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define KernelPackage/airoha-an7581-oc
  SUBMENU:=Other modules
  TITLE:=Board-gated AN7581 CPU PLL control
  DEPENDS:=@TARGET_airoha_an7581
  FILES:=$(PKG_BUILD_DIR)/airoha-an7581-oc.ko
endef

define KernelPackage/airoha-an7581-oc/description
  Opt-in, board-gated PLL control for the XG-040G-MD tcboot profile.
  The module is never auto-loaded and loading it never changes frequency.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,airoha-an7581-oc))

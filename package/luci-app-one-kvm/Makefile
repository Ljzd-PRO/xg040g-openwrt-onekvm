include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-one-kvm
PKG_VERSION:=20260709
PKG_RELEASE:=3
PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=Apache-2.0

LUCI_TITLE:=LuCI support for One-KVM
LUCI_DEPENDS:=+luci-base +rpcd +rpcd-mod-ucode +one-kvm
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/one-kvm
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))

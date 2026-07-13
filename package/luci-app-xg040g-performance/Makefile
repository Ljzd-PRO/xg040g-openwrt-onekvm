include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-xg040g-performance
PKG_VERSION:=20260713
PKG_RELEASE:=2
PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=Apache-2.0

LUCI_TITLE:=LuCI support for XG-040G-MD software-switch performance
LUCI_DEPENDS:=+luci-base +rpcd +xg040g-performance
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))

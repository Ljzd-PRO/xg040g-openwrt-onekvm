include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-monitoring-defaults
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-monitoring-defaults
  SECTION:=admin
  CATEGORY:=Administration
  TITLE:=LuCI statistics and thermal defaults for XG-040G-MD
  PKGARCH:=all
  DEPENDS:=+luci-app-statistics +luci-i18n-statistics-zh-cn \
	+collectd-mod-thermal
endef

define Package/xg040g-monitoring-defaults/description
  Enables volatile collectd RRD statistics and the AN7581 cpu-thermal input.
  History is stored in RAM under /tmp to avoid persistent flash writes.
endef

define Build/Compile
endef

define Package/xg040g-monitoring-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/90-xg040g-monitoring \
		$(1)/etc/uci-defaults/90-xg040g-monitoring
endef

$(eval $(call BuildPackage,xg040g-monitoring-defaults))

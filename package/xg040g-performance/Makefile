include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-performance
PKG_VERSION:=1.0.0
PKG_RELEASE:=3
PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-performance
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Safe software-switch performance controls for XG-040G-MD
  DEPENDS:=+kmod-airoha-an7581-oc +rpcd +jsonfilter
endef

define Package/xg040g-performance/description
  Provides stock-default CPU PLL policy, thermal rollback, full-core RPS
  status and protected runtime controls for XG-040G-MD.
endef

define Package/xg040g-performance/conffiles
/etc/config/xg040g-performance
endef

define Build/Compile
endef

define Package/xg040g-performance/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/xg040g-performance \
		$(1)/etc/config/xg040g-performance

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/xg040g-performance \
		$(1)/etc/init.d/xg040g-performance

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/30-xg040g-performance-defaults \
		$(1)/etc/uci-defaults/30-xg040g-performance-defaults

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-cpuctl $(1)/usr/sbin/xg040g-cpuctl
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-cpu-monitor \
		$(1)/usr/sbin/xg040g-cpu-monitor

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/usr/libexec/rpcd/xg040g.performance \
		$(1)/usr/libexec/rpcd/xg040g.performance
endef

$(eval $(call BuildPackage,xg040g-performance))

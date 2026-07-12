include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-switch-management
PKG_VERSION:=2.0.0
PKG_RELEASE:=2

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-switch-management
  SECTION:=net
  CATEGORY:=Network
  TITLE:=DHCP switch, IPv4LL and selectable PXE port for XG-040G-MD
  DEPENDS:=+avahi-autoipd +avahi-nodbus-daemon +dnsmasq-full +firewall4 +uhttpd
endef

define Package/xg040g-switch-management/description
  Configures all four ports as a DHCP-managed switch by default, optionally
  dedicates one selected port to PXE, and provides mDNS plus RFC3927 IPv4LL.
endef

define Package/xg040g-switch-management/conffiles
/etc/config/xg040g-management
endef

define Build/Compile
endef

define Package/xg040g-switch-management/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/xg040g-management $(1)/etc/config/xg040g-management

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/xg040g-autoip $(1)/etc/init.d/xg040g-autoip
	$(INSTALL_BIN) ./files/etc/init.d/xg040g-pxe-http $(1)/etc/init.d/xg040g-pxe-http

	$(INSTALL_DIR) $(1)/etc/avahi/services
	$(INSTALL_DATA) ./files/etc/avahi/services/http.service $(1)/etc/avahi/services/http.service
	$(INSTALL_DATA) ./files/etc/avahi/services/ssh.service $(1)/etc/avahi/services/ssh.service

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/20-xg040g-network-schema \
		$(1)/etc/uci-defaults/20-xg040g-network-schema
	$(INSTALL_BIN) ./files/etc/uci-defaults/25-xg040g-avahi-management-only \
		$(1)/etc/uci-defaults/25-xg040g-avahi-management-only

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-autoip-monitor $(1)/usr/sbin/xg040g-autoip-monitor
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-network-mode $(1)/usr/sbin/xg040g-network-mode
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-pxe-uplink $(1)/usr/sbin/xg040g-pxe-uplink
endef

$(eval $(call BuildPackage,xg040g-switch-management))

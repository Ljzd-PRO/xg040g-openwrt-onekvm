include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-cloud-pxe
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-cloud-pxe
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Remote access
  TITLE:=Read-only rclone HTTP data plane for XG-040G-MD PXE
  DEPENDS:=+rclone +ca-bundle +xg040g-switch-management
endef

define Package/xg040g-cloud-pxe/conffiles
/etc/xg040g/rclone.conf
endef

define Build/Compile
endef

define Package/xg040g-cloud-pxe/install
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/uci-defaults $(1)/etc/xg040g
	$(INSTALL_BIN) ./files/etc/init.d/xg040g-cloud-pxe $(1)/etc/init.d/xg040g-cloud-pxe
	$(INSTALL_BIN) ./files/etc/uci-defaults/95-xg040g-cloud-pxe $(1)/etc/uci-defaults/95-xg040g-cloud-pxe
	$(INSTALL_CONF) ./files/etc/xg040g/rclone.conf $(1)/etc/xg040g/rclone.conf
	$(INSTALL_DIR) $(1)/etc/hotplug.d/block
	$(INSTALL_BIN) ./files/etc/hotplug.d/block/95-xg040g-cloud-pxe $(1)/etc/hotplug.d/block/95-xg040g-cloud-pxe
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/share/xg040g-cloud-pxe
	$(INSTALL_BIN) ./files/usr/sbin/xg040g-cloud-pxe $(1)/usr/sbin/xg040g-cloud-pxe
	$(INSTALL_DATA) ./files/usr/share/xg040g-cloud-pxe/boot-select.ipxe $(1)/usr/share/xg040g-cloud-pxe/boot-select.ipxe
	$(INSTALL_DATA) ./files/usr/share/xg040g-cloud-pxe/cloud.ipxe $(1)/usr/share/xg040g-cloud-pxe/cloud.ipxe
	$(INSTALL_DATA) ./files/usr/share/xg040g-cloud-pxe/ipxe.efi $(1)/usr/share/xg040g-cloud-pxe/ipxe.efi
	$(INSTALL_DATA) ./files/usr/share/xg040g-cloud-pxe/undionly.kpxe $(1)/usr/share/xg040g-cloud-pxe/undionly.kpxe
endef

$(eval $(call BuildPackage,xg040g-cloud-pxe))

include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-kvm-support
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-kvm-support
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Remote access
  TITLE:=Host-only KVM, PXE, storage and cloud helpers for XG-040G-MD
  DEPENDS:=+block-mount +ca-bundle +coreutils-stty +curl +dnsmasq-full \
	+e2fsprogs +fuse3-utils +ip-bridge +kmod-fs-ext4 +kmod-fuse \
	+kmod-scsi-core +kmod-usb-serial +kmod-usb-serial-ch341 \
	+kmod-usb-storage +kmod-usb-storage-uas +kmod-usb3 +kmod-video-uvc \
	+parted +picocom +rclone +rclone-config +smartmontools +usbutils \
	+ustreamer +v4l-utils +wget-ssl
endef

define Package/xg040g-kvm-support/description
  Runtime helpers for CH9329 serial HID discovery, optional ustreamer
  diagnostics, USB3 KVMSTORE mounting, PXE/iPXE setup and rclone cloud sync.
  Network changes are never applied automatically during package installation.
endef

define Package/xg040g-kvm-support/conffiles
/etc/config/xg040g-kvm
endef

define Package/xg040g-kvm-support/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/xg040g-kvm $(1)/etc/config/xg040g-kvm

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/kvm-ustreamer $(1)/etc/init.d/kvm-ustreamer

	$(INSTALL_DIR) $(1)/etc/hotplug.d/tty
	$(INSTALL_BIN) ./files/etc/hotplug.d/tty/99-ch9329-link $(1)/etc/hotplug.d/tty/99-ch9329-link

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/ch9329-detect $(1)/usr/sbin/ch9329-detect
	$(INSTALL_BIN) ./files/usr/sbin/kvm-cloud-check $(1)/usr/sbin/kvm-cloud-check
	$(INSTALL_BIN) ./files/usr/sbin/kvm-cloud-cron $(1)/usr/sbin/kvm-cloud-cron
	$(INSTALL_BIN) ./files/usr/sbin/kvm-cloud-sync $(1)/usr/sbin/kvm-cloud-sync
	$(INSTALL_BIN) ./files/usr/sbin/kvm-lite-setup $(1)/usr/sbin/kvm-lite-setup
endef

$(eval $(call BuildPackage,xg040g-kvm-support))


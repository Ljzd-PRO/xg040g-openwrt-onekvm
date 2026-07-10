include $(TOPDIR)/rules.mk

PKG_NAME:=xg040g-onekvm-runtime
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=XG-040G-MD OpenWrt One-KVM contributors
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/xg040g-onekvm-runtime
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Remote access
  TITLE:=Full host-only One-KVM runtime for XG-040G-MD
  DEPENDS:=+alsa-lib +alsa-utils +bash +easytier-core +frpc +gostc \
	+gpiod-tools +kmod-hid +kmod-hid-generic +kmod-sound-core +kmod-tun \
	+kmod-usb-acm +kmod-usb-audio +kmod-usb-hid +kmod-usb-serial \
	+kmod-usb-serial-ch341 +kmod-usb-serial-cp210x +kmod-usb-serial-ftdi \
	+kmod-usb-serial-pl2303 +libffmpeg-onekvm +libopus +libvpx +libx264 \
	+libx265 +libyuv +ttyd
endef

define Package/xg040g-onekvm-runtime/description
  Versioned runtime ABI baseline for the independently upgradeable One-KVM
  APK. It fixes the complete audio, software codec, remote-access and ATX
  dependency closure while leaving every optional service disabled by default.
endef

define Build/Compile
endef

define Package/xg040g-onekvm-runtime/install
	$(INSTALL_DIR) $(1)/usr/share/xg040g-onekvm-runtime
	$(INSTALL_DATA) ./files/runtime-abi $(1)/usr/share/xg040g-onekvm-runtime/abi
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/one-kvm-runtime-check $(1)/usr/sbin/one-kvm-runtime-check
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-one-kvm-runtime-ownership $(1)/etc/uci-defaults/99-one-kvm-runtime-ownership
endef

define Package/xg040g-onekvm-runtime/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT:-}" ] && exit 0
for service in ttyd frpc; do
	[ -x "/etc/init.d/$$service" ] || continue
	"/etc/init.d/$$service" stop >/dev/null 2>&1 || true
	"/etc/init.d/$$service" disable >/dev/null 2>&1 || true
done
exit 0
endef

$(eval $(call BuildPackage,xg040g-onekvm-runtime))

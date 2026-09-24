include $(TOPDIR)/rules.mk

PKG_NAME:=factory-wifi
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/factory-wifi
  SECTION:=siflower
  CATEGORY:=Siflower
  TITLE:=Pembaca 4 Factory Nodes: LAN/WAN MAC, SSID, Pre-shared Key
  DEPENDS:=+sf_common
endef

define Package/factory-wifi/description
  Daemon otomatis pembaca 4 factory nodes dari partisi Factory (mtd4)
  untuk router Tenda SFA28 / SF19A28: LAN MAC, WAN MAC, SSID unik, dan Pre-Shared Key.
endef

define Build/Compile
endef

define Package/factory-wifi/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/factory-wifi $(1)/etc/init.d/factory-wifi
endef

$(eval $(call BuildPackage,factory-wifi))

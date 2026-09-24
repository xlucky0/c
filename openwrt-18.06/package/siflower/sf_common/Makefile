include $(TOPDIR)/rules.mk

PKG_NAME:=sf_common
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/sf_common
  SECTION:=siflower
  CATEGORY:=Siflower
  TITLE:=Library utilitas hardware Siflower
  DEPENDS:=+libpthread +libubox +libuci
endef

define Package/sf_common/description
  Library utilitas hardware Siflower SFA28 / SF19A28.
  Menyediakan libsf_common.so, GPIO register access, dan RF trimming calibration helper.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/ 2>/dev/null || true
endef

define Build/Compile
	mkdir -p $(PKG_BUILD_DIR)
endef

define Package/sf_common/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/bin
	[ -f ./files/libsf_common.so ] && $(INSTALL_DATA) ./files/libsf_common.so $(1)/usr/lib/ || true
endef

$(eval $(call BuildPackage,sf_common))

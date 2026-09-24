#
# Copyright (C) 2024 OpenWrt.org & Community
# Target Profile untuk Router Tenda AC8v5 / AC28s (Siflower SFA28 / SF19A28)
#

define Profile/TENDA-AC28S
  NAME:= Tenda AC8v5 / AC28s (8MB Flash / 64MB RAM) Pure OpenWrt
  PACKAGES:=\
	kmod-sf1688_fmac kmod-switch-mt7530 factory-wifi \
	luci luci-theme-bootstrap luci-app-upnp \
	mtd fstools block-mount
endef

define Profile/TENDA-AC28S/Description
  Firmware OpenWrt Murni untuk Router Tenda AC8v5 / AC28s (SoC Siflower SFA28/SF19A28).
  Konfigurasi khusus untuk IC SPI-NOR Flash 8MB (W25Q64) dan RAM 64MB DDR2,
  lengkap dengan web interface LuCI, driver switch gigabit MediaTek MT7530,
  serta driver Wi-Fi Dual Band AC1200 dengan pembacaan kalibrasi RF asli.
endef

define Profile/TENDA-AC28S/Config
select TARGET_ROOTFS_SQUASHFS
select BUSYBOX_DEFAULT_FEATURE_TOP_SMP_CPU
select BUSYBOX_DEFAULT_FEATURE_TOP_DECIMALS
select BUSYBOX_DEFAULT_FEATURE_TOP_SMP_PROCESS
select BUSYBOX_DEFAULT_FEATURE_TOPMEM
select BUSYBOX_DEFAULT_FEATURE_USE_TERMIOS
select BUSYBOX_DEFAULT_CKSUM
endef

$(eval $(call Profile,TENDA-AC28S))

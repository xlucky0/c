#!/bin/bash
# make_flash_image.sh - Tool Penggabung 8MB Full Flash SPI-NOR
# Output: fullflash_sfa28_8MB.bin (8.388.608 bytes)
set -e

OUTPUT="fullflash_sfa28_8MB.bin"
echo "[1/4] Membuat blank flash file 8MB (8.388.608 bytes)..."
dd if=/dev/zero of=${OUTPUT} bs=1M count=8

echo "[2/4] Menginjeksi SPL, U-Boot, dan Factory Calibration..."
[ -f 01_spl-loader.bin ] && dd if=01_spl-loader.bin of=${OUTPUT} bs=1 seek=0 conv=notrunc
[ -f 02_u-boot.bin ] && dd if=02_u-boot.bin of=${OUTPUT} bs=1 seek=$((0x008000)) conv=notrunc
[ -f 03_u-boot-env.bin ] && dd if=03_u-boot-env.bin of=${OUTPUT} bs=1 seek=$((0x060000)) conv=notrunc
[ -f 04_factory_calibration.bin ] && dd if=04_factory_calibration.bin of=${OUTPUT} bs=1 seek=$((0x070000)) conv=notrunc

echo "[3/4] Menginjeksi Pure OpenWrt Firmware ke offset 0x080000..."
SYSUPGRADE_BIN="../openwrt-18.06/bin/targets/siflower/sf19a28-fullmask/openwrt-siflower-sf19a28-fullmask-tenda-ac28s-squashfs-sysupgrade.bin"
if [ -f "$SYSUPGRADE_BIN" ]; then
	dd if="$SYSUPGRADE_BIN" of=${OUTPUT} bs=1 seek=$((0x080000)) conv=notrunc
elif [ -f "openwrt-siflower-sysupgrade.bin" ]; then
	dd if="openwrt-siflower-sysupgrade.bin" of=${OUTPUT} bs=1 seek=$((0x080000)) conv=notrunc
else
	echo "[WARN] File sysupgrade belum ditemukan di folder bin/, pastikan build make selesai!"
fi

echo "[4/4] Selesai! File flash biner 8MB utuh telah siap: ${OUTPUT}"
ls -lh ${OUTPUT}

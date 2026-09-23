# Panduan Build OpenWrt 18.06 untuk Board Siflower SFA28/SF19A28

Disusun dari data log yang diambil dari perangkat (`bdinfo`, `printenv`, FDT,
dump kalibrasi Wi-Fi) dan SDK resmi Siflower: https://github.com/Siflower/1806_SDK

## 1. Ringkasan hardware (dari log kalian)

| Item | Nilai | Sumber |
|---|---|---|
| SoC | Siflower SFA28 / SF19A28, MIPS interAptiv | FDT (`compatible = "sf,sfa28"`) |
| RAM | 64 MB DDR2 | bdinfo (`memsize = 0x04000000`) |
| Flash | 8 MB SPI-NOR (W25Q64CV/S25FL064K) | ringkasan spesifikasi |
| Ethernet | `sf_eth1` + switch MediaTek MT7530 | printenv (`ethact=sf_eth1`) |
| Wi-Fi | `sf1688_lb_fmac` (2.4G) + `sf1688_hb_fmac` (5G) | ringkasan spesifikasi |
| UART | `serial@8300000`, 115200 8N1 | FDT + bdinfo |
| SPI flash ctrl | `spi@8202000`, max 33 MHz | FDT + bootcmd |
| bootcmd | `sf probe 0 33000000; sf read 0x81000000 0x80000 0x300000; bootm` | printenv |
| preboot | `btn_httpd_detect 192.168.4.1` (mode recovery web via tombol) | printenv |
| ethaddr | `00:90:4c:88:88:88` | printenv/bdinfo — **pola terlalu rapi, kemungkinan placeholder pabrik, bukan MAC asli unit** |

Indikasi kuat ini adalah router **Tenda** (bukan eval-board Siflower), karena
ringkasan flash layout kalian menyebut partisi `CFM/CFG` yang merupakan format
konfigurasi khas firmware Tenda.

## 2. Kenapa harus hati-hati sebelum mulai

- **Belum ada dump flash 8MB penuh.** Semua offset partisi di atas ditarik
  dari beberapa command log parsial, bukan dari image lengkap. Sebelum
  build/flash apa pun, ambil dump utuh dulu lewat u-boot:
  ```
  sfa28 # sf probe 0
  sfa28 # sf read 0x81000000 0x0 0x800000
  ```
  lalu transfer 0x800000 byte itu ke PC (tftp atau xmodem, tergantung u-boot
  kalian support apa — cek `help` di console u-boot). Simpan sebagai
  `fullflash-backup.bin` sebelum melakukan apa pun lagi. Ini adalah jaring
  pengaman satu-satunya kalau nanti firmware baru gagal boot.
- **Wi-Fi calibration/factory data itu unik per unit** (RF trim, MAC asli,
  dsb). Jangan pernah timpa partisi `factory` (`0x70000`-`0x80000`) dengan
  data dari unit lain atau dari image generik SDK — itu bisa membuat Wi-Fi
  tidak berfungsi permanen kalau tidak ada backup.
- Siapkan akses UART/serial ke board sebelum mencoba boot image baru — kalau
  gagal boot, kalian butuh console u-boot untuk recovery (tftpboot kernel
  lama, atau tulis ulang lewat SPI programmer external kalau u-boot ikut rusak).

## 3. Menyiapkan SDK

Repo `Siflower/1806_SDK` berisi tiga komponen yang saling terkait:
`uboot/`, `linux-4.14.90-dev/` (kernel), `openwrt-18.06/` (userspace/rootfs),
dan `image_maker_8M/` (tool untuk menggabungkan semuanya jadi image final
8MB — ini sudah cocok dengan flash size kalian, jadi kemungkinan besar SDK
ini memang basis dari firmware yang sudah jalan di perangkat kalian).

```bash
git clone https://github.com/Siflower/1806_SDK.git -b release2.0.0
cd 1806_SDK
```

### Dependensi build (Ubuntu/Debian, mirip kebutuhan OpenWrt 18.06 pada umumnya)

```bash
sudo apt update
sudo apt install -y build-essential asciidoc bison flex g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
  python3-distutils python2.7 rsync unzip zlib1g-dev file wget \
  subversion mercurial ccache libelf-dev
```

> OpenWrt 18.06 masih memakai beberapa tool Python 2 di build system lama —
> kalau `make menuconfig` atau `scripts/*.pl` error soal python, cek
> `README`/`docs` di masing-masing subfolder SDK, karena versi toolchain yang
> dibundel biasanya sudah disiapkan Siflower sendiri di dalam
> `openwrt-18.06/dl` atau `staging_dir`.

## 4. Menyesuaikan target ke board kalian

1. Masuk ke `openwrt-18.06/`, cari target siflower yang paling dekat dengan
   nama mesin di log kalian (`sf19a28-ac28s` / `sfa28`):
   ```bash
   cd openwrt-18.06
   find target/linux -iname '*sfa28*' -o -iname '*ac28*' -o -iname '*sf19a28*'
   ```
2. Bandingkan file `.dts`/`.dtsi` board yang ditemukan dengan
   `partition-8MB.dtsi` yang saya siapkan (lihat file terpisah) — sesuaikan
   offset partisi kalau ada perbedaan dengan dump flash asli kalian.
3. Kalau tidak ada target yang persis cocok (kemungkinan besar, karena board
   Tenda biasanya custom), kalian perlu **menduplikasi board profile yang
   paling mirip** (biasanya named `*-ac28s*` atau eval board `sfa28`) lalu:
   - ganti `compatible`/`model` sesuai model Tenda kalian,
   - timpa blok `partitions` dengan isi `partition-8MB.dtsi`,
   - sesuaikan `ethaddr`/nvmem MAC agar dibaca dari partisi `factory`, bukan
     hardcode.
4. Jalankan `make menuconfig`, pilih target Siflower yang sudah kalian
   sesuaikan, lalu paket-paket yang diperlukan (luci, dsb).

## 5. Build

```bash
make -j$(nproc) V=s 2>&1 | tee build.log
```

Build pertama akan lama (download source paket + kompilasi toolchain kalau
belum ada prebuilt). Hasil akhir biasanya ada di `bin/targets/siflower/...`.

## 6. Menggabungkan image final dengan `image_maker_8M`

Folder `image_maker_8M/` di SDK adalah tool khusus Siflower untuk
menggabungkan `u-boot + kernel + rootfs + partition table` jadi satu file
image 8MB yang formatnya dikenali bootloader board kalian (dan kemungkinan
juga format upgrade Tenda kalau firmware originalnya Tenda). Baca
`README`/script di folder itu — biasanya ada `Makefile` atau shell script
yang menerima output dari langkah 5 sebagai input.

## 7. Testing aman

1. **Jangan langsung flash ke SPI-NOR.** Uji dulu image kernel lewat u-boot
   `tftpboot` + `bootm` dari RAM (tanpa menulis flash sama sekali). Kalau
   command `tftpboot`/network u-boot belum aktif, cek dulu di FDT/uboot
   config kalian.
2. Kalau boot dari RAM berhasil dan semua interface (LAN, WiFi) terdeteksi,
   baru pertimbangkan menulis ke flash — dan tetap simpan
   `fullflash-backup.bin` dari langkah 2.

## 8. Untuk fork ke repo kalian

Struktur yang disarankan di repo fork kalian:
```
your-repo/
├── 1806_SDK/                 (submodule/fork dari Siflower/1806_SDK)
├── docs/
│   └── PANDUAN_BUILD_OPENWRT_SFA28.md   (file ini)
├── device-notes/
│   ├── bdinfo.txt
│   ├── printenv.txt
│   ├── FDT.txt
│   └── partition-8MB.dtsi
└── README.md
```
Simpan semua log mentah kalian (bdinfo, printenv, FDT) di repo — sangat
berguna untuk kontributor lain dengan board yang sama, dan sebagai referensi
kalau suatu saat perlu recovery.

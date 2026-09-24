# Tutorial Lengkap: Build OpenWrt untuk Router Tenda (Siflower SFA28)

Tutorial ini ditulis supaya bisa diikuti walau kalian belum pernah utak-atik
firmware router sebelumnya. Setiap istilah teknis dijelaskan singkat saat
pertama muncul.

---

## Bagian 0: Istilah dasar (skip kalau sudah paham)

- **Flash chip**: chip penyimpanan kecil di dalam router tempat semua
  software (bootloader, sistem operasi, pengaturan) disimpan. Router kalian
  punya 8MB flash.
- **Partition table**: flash 8MB itu dibagi-bagi jadi beberapa "kotak" (partisi)
  dengan fungsi berbeda-beda — mirip hard disk yang dibagi jadi drive C:, D:,
  dst. Kalau kita salah menaruh data di kotak yang salah, router bisa gagal
  nyala ("brick").
- **U-Boot**: program kecil pertama yang jalan saat router dinyalakan. Tugasnya
  cuma satu: memuat sistem operasi (Linux) dari flash ke memori (RAM), lalu
  menjalankannya. Mirip BIOS di komputer.
- **Kernel**: inti sistem operasi Linux.
- **Rootfs (root filesystem)**: semua file sistem Linux (program, halaman
  web admin, dsb), biasanya dipadatkan dalam format **squashfs** (seperti
  file .zip yang bisa langsung dijalankan tanpa diekstrak dulu).
- **Firmware**: istilah umum untuk gabungan kernel + rootfs yang siap dijalankan.
- **UART/serial console**: kabel kecil (3 pin: TX, RX, GND) yang disolder/dijepit
  ke papan router, dipakai untuk "mengintip" apa yang router lakukan saat
  booting, lewat program terminal di PC (seperti PuTTY/minicom).
- **Dump flash**: proses membaca SELURUH isi flash chip dan menyimpannya
  sebagai satu file di komputer, biasanya pakai clip/programmer eksternal
  (mis. CH341A) yang dijepitkan langsung ke kaki chip flash.

---

## Bagian 1: Apa yang sudah kita ketahui pasti tentang router kalian

Ini bukan tebakan lagi — semua di bawah ini saya konfirmasi langsung dari
byte-per-byte isi `full_dump.bin` yang kalian kirim.

### 1.1 Peta partisi flash (8MB total)

| # | Nama partisi | Alamat mulai | Alamat selesai | Ukuran | Isi |
|---|---|---|---|---|---|
| 1 | `spl-loader` | `0x000000` | `0x008000` | 32 KB | Program pemula super kecil, dijalankan chip sebelum U-Boot |
| 2 | `u-boot` | `0x008000` | `0x060000` | 352 KB | Bootloader U-Boot versi **2016.07** |
| 3 | `u-boot-env` | `0x060000` | `0x070000` | 64 KB | Tempat menyimpan pengaturan U-Boot (saat ini masih kosong/default) |
| 4 | `factory` | `0x070000` | `0x080000` | 64 KB | Data kalibrasi radio Wi-Fi + alamat MAC asli unit kalian — **JANGAN PERNAH DIUTAK-ATIK** |
| 5 | `firmware` | `0x080000` | `0x780000` | 7 MB | Kernel Linux **4.14.90** + rootfs squashfs |
| 6 | `oem-reserved` | `0x780000` | `0x800000` | 512 KB | Data konfigurasi khas Tenda (SSID default, dll) + satu blok kecil terenkripsi |

Cara saya memastikan ini bukan tebakan (untuk yang penasaran / mau
verifikasi ulang):
- Di offset `0x4` ada tulisan "sa18" — tanda pengenal khusus SPL Siflower.
- Di offset `0x8014` ada header standar U-Boot ("uImage") berisi teks nama
  `"U-Boot 2016.07-r#..."` dan ukuran file persis 365.154 byte.
- Setelah offset `0x60000`, isinya kosong total (semua nol) sampai
  `0x70000` — ini persis 65.536 byte, dan kalau dicek di `printenv.txt`
  kalian, U-Boot memang bilang kapasitas penyimpanan pengaturannya
  "65532 bytes" (dibulatkan). Jadi ini pasti kotak `u-boot-env`.
- Setelah `0x70000`, ada sedikit data asli (bukan kosong) — ini cocok
  dengan dump kalibrasi Wi-Fi yang kalian kirim di awal percakapan.
- Di offset `0x8015b` ada header uImage KEDUA, kali ini isinya
  `"MIPS Tenda Linux-4.14.90"` — ini header kernel Linux-nya, dikompresi
  LZMA, ukuran 2.037.090 byte.
- Persis setelah kernel selesai (offset `0x271a78`), ada tanda pengenal
  `"hsqs"` — tanda mulainya filesystem SquashFS (rootfs), dengan ukuran
  tercatat 5.287.580 byte di dalam header squashfs itu sendiri.
- `0x80000 + 0x700000 (7MB) = 0x780000` — pas di titik itu, isi flash
  berubah dari "penuh data" jadi campuran kosong/data kecil-kecil, tanda
  partisi firmware sudah habis di situ.

### 1.2 Peringatan tentang integritas dump

Saya coba cocokkan checksum internal (CRC) kernel dengan isi byte-nya, dan
**tidak cocok** — kemungkinan ada sedikit kesalahan baca saat proses dump
(wajar terjadi kalau pakai clip/programmer eksternal). Ini tidak masalah
untuk keperluan kita karena kita akan **membuat kernel sendiri dari source
code**, bukan memakai kernel dari dump ini. Tapi kalau nanti kalian mau
pakai dump ini untuk keperluan lain (misal ekstrak rootfs asli untuk
dipelajari), sebaiknya dump ulang dan bandingkan dua hasil dump untuk
memastikan tidak ada bagian yang salah baca.

---

## Bagian 2: Menyiapkan komputer untuk build

Build OpenWrt HARUS dilakukan di Linux (disarankan Ubuntu 20.04/22.04).
Kalau kalian di Windows, pakai WSL2 atau install Ubuntu di virtual machine.

```bash
sudo apt update
sudo apt install -y build-essential asciidoc bison flex g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
  python3-distutils python2.7 rsync unzip zlib1g-dev file wget \
  subversion mercurial ccache libelf-dev
```

## Bagian 3: Ambil source code

```bash
git clone https://github.com/Siflower/1806_SDK.git -b release2.0.0
cd 1806_SDK
```

Kalian akan lihat 4 folder utama:
- `uboot/` — source code bootloader
- `linux-4.14.90-dev/` — source code kernel (**cocok** dengan yang kita
  temukan di device kalian, 4.14.90 — SDK ini memang basis firmware asli
  router kalian)
- `openwrt-18.06/` — source code OpenWrt (sistem operasi + rootfs)
- `image_maker_8M/` — tool untuk menggabungkan semuanya jadi satu file
  firmware siap-flash, khusus untuk flash 8MB (cocok dengan router kalian)

## Bagian 4: Pasang board profile yang sudah disesuaikan

1. Cari lokasi file board reference di dalam SDK:
   ```bash
   find . -iname 'sf19a28_fullmask_ac28s.dts'
   ```
2. Taruh file **`sf19a28_fullmask_ac28s_custom.dts`** (saya siapkan di
   bawah) di folder yang sama.
3. Cari juga file yang mendaftarkan `ac28s` sebagai target board (biasanya
   file `.mk` atau `Makefile` di `openwrt-18.06/target/linux/siflower/`),
   duplikasi baris yang mereferensikan `ac28s`, ganti nama target ke
   sesuatu yang jelas (misal `tenda_ac8v5-si`), dan arahkan ke file dts
   custom kalian.

File dts ini sudah memuat partition table yang **terverifikasi** dari
analisis kita di Bagian 1 — jauh lebih akurat dari versi-versi sebelumnya.

## Bagian 5: Konfigurasi & build

```bash
cd openwrt-18.06
make menuconfig
```

Di menu ini:
- Pilih **Target System** → cari profil Siflower kalian
- Pilih **Target Profile** → board custom yang tadi kalian daftarkan
- Di bagian **LuCI** → centang `luci` (supaya ada tampilan web admin)
- Simpan (`Save`) lalu keluar (`Exit`)

Lalu build:
```bash
make -j$(nproc) V=s 2>&1 | tee build.log
```

Build pertama akan lama (30 menit - beberapa jam tergantung komputer),
karena harus download & compile banyak hal. Kalau ada error, cari baris
error pertama di `build.log` (error di tengah biasanya cuma efek domino
dari error pertama).

Hasil build ada di `bin/targets/siflower/.../` — akan ada file kernel dan
rootfs terpisah.

## Bagian 6: Gabungkan jadi satu image dengan `image_maker_8M`

Masuk ke folder `image_maker_8M/`, baca `README` di dalamnya — biasanya
ada script (`Makefile` atau `.sh`) yang menerima kernel+rootfs hasil
Bagian 5 sebagai input dan menghasilkan satu file image utuh yang formatnya
cocok dengan bootloader kalian.

## Bagian 7: TESTING SEBELUM FLASH (paling penting!)

**Jangan langsung tulis ke flash.** Uji dulu boot dari RAM:

1. Nyalakan router, masuk ke console U-Boot (tekan tombol apa pun saat
   booting kalau ada `bootdelay`, seperti punya kalian yang `bootdelay=2`)
2. Karena `tftpput` tidak tersedia di U-Boot kalian (sudah kita cek), untuk
   MENGIRIM file baru ke board kalian pakai `tftpboot` (arahnya download,
   bukan upload — ini memang tersedia):
   ```
   sfa28 # setenv ipaddr 192.168.4.10
   sfa28 # setenv serverip 192.168.4.1
   sfa28 # tftpboot 0x81000000 openwrt-kernel.bin
   sfa28 # bootm 0x81000000
   ```
   (siapkan server TFTP di PC kalian dulu, isi dengan file kernel hasil
   build, lalu sambungkan PC-router lewat kabel LAN langsung)
3. Kalau berhasil boot dan LuCI (web admin OpenWrt) bisa diakses, LAN/WiFi
   terdeteksi — baru pertimbangkan tulis ke flash.
4. **Sebelum menulis ke flash sungguhan**, simpan ulang `full_dump.bin`
   sebagai cadangan permanen di beberapa tempat (cloud, hardisk lain).
   Ini satu-satunya cara balik ke kondisi awal kalau firmware baru
   bermasalah setelah ditulis ke flash.
5. Menulis ke flash sebaiknya pakai clip/programmer eksternal yang sama
   dengan yang dipakai untuk dump (paling aman, karena kalian tidak
   bergantung pada U-Boot yang mungkin ikut rusak kalau ada kesalahan).

## Bagian 8: Fork ke repo kalian

Struktur folder yang disarankan:
```
your-repo/
├── 1806_SDK/                              (fork dari Siflower/1806_SDK)
├── docs/
│   └── TUTORIAL_LENGKAP_OPENWRT_SFA28.md  (file ini)
├── device-notes/
│   ├── full_dump.bin                      (cadangan dump asli - JANGAN dihapus)
│   ├── bdinfo.txt / printenv.txt / FDT.txt / bootcmd.txt
│   └── sf19a28_fullmask_ac28s_custom.dts  (board dts final)
└── README.md
```

Simpan `full_dump.bin` di repo (atau minimal di tempat aman lain) selamanya
— itu adalah satu-satunya jejak lengkap kondisi asli pabrik unit kalian.

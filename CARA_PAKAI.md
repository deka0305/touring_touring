# Touring Tracker — Cara Pakai

App touring motor: rencanakan rute, bagikan grup, rekam perjalanan.
Tidak ada data contoh — semua yang tampil berasal dari grup dan jejak GPS-mu
sendiri.

---

## Yang bisa dan belum bisa

**Bisa sekarang**

- Buat grup touring dengan Group ID sendiri.
- Susun rute yang mengikuti jalan raya asli, lengkap dengan jarak dan estimasi waktu.
- Kelola anggota beserta perannya: Road Captain, Sweeper, Marshal, Rider.
- Bagikan grup lewat WhatsApp; anggota gabung dengan menempel kode, dan
  **road captain langsung melihat mereka masuk**.
- Grup & rute tersimpan di server, jadi tidak hilang saat ganti HP.
- Tetap terbuka offline dari salinan di HP.
- **Lihat posisi anggota live di peta**, lengkap dengan deteksi siapa hilang
  sinyal — selama app dibuka.
- **Rekam perjalanan** lalu bagikan rekapnya sebagai kartu gambar.
- **Merekam terus walau layar mati** — HP boleh masuk kantong.

**Belum bisa**

Perekaman berhenti kalau **app-nya ditutup paksa** (di-swipe dari daftar app
terbaru) atau HP mematikan aplikasinya untuk hemat baterai. Selama merekam ada
notifikasi *"Merekam perjalanan"* — kalau notifikasi itu hilang padahal belum
ditekan STOP, jejaknya terputus. Bawa power bank untuk touring panjang.

Notifikasi SOS ke HP yang app-nya tertutup juga belum bisa, dan tidak akan bisa
di paket Firebase gratis. **HT atau telepon tetap jalur darurat utama.**

Artinya: pakai app ini untuk **merencanakan dan membagikan** touring. Saat hari-H,
komunikasi tetap lewat HT atau WhatsApp.

> Kalau app bilang "Server tidak tersambung", konfigurasi Firebase belum diisi —
> lihat `RENCANA_BACKEND.md`. Grup tetap bisa dibuat, hanya belum bisa dibagikan.

---

## 0. Pertama kali buka

App mulai kosong: belum ada grup sama sekali. Dua pilihan saja, karena memang
cuma ada dua jalan masuk:

- **Buat grup touring** — kamu jadi road captain
- **Gabung pakai kode** — kalau road captain sudah mengirim kodenya

---

## 1. Buat grup touring

**Grup → Buat grup**

| Isian | Contoh | Catatan |
|---|---|---|
| Nama touring | `Bromo Etape 2` | Nama acaranya, bukan nama klub |
| Nama klub / komunitas | `Garuda Rider Club` | Dipakai untuk inisial logo |
| Jadwal keberangkatan | `3 Agu 2026 · 13:30` | Tanggal dan jam, dipakai menghitung perkiraan jam lintas checkpoint |
| Nama kamu | `Bagas Pratama` | |
| Nomor polisi | `N 1234 AB` | |

Pembuat grup otomatis jadi **Road Captain**. Peran ini bisa dipindah nanti.

Setelah disimpan, app membuat **Group ID** acak seperti `GRC-2026`. ID ini yang
kamu sebut ke anggota.

Tekan **Lanjut · atur rute**.

---

## 2. Susun rute

**Detail grup → Susun rute sekarang** (atau tab **Peta** → tombol 🛣️)

### Pilih moda dulu

Baris paling atas: **Motor · Mobil · Sepeda · Lari**. Ini menentukan jalan mana
yang boleh dipakai, dan hasilnya benar-benar berbeda:

| Moda | Aturan | Malang → Jemplang → Penanjakan |
|---|---|---|
| **Motor** | **Hindari tol** | 92 km |
| **Mobil** | Boleh tol, cari tercepat | 105 km |
| **Sepeda** | Jalur sepeda | 54 km |
| **Lari** | Jalur pejalan | 53 km |

Motor **wajib** menghindari tol — di Indonesia motor dilarang masuk jalan tol,
jadi memakai profil mobil untuk motor menghasilkan rute yang tidak boleh
dijalani. Mobil justru sebaliknya: tol diizinkan supaya dapat yang tercepat.

Sepeda dan lari sering jauh lebih pendek karena boleh lewat jalan kecil yang
tertutup untuk kendaraan bermotor.

Mengganti moda langsung menghitung ulang rutenya.

Ada dua cara menaruh titik:

1. **Cari nama tempat** — tekan `+ Cari & tambah tujuan`, ketik minimal 3 huruf,
   pilih dari hasil. Pakai nama yang umum: `Tumpang Malang` lebih mudah ketemu
   daripada `Rest Area Tumpang`, karena nama tempat diambil dari peta
   OpenStreetMap dan tidak semua POI terdaftar.
2. **Tahan lama di peta** — titik ditaruh persis di lokasi yang kamu tekan,
   dinamai `Titik 3`, dst. Ganti namanya lewat menu ⋮ → Ganti nama.

Mengatur daftar titik:

- **Geser ikon ☰** untuk mengubah urutan. Titik pertama jadi **MULAI**, titik
  terakhir jadi **FINISH**, sisanya **MAMPIR**.
- **Menu ⋮** → Ganti nama / Cari tempat lain / Hapus titik.

Setiap kali daftar berubah, rute dihitung ulang otomatis mengikuti jalan raya.
Jarak dan estimasi waktu muncul di bawah. Tekan **Simpan rute**.

> **Catatan jarak.** Rute mengikuti profil kendaraan biasa. Untuk Malang →
> Penanjakan, hasilnya bisa jauh lebih panjang dari perkiraan kasar karena
> beberapa jalur pegunungan tidak dianggap jalan umum. Kalau kamu tahu jalur
> yang benar, tambahkan titik mampir di sepanjang jalur itu supaya rute dipaksa
> lewat sana.

**Butuh internet.** Pencarian tempat dan penyusunan rute memanggil layanan
OpenStreetMap. Kalau jaringan mati, rute digambar sebagai garis lurus putus-putus
dan diberi peringatan — jaraknya jadi perkiraan kasar. Rute yang sudah tersimpan
tetap bisa dilihat offline.

---

## 3. Anggota masuk sendiri

**Tidak ada tombol "tambah anggota".** Ini disengaja.

Lokasi itu milik HP, bukan milik orang: satu pemasangan app = satu uid = satu
posisi. Kalau road captain mengetik 20 nama dari HP-nya, ke-20 orang itu tidak
akan pernah punya titik di peta — HP-nya cuma tahu posisi HP-nya sendiri. Baris
seperti itu hanya terlihat seperti rider yang bisa dipantau padahal tidak, dan
menugaskan "Sweeper" ke orang yang tidak terlacak lebih buruk daripada tidak
berguna.

Jadi caranya cuma satu: **tiap rider memasang app dan menempel kode gabung.**
Nama yang muncul di daftar anggota berarti orang itu benar-benar bisa dipantau.

Konsekuensinya, rider tanpa smartphone tidak bisa didaftarkan. Untuk touring
sungguhan, dia harus didampingi seseorang yang membagikan lokasi.

### Yang bisa dilakukan road captain

**Ketuk baris anggota** untuk mengubah nama, nopol, dan peran — atau **Hapus**
untuk mengeluarkannya. Geser baris ke kiri juga bisa.

| Isian | Catatan |
|---|---|
| Nama | Wajib |
| Nomor polisi | Opsional, otomatis jadi huruf kapital |
| Peran | Road Captain / Sweeper / Marshal / Rider |

Aturan peran:

- **Road Captain** dan **Sweeper** masing-masing hanya boleh satu orang. Kalau
  kamu menunjuk orang baru, yang lama otomatis turun jadi Rider — app memberi
  tahu sebelum menyimpan.
- **Marshal** dan **Rider** bebas berapa saja.

Mengubah anggota: tekan barisnya. Menghapus: tekan barisnya lalu **Hapus**, atau
geser barisnya ke kiri.

### Mengeluarkan anggota benar-benar mengeluarkan

Saat road captain menghapus anggota dari grup di server, tiga hal terjadi:

1. Namanya dihapus dari daftar anggota
2. Posisinya dihapus, jadi markernya tidak menggantung di peta anggota lain
3. Dia **dicekal** — tidak bisa mendaftar ulang walau kode gabungnya masih dia
   pegang

Tanpa nomor 3, mengeluarkan orang tidak ada artinya: dia tinggal menempel kode
yang sama dan masuk lagi.

Di HP orang itu, grupnya hilang sendiri dan riwayat mencatat **"Akses ke … dicabut"**.

Kalau kamu ingin memasukkannya kembali, itu belum ada tombolnya — daftar cekal
hanya bisa dibersihkan lewat konsol Firebase (hapus `banned/<uid>`). Bilang saja
kalau perlu tombol "izinkan lagi".

Bedanya dengan **keluar sendiri** (menu ⋮ → Keluar dari grup): itu tidak dicekal,
jadi orangnya bisa gabung lagi kapan pun pakai kode yang sama.

Selama grup masih kurang sesuatu, kartu kuning **"Belum siap jalan"** muncul di
detail grup dan menyebutkan apa yang kurang.

---

## 4. Bagikan ke anggota

**Detail grup → Bagikan**

- **Kirim via WhatsApp** — pesan undangan otomatis berisi nama touring, jadwal,
  daftar titik rute, jarak, dan kode gabung.
- **Salin kode** — kalau mau dikirim lewat jalur lain.

Di sisi anggota:

1. Pasang app ini.
2. **Grup → Gabung pakai kode**.
3. Tempel kodenya, tekan **Gabung**.
4. Isi nama dan nopol — **namamu langsung terlihat road captain.**

### Dua jenis kode

| | Grup di server | Grup lokal |
|---|---|---|
| Kapan | Dibuat saat server tersambung | Dibuat saat offline |
| Panjang | **~103 karakter** | ~255 karakter |
| Isinya | Kunci grup + identitas | Identitas + semua titik rute |
| Saat gabung | Rute & daftar anggota diambil dari server; RC melihat kamu masuk | Hanya menyalin rencana; RC **tidak** tahu, dan rute harus disusun ulang |

Kode grup server jauh lebih pendek karena rutenya tidak perlu ikut — cukup
kuncinya, sisanya diambil dari server. Yang memegang kode itu boleh masuk,
seperti tautan Google Meet, jadi jangan sebar ke sembarang orang.

Untuk kode lokal, nama titik dipotong di 28 karakter supaya kodenya tidak
membengkak, dan karakter `|`, `;`, `,` diganti spasi karena dipakai sebagai
pemisah.

### Siapa boleh mengubah apa

Di grup server, hanya **road captain** yang boleh mengubah rute, detail grup, dan
peran anggota. Anggota lain hanya bisa mengubah datanya sendiri dan keluar dari
grup — itu ditegakkan di server, bukan cuma disembunyikan di UI.

Daftar anggota **tidak** ikut dalam kode. Tanpa server, tiap HP punya daftarnya
sendiri — road captain yang memelihara daftar lengkapnya.

---

## 5. Mulai merekam saat berangkat

**Tab Peta → tombol MULAI di bawah.**

Satu tombol mengerjakan dua hal:

1. **Merekam jejak GPS** — untuk rekap dan kartu bagikan. Selalu jalan, bahkan
   tanpa internet, karena jejak itu milikmu sendiri.
2. **Menampilkan posisimu ke anggota** — hanya kalau grupnya ada di server.

Saat merekam, tombolnya jadi merah dan menampilkan angka berjalan: jarak, waktu,
rata-rata. Tekan lagi untuk berhenti; app menanyakan konfirmasi dulu supaya
rekaman tidak mati karena tersenggol.

Yang perlu diketahui:

- Lokasimu **tidak pernah dikirim** sampai kamu menekan MULAI.
- Izin lokasi diminta sekali. Kalau pernah ditolak permanen, app mengarahkan ke
  Pengaturan → Aplikasi → Touring Tracker → Izin → Lokasi.
- Posisi dikirim tiap **10 detik**, dilewati kalau bergeser kurang dari
  **25 meter**. Rider yang berhenti hampir tidak memakai kuota.
- Jejak disimpan satu titik per **200 meter** — rute 100 km jadi ~500 titik.
- **Layar boleh dimatikan, HP boleh masuk kantong.** Selama merekam muncul
  notifikasi *"Merekam perjalanan"* yang tidak bisa di-swipe — itu tandanya
  perekaman masih hidup. Jangan tutup paksa app-nya (swipe dari daftar app
  terbaru), itu mematikan perekaman.
- Ikon ☁️ bersilang di tombol berarti grupnya lokal: jejak tetap direkam, tapi
  anggota lain tidak melihat posisimu.
- **Rute belum perlu ada.** Tombol MULAI tetap muncul walau rutenya belum
  disusun — merekam jejak tidak butuh rute.

### Kalau GPS tidak mau jalan

Sesudah menekan MULAI, tombolnya harus jadi merah. Kalau tidak:

| Yang terlihat | Artinya |
|---|---|
| **MENUNGGU SINYAL GPS…** | Normal. GPS sedang mencari sinyal — di dalam ruangan bisa lama. Keluar ke tempat terbuka |
| Pesan *"Izin lokasi ditolak"* | Tekan MULAI lagi dan pilih **Izinkan** |
| Pesan *"Izin lokasi diblokir"* | Pengaturan → Aplikasi → Touring Tracker → Izin → Lokasi → Izinkan |
| Pesan *"GPS mati"* | Nyalakan Lokasi di panel setelan cepat HP |
| Jejak terputus sesudah HP dikantongi | Hemat baterai membunuh app-nya. Pengaturan → Aplikasi → Touring Tracker → Baterai → **Tanpa batasan** (Xiaomi/Oppo/Vivo/Samsung paling agresif) |

Semua kegagalan juga tercatat di **tab SOS → Riwayat kejadian**, jadi alasannya
tetap bisa dibaca setelah pesan sekilasnya hilang.

### Pilih apa yang digambar di peta

Dua tombol di kanan atas, warnanya sama dengan garisnya:

| Tombol | Garis | Warna |
|---|---|---|
| 🛣️ | Rute rencana dari maps | **oranye** |
| 〰️ | Jejak GPS yang kamu lalui | **hijau** |

Keduanya bisa hidup bersamaan — dan itu justru pemakaian yang paling berguna:
kelihatan seberapa jauh jalur nyatamu menyimpang dari rute. Saat jejak
ditampilkan, rute rencana diredupkan supaya jejaknya yang menonjol.

Tombol jejak baru muncul setelah ada jejak yang terekam. Kalau belum, tombol itu
tidak akan mengubah apa pun, jadi lebih baik tidak ada.

### Status anggota di peta dan tab Tim

| Status | Warna | Artinya |
|---|---|---|
| AMAN | hijau | Bergerak, masih dalam formasi |
| BERHENTI | abu | Kecepatan di bawah 3 km/j |
| TERTINGGAL | kuning | Lebih dari 3,2 km di belakang yang paling depan |
| **HILANG** | oranye | **Sinyalnya putus** — server tidak menerima kiriman lebih dari 90 detik |
| SOS | merah | Menekan tombol darurat |

**HILANG** itu bagian paling berguna saat touring. Server yang menandainya
sendiri begitu koneksi HP anggota terputus, jadi tetap terdeteksi walau app-nya
mati mendadak atau masuk area tanpa sinyal — bukan menunggu dia melapor.

### Belum terlacak

Tab Tim punya dua bagian:

- **TERLACAK** — anggota yang posisinya diketahui, dengan status di atas
- **BELUM TERLACAK** — sudah gabung, tapi belum menyalakan tombol lokasi

Yang belum terlacak **tidak muncul di peta** dan tidak ikut hitungan apa pun.
Itu disengaja: menaruhnya di KM 0 akan menjadikannya sweeper dan membuat rentang
rombongan melonjak jadi sepanjang rute.

Tapi mereka tetap terdaftar di tab Tim — periksa bagian ini sebelum berangkat,
karena inilah daftar orang yang tidak akan bisa kamu pantau di jalan.

---

## 6. Bagikan hasilnya sebagai gambar

**Tab Rekap → Bagikan sebagai gambar.**

Kartunya bisa dikirim ke WhatsApp, Instagram, Telegram, atau disimpan ke galeri —
semuanya lewat lembar bagikan bawaan HP, jadi app ini tidak perlu tahu satu pun
dari mereka.

### Pilih garis yang digambar

| Pilihan | Garisnya | Angkanya |
|---|---|---|
| **Jejak GPS** | Yang benar-benar kamu lalui | Jarak, waktu, rata-rata, kecepatan maks — dari perjalanan |
| **Rute rencana** | Rute dari maps, digambar utuh | Jarak rute, **estimasi** waktu, moda, jumlah titik |

Angka kedua pilihan **tidak pernah dicampur.** Kalau kartunya bilang "Estimasi",
itu perkiraan dari rute; kalau bilang "Waktu", itu waktu yang sungguh berjalan.
Badge-nya juga ikut: `RENCANA` untuk rute, nama moda (`MOTOR`, `MOBIL`, …) untuk
jejak nyata.

Pilihan **Jejak GPS** baru bisa dipakai setelah kamu menekan MULAI dan bergerak.
Sebelum itu pilihannya tetap terlihat tapi tidak bisa ditekan, supaya jelas
kenapa.

Jejak yang baru berisi dua titik tidak digambar — dua titik hanya jadi garis
lurus yang terlihat seperti kerusakan. Kartunya bilang "Jejak masih terlalu
pendek untuk digambar".

### Tambah foto

**Pilih foto** dari galeri atau **Kamera** untuk memotret langsung. Fotonya jadi
latar, dengan gradien gelap supaya angkanya tetap terbaca di foto terang.

---

## 7. Pilih grup aktif

**Grup → tombol "Pakai"** pada grup yang dituju.

Grup aktif (bertanda **AKTIF** hijau) menentukan apa yang tampil di tab lain:

Apa yang tampil bergantung pada apa yang sudah ada — bukan pada jenis grup:

| Tab | Belum ada posisi | Sudah ada posisi dari server |
|---|---|---|
| **Peta** | Rute + titik bernomor + ringkasan rencana | Marker anggota, pin RC/sweeper, rentang rombongan |
| **Tim** | Daftar anggota dengan peran dan nopol | TERLACAK (status, kecepatan) + BELUM TERLACAK |
| **SOS** | Keterangan kenapa belum aktif | Tombol darurat aktif + riwayat |
| **Rekap** | Rencana rute | Keadaan rombongan; kalau kamu sudah merekam, rekap jejak GPS-mu |

---

## Hal lain

**Tema.** Ikon matahari/bulan di kanan atas. Pilihanmu tersimpan.

**Data kamu.** Grup, rute, dan anggota tersimpan di server, jadi tidak hilang
saat ganti HP. **Jejak GPS-mu disimpan di HP ini saja** dan tidak dikirim ke mana
pun — menghapus app berarti menghapus jejaknya.

**Tidak ada data contoh.** App ini tidak punya grup demo. Pemasangan baru mulai
kosong dengan dua pilihan: buat grup, atau gabung pakai kode. Setiap angka yang
kamu lihat berasal dari grup, rute, atau jejak GPS-mu sendiri — dulu ada grup
contoh berisi 50 rider palsu, dan angka simulasinya bocor ke tab Rekap serta
kartu bagikan sebagai jarak dan durasi yang tidak pernah terjadi.

Kalau semua grup dihapus, app kembali ke layar awal itu — bukan diisi data
karangan.

**Sumber peta.** Petak peta dari CARTO, data dari OpenStreetMap, pencarian nama
tempat dari Nominatim, penyusunan rute dari Valhalla. Semuanya gratis tanpa API
key, jadi mohon dipakai dengan wajar — pencarian sengaja diperlambat sedikit agar
tidak membanjiri layanannya.

---

## Untuk yang mengembangkan

```
lib/
  model.dart              Stop, Member, TripGroup, Rider — murni data, tanpa Flutter UI
  store.dart              simpan/muat ke SharedPreferences (satu blob JSON)
  data.dart               TripState (global `trip`) + cache rute aktif
  osm.dart                Nominatim (cari tempat) & Valhalla (rute per moda)
  track.dart              rekaman jejak GPS, diperkecil per 200 m
  share_card.dart         kartu gambar + tangkap PNG + lembar bagikan
  theme.dart              palet gelap/terang, helper font mono()/arch()
  main.dart               shell + bottom nav 5 tab + header
  screens/
    map_screen.dart       peta live / tampilan rencana
    team_screen.dart      daftar rider live / daftar anggota
    sos_screen.dart       tombol tahan 3 detik + riwayat
    groups_screen.dart    daftar grup, buat grup, gabung pakai kode
    group_screen.dart     detail grup: rute, anggota, bagikan
    route_edit_screen.dart penyusun rute + sheet pencarian tempat
    trip_screen.dart      rekap live / rencana + kartu bagikan
    help_screen.dart      ringkasan cara pakai di dalam app
```

Jalankan test:

```
flutter test
```

Menambah pelacakan live nanti perlu: server yang menerima kiriman GPS,
autentikasi anggota, dan paket `geolocator` di sisi app. `Rider` di
`model.dart` sudah berbentuk seperti hasil yang diharapkan dari server itu, jadi
sambungannya masuk lewat sana.

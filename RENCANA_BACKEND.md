# Rencana Backend — Firebase Realtime Database

Proyek: `api-database-b4568` · region `asia-southeast1` (Singapore) · paket **Spark**

## Status

**Tahap 1 dan 2 sudah dikerjakan.**

- Tahap 1 — grup & rute di server, join sungguhan, anonymous auth.
- Tahap 2 — lokasi live + presence, **selama app dibuka**. Interval 10 detik dan
  saringan 25 m sesuai §5. Status `HILANG` memakai `onDisconnect()` server plus
  batas umur data 90 detik sebagai jaring kedua.

Belum: SOS realtime lintas HP, foreground service (lokasi saat layar mati),
track bersama untuk rekap. Baterai juga belum dikirim — node `live/b` sudah
disiapkan di Rules, tinggal menambah `battery_plus`.

Supaya jalan, dua hal harus kamu lakukan di konsol:

1. **Pasang rules** dari `firebase/database.rules.json` ke tab Rules
   (sekarang masih `.read/.write: true` — siapa pun bisa menghapus isinya).
2. **Aktifkan Anonymous sign-in**: Authentication → Sign-in method → Anonymous.

Lalu isi konfigurasi di `lib/firebase_options.dart` — cara tercepat:

```
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login
flutterfire configure --project=api-database-b4568
```

Selama konfigurasi belum diisi, app **tetap jalan** dalam mode lokal: grup
tersimpan di HP, tapi belum bisa dibagikan. Layar "Buat grup" mengatakan itu
apa adanya.

---

---

## 1. Kesimpulan singkat

RTDB cocok untuk app ini. Lokasi live adalah pola "tulis kecil, sangat sering,
banyak pendengar" — itu justru yang dirancang RTDB, dan region Singapore membuat
latensi dari Indonesia rendah.

Tapi paket Spark memberi tiga batas keras yang membentuk rancangannya:

| Batas Spark | Angka | Artinya untuk app ini |
|---|---|---|
| Koneksi bersamaan | **100** | Satu rombongan 50 rider aman. **Dua** rombongan 50 orang jalan bersamaan = mentok |
| Penyimpanan | **1 GB** | Praktis tak terbatas — **asal riwayat posisi mentah tidak disimpan** |
| Unduhan | **10 GB/bulan** | Ini pengikat sebenarnya, hitungannya di §5 |
| Cloud Functions | **tidak ada** | Lihat §6 — ada fitur yang jadi mustahil |

---

## 2. Yang bisa dikerjakan Firebase untuk app ini

Diurutkan dari yang paling berharga:

1. **Join yang benar-benar join.** Sekarang kode gabung hanya menyalin rencana;
   road captain tidak pernah tahu. Dengan RTDB, anggota menulis dirinya ke
   `/groups/{gid}/members/{uid}` dan RC langsung melihatnya.
2. **Lokasi live antar-HP.** Inti fitur yang sekarang tidak ada.
3. **Presence — siapa hilang sinyal.** RTDB punya `onDisconnect()`: server
   menandai rider offline otomatis saat koneksinya putus. Untuk touring di
   pegunungan ini sangat berguna, dan tidak ada layanan lain yang memberikannya
   segratis ini.
4. **Grup & rute tidak lagi terikat satu HP.** Ganti HP atau uninstall tidak
   menghilangkan data.
5. **Geometri rute dibagikan dari server.** Sekarang penerima kode harus
   menjalankan ulang OSRM. Dengan server, geometri disimpan sekali oleh RC dan
   diunduh anggota — tidak perlu internet ke OSRM di sisi anggota.
6. **Riwayat kejadian bersama.** Log SOS/berhenti/checkpoint dilihat semua
   anggota, bukan per HP.
7. **SOS realtime** — dengan batasan penting di §6.
8. **Rekap akhir bersama** dari track yang sudah diperkecil (§4).

Yang **tidak** perlu dipindah ke Firebase: preferensi tema, grup aktif yang
sedang dipilih, dan cache rute untuk dipakai offline. Itu tetap di
SharedPreferences — server jadi sumber kebenaran, penyimpanan lokal jadi cache.

---

## 3. Bentuk data

```
/groups/{gid}
  meta/
    displayId : "GRC-2026"        // yang dilihat manusia
    name      : "Bromo Etape 2"
    club      : "Garuda Rider Club"
    whenMs    : 1785000000000
    rcUid     : "<uid>"           // pemilik; hanya dia boleh ubah meta & rute
    createdMs : 1785000000000
    closedMs  : null              // terisi saat touring ditutup

  stops/{i}                       // sumber kebenaran rute
    l   : "Rest Area Tumpang"
    lat : -8.0092
    lng : 112.7180

  route/
    km      : 43.2
    minutes : 96
    geom    : "}_ozAgqk|R..."     // encoded polyline, bukan array titik
    idx/{i} : 412                 // indeks tiap stop di dalam geom

  members/{uid}
    name     : "Rizky Nugroho"
    plat     : "N 7 GH"
    role     : "RIDER"            // RC | SWP | MRSHL | RIDER
    joinedMs : 1785000000000

  live/{uid}                      // node cepat, dipisah dari members
    lat    : -8.0092
    lng    : 112.7180
    s      : 52                   // km/j
    b      : 78                   // baterai %
    h      : 118                  // arah, derajat
    t      : 1785000000000
    online : true                 // di-set false oleh onDisconnect()

  sos/{uid}
    lat, lng, t
    note       : "bocor, butuh tambal"
    resolvedMs : null

  log/{pushId}
    t, title, body, color

  track/{uid}/{i}                 // opsional, untuk rekap; lihat §4
    lat, lng, t
```

Dua keputusan yang menentukan:

**`route/geom` sebagai encoded polyline, bukan array.** Rute 43 km dari OSRM
punya ~2000 titik. Sebagai array JSON itu ~60 KB; sebagai encoded polyline
~10 KB. Enam kali lebih kecil di penyimpanan **dan** di setiap unduhan anggota.
Formatnya standar (algoritma Google), dan paket `flutter_polyline_points` sudah
bisa membacanya.

**`live/` dipisah dari `members/`.** Anggota hanya mendengarkan `live/` yang
berubah tiap beberapa detik, dan `members/` yang hampir tidak pernah berubah
cukup diambil sekali. Kalau digabung, tiap kiriman GPS ikut menarik nama, nopol,
dan peran — pemborosan kuota yang tidak perlu.

---

## 4. Riwayat posisi: jangan simpan mentah

Menyimpan posisi tiap 5 detik untuk 50 rider selama 4 jam = 144.000 record.
Itu bukan masalah penyimpanan (masih kecil dibanding 1 GB), tapi masalah
**kuota unduhan** kalau ada yang membacanya, dan masalah kerapian.

Untuk rekap, cukup simpan track yang sudah diperkecil: satu titik tiap **200 m
perjalanan**, bukan tiap satuan waktu. Rute 100 km = 500 titik per rider ≈
10 KB. Itu cukup untuk menggambar garis rekap dan menghitung statistik.

Aturannya: `live/` untuk yang sekarang, `track/` untuk kenang-kenangan,
tidak ada yang di antaranya.

---

## 5. Hitungan kuota unduhan

Asumsi: 50 rider, tiap HP mendengarkan posisi 49 lainnya, satu record posisi
≈ 100 byte setelah overhead protokol.

| Interval kirim | Unduhan/detik | Per jam | Ride 4 jam | Ride/bulan dalam 10 GB |
|---|---|---|---|---|
| tiap 5 detik | 49 KB | 176 MB | **706 MB** | ~14 |
| tiap 10 detik | 25 KB | 88 MB | **353 MB** | ~28 |
| tiap 10 detik + hanya bila bergeser >25 m | ~15 KB | 53 MB | **212 MB** | ~47 |

Perhitungan interval 5 detik: 50 rider ÷ 5 detik = 10 tulis/detik, tiap tulis
dikirim ke 49 pendengar = 490 pengiriman/detik × 100 byte ≈ 49 KB/detik.

**Rekomendasi:** interval 10 detik, dan lewati pengiriman kalau posisi bergeser
kurang dari 25 m. Rider yang sedang berhenti tidak perlu menghabiskan kuota.
Dengan itu klub bisa touring ~47 kali sebulan sebelum menyentuh batas — jauh di
atas kebutuhan nyata.

Kalau nanti kurang, penghematan berikutnya: anggota biasa cukup mendengarkan
posisi RC dan sweeper saja (2 node, bukan 49), sedangkan RC yang mendengarkan
semua. Itu memotong unduhan hampir 95%, dengan konsekuensi anggota biasa tidak
melihat 50 marker.

---

## 6. Yang tidak bisa tanpa Cloud Functions

Cloud Functions butuh paket Blaze. Tanpa itu:

- **Notifikasi SOS ke HP yang app-nya tertutup: tidak bisa.** Mengirim FCM butuh
  kredensial server, dan itu tidak boleh ada di dalam app. SOS hanya sampai ke
  HP yang app-nya terbuka dan listener-nya hidup. **Ini batasan serius untuk
  fitur darurat** — HT atau telepon tetap wajib jadi jalur utama, dan itu harus
  dikatakan jelas di dalam app, bukan disembunyikan.
- **Tidak ada pembersihan otomatis** grup lama atau node `live/` yatim.
  Gantinya: RC menghapus grup dari app, dan `onDisconnect()` menangani status
  offline.
- **Validasi hanya lewat Security Rules.** Ini sebetulnya cukup kuat (lihat §7),
  tapi tidak bisa melakukan hal yang butuh logika, mis. memanggil OSRM di sisi
  server.

Kalau notifikasi SOS saat app tertutup jadi kebutuhan wajib, itu satu-satunya
alasan kuat naik ke Blaze. Blaze punya kuota gratis yang sama besar; biayanya
nol sampai pemakaian melewatinya, tapi butuh kartu kredit terpasang.

---

## 7. Keamanan

### Masalah sekarang

```json
{ "rules": { ".read": true, ".write": true } }
```

Siapa pun yang tahu hostname database bisa membaca seluruh isinya dan
menghapusnya. Hostname itu bukan rahasia — ia ikut tertanam di dalam app dan
terlihat di screenshot konsol. **Ganti sebelum ada data nyata.**

### Autentikasi

**Anonymous sign-in.** Rider tidak perlu daftar apa pun — app memanggil
`signInAnonymously()` sekali, dan Firebase memberi `uid` tetap yang bertahan
selama app tidak dihapus. Ini pas untuk app touring: nol gesekan, tapi rules
tetap bisa membedakan siapa menulis apa.

Aktifkan di konsol: **Authentication → Sign-in method → Anonymous → Enable**.

Konsekuensi yang harus diterima: uid hilang kalau app dihapus, jadi rider yang
install ulang akan tampil sebagai anggota baru. Kalau itu mengganggu, naikkan ke
sign-in Google nanti — `linkWithCredential` bisa menyambung akun anonim yang
sudah ada tanpa kehilangan data.

### Group ID sebagai kunci

`GRC-2026` terlalu mudah ditebak untuk jadi satu-satunya penjaga: 24³ × 9000 ≈
124 juta kombinasi, dan rules tidak bisa membatasi laju percobaan.

Karena itu pisahkan dua hal:

- `displayId` — `GRC-2026`, untuk dilihat manusia, boleh ditebak
- `gid` — 16 karakter acak, dipakai sebagai path database, **inilah rahasianya**

Kode gabung memuat `gid`. Modelnya sama seperti tautan Google Meet: yang
memegang tautan boleh masuk. Sederhana, tanpa server, dan cukup untuk kasus ini.

### Rules yang diusulkan

```json
{
  "rules": {
    "groups": {
      "$gid": {
        // Hanya anggota yang boleh membaca grup.
        ".read": "auth != null && data.child('members').child(auth.uid).exists()",

        "meta": {
          // Grup baru: penulis harus mendaftarkan dirinya sebagai rcUid.
          // Grup lama: hanya RC boleh ubah.
          ".write": "auth != null && ((!data.exists() && newData.child('rcUid').val() === auth.uid) || data.child('rcUid').val() === auth.uid)",
          "name":   { ".validate": "newData.isString() && newData.val().length <= 60" },
          "club":   { ".validate": "newData.isString() && newData.val().length <= 60" },
          "whenMs": { ".validate": "newData.isNumber()" }
        },

        // Rute hanya boleh diubah road captain.
        "stops": { ".write": "auth != null && data.parent().child('meta/rcUid').val() === auth.uid" },
        "route": { ".write": "auth != null && data.parent().child('meta/rcUid').val() === auth.uid" },

        "members": {
          "$uid": {
            // Tiap orang menulis dirinya sendiri; RC boleh mengubah siapa pun
            // (untuk menetapkan peran) dan mengeluarkan anggota.
            ".write": "auth != null && ($uid === auth.uid || data.parent().parent().child('meta/rcUid').val() === auth.uid)",
            // Peran khusus hanya boleh diberikan RC — anggota tidak bisa
            // mengangkat dirinya jadi road captain.
            "role": { ".validate": "newData.val() === 'RIDER' || root.child('groups/' + $gid + '/meta/rcUid').val() === auth.uid" },
            "name": { ".validate": "newData.isString() && newData.val().length <= 40" },
            "plat": { ".validate": "newData.isString() && newData.val().length <= 15" }
          }
        },

        "live": {
          "$uid": {
            // Posisi hanya boleh ditulis pemiliknya, dan hanya kalau dia anggota.
            ".write": "auth != null && $uid === auth.uid && root.child('groups/' + $gid + '/members/' + auth.uid).exists()",
            "lat": { ".validate": "newData.isNumber() && newData.val() >= -90 && newData.val() <= 90" },
            "lng": { ".validate": "newData.isNumber() && newData.val() >= -180 && newData.val() <= 180" },
            "t":   { ".validate": "newData.isNumber()" }
          }
        },

        "sos": {
          "$uid": {
            // Rider mengirim SOS-nya sendiri; RC boleh menandai selesai.
            ".write": "auth != null && ($uid === auth.uid || data.parent().parent().child('meta/rcUid').val() === auth.uid)"
          }
        },

        "log":   { "$id": { ".write": "auth != null && root.child('groups/' + $gid + '/members/' + auth.uid).exists()" } },
        "track": { "$uid": { ".write": "auth != null && $uid === auth.uid" } }
      }
    }
  }
}
```

Satu lubang yang disengaja: pendaftaran mandiri. Karena `.read` menuntut
keanggotaan sedangkan calon anggota belum jadi anggota, alurnya adalah
**tulis dulu, baru baca** — dia menulis `members/{uid}` miliknya, setelah itu
grupnya bisa dibaca. Yang menjaga pintu adalah `gid` yang tidak bisa ditebak.

Sebelum dipasang, uji tiap aturan di **Rules playground** (tombolnya ada di
halaman Rules): coba tulis `live/` orang lain, coba angkat diri jadi RC, coba
baca grup tanpa jadi anggota. Ketiganya harus ditolak.

---

## 8. Paket Flutter yang dibutuhkan

```yaml
firebase_core: ^4.x        # wajib
firebase_auth: ^6.x        # anonymous sign-in
firebase_database: ^12.x   # RTDB
geolocator: ^14.x          # GPS + izin lokasi
flutter_polyline_points    # baca/tulis encoded polyline
```

Plus konfigurasi: jalankan `flutterfire configure` untuk membuat
`firebase_options.dart`, tambahkan `google-services.json` ke
`android/app/`, dan izin `ACCESS_FINE_LOCATION` +
`FOREGROUND_SERVICE_LOCATION` di manifest.

Untuk kiriman GPS saat app di background, Android butuh **foreground service**
dengan notifikasi permanen. Tanpa itu, Android akan menghentikan pengiriman
beberapa menit setelah layar mati — dan touring berjam-jam dengan layar menyala
akan menghabiskan baterai.

---

## 9. Bagaimana kodenya berubah

Yang membuat ini tidak semahal kelihatannya: `TripState` sudah jadi satu-satunya
sumber state, dan `store.dart` sudah jadi satu-satunya jalur simpan/muat.
Firebase masuk di belakang keduanya, bukan disebar ke layar-layar.

| Berkas | Perubahan |
|---|---|
| `store.dart` | Tetap ada sebagai cache offline. Tambah `cloud.dart` di sebelahnya |
| `cloud.dart` (baru) | Semua panggilan Firebase: auth, baca/tulis grup, stream `live/`, `onDisconnect` |
| `location.dart` (baru) | Ambil GPS, saring <25 m, kirim tiap 10 detik |
| `data.dart` | `riders` diisi dari stream `live/` alih-alih timer simulasi. Grup demo tetap pakai simulasi supaya app bisa dicoba tanpa jaringan |
| `model.dart` | Tambah `gid`, `rcUid`; `geometry` disimpan sebagai encoded polyline |
| layar-layar | Nyaris tidak berubah — `trip.live` sudah jadi penjaganya, sekarang artinya "ada data server" bukan "ini grup demo" |

Usul tahapan, tiap tahap berdiri sendiri dan bisa dipakai:

1. **Rules + Anonymous auth + grup/rute di server.** Belum ada GPS. Hasilnya:
   join sungguhan, RC melihat anggota masuk, data tidak hilang ganti HP. Ini
   sudah menutup gap yang kamu tanyakan.
2. **Lokasi live foreground.** GPS jalan saat app terbuka. Inti fiturnya.
3. **Presence + SOS realtime.** `onDisconnect`, banner SOS ke semua anggota.
4. **Foreground service** supaya lokasi tetap terkirim saat layar mati.
5. **Track + rekap bersama.**

Tahap 1 saja sudah mengubah app ini dari perencana jadi app grup yang benar.

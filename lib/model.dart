import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart' hide Path;

import 'polyline.dart';

// Warna disimpan sebagai int agar model bebas dari Flutter UI.
const kAcc = 0xFFFF6B1F;
const kOk = 0xFF35D07F;
const kWarn = 0xFFFFC043;
const kGrey = 0xFF8B95A3;
const kBad = 0xFFFF3B30;

// roundResult:false WAJIB. Default Distance() membulatkan hasilnya ke satuan
// bulat, jadi as(Kilometer) pada segmen 40 m mengembalikan 0 — dan rute hasil
// snap ke jalan punya titik tiap ~40 m, sehingga total jaraknya jadi 0 km.
const _dist = Distance(roundResult: false);

/// Satu tujuan yang dipilih pengguna. Ini sumber kebenaran rute — geometri
/// jalan cuma hasil turunan dari mesin rute, jadi kode bagikan cukup memuat
/// stop.
class Stop {
  Stop(this.label, this.at);
  String label;
  LatLng at;

  Map<String, dynamic> toJson() => {
        'l': label,
        'a': [at.latitude, at.longitude],
      };

  static Stop fromJson(Map<String, dynamic> j) => Stop(
        j['l'] as String,
        LatLng((j['a'][0] as num).toDouble(), (j['a'][1] as num).toDouble()),
      );
}

/// Titik bernama pada geometri rute, dipakai untuk label peta & checkpoint.
class Waypoint {
  final int at;
  final String label;
  const Waypoint(this.at, this.label);
}

/// Moda perjalanan. Menentukan jalan mana yang boleh dilewati saat rute
/// disusun — sama seperti pilihan kendaraan di Google Maps.
enum TripMode {
  /// **Tanpa tol.** Di Indonesia motor dilarang masuk jalan tol, jadi memakai
  /// profil mobil untuk motor bukan cuma kurang pas — hasilnya melanggar
  /// aturan dan tidak bisa dijalani.
  motor,

  /// Tol diperbolehkan, dicarikan yang tercepat.
  mobil,
  sepeda,
  lari,
}

extension TripModeX on TripMode {
  String get label => switch (this) {
        TripMode.motor => 'Motor',
        TripMode.mobil => 'Mobil',
        TripMode.sepeda => 'Sepeda',
        TripMode.lari => 'Lari',
      };

  String get note => switch (this) {
        TripMode.motor => 'Hindari tol',
        TripMode.mobil => 'Boleh tol, cari tercepat',
        TripMode.sepeda => 'Jalur sepeda',
        TripMode.lari => 'Jalur pejalan',
      };

  /// Nama costing di Valhalla.
  String get costing => switch (this) {
        TripMode.motor => 'motorcycle',
        TripMode.mobil => 'auto',
        TripMode.sepeda => 'bicycle',
        TripMode.lari => 'pedestrian',
      };

  Map<String, Object?> get costingOptions => switch (this) {
        TripMode.motor => {'use_tolls': 0},
        TripMode.mobil => {'use_tolls': 1},
        _ => const {},
      };

  /// Untuk disimpan; nama enum dipakai apa adanya.
  String get key => name;

  static TripMode fromKey(String? k) => TripMode.values
      .firstWhere((m) => m.name == k, orElse: () => TripMode.motor);
}

const roleOrder = ['RC', 'SWP', 'MRSHL', 'RIDER'];
const roleNames = {
  'RC': 'Road Captain',
  'SWP': 'Sweeper',
  'MRSHL': 'Marshal',
  'RIDER': 'Rider',
};

class Member {
  Member({
    required this.name,
    required this.plat,
    required this.role,
    this.uid,
    this.hp = '',
  });

  String name;
  String plat;
  String role;

  /// Nomor HP, opsional. Dipakai tombol Telepon saat dia kirim SOS.
  String hp;

  /// uid Firebase pemilik baris ini. Null untuk anggota yang hanya ada di HP
  /// ini, mis. grup yang dibuat sebelum tersambung ke server.
  String? uid;

  Map<String, dynamic> toJson() =>
      {'n': name, 'p': plat, 'r': role, if (uid != null) 'u': uid, if (hp.isNotEmpty) 'h': hp};

  static Member fromJson(Map<String, dynamic> j) => Member(
        name: j['n'] as String,
        plat: j['p'] as String,
        role: j['r'] as String,
        uid: j['u'] as String?,
        hp: j['h'] as String? ?? '',
      );
}

class TripGroup {
  TripGroup({
    required this.id,
    required this.name,
    required this.club,
    required this.when,
    this.gid,
    this.rcUid,
    List<Stop>? stops,
    List<LatLng>? geometry,
    List<int>? stopIndices,
    this.km = 0,
    this.minutes = 0,
    this.mode = TripMode.motor,
    List<Member>? members,
  })  : stops = stops ?? [],
        geometry = geometry ?? [],
        stopIndices = stopIndices ?? [],
        members = members ?? [];

  /// Yang dilihat manusia, mis. `GRC-2026`. Boleh ditebak.
  String id;
  String name;
  String club;
  DateTime when;

  /// Kunci grup di server: 16 karakter acak, sekaligus rahasianya. Yang
  /// memegangnya boleh masuk — modelnya seperti tautan Google Meet, karena
  /// Security Rules tidak bisa membatasi laju percobaan tebakan.
  /// Null berarti grup ini hanya ada di HP ini, mis. dibuat saat offline.
  String? gid;

  /// uid pemilik grup. Hanya dia yang boleh mengubah rute dan peran anggota.
  String? rcUid;

  bool get onCloud => gid != null;

  /// Anggota yang dikeluarkan: uid → nama, **hanya di HP ini**.
  ///
  /// Server memang punya `banned/{uid}`, tapi Rules membatasi nilainya ke
  /// boolean sehingga namanya tidak bisa ikut disimpan. Nama disimpan di sini
  /// supaya road captain melihat siapa yang dicekal, bukan sederet uid. Cuma RC
  /// yang boleh membatalkan cekalan, dan RC itu orang yang mengeluarkannya —
  /// jadi HP-nya memang HP yang tepat untuk menyimpan daftar ini.
  final banned = <String, String>{};

  List<Stop> stops;

  /// Geometri jalan dari mesin rute. Kosong berarti rute belum disusun.
  List<LatLng> geometry;
  List<int> stopIndices;
  double km;
  int minutes;

  /// Moda perjalanan grup ini — menentukan jalan mana yang dipakai saat rute
  /// disusun ulang.
  TripMode mode;

  List<Member> members;

  bool get hasRoute => geometry.length >= 2 && stopIndices.length == stops.length;

  List<Waypoint> get waypoints => [
        for (var i = 0; i < stops.length; i++)
          Waypoint(stopIndices[i], stops[i].label),
      ];

  /// Jarak tempuh (km) sampai stop ke-[i] sepanjang geometri jalan.
  double stopKmAt(int i) {
    if (!hasRoute || i <= 0) return 0;
    final end = stopIndices[i].clamp(0, geometry.length - 1);
    var km = 0.0;
    for (var j = 0; j < end; j++) {
      km += _dist.as(LengthUnit.Kilometer, geometry[j], geometry[j + 1]);
    }
    return km;
  }

  Member? get roadCaptain =>
      members.where((m) => m.role == 'RC').firstOrNull;
  Member? get sweeper => members.where((m) => m.role == 'SWP').firstOrNull;

  /// Apa yang masih kurang sebelum grup siap dipakai touring.
  List<String> get todo => [
        if (!hasRoute) 'Rute belum disusun',
        if (members.isEmpty) 'Belum ada anggota',
        if (members.isNotEmpty && roadCaptain == null)
          'Belum ada road captain',
      ];

  bool get ready => todo.isEmpty;

  /// Timpa isi grup ini dengan data dari [other], **tanpa menukar objeknya.**
  ///
  /// Layar-layar memegang referensi TripGroup, jadi mengganti objek di
  /// `trip.groups` membuat referensi mereka jadi yatim — dulu itu bikin layar
  /// detail grup jadi hitam blank begitu data server masuk. Identitas objek
  /// dijaga tetap, isinya saja yang menyusul.
  void applyFrom(TripGroup other) {
    id = other.id;
    gid = other.gid;
    rcUid = other.rcUid;
    name = other.name;
    club = other.club;
    when = other.when;
    stops = other.stops;
    geometry = other.geometry;
    stopIndices = other.stopIndices;
    km = other.km;
    minutes = other.minutes;
    mode = other.mode;
    members = other.members;
    // `banned` sengaja TIDAK disalin. Daftar itu hanya ada di HP ini: server
    // menyimpan cekalan sebagai `banned/{uid}: true` tanpa nama (Rules-nya
    // memang membatasi nilainya ke boolean), jadi salinan server selalu kosong
    // dan menyalinnya akan menghapus nama-namanya tiap snapshot masuk.
  }

  /// Untuk cache lokal. Geometri disimpan sebagai encoded polyline — bentuk
  /// yang sama seperti di server, jadi tidak ada konversi bolak-balik.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (gid != null) 'gid': gid,
        if (rcUid != null) 'rcUid': rcUid,
        'name': name,
        'club': club,
        'when': when.toIso8601String(),
        'stops': [for (final s in stops) s.toJson()],
        'geom': encodePolyline(geometry),
        'idx': stopIndices,
        'km': km,
        'min': minutes,
        'mode': mode.key,
        'members': [for (final m in members) m.toJson()],
        if (banned.isNotEmpty) 'banned': banned,
      };

  static TripGroup fromJson(Map<String, dynamic> j) => TripGroup(
        id: j['id'] as String,
        gid: j['gid'] as String?,
        rcUid: j['rcUid'] as String?,
        name: j['name'] as String,
        club: j['club'] as String,
        when: DateTime.parse(j['when'] as String),
        stops: [
          for (final s in (j['stops'] as List))
            Stop.fromJson(s as Map<String, dynamic>),
        ],
        geometry: decodePolyline(j['geom'] as String? ?? ''),
        stopIndices: [for (final i in (j['idx'] as List)) i as int],
        km: (j['km'] as num).toDouble(),
        minutes: j['min'] as int,
        mode: TripModeX.fromKey(j['mode'] as String?),
        members: [
          for (final m in (j['members'] as List))
            Member.fromJson(m as Map<String, dynamic>),
        ],
      )..banned.addAll({
          for (final e in (j['banned'] as Map? ?? const {}).entries)
            e.key as String: e.value as String,
        });

  /// Kode gabung. Bidang dipisah `|`, waktu jadi menit-epoch, lalu di-base64url
  /// supaya jadi satu blob yang aman disalin lewat WhatsApp.
  ///
  /// Ada dua bentuk:
  ///
  /// - **v3, grup di server** — hanya kunci grup + identitas untuk ditampilkan
  ///   sebelum bergabung. Rute dan anggota diambil dari server, jadi titiknya
  ///   tidak perlu ikut dan kodenya jadi ~3× lebih pendek.
  /// - **v2, grup lokal** — belum ada di server, jadi daftar titik harus ikut.
  ///   Koordinat dibulatkan ke 5 desimal (± 1 m) dan ditulis sebagai selisih
  ///   dari titik sebelumnya dalam basis 36.
  String get shareCode => gid != null ? _cloudCode(gid!) : _localCode();

  /// Yang dibagikan ke anggota. Grup baru memakai kode pendek `TRG-XXXXXX`
  /// yang memang kunci servernya; grup lama (kunci 16 karakter) masih memakai
  /// kode panjang yang ditempel.
  String get inviteCode =>
      gid != null && isInviteCode(gid!) ? gid! : shareCode;

  String _cloudCode(String key) => _pack(
        StringBuffer()
          ..write('3|')
          ..write(key)
          ..write('|')
          ..write(id)
          ..write('|')
          ..write(_clean(name))
          ..write('|')
          ..write(_clean(club))
          ..write('|')
          ..write(when.millisecondsSinceEpoch ~/ 60000),
      );

  String _localCode() {
    final b = StringBuffer()
      ..write('2|')
      ..write(id)
      ..write('|')
      ..write(_clean(name))
      ..write('|')
      ..write(_clean(club))
      ..write('|')
      ..write(when.millisecondsSinceEpoch ~/ 60000)
      ..write('|');

    var prevLat = 0, prevLng = 0;
    for (var i = 0; i < stops.length; i++) {
      final lat = (stops[i].at.latitude * 1e5).round();
      final lng = (stops[i].at.longitude * 1e5).round();
      if (i > 0) b.write(';');
      b
        ..write(_clean(stops[i].label))
        ..write(',')
        ..write((lat - prevLat).toRadixString(36))
        ..write(',')
        ..write((lng - prevLng).toRadixString(36));
      prevLat = lat;
      prevLng = lng;
    }
    return _pack(b);
  }

  /// Padding '=' dibuang: sering hilang atau bikin kacau saat disalin.
  static String _pack(StringBuffer b) =>
      base64Url.encode(utf8.encode(b.toString())).replaceAll('=', '');

  /// Pemisah bidang tidak boleh muncul di dalam teks, dan label yang panjang
  /// hanya memanjangkan kode tanpa menambah kejelasan.
  static String _clean(String s) {
    final t = s.replaceAll(RegExp(r'[|;,]'), ' ').trim();
    return t.length <= 28 ? t : t.substring(0, 28).trim();
  }

  /// Baca kode bagikan. Melempar [FormatException] kalau kodenya rusak.
  static TripGroup fromShareCode(String code) {
    final clean = code.trim().replaceAll(RegExp(r'\s'), '');
    if (clean.isEmpty) throw const FormatException('Kode kosong.');

    final String raw;
    try {
      raw = utf8.decode(base64Url.decode(base64Url.normalize(clean)));
    } catch (_) {
      throw const FormatException('Kode grup tidak dikenali.');
    }

    // Kode versi 1 (JSON) masih diterima supaya kode lama tidak mati.
    if (raw.startsWith('{')) return _fromJsonCode(raw);
    if (raw.startsWith('3|')) return _fromCloudCode(raw);
    if (!raw.startsWith('2|')) {
      throw const FormatException('Kode dibuat versi app yang berbeda.');
    }

    final parts = raw.split('|');
    if (parts.length != 6) {
      throw const FormatException('Kode grup tidak lengkap.');
    }
    try {
      var prevLat = 0, prevLng = 0;
      final stops = <Stop>[];
      if (parts[5].isNotEmpty) {
        for (final chunk in parts[5].split(';')) {
          final f = chunk.split(',');
          if (f.length != 3) throw const FormatException('titik rusak');
          prevLat += int.parse(f[1], radix: 36);
          prevLng += int.parse(f[2], radix: 36);
          stops.add(Stop(f[0], LatLng(prevLat / 1e5, prevLng / 1e5)));
        }
      }
      return TripGroup(
        id: parts[1],
        name: parts[2],
        club: parts[3],
        when: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]) * 60000),
        stops: stops,
      );
    } catch (_) {
      throw const FormatException('Kode grup rusak, minta dikirim ulang.');
    }
  }

  /// Kode grup di server: rute dan anggota belum ada di sini, tapi identitasnya
  /// cukup untuk ditampilkan sebelum bergabung — dan tetap terbaca kalau
  /// pengambilan dari server gagal.
  static TripGroup _fromCloudCode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 6) {
      throw const FormatException('Kode grup tidak lengkap.');
    }
    if (parts[1].isEmpty) {
      throw const FormatException('Kode grup tidak memuat kunci server.');
    }
    try {
      return TripGroup(
        gid: parts[1],
        id: parts[2],
        name: parts[3],
        club: parts[4],
        when: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[5]) * 60000),
      );
    } catch (_) {
      throw const FormatException('Kode grup rusak, minta dikirim ulang.');
    }
  }

  static TripGroup _fromJsonCode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['v'] != 1) {
        throw const FormatException('Kode dibuat versi app yang berbeda.');
      }
      return TripGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        club: j['club'] as String,
        when: DateTime.parse(j['when'] as String),
        stops: [
          for (final s in (j['stops'] as List? ?? []))
            Stop.fromJson(s as Map<String, dynamic>),
        ],
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Kode grup rusak, minta dikirim ulang.');
    }
  }
}

/// Status rider. Urutan deklarasi menentukan urutan tampil — yang paling
/// perlu perhatian lebih dulu.
enum RiderStatus { sos, hilang, tertinggal, berhenti, aman }

extension RiderStatusX on RiderStatus {
  String get label => switch (this) {
        RiderStatus.sos => 'SOS',
        RiderStatus.hilang => 'HILANG',
        RiderStatus.tertinggal => 'TERTINGGAL',
        RiderStatus.berhenti => 'BERHENTI',
        RiderStatus.aman => 'AMAN',
      };

  /// Memakai kelima warna palet apa adanya, tanpa menambah warna baru: merah
  /// hanya untuk SOS, oranye untuk hilang sinyal supaya terbaca mendesak tapi
  /// tidak tertukar dengan darurat.
  int get color => switch (this) {
        RiderStatus.sos => kBad,
        RiderStatus.hilang => kAcc,
        RiderStatus.tertinggal => kWarn,
        RiderStatus.berhenti => kGrey,
        RiderStatus.aman => kOk,
      };

  int get rank => index;
}

class Rider {
  Rider({
    required this.id,
    required this.name,
    required this.plat,
    required this.role,
    required this.p,
    required this.v,
    required this.batt,
    this.uid,
  });

  final int id;

  /// uid Firebase pemiliknya. Dipakai untuk
  /// mencocokkan dengan posisi dari server — jangan cocokkan lewat nama,
  /// dua anggota bisa bernama sama.
  final String? uid;
  final String name;
  final String plat;
  final String role;

  /// Progres di rute, 0..1.
  double p;

  /// Kecepatan km/j.
  double v;

  /// Null berarti HP-nya tidak melaporkan baterai — tampilkan "—", jangan 0%.
  int? batt;

  // Turunan, diisi ulang tiap kiriman posisi dari server.
  RiderStatus status = RiderStatus.aman;
  double behindKm = 0;
  LatLng pos = const LatLng(0, 0);
  double head = 0;

  /// Sejak kapan posisinya tidak diperbarui.
  Duration? staleness;
}

/// Jejak yang sudah dilalui satu anggota, apa adanya dari server.
///
/// Beda dari [Track] milik sendiri: yang ini cuma untuk digambar, jadi tidak
/// membawa waktu per-titik maupun kecepatan maksimum. Rekap tetap dihitung dari
/// jejak sendiri, karena hanya jejak itu yang lengkap.
class MateTrack {
  const MateTrack({required this.points, required this.km, required this.atMs});

  final List<LatLng> points;
  final double km;

  /// Kapan terakhir diperbarui, milidetik epoch.
  final int atMs;
}

/// Satu kiriman posisi dari HP anggota, apa adanya dari server.
class LivePos {
  const LivePos({
    required this.at,
    required this.speedKmh,
    required this.heading,
    required this.battery,
    required this.atMs,
    required this.online,
  });

  final LatLng at;
  final double speedKmh;
  final double heading;

  /// Null berarti HP-nya tidak melaporkan baterai.
  final int? battery;

  /// Kapan posisi ini dikirim, milidetik epoch.
  final int atMs;

  /// Di-set false oleh server lewat onDisconnect saat koneksinya putus.
  final bool online;

  /// Umur data. Posisi lama berarti sinyalnya bermasalah walau `online` masih
  /// true — onDisconnect butuh beberapa detik untuk dieksekusi server.
  Duration age(DateTime now) =>
      now.difference(DateTime.fromMillisecondsSinceEpoch(atMs));

  /// Dianggap hilang kalau server bilang offline, atau kiriman terakhirnya
  /// sudah lewat 90 detik (9× interval kirim — cukup longgar untuk sinyal
  /// jelek di pegunungan tanpa langsung bikin alarm palsu).
  bool stale(DateTime now) => !online || age(now) > const Duration(seconds: 90);
}

class LogEntry {
  LogEntry(this.time, this.title, this.body, this.color);
  final String time, title, body;
  final int color;

  Map<String, dynamic> toJson() =>
      {'t': time, 'ti': title, 'b': body, 'c': color};

  static LogEntry fromJson(Map<String, dynamic> j) => LogEntry(
        j['t'] as String,
        j['ti'] as String,
        j['b'] as String,
        j['c'] as int,
      );
}

const _monthsId = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String fmtWhen(DateTime d) =>
    '${d.day} ${_monthsId[d.month - 1]} ${d.year} · ${fmtClock(d)}';

String fmtClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';

String fmtDur(int minutes) =>
    '${minutes ~/ 60}j ${(minutes % 60).toString().padLeft(2, "0")}m';

String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

String km1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Group ID acak. Huruf yang mudah tertukar (I, O) sengaja dibuang.
String newGroupId(math.Random rnd) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  final head = List.generate(3, (_) => letters[rnd.nextInt(letters.length)]);
  return '${head.join()}-${1000 + rnd.nextInt(8999)}';
}

/// Kunci anggota untuk grup yang belum ada di server, mis. dibuat saat offline.
/// Di grup server kuncinya selalu uid Firebase — Rules menuntut baris anggota
/// berada di `members/{auth.uid}`.
///
/// Setiap anggota wajib punya kunci: tanpa itu dia tidak bisa ditulis ke
/// `members/` dan akan lenyap begitu snapshot server masuk.
String newLocalMemberKey(math.Random rnd) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'lokal-'
      '${List.generate(12, (_) => alphabet[rnd.nextInt(alphabet.length)]).join()}';
}

double bearingDeg(LatLng a, LatLng b) => (_dist.bearing(a, b) + 360) % 360;

/// Tautan rute untuk dibuka di app Google Maps: titik pertama jadi asal,
/// terakhir tujuan, sisanya titik singgah. Gratis, tanpa API key.
///
/// Google Maps menerima paling banyak 9 titik singgah; kalau lebih, diambil
/// merata supaya bentuk rutenya tetap terwakili. Tol tidak bisa dihindari
/// lewat tautan — untuk motor, pilih "Hindari tol" di Google Maps-nya.
Uri googleMapsRoute(List<LatLng> titik, TripMode mode) {
  String ll(LatLng p) => '${p.latitude},${p.longitude}';
  final tengah = titik.length > 2 ? titik.sublist(1, titik.length - 1) : <LatLng>[];
  final singgah = tengah.length <= 9
      ? tengah
      : [for (var i = 0; i < 9; i++) tengah[(i * (tengah.length - 1) / 8).round()]];
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': ll(titik.first),
    'destination': ll(titik.last),
    if (singgah.isNotEmpty) 'waypoints': singgah.map(ll).join('|'),
    'travelmode': switch (mode) {
      TripMode.motor || TripMode.mobil => 'driving',
      TripMode.sepeda => 'bicycling',
      TripMode.lari => 'walking',
    },
  });
}

/// Kode undangan yang diketik anggota, sekaligus kunci grup di server.
/// 6 karakter tanpa huruf/angka yang gampang tertukar (I, O, 0, 1): ±1 miliar
/// kemungkinan — cukup untuk tidak ketemu dengan menebak-nebak.
String newInviteCode(math.Random rnd) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return 'TRG-${List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)]).join()}';
}

final _invite = RegExp(r'^TRG-?([A-Z2-9]{6})$');

bool isInviteCode(String s) => _invite.hasMatch(s);

/// Rapikan ketikan anggota: huruf besar, spasi dibuang, tanda hubung dipasang.
/// Null kalau bukan kode pendek — mungkin kode panjang versi lama.
String? normInviteCode(String raw) {
  final m = _invite.firstMatch(raw.replaceAll(RegExp(r'\s'), '').toUpperCase());
  return m == null ? null : 'TRG-${m.group(1)}';
}

/// Grup yang pernah kubuat sendiri. Kodenya disimpan di HP ini supaya road
/// captain yang keluar bisa masuk lagi tanpa diundang ulang — di server dia
/// tetap `rcUid`.
class CreatedGroupRef {
  CreatedGroupRef({
    required this.gid,
    required this.name,
    required this.club,
    required this.createdAt,
    required this.myName,
    required this.myPlat,
    this.leftAt,
  });

  final String gid;
  String name;
  String club;

  /// Identitasku di grup itu, dipakai lagi saat masuk kembali.
  final String myName;
  final String myPlat;
  final DateTime createdAt;

  /// Null berarti aku masih di dalam grupnya.
  DateTime? leftAt;

  Map<String, dynamic> toJson() => {
        'g': gid,
        'n': name,
        'c': club,
        'at': createdAt.millisecondsSinceEpoch,
        'mn': myName,
        'mp': myPlat,
        if (leftAt != null) 'left': leftAt!.millisecondsSinceEpoch,
      };

  static CreatedGroupRef fromJson(Map<String, dynamic> j) => CreatedGroupRef(
        gid: j['g'] as String,
        name: j['n'] as String,
        club: j['c'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        myName: j['mn'] as String? ?? 'Road Captain',
        myPlat: j['mp'] as String? ?? '',
        leftAt: j['left'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['left'] as int),
      );
}

/// Satu pesan obrolan grup: teks, atau pesan suara ([voiceSec] > 0).
/// Rekaman suaranya sendiri disimpan terpisah di `audio/{key}` dan baru
/// diunduh saat diputar, supaya membuka obrolan tidak menyedot kuota.
class ChatMsg {
  const ChatMsg({
    required this.key,
    required this.uid,
    required this.name,
    required this.text,
    required this.voiceSec,
    required this.atMs,
  });

  final String key;
  final String uid;
  final String name;
  final String text;
  final int voiceSec;
  final int atMs;

  bool get isVoice => voiceSec > 0;
  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);
}

/// "baru saja", "5 mnt lalu", "2 jam lalu".
String fmtAgo(Duration d) => d.inMinutes < 1
    ? 'baru saja'
    : d.inHours < 1
        ? '${d.inMinutes} mnt lalu'
        : d.inDays < 1
            ? '${d.inHours} jam lalu'
            : '${d.inDays} hari lalu';

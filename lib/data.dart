import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'cloud.dart';
import 'location.dart';
import 'model.dart';
import 'store.dart';
import 'track.dart';

export 'cloud.dart' show Cloud;
export 'location.dart' show LocationShareResult;
export 'model.dart';
export 'track.dart';

// roundResult:false WAJIB. Default Distance() membulatkan hasilnya ke satuan
// bulat, jadi as(Kilometer) pada segmen 40 m mengembalikan 0 — dan rute hasil
// snap ke jalan punya titik tiap ~40 m, sehingga total jaraknya jadi 0 km.
const _dist = Distance(roundResult: false);

// ── Rute aktif ──────────────────────────────────────────────────────────────
// Cache geometri grup aktif. Semua layar peta/rekap membaca dari sini; diisi
// oleh [setRoute] setiap grup aktif berganti atau rutenya diedit.

var route = <LatLng>[];
var waypoints = <Waypoint>[];
double totalKm = 0;

/// False kalau grup aktif belum punya rute — layar peta/rekap harus mengecek
/// ini sebelum memakai [route], [waypoints], atau [totalKm].
bool get routeReady => route.length >= 2;

class _Seg {
  _Seg(this.a, this.b, this.d, this.at);
  final LatLng a, b;
  final double d, at;
}

var _segs = <_Seg>[];

void setRoute(List<LatLng> points, List<Waypoint> wps) {
  assert(points.length >= 2, 'rute butuh minimal 2 titik');
  route = points;
  waypoints = wps;
  var t = 0.0;
  _segs = [];
  for (var i = 0; i < points.length - 1; i++) {
    final d = _dist.as(LengthUnit.Kilometer, points[i], points[i + 1]).toDouble();
    _segs.add(_Seg(points[i], points[i + 1], d, t));
    t += d;
  }
  totalKm = _segs.last.at + _segs.last.d;
}

void clearRoute() {
  route = [];
  waypoints = [];
  _segs = [];
  totalKm = 0;
}

/// Titik di rute pada progres [p] (0..1).
LatLng pointAt(double p) {
  if (!routeReady) return const LatLng(0, 0);
  final target = p.clamp(0.0, 1.0) * totalKm;
  for (final s in _segs) {
    if (target <= s.at + s.d || s == _segs.last) {
      final t = ((target - s.at) / s.d).clamp(0.0, 1.0);
      return LatLng(
        s.a.latitude + (s.b.latitude - s.a.latitude) * t,
        s.a.longitude + (s.b.longitude - s.a.longitude) * t,
      );
    }
  }
  return route.first;
}

/// Jarak kumulatif (km) sampai titik rute ke-[idx].
double distAt(int idx) {
  if (!routeReady || idx <= 0) return 0;
  final i = math.min(idx, _segs.length);
  return _segs[i - 1].at + _segs[i - 1].d;
}

/// Jarak tempuh rider di rute aktif. Hidup di data.dart karena butuh
/// [totalKm], sedangkan model.dart sengaja bebas dari state global.
extension RiderKm on Rider {
  double get km => p * totalKm;
}

// ── State ───────────────────────────────────────────────────────────────────

/// Satu-satunya sumber state. Global [trip] dipakai lewat ListenableBuilder —
/// tanpa paket state management.
class TripState extends ChangeNotifier {
  TripState({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  Timer? _timer;
  var _disposed = false;

  final groups = <TripGroup>[];
  String? activeId;
  final logs = <LogEntry>[];
  bool dark = true;

  /// Anggota yang posisinya diketahui dari server. Semua hitungan rombongan —
  /// leader, sweeper, rentang — memakai daftar ini saja.
  final riders = <Rider>[];

  /// Anggota yang sudah gabung tapi belum menyalakan berbagi lokasi. Sengaja
  /// dipisah dari [riders] supaya tidak merusak hitungan, tapi tetap
  /// ditampilkan — RC justru perlu tahu siapa yang belum menyalakan lokasi.
  final untracked = <Member>[];

  /// uid rider yang sedang minta bantuan, dan sejak kapan.
  ///
  /// Sengaja uid, BUKAN `Rider.id`. Rider.id itu indeks yang dibuat ulang tiap
  /// kiriman posisi dan hanya mencakup anggota yang sedang terlacak — begitu
  /// ada yang berhenti berbagi lokasi, indeksnya bergeser dan tanda SOS-nya
  /// pindah ke orang lain.
  String? sosUid;
  DateTime? sosAt;

  /// Muat cache lokal lalu sambungkan ke server. Panggil sebelum runApp.
  /// Idempoten: memanggil ulang memuat ulang dari nol, tidak menumpuk grup.
  ///
  /// Cache dibaca lebih dulu supaya app langsung terbuka walau offline; data
  /// server menyusul lewat [_watch] dan menimpa yang lokal.
  Future<void> init({Cloud? cloud}) async {
    _timer?.cancel();
    _timer = null;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _retried.clear();
    groups.clear();
    logs.clear();
    riders.clear();
    untracked.clear();
    _tracks.clear();
    sosUid = null;
    clearRoute();

    final saved = await loadState();
    if (saved != null && saved.groups.isNotEmpty) {
      groups.addAll(saved.groups);
      logs.addAll(saved.logs);
      dark = saved.dark;
      activeId = saved.activeId;
      _tracks.addAll(saved.tracks);
    }
    // Pemasangan baru tidak punya grup sama sekali. Shell menampilkan layar
    // "buat grup dulu" untuk keadaan itu — dulu di sini ada grup demo berisi 50
    // rider palsu, dan angka simulasinya bocor ke rekap serta kartu bagikan.
    if (!groups.any((g) => g.id == activeId)) {
      activeId = groups.isEmpty ? null : groups.first.id;
    }
    if (hasGroup) _activate();

    _cloud = cloud;
    if (cloud == null) return;
    await cloud.init();
    if (!cloud.ready) {
      notifyListeners();
      return;
    }
    for (final g in groups.where((g) => g.onCloud)) {
      _watch(g.gid!);
    }
    notifyListeners();
  }

  Cloud? _cloud;
  final _subs = <StreamSubscription<TripGroup>>[];

  /// gid yang sudah pernah dicoba daftarkan ulang — penjaga anti-loop.
  final _retried = <String>{};

  /// True kalau server tersambung. UI memakai ini untuk memberi tahu kapan
  /// grup baru akan dibagikan sungguhan dan kapan hanya lokal.
  bool get online => _cloud?.ready ?? false;
  String? get cloudError => _cloud?.error;
  String? get myUid => _cloud?.uid;

  /// True kalau aku road captain grup [g] — penentu apa yang boleh kuubah.
  /// Grup lokal selalu milikku sendiri.
  bool amRc(TripGroup g) =>
      !g.onCloud || g.rcUid == null || g.rcUid == myUid;

  /// Ikuti satu grup di server. Perubahan dari HP lain (anggota baru, rute
  /// diubah RC) masuk lewat sini.
  void _watch(String gid) {
    final cloud = _cloud;
    if (cloud == null || !cloud.ready) return;
    _subs.add(cloud.watchGroup(gid).listen(
      (fresh) {
        final mine = groups.where((g) => g.gid == gid).firstOrNull;
        if (mine == null) return;
        // Server adalah sumber kebenaran, tapi objeknya JANGAN ditukar —
        // layar yang sedang terbuka memegang referensi ini.
        mine.applyFrom(fresh);
        if (mine.id == activeId) _activate();
        _persist();
        notifyListeners();
      },
      onError: (Object e) {
        // Penolakan izin ditangani terpisah: artinya bisa "aku dikeluarkan"
        // atau "grupku belum terdaftar". Lihat [onAccessDenied].
        if (Cloud.isPermissionDenied(e)) {
          onAccessDenied(gid);
        } else {
          debugPrint('cloud: watch $gid gagal ($e)');
        }
      },
    ));
  }

  /// Server menolak membaca grup [gid]. Dua sebab yang sangat berbeda:
  ///
  /// - **Aku bukan RC-nya** → aku memang dikeluarkan, atau grupnya dihapus.
  ///   Salinan lokal dilepas, kalau tidak grupnya terus terlihat dengan data
  ///   basi selamanya.
  /// - **Aku RC-nya** → mustahil dikeluarkan dari grup sendiri, jadi yang
  ///   terjadi adalah pendaftarannya belum tuntas. Didaftarkan ulang.
  void onAccessDenied(String gid) {
    final g = groups.where((e) => e.gid == gid).firstOrNull;
    if (g == null) return;

    // Road captain tidak mungkin dikeluarkan dari grupnya sendiri. Penolakan
    // baca di grup sendiri berarti pendaftarannya ke server belum tuntas —
    // biasanya penulisan `members/{uid}` gagal dan kegagalannya ditelan _guard.
    //
    // Dulu grupnya langsung dihapus di sini, dan akibatnya orang yang baru
    // membuat grup terlempar kembali ke layar "buat grup" dengan pekerjaannya
    // hilang. Daftarkan ulang, jangan dibuang.
    if (amRc(g)) {
      // Sekali coba saja. Tanpa penjaga ini, pendaftaran yang terus ditolak
      // memicu watcher error → daftar ulang → error, berputar tanpa henti
      // sambil menumpuk langganan.
      if (_retried.add(gid)) {
        _log('Grup "${g.name}" belum terdaftar di server',
            'Mencoba mendaftarkan ulang', kWarn);
        _register(g);
      } else {
        g
          ..gid = null
          ..rcUid = null;
        _log('Grup "${g.name}" tidak bisa didaftarkan',
            'Tersimpan di HP ini saja — datanya tetap utuh', kWarn);
        _persist();
      }
      notifyListeners();
      return;
    }

    _log('Akses ke "${g.name}" dicabut',
        'Kamu dikeluarkan dari grup, atau grupnya dihapus road captain', kWarn);
    groups.remove(g);
    _tracks.remove(g.id);
    _reseat();
    _persist();
    notifyListeners();
  }

  /// Daftarkan (atau daftarkan ulang) [g] ke server. Kalau gagal, `gid`
  /// dilepas supaya grupnya jujur berstatus lokal dan bisa dicoba lagi —
  /// bukan menggantung sebagai "ada di server" padahal tidak.
  Future<void> _register(TripGroup g) async {
    final cloud = _cloud;
    if (cloud == null || !cloud.ready || g.gid == null) return;
    try {
      await cloud.createGroup(g);
      if (g.hasRoute) await cloud.putRoute(g);
      _watch(g.gid!);
      _log('Grup "${g.name}" terdaftar di server',
          'Kodenya sudah bisa dibagikan ke anggota', kOk);
    } catch (e) {
      debugPrint('cloud: pendaftaran ${g.gid} gagal ($e)');
      g
        ..gid = null
        ..rcUid = null;
      _log('Grup "${g.name}" belum bisa didaftarkan',
          'Tersimpan di HP ini saja. Coba lagi saat sinyal membaik.', kWarn);
    }
    _persist();
    notifyListeners();
  }

  /// Pilih grup aktif setelah daftar berubah. Boleh berakhir tanpa grup —
  /// Shell menampilkan layar "buat grup dulu" untuk keadaan itu.
  void _reseat() {
    if (!groups.any((e) => e.id == activeId)) {
      activeId = groups.isEmpty ? null : groups.first.id;
    }
    if (hasGroup) {
      _activate();
    } else {
      riders.clear();
      untracked.clear();
      _liveSub?.cancel();
      _liveSub = null;
      _sosSub?.cancel();
      _sosSub = null;
      _trackSub?.cancel();
      _trackSub = null;
      mateTracks.clear();
      _timer?.cancel();
      _timer = null;
      clearRoute();
    }
  }

  /// Hentikan timer penyegar status tanpa membuang state — dipakai saat app
  /// masuk background dan oleh test supaya tidak ada timer menggantung.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Idempoten: [trip] itu global, jadi beberapa pemakai boleh menutupnya.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pause();
    // Langganan ikut ditutup di sini, bukan di pause(): pause hanya menghentikan
    // penyegar status dan dipakai saat app ke latar belakang.
    _liveSub?.cancel();
    _liveSub = null;
    _sosSub?.cancel();
    _sosSub = null;
    _trackSub?.cancel();
    _trackSub = null;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  void _persist() => saveState(Saved(
        groups: groups,
        activeId: activeId,
        logs: logs,
        dark: dark,
        tracks: _tracks,
      ));

  // ── Grup ──────────────────────────────────────────────────────────────────

  /// False untuk pemasangan baru: belum ada grup sama sekali. Shell memeriksa
  /// ini dan menampilkan layar onboarding, sehingga layar-layar tab boleh
  /// menganggap [active] selalu ada.
  bool get hasGroup => groups.isNotEmpty;

  TripGroup? get activeOrNull => groups.isEmpty
      ? null
      : groups.firstWhere((g) => g.id == activeId, orElse: () => groups.first);

  /// Grup aktif. Melempar kalau belum ada grup — panggil hanya di belakang
  /// penjaga [hasGroup]. Lebih baik gagal terang-terangan daripada mengembalikan
  /// grup kosong yang angkanya menyesatkan.
  TripGroup get active {
    final g = activeOrNull;
    if (g == null) {
      throw StateError('Belum ada grup — periksa hasGroup dulu.');
    }
    return g;
  }

  /// True kalau ada posisi rider dari server yang bisa ditampilkan. Layar
  /// peta/tim/rekap memakai ini untuk memilih antara tampilan live dan rencana.
  ///
  /// Sengaja TIDAK menyertakan [routeReady]. Marker digambar di posisi GPS asli
  /// ([Rider.pos]), jadi melacak anggota sama sekali tidak butuh rute — dan
  /// dulu syarat itu membuat rombongan tidak pernah muncul di peta pada grup
  /// yang rutenya belum disusun. Angka yang memang butuh rute (rentang
  /// rombongan, ETA, progres) menjaga dirinya sendiri dengan [routeReady].
  bool get live => riders.isNotEmpty;

  void setActive(String id) {
    if (!groups.any((g) => g.id == id)) return;
    activeId = id;
    _activate();
    _persist();
    notifyListeners();
  }

  /// Pasang rute grup aktif ke cache global, lalu ikuti stream `live/` kalau
  /// grupnya ada di server. Satu-satunya sumber posisi adalah server — dulu ada
  /// jalur simulasi di sini, dan angkanya bocor ke rekap serta kartu bagikan.
  void _activate() {
    final g = active;
    if (g.hasRoute) {
      setRoute(g.geometry, g.waypoints);
    } else {
      clearRoute();
    }

    riders.clear();
    untracked.clear();
    _timer?.cancel();
    _timer = null;
    _liveSub?.cancel();
    _liveSub = null;
    _sosSub?.cancel();
    _sosSub = null;
    _trackSub?.cancel();
    _trackSub = null;
    mateTracks.clear();
    _livePos.clear();
    sosUid = null;
    sosAt = null;
    if (g.onCloud) _startLiveFeed(g);
  }

  // ── Lokasi live ───────────────────────────────────────────────────────────

  StreamSubscription<Map<String, LivePos>>? _liveSub;
  StreamSubscription<Map<String, int>>? _sosSub;
  StreamSubscription<Map<String, MateTrack>>? _trackSub;

  /// Jejak anggota lain, uid → garis yang sudah dilalui. Jejakku sendiri TIDAK
  /// di sini — itu ada di [track], yang lebih lengkap dan tidak perlu menunggu
  /// perjalanan bolak-balik ke server.
  final mateTracks = <String, MateTrack>{};

  /// Nama untuk uid, dari daftar anggota grup aktif. Dipakai peta untuk memberi
  /// label jejak orang lain.
  String mateName(String uid) =>
      activeOrNull?.members.where((m) => m.uid == uid).firstOrNull?.name ??
      'Anggota';
  final _livePos = <String, LivePos>{};
  LocationSharer? _sharer;

  /// True kalau GPS sedang direkam — inti dari tombol MULAI/STOP.
  bool get recording => _sharer?.running ?? false;

  /// True kalau posisiku juga terkirim ke anggota grup. Beda dari [recording]:
  /// merekam jejak selalu bisa, mengirim ke anggota butuh grup di server.
  bool get sharingLocation =>
      active.gid != null && _sharer?.sharingGid == active.gid;

  void _startLiveFeed(TripGroup g) {
    final cloud = _cloud;
    if (cloud == null || !cloud.ready) return;
    _liveSub = cloud.watchLive(g.gid!).listen(
      (pos) {
        _livePos
          ..clear()
          ..addAll(pos);
        _rebuildRidersFromLive();
        notifyListeners();
      },
      onError: (Object e) => debugPrint('cloud: live feed gagal ($e)'),
    );
    // SOS dari anggota lain. Aliran terpisah dari `live/` supaya SOS tetap
    // sampai walau posisinya belum/tidak dikirim.
    _sosSub = cloud.watchSos(g.gid!).listen(
      applySos,
      onError: (Object e) => debugPrint('cloud: feed SOS gagal ($e)'),
    );
    _trackSub = cloud.watchTracks(g.gid!).listen(
      applyMateTracks,
      onError: (Object e) => debugPrint('cloud: feed jejak gagal ($e)'),
    );
    // Status "hilang" bergantung pada umur data, jadi harus dihitung ulang
    // walau tidak ada kiriman baru — kalau tidak, rider yang mati sinyalnya
    // akan terlihat aman selamanya.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_livePos.isEmpty) return;
      _rebuildRidersFromLive();
      notifyListeners();
    });
  }

  /// Terapkan jejak anggota lain dari server.
  ///
  /// Jejak sendiri dibuang dari daftar: [track] lokal selalu lebih baru daripada
  /// yang sudah sampai ke server, dan menggambar keduanya membuat garis ganda
  /// yang ujungnya beda.
  @visibleForTesting
  void applyMateTracks(Map<String, MateTrack> masuk) {
    final aku = myUid;
    mateTracks
      ..clear()
      ..addAll({
        for (final e in masuk.entries)
          if (e.key != aku) e.key: e.value,
      });
    notifyListeners();
  }

  /// Terapkan daftar SOS dari server.
  ///
  /// Yang ditampilkan hanya satu: **yang paling dulu menekan**. Layar SOS dan
  /// spanduk peta memang dibuat untuk satu orang, dan menampilkan yang terbaru
  /// akan menutupi orang pertama yang mungkin justru keadaannya lebih berat.
  @visibleForTesting
  void applySos(Map<String, int> aktif) {
    final sebelum = sosUid;
    if (aktif.isEmpty) {
      sosUid = null;
      sosAt = null;
    } else {
      final urut = aktif.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      sosUid = urut.first.key;
      sosAt = DateTime.fromMillisecondsSinceEpoch(urut.first.value);
    }
    if (sosUid != sebelum && sosUid != null && sosUid != myUid) {
      final nama = active.members
              .where((m) => m.uid == sosUid)
              .firstOrNull
              ?.name ??
          'Seorang anggota';
      _log('$nama minta bantuan', 'Buka tab SOS untuk lokasinya', kBad);
    }
    _relabelLive(DateTime.now());
    notifyListeners();
  }

  /// Masukkan posisi seolah datang dari server. Hanya untuk tes — jalur
  /// aslinya butuh Firebase hidup, dan tanpa seam ini bug "rombongan tidak
  /// muncul di peta" tidak bisa dijaga oleh tes apa pun.
  @visibleForTesting
  void applyLive(Map<String, LivePos> pos) {
    _livePos
      ..clear()
      ..addAll(pos);
    _rebuildRidersFromLive();
    notifyListeners();
  }

  /// Susun daftar rider dari anggota grup + posisi terakhir mereka.
  ///
  /// Anggota yang belum pernah mengirim posisi masuk ke [untracked], bukan ke
  /// [riders]. Dua alasan: dia tidak bisa digambar di peta, dan menaruhnya di
  /// km 0 akan merusak semua hitungan — dia langsung jadi sweeper dan rentang
  /// rombongan melonjak jadi sepanjang rute.
  void _rebuildRidersFromLive() {
    final g = active;
    riders.clear();
    untracked.clear();

    final now = DateTime.now();
    var i = 0;
    for (final m in g.members) {
      final pos = m.uid == null ? null : _livePos[m.uid];
      if (pos == null) {
        untracked.add(m);
        continue;
      }
      riders.add(Rider(
        id: i++,
        uid: m.uid,
        name: m.name,
        plat: m.plat,
        role: m.role,
        p: _progressAt(pos.at),
        v: pos.speedKmh,
        batt: pos.battery,
      )
        ..pos = pos.at
        ..head = pos.heading
        ..staleness = pos.age(now));
    }
    _relabelLive(now);
  }

  /// Proyeksikan posisi GPS ke progres di rute (0..1) dengan mencari titik
  /// rute terdekat. Dipakai untuk mengurutkan rombongan dan menghitung siapa
  /// tertinggal — bukan untuk menggambar, karena marker memakai posisi asli.
  double _progressAt(LatLng at) {
    if (!routeReady) return 0;
    var best = 0, bestM = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final m = _dist.as(LengthUnit.Meter, route[i], at);
      if (m < bestM) {
        bestM = m;
        best = i;
      }
    }
    return totalKm == 0 ? 0 : (distAt(best) / totalKm).clamp(0.0, 1.0);
  }

  /// Status untuk rider dari server. Beda dari [_relabel]: posisi dan arah
  /// datang dari GPS, dan ada status baru "hilang" dari presence.
  void _relabelLive(DateTime now) {
    if (riders.isEmpty) return;
    final lead = riders.map((r) => r.p).reduce(math.max);
    for (final r in riders) {
      r.behindKm = (lead - r.p) * totalKm;
      final pos = r.uid == null ? null : _livePos[r.uid];
      r.status = sosUid != null && sosUid == r.uid
          ? RiderStatus.sos
          : (pos != null && pos.stale(now))
              ? RiderStatus.hilang
              // Kecepatan GPS di bawah 3 km/j itu derau saat diam, bukan gerak.
              : r.v < 3
                  ? RiderStatus.berhenti
                  : r.behindKm > 3.2
                      ? RiderStatus.tertinggal
                      : RiderStatus.aman;
    }
  }

  /// Jejak perjalananku di grup aktif, direkam lokal saat berbagi lokasi.
  /// Dipakai kartu bagikan untuk menggambar rute yang benar-benar dilalui.
  Track get track => _tracks.putIfAbsent(active.id, Track.new);
  final _tracks = <String, Track>{};

  /// Kirim jejakku supaya anggota lain bisa melihat jalur yang sudah kulalui.
  ///
  /// Diam-diam gagal kalau grupnya lokal atau server tidak terjangkau: jejaknya
  /// tetap utuh di HP ini, dan kiriman berikutnya membawa keseluruhannya. Tidak
  /// perlu diributkan ke pengguna tiap 2 km.
  void _pushTrack() {
    final g = activeOrNull;
    if (g == null || !g.onCloud) return;
    final cloud = _cloud;
    if (cloud == null || !cloud.ready) return;
    final t = track;
    if (t.points.length < 2) return;
    cloud.putTrack(g.gid!, t.points, t.km).catchError(
        (Object e) => debugPrint('cloud: kirim jejak gagal ($e)'));
  }

  /// Catat satu fix GPS ke jejak grup aktif.
  ///
  /// Dipisah dari [startRecording] supaya bisa diuji: jalur aslinya lewat
  /// geolocator, yang tidak ada di lingkungan tes.
  @visibleForTesting
  void recordFix(LatLng at, double speedKmh, DateTime now) {
    final sebelum = track.points.length;
    track.add(at, speedKmh, now);
    final titik = track.points.length;
    // Jejak disimpan berkala, bukan tiap fix: tulis-ulang blob penuh tiap
    // 10 detik itu pemborosan. Tiap ~1 km cukup — kalau app mati mendadak,
    // yang hilang paling satu kilometer terakhir.
    if (titik % 5 == 0) _persist();
    // Dikirim ke anggota lain lebih jarang lagi (~2 km), dan hanya saat titiknya
    // benar-benar bertambah. Sekali kirim menulis ulang SELURUH garis, jadi
    // frekuensinya yang menentukan biaya kuota — bukan panjang perjalanannya.
    if (titik > sebelum && titik % 10 == 0) _pushTrack();
    // WAJIB. Angka berjalan di tombol STOP dan garis jejak di peta hanya ikut
    // berubah kalau ada pemberitahuan. Tanpa ini keduanya membeku di "MENUNGGU
    // SINYAL GPS…" selama grupnya tidak di server — grup di server kebetulan
    // tertolong oleh gema posisi yang datang balik dari `live/`.
    notifyListeners();
  }

  /// Nyalakan berbagi lokasi untuk grup aktif. Selalu atas permintaan
  /// pengguna — posisi tidak pernah dikirim tanpa dia menekan tombolnya.
  Future<LocationShareResult> startRecording() async {
    // Tanpa server pun tetap jalan: jejak itu milik pengguna sendiri, dan
    // rekapnya tidak bergantung pada siapa pun.
    final cloud = _cloud;
    if (_sharer != null && cloud != null) _sharer!.cloud = cloud;
    _sharer ??= LocationSharer(cloud ?? Cloud())
      ..onFix = (at, speedKmh) => recordFix(at, speedKmh, DateTime.now());
    final r = await _sharer!.start(active.gid);
    if (r == LocationShareResult.ok) {
      _log('Mulai merekam perjalanan',
          'Jejak dicatat dan posisimu terlihat anggota grup', kOk);
    } else if (r == LocationShareResult.tanpaServer) {
      _log('Mulai merekam perjalanan',
          'Jejak dicatat di HP ini; anggota lain belum bisa melihat posisimu',
          kWarn);
    } else {
      // Kegagalan ikut dicatat ke riwayat, bukan cuma lewat SnackBar yang
      // hilang beberapa detik kemudian — supaya sebabnya masih bisa dibaca.
      _log('Gagal menyalakan GPS', switch (r) {
        LocationShareResult.ditolak => 'Izin lokasi ditolak',
        LocationShareResult.ditolakPermanen =>
          'Izin lokasi diblokir permanen — buka Pengaturan aplikasi',
        LocationShareResult.layananMati => 'Layanan lokasi HP sedang mati',
        _ => 'Alasan tidak diketahui',
      }, kBad);
    }
    notifyListeners();
    return r;
  }

  /// Buang jejak grup aktif — dipakai saat mau mulai merekam perjalanan baru
  /// di rute yang sama.
  void resetTrack() {
    track.clear();
    _log('Jejak perjalanan dihapus', 'Rekaman dimulai dari nol', kGrey);
    _persist();
    notifyListeners();
    // Ikut dihapus di server. Kalau tidak, anggota lain terus melihat jejak
    // lama yang di HP ini sudah tidak ada — dan tidak ada lagi yang akan
    // menimpanya sampai perjalanan berikutnya cukup panjang.
    final g = activeOrNull;
    if (g != null && g.onCloud) {
      _guard('Jejak gagal dihapus di server', () => _cloud!.clearTrack(g.gid!));
    }
  }

  Future<void> stopRecording() async {
    await _sharer?.stop();
    // Kiriman terakhir supaya anggota lain melihat jejak yang lengkap — tanpa
    // ini, sampai ~2 km terakhir hilang dari pandangan mereka selamanya.
    _pushTrack();
    final t = track;
    _log('Berhenti merekam',
        t.isEmpty
            ? 'Belum ada jejak yang tercatat'
            : '${km1(t.km)} km · ${fmtDur(t.duration.inMinutes)}',
        kGrey);
    _persist();
    notifyListeners();
  }

  /// Buat grup. Kalau server tersambung, grup langsung terdaftar di sana dan
  /// bisa dibagikan sungguhan; kalau tidak, grup hanya hidup di HP ini.
  Future<TripGroup> createGroup({
    required String name,
    required String club,
    required DateTime when,
    required Member you,
  }) async {
    final cloud = _cloud;
    final g = TripGroup(
      id: newGroupId(_rnd),
      gid: cloud != null && cloud.ready ? Cloud.newGid() : null,
      rcUid: cloud?.uid,
      name: name.trim(),
      club: club.trim(),
      when: when,
      members: [
        Member(
          name: you.name,
          plat: you.plat,
          role: 'RC',
          // Grup di server: kuncinya wajib uid Firebase, karena Rules menuntut
          // baris RC berada di members/{auth.uid}. Grup lokal: kunci apa pun
          // boleh, yang penting tidak null — setiap anggota harus punya kunci.
          uid: cloud?.uid ?? newLocalMemberKey(_rnd),
        ),
      ],
    );
    groups.add(g);
    activeId = g.id;
    _log('Grup "${g.name}" dibuat',
        g.onCloud ? '${g.id} · bagikan kodenya ke anggota'
                  : '${g.id} · lokal saja, server tidak tersambung',
        kAcc);
    _activate();
    _persist();
    notifyListeners();

    // Satu jalur pendaftaran untuk semua kasus: buat baru maupun coba lagi
    // setelah gagal. Kalau gagal, gid dilepas supaya grupnya jujur lokal.
    if (g.onCloud) await _register(g);
    return g;
  }

  /// Gabung grup. Untuk kode versi 3 (grup di server) ini pendaftaran nyata:
  /// [you] ditulis ke `members/` dan road captain langsung melihatnya. Untuk
  /// kode versi lama, ini hanya menyalin rencana ke HP ini.
  Future<void> importGroup(TripGroup g, {Member? you}) async {
    if (groups.any((e) => e.id == g.id || (g.onCloud && e.gid == g.gid))) {
      throw StateError('Grup ${g.id} sudah ada di daftarmu.');
    }

    final cloud = _cloud;
    var joined = g;
    if (g.onCloud && cloud != null && cloud.ready && you != null) {
      final fresh = await cloud.join(g.gid!, you);
      if (fresh == null) {
        throw StateError('Grup tidak ditemukan di server. Kodenya kedaluwarsa?');
      }
      joined = fresh;
    } else if (g.onCloud && you != null) {
      throw StateError(
          cloud?.error ?? 'Butuh koneksi untuk gabung grup di server.');
    }

    groups.add(joined);
    activeId = joined.id;
    _log('Gabung grup "${joined.name}"',
        '${joined.id} · ${joined.members.length} anggota', kOk);
    _activate();
    _persist();
    notifyListeners();
    if (joined.onCloud) _watch(joined.gid!);
  }

  /// Hapus dari HP ini. Road captain juga menghapusnya di server; anggota biasa
  /// hanya keluar dari grup, karena Rules melarangnya menghapus grup orang.
  Future<void> deleteGroup(String id) async {
    final g = groups.where((e) => e.id == id).firstOrNull;
    final cloud = _cloud;

    if (g != null && g.onCloud && cloud != null && cloud.ready) {
      final me = g.members.where((m) => m.uid == cloud.uid).firstOrNull;
      await _guard('Gagal memperbarui server', () async {
        if (amRc(g)) {
          await cloud.deleteGroup(g);
        } else if (me != null) {
          await cloud.removeMember(g, me);
        }
      });
    }

    groups.removeWhere((e) => e.id == id);
    // Jejaknya ikut dibuang. Kalau tidak, ia tersimpan selamanya di blob JSON
    // tanpa ada layar yang bisa menampilkannya lagi — sampah murni yang ikut
    // ditulis ulang tiap penyimpanan.
    _tracks.remove(id);
    _reseat();
    _persist();
    notifyListeners();
  }

  /// Jalankan tulisan ke server; kegagalan dicatat ke riwayat, tidak dilempar,
  /// supaya perubahan lokal tetap tersimpan dan UI tidak mati.
  Future<void> _guard(String what, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('cloud: $what ($e)');
      _log(what, 'Perubahan tersimpan di HP ini saja. Coba lagi saat online.',
          kWarn);
      notifyListeners();
    }
  }

  void editGroup(TripGroup g,
      {String? name, String? club, DateTime? when}) {
    if (name != null) g.name = name.trim();
    if (club != null) g.club = club.trim();
    if (when != null) g.when = when;
    _persist();
    notifyListeners();
    if (g.onCloud) {
      _guard('Detail grup gagal disimpan ke server', () => _cloud!.putMeta(g));
    }
  }

  // ── Rute ──────────────────────────────────────────────────────────────────

  /// Simpan rute hasil penyusun ke [g]. Kalau [g] aktif, cache global ikut.
  void applyRoute(
    TripGroup g, {
    required List<Stop> stops,
    required List<LatLng> geometry,
    required List<int> stopIndices,
    required double km,
    required int minutes,
    TripMode? mode,
  }) {
    g
      ..stops = stops
      ..geometry = geometry
      ..stopIndices = stopIndices
      ..km = km
      ..minutes = minutes
      ..mode = mode ?? g.mode;
    _log('Rute "${g.name}" diperbarui',
        '${stops.length} titik · ${km1(km)} km · ${g.mode.label}', kAcc);
    if (g.id == activeId) _activate();
    _persist();
    notifyListeners();
    if (g.onCloud) {
      _guard('Rute gagal disimpan ke server', () => _cloud!.putRoute(g));
    }
  }

  // ── Anggota ───────────────────────────────────────────────────────────────

  // Tidak ada addMember: anggota hanya masuk dengan memasang app dan menempel
  // kode gabung. Mendaftarkan orang secara manual dulu bisa, tapi dibuang —
  // GPS itu milik HP, jadi anggota yang didaftarkan dari HP orang lain tidak
  // akan pernah punya posisi, dan barisnya di daftar hanya terlihat seperti
  // rider yang bisa dipantau padahal tidak.

  void updateMember(TripGroup g, Member m,
      {String? name, String? plat, String? role}) {
    if (name != null) m.name = name.trim();
    if (plat != null) m.plat = plat.trim().toUpperCase();
    if (role != null) {
      m.role = role;
      _dedupeRole(g, m, 'RC');
      _dedupeRole(g, m, 'SWP');
    }
    if (g.id == activeId) _activate();
    _persist();
    notifyListeners();
    _pushMembers(g, m);
  }

  void removeMember(TripGroup g, Member m) {
    g.members.remove(m);
    if (g.id == activeId) _activate();
    _persist();
    notifyListeners();
    if (g.onCloud && m.uid != null) {
      // Dikeluarkan orang lain = dicekal, kalau tidak dia tinggal mendaftar
      // ulang pakai kode yang masih dia pegang. Keluar sendiri tidak dicekal
      // supaya bisa gabung lagi.
      final dikeluarkan = m.uid != myUid;
      // Namanya dicatat supaya cekalan ini bisa dibatalkan lagi. Tanpa ini
      // satu kesalahan mengeluarkan orang jadi permanen: server hanya
      // menyimpan uid-nya, dan uid tidak bisa dikenali manusia.
      if (dikeluarkan) g.banned[m.uid!] = m.name;
      _guard('Anggota gagal dihapus di server',
          () => _cloud!.removeMember(g, m, ban: dikeluarkan));
    }
  }

  /// Batalkan cekalan supaya dia bisa gabung lagi pakai kode yang sama.
  void unbanMember(TripGroup g, String uid) {
    final nama = g.banned.remove(uid) ?? 'Anggota';
    _log('$nama diizinkan gabung lagi', 'Dia bisa pakai kode gabung yang sama',
        kOk);
    _persist();
    notifyListeners();
    if (g.onCloud) {
      // Kalau ini gagal, cekalannya masih berlaku di server sementara daftar
      // lokalnya sudah bersih — jadi kegagalannya harus terlihat, bukan diam.
      _guard('Cekalan gagal dibatalkan di server',
          () => _cloud!.unban(g, uid));
    }
  }

  /// Kirim [changed] ke server, plus anggota lain yang perannya ikut turun
  /// karena aturan satu-RC-satu-sweeper.
  void _pushMembers(TripGroup g, Member changed) {
    if (!g.onCloud) return;
    // Anggota dari server selalu punya uid, dan pembuat grup diberi kunci di
    // createGroup. Yang null di sini berarti data lama dari versi app yang
    // masih punya fitur tambah manual — beri kunci daripada dibiarkan hilang.
    for (final m in g.members) {
      m.uid ??= newLocalMemberKey(_rnd);
    }
    // Anggota lain ikut dikirim karena aturan satu-RC-satu-sweeper bisa
    // menurunkan peran mereka.
    final touched = {changed, ...g.members};
    _guard('Anggota gagal disimpan ke server', () async {
      for (final m in touched) {
        await _cloud!.putMember(g, m);
      }
    });
  }

  void _dedupeRole(TripGroup g, Member keep, String role) {
    if (keep.role != role) return;
    for (final m in g.members) {
      if (m != keep && m.role == role) m.role = 'RIDER';
    }
  }

  // ── Tema & riwayat ────────────────────────────────────────────────────────

  void toggleTheme(bool toDark) {
    dark = toDark;
    _persist();
    notifyListeners();
  }

  /// Riwayat dibatasi. Setiap catatan ikut ditulis ke blob JSON tiap
  /// penyimpanan, jadi daftar tanpa batas membuat penyimpanan makin lambat
  /// seiring app dipakai — dan tidak ada yang membaca kejadian bulan lalu.
  static const _maxLogs = 200;

  void _log(String title, String body, int color) {
    logs.insert(0, LogEntry(fmtClock(DateTime.now()), title, body, color));
    if (logs.length > _maxLogs) logs.removeRange(_maxLogs, logs.length);
  }

  // ── Turunan untuk layar live ───────────────────────────────────────────────

  /// Dipakai saat grup aktif tidak punya rider (grup nyata tanpa pelacakan).
  /// Nilai netral, bukan exception: layar yang menampilkannya sudah dijaga
  /// [live], jadi ini cuma jaring supaya `reduce` tidak pernah melempar
  /// "Bad state: No element" kalau ada satu penjaga yang terlewat.
  static final _noRider =
      Rider(id: -1, name: '—', plat: '', role: 'RIDER', p: 0, v: 0, batt: 0);

  Rider get leader =>
      riders.isEmpty ? _noRider : riders.reduce((m, r) => r.p > m.p ? r : m);
  Rider get sweeper =>
      riders.isEmpty ? _noRider : riders.reduce((m, r) => r.p < m.p ? r : m);
  double get spread => riders.isEmpty ? 0 : (leader.p - sweeper.p) * totalKm;

  /// Progres rombongan 0..1. Nol untuk grup yang belum jalan.
  double get progress => riders.isEmpty ? 0 : leader.p;
  Rider? get sosRider =>
      sosUid == null ? null : riders.where((r) => r.uid == sosUid).firstOrNull;

  int count(RiderStatus s) => riders.where((r) => r.status == s).length;

  List<Rider> get sorted => riders.toList()
    ..sort((a, b) {
      final c = a.status.rank - b.status.rank;
      return c != 0 ? c : b.p.compareTo(a.p);
    });

  double get avgSpeed => riders.isEmpty
      ? 0
      : riders.map((r) => r.v).reduce((a, b) => a + b) / riders.length;
  double get topSpeed =>
      riders.isEmpty ? 0 : riders.map((r) => r.v).reduce(math.max);

  /// Berapa rider yang sedang tidak bergerak, dari kecepatan GPS-nya.
  int get stopCount =>
      riders.where((r) => r.status == RiderStatus.berhenti).length;

  int get etaMin => riders.isEmpty
      ? 0
      : math.max(0,
          ((totalKm - leader.p * totalKm) / math.max(20, avgSpeed) * 60).round());

  /// Sudah berapa lama SOS-nya aktif. Null kalau tidak ada SOS.
  Duration? get sosFor =>
      sosAt == null ? null : DateTime.now().difference(sosAt!);

  /// Tandai diriku sedang butuh bantuan, dan umumkan ke anggota lain.
  ///
  /// Ditandai lokal lebih dulu supaya spanduknya langsung muncul, lalu ditulis
  /// ke server. Urutannya penting: orang yang menekan SOS tidak boleh menunggu
  /// jaringan untuk melihat bahwa tombolnya bekerja.
  void fireSos() {
    // Jangan pakai `r.uid == myUid` langsung: kalau myUid null, perbandingannya
    // cocok dengan rider mana pun yang uid-nya juga null, dan SOS-nya menempel
    // ke orang yang salah.
    final uid = myUid;
    if (uid == null) {
      _log('SOS tidak bisa dikirim',
          'Grup ini hanya tersimpan di HP ini — server tidak tahu siapa kamu',
          kWarn);
      notifyListeners();
      return;
    }
    final me = riders.where((r) => r.uid == uid).firstOrNull;
    if (me == null) {
      _log('SOS tidak bisa dikirim',
          'Tekan MULAI dulu supaya posisimu diketahui', kWarn);
      notifyListeners();
      return;
    }
    sosUid = me.uid;
    sosAt = DateTime.now();
    _log('SOS dikirim oleh ${me.name}',
        'Hubungi road captain dan sweeper lewat telepon juga', kBad);
    _relabelLive(DateTime.now());
    _persist();
    notifyListeners();
    final g = active;
    if (g.onCloud) {
      _guard('SOS gagal dikirim ke anggota lain', () => _cloud!.putSos(g.gid!));
    }
  }

  void clearSos() {
    final g = active;
    final uid = sosUid;
    sosUid = null;
    sosAt = null;
    _log('SOS ditutup', 'Ditandai sudah ditangani', kOk);
    _relabelLive(DateTime.now());
    _persist();
    notifyListeners();
    // Rules mengizinkan ini hanya untuk yang bersangkutan atau road captain.
    // Kalau bukan keduanya, penulisannya ditolak dan tanda SOS kembali muncul
    // dari server — itu benar: bukan haknya menutup SOS orang lain.
    if (g.onCloud && uid != null) {
      _guard('SOS gagal ditutup di server',
          () => _cloud!.clearSos(g.gid!, uid));
    }
  }
}

final trip = TripState();

/// Rekap teks. Angkanya dari jejak GPS kalau ada; kalau belum, dari rencana —
/// dan tidak pernah dari keduanya sekaligus.
String shareText(TripState s) {
  final g = s.active;
  final t = s.track;
  final stops = g.stops.map((e) => e.label).join(' → ');

  if (t.isEmpty) {
    return '🏍️ Rencana Touring — ${g.name} (${g.club})\n'
        'Group ID: ${g.id}\n'
        'Jadwal: ${fmtWhen(g.when)}\n'
        'Moda: ${g.mode.label}\n'
        'Rute: $stops\n'
        'Jarak: ${km1(g.km)} km · estimasi ${fmtDur(g.minutes)}\n'
        'Anggota: ${g.members.length} rider\n'
        'Kode gabung:\n${g.shareCode}';
  }

  return '🏍️ Rekap Touring — ${g.name} (${g.club})\n'
      'Moda: ${g.mode.label}\n'
      'Rute: $stops\n'
      'Jarak tempuh: ${km1(t.km)} km'
      '${g.hasRoute ? " dari rute ${km1(g.km)} km" : ""}\n'
      'Durasi: ${fmtDur(t.duration.inMinutes)}\n'
      'Kecepatan rata-rata: ${t.avgKmh.round()} km/j '
      '(maks ${t.topKmh.round()} km/j)\n'
      'Mulai: ${fmtWhen(t.startedAt!)}';
}

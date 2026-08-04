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

const _dist = Distance();

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

// ── Grup demo ───────────────────────────────────────────────────────────────

const _demoNames = <String>[
  'Bagas Pratama', 'Rizky Nugroho', 'Dimas Saputra', 'Yoga Ardiansyah',
  'Fajar Setiawan', 'Hendra Wijaya', 'Arif Kurniawan', 'Galih Permana',
  'Bayu Santoso', 'Ilham Maulana', 'Reza Fauzi', 'Doni Hermawan',
  'Wahyu Utomo', 'Andre Saputro', 'Teguh Prasetyo', 'Eko Widodo',
  'Rangga Adiputra', 'Sandi Firmansyah', 'Aji Nurcahyo', 'Panca Wibowo',
  'Gilang Ramadhan', 'Toni Sugiarto', 'Bram Alfarizi', 'Cahyo Purnomo',
  'Deni Iskandar', 'Farid Hakim', 'Gunawan Riyadi', 'Hafiz Alamsyah',
  'Irfan Maulida', 'Joko Susilo', 'Krisna Dewa', 'Lutfi Ananda',
  'Miko Handoyo', 'Nanda Prakoso', 'Okto Damanik', 'Putra Sanjaya',
  'Qomar Hidayat', 'Ridho Alfian', 'Surya Mahendra', 'Tomi Rahardjo',
  'Ucok Simbolon', 'Vino Adyatma', 'Wisnu Baskara', 'Xaverius Ola',
  'Yusuf Arkan', 'Zaki Ramadhan', 'Ade Nurhalim', 'Beni Kusuma',
  'Candra Wirawan', 'Dwi Anggoro',
];

/// Malang – Tumpang – Gubugklakah – Ngadas – Jemplang – Penanjakan.
final _demoGeometry = <LatLng>[
  const LatLng(-7.9797, 112.6304), const LatLng(-7.9866, 112.6520),
  const LatLng(-7.9930, 112.6720), const LatLng(-8.0010, 112.6950),
  const LatLng(-8.0092, 112.7180), const LatLng(-8.0170, 112.7380),
  const LatLng(-8.0245, 112.7600), const LatLng(-8.0290, 112.7800),
  const LatLng(-8.0325, 112.8060), const LatLng(-8.0330, 112.8300),
  const LatLng(-8.0295, 112.8520), const LatLng(-8.0260, 112.8700),
  const LatLng(-8.0312, 112.8880), const LatLng(-8.0350, 112.9020),
  const LatLng(-8.0140, 112.9200), const LatLng(-7.9990, 112.9280),
  const LatLng(-7.9770, 112.9360), const LatLng(-7.9560, 112.9420),
  const LatLng(-7.9425, 112.9530),
];

const _demoStopIndices = [0, 4, 7, 13, 18];
const _demoStopLabels = [
  'Titik Kumpul Malang',
  'Rest Area Tumpang',
  'SPBU Gubugklakah',
  'Jemplang',
  'Finish · Penanjakan',
];

const demoGroupId = 'GRC-2026';

TripGroup buildDemoGroup() {
  var km = 0.0;
  for (var i = 0; i < _demoGeometry.length - 1; i++) {
    km += _dist.as(LengthUnit.Kilometer, _demoGeometry[i], _demoGeometry[i + 1]);
  }
  return TripGroup(
    id: demoGroupId,
    name: 'Bromo Etape 2 (contoh)',
    club: 'Garuda Rider Club',
    when: DateTime(2026, 8, 3, 13, 30),
    stops: [
      for (var i = 0; i < _demoStopIndices.length; i++)
        Stop(_demoStopLabels[i], _demoGeometry[_demoStopIndices[i]]),
    ],
    geometry: List.of(_demoGeometry),
    stopIndices: List.of(_demoStopIndices),
    km: km,
    minutes: (km / 32 * 60).round(),
    members: [
      for (var i = 0; i < _demoNames.length; i++)
        Member(
          name: _demoNames[i],
          plat: 'N ${1000 + i * 37} ${const ['AB', 'CD', 'GH', 'KL', 'ZR'][i % 5]}',
          role: i == 0
              ? 'RC'
              : i == _demoNames.length - 1
                  ? 'SWP'
                  : i % 12 == 0
                      ? 'MRSHL'
                      : 'RIDER',
        ),
    ],
    demo: true,
  );
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

  /// Anggota yang posisinya diketahui: dari simulasi (grup demo) atau dari
  /// server. Semua hitungan rombongan — leader, sweeper, rentang — memakai
  /// daftar ini saja.
  final riders = <Rider>[];

  /// Anggota yang sudah gabung tapi belum menyalakan berbagi lokasi. Sengaja
  /// dipisah dari [riders] supaya tidak merusak hitungan, tapi tetap
  /// ditampilkan — RC justru perlu tahu siapa yang belum menyalakan lokasi.
  final untracked = <Member>[];

  int tick = 0;
  String clock = '14:32';
  int? sos;

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
    groups.clear();
    logs.clear();
    riders.clear();
    untracked.clear();
    _tracks.clear();
    sos = null;
    clearRoute();

    final saved = await loadState();
    if (saved != null && saved.groups.isNotEmpty) {
      groups.addAll(saved.groups);
      logs.addAll(saved.logs);
      dark = saved.dark;
      activeId = saved.activeId;
      _tracks.addAll(saved.tracks);
    } else {
      groups.add(buildDemoGroup());
      logs.addAll(_demoLogs());
    }
    if (!groups.any((g) => g.id == activeId)) activeId = groups.first.id;
    _activate();

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
        // Penolakan izin berarti aksesku memang dicabut — road captain
        // mengeluarkan aku, atau grupnya dihapus. Salinan lokal harus dilepas,
        // kalau tidak grupnya terus terlihat dengan data basi selamanya.
        if (Cloud.isPermissionDenied(e)) {
          _dropGroup(gid);
        } else {
          debugPrint('cloud: watch $gid gagal ($e)');
        }
      },
    ));
  }

  /// Lepas grup yang aksesnya sudah dicabut server.
  void _dropGroup(String gid) {
    final g = groups.where((e) => e.gid == gid).firstOrNull;
    if (g == null) return;
    _log('Akses ke "${g.name}" dicabut',
        'Kamu dikeluarkan dari grup, atau grupnya dihapus road captain', kWarn);
    groups.remove(g);
    if (groups.isEmpty) groups.add(buildDemoGroup());
    if (!groups.any((e) => e.id == activeId)) activeId = groups.first.id;
    _activate();
    _persist();
    notifyListeners();
  }

  List<LogEntry> _demoLogs() => [
        LogEntry('14:28', 'Rombongan lewat Rest Area Tumpang',
            '48 dari 50 anggota tercatat', kOk),
        LogEntry('14:12', 'Dimas Saputra berhenti',
            'Isi bensin di SPBU Tumpang, 6 menit', kWarn),
        LogEntry('13:55', 'Formasi dirapatkan',
            'Rentang rombongan turun ke 2,1 km', kAcc),
        LogEntry('13:30', 'Start etape 2',
            '50 anggota check-in di Titik Kumpul Malang', kGrey),
      ];

  /// Hentikan simulasi tanpa membuang state — dipakai saat app masuk
  /// background dan oleh test supaya tidak ada timer menggantung.
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

  TripGroup get active =>
      groups.firstWhere((g) => g.id == activeId, orElse: () => groups.first);

  /// True kalau ada posisi rider yang bisa ditampilkan — dari simulasi (grup
  /// demo) maupun dari server. Layar peta/tim/rekap memakai ini untuk memilih
  /// antara tampilan live dan tampilan rencana.
  bool get live => routeReady && riders.isNotEmpty;

  void setActive(String id) {
    if (!groups.any((g) => g.id == id)) return;
    activeId = id;
    _activate();
    _persist();
    notifyListeners();
  }

  /// Pasang rute grup aktif ke cache global, lalu siapkan sumber posisi:
  /// simulasi untuk grup demo, stream `live/` untuk grup server.
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
    _livePos.clear();
    sos = null;
    if (!routeReady) return;

    if (g.demo) {
      _startSimulation(g);
    } else if (g.onCloud) {
      _startLiveFeed(g);
    }
  }

  void _startSimulation(TripGroup g) {
    for (var i = 0; i < g.members.length; i++) {
      final m = g.members[i];
      riders.add(Rider(
        id: i,
        name: m.name,
        plat: m.plat,
        role: m.role,
        p: math.max(
          0.02,
          0.58 - i * 0.00042 - (i % 5) * 0.0002 -
              ([11, 33, 27].contains(i) ? 0.028 : 0),
        ),
        v: 46 + ((i * 13) % 22),
        batt: 38 + ((i * 17) % 58),
        stopUntil: (i == 11 || i == 33) ? 40 : 0,
      ));
    }
    _relabel();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  // ── Lokasi live ───────────────────────────────────────────────────────────

  StreamSubscription<Map<String, LivePos>>? _liveSub;
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
    // Status "hilang" bergantung pada umur data, jadi harus dihitung ulang
    // walau tidak ada kiriman baru — kalau tidak, rider yang mati sinyalnya
    // akan terlihat aman selamanya.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_livePos.isEmpty) return;
      _rebuildRidersFromLive();
      notifyListeners();
    });
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
    if (!routeReady) return;

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
        stopUntil: 0,
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
      r.status = sos == r.id
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

  /// Nyalakan berbagi lokasi untuk grup aktif. Selalu atas permintaan
  /// pengguna — posisi tidak pernah dikirim tanpa dia menekan tombolnya.
  Future<LocationShareResult> startRecording() async {
    // Tanpa server pun tetap jalan: jejak itu milik pengguna sendiri, dan
    // rekapnya tidak bergantung pada siapa pun.
    _sharer ??= LocationSharer(_cloud ?? Cloud())
      ..onFix = (at, speedKmh) {
        track.add(at, speedKmh, DateTime.now());
        // Jejak disimpan berkala, bukan tiap fix: tulis-ulang blob penuh tiap
        // 10 detik itu pemborosan. Tiap ~1 km cukup — kalau app mati mendadak,
        // yang hilang paling satu kilometer terakhir.
        if (track.points.length % 5 == 0) _persist();
      };
    final r = await _sharer!.start(active.gid);
    if (r == LocationShareResult.ok) {
      _log('Mulai merekam perjalanan',
          'Jejak dicatat dan posisimu terlihat anggota grup', kOk);
    } else if (r == LocationShareResult.tanpaServer) {
      _log('Mulai merekam perjalanan',
          'Jejak dicatat di HP ini; anggota lain belum bisa melihat posisimu',
          kWarn);
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
  }

  Future<void> stopRecording() async {
    await _sharer?.stop();
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

    if (g.onCloud) {
      await _guard('Grup gagal didaftarkan ke server', () async {
        await cloud!.createGroup(g);
        _watch(g.gid!);
      });
    }
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
    if (groups.isEmpty) groups.add(buildDemoGroup());
    if (!groups.any((e) => e.id == activeId)) activeId = groups.first.id;
    _activate();
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
      _guard('Anggota gagal dihapus di server',
          () => _cloud!.removeMember(g, m, ban: dikeluarkan));
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

  void _log(String title, String body, int color) =>
      logs.insert(0, LogEntry(clock, title, body, color));

  // ── Turunan untuk layar live ───────────────────────────────────────────────

  /// Dipakai saat grup aktif tidak punya rider (grup nyata tanpa pelacakan).
  /// Nilai netral, bukan exception: layar yang menampilkannya sudah dijaga
  /// [live], jadi ini cuma jaring supaya `reduce` tidak pernah melempar
  /// "Bad state: No element" kalau ada satu penjaga yang terlewat.
  static final _noRider = Rider(
      id: -1, name: '—', plat: '', role: 'RIDER', p: 0, v: 0, batt: 0,
      stopUntil: 0);

  Rider get leader =>
      riders.isEmpty ? _noRider : riders.reduce((m, r) => r.p > m.p ? r : m);
  Rider get sweeper =>
      riders.isEmpty ? _noRider : riders.reduce((m, r) => r.p < m.p ? r : m);
  double get spread => riders.isEmpty ? 0 : (leader.p - sweeper.p) * totalKm;

  /// Progres rombongan 0..1. Nol untuk grup yang belum jalan.
  double get progress => riders.isEmpty ? 0 : leader.p;
  Rider? get sosRider =>
      sos == null ? null : riders.where((r) => r.id == sos).firstOrNull;

  int count(RiderStatus s) => riders.where((r) => r.status == s).length;

  List<Rider> get sorted => riders.toList()
    ..sort((a, b) {
      final c = a.status.rank - b.status.rank;
      return c != 0 ? c : b.p.compareTo(a.p);
    });

  int get startMinute => active.when.hour * 60 + active.when.minute;

  int get elapsedMin {
    final parts = clock.split(':').map(int.parse).toList();
    return math.max(1, parts[0] * 60 + parts[1] - startMinute);
  }

  double get avgSpeed => riders.isEmpty
      ? 0
      : riders.map((r) => r.v).reduce((a, b) => a + b) / riders.length;
  double get topSpeed =>
      riders.isEmpty ? 0 : riders.map((r) => r.v).reduce(math.max);
  int get stopCount => riders.where((r) => r.stopUntil > 0).length;
  String get durText => fmtDur(elapsedMin);
  int get etaMin => riders.isEmpty
      ? 0
      : math.max(0,
          ((totalKm - leader.p * totalKm) / math.max(20, avgSpeed) * 60).round());

  void fireSos() {
    if (riders.isEmpty) return;
    final me = riders[math.min(27, riders.length - 1)];
    sos = me.id;
    _log('SOS dikirim oleh ${me.name}',
        'Notifikasi ke road captain, sweeper, dan grup keluarga', kBad);
    _relabel();
    _persist();
    notifyListeners();
  }

  void clearSos() {
    sos = null;
    _log('SOS ditutup', 'Anggota sudah bergabung kembali ke rombongan', kOk);
    _relabel();
    _persist();
    notifyListeners();
  }

  void _tick() {
    if (riders.isEmpty || !routeReady) return;
    final lead0 = riders.map((r) => r.p).reduce(math.max);
    for (final r in riders) {
      if (r.stopUntil > 0) {
        r.stopUntil -= 1;
      } else {
        r.p = math.min(1, r.p + (r.v / 3600) * 0.9 / totalKm * 6);
      }
      if (_rnd.nextDouble() < 0.0015 && r.stopUntil == 0 && r.role == 'RIDER') {
        r.stopUntil = 10 + _rnd.nextInt(16);
      }
      r.v = (r.v + (_rnd.nextDouble() - .5) * 5).clamp(38, 78);
      // Jangan biarkan ada yang tertinggal lebih dari 6 km.
      r.p = math.max(r.p, math.min(lead0, lead0 - 6 / totalKm));
      if (tick % 40 == 0 && r.batt != null) {
        r.batt = math.max(4, r.batt! - 1);
      }
    }
    tick++;
    clock = '14:${((32 + tick ~/ 4) % 60).toString().padLeft(2, "0")}';
    _relabel();
    notifyListeners();
  }

  /// Hitung ulang status, posisi, dan arah tiap rider.
  void _relabel() {
    if (riders.isEmpty || !routeReady) return;
    final lead = riders.map((r) => r.p).reduce(math.max);
    for (final r in riders) {
      r.behindKm = (lead - r.p) * totalKm;
      r.status = sos == r.id
          ? RiderStatus.sos
          : r.stopUntil > 0
              ? RiderStatus.berhenti
              : r.behindKm > 3.2
                  ? RiderStatus.tertinggal
                  : RiderStatus.aman;
      r.pos = pointAt(r.p);
      r.head = bearingDeg(r.pos, pointAt(math.min(1, r.p + 0.004)));
    }
  }
}

final trip = TripState();

String shareText(TripState s) {
  final g = s.active;
  final stops = g.stops.map((e) => e.label).join(' → ');
  if (!s.live) {
    return '🏍️ Rencana Touring — ${g.name} (${g.club})\n'
        'Group ID: ${g.id}\n'
        'Jadwal: ${fmtWhen(g.when)}\n'
        'Rute: $stops\n'
        'Jarak: ${km1(g.km)} km · estimasi ${fmtDur(g.minutes)}\n'
        'Anggota: ${g.members.length} rider\n'
        'Kode gabung:\n${g.shareCode}';
  }
  return '🏍️ Rekap Touring — ${g.name} (${g.club})\n'
      'Rute: $stops\n'
      'Jarak: ${km1(s.leader.p * totalKm)} / ${km1(totalKm)} km\n'
      'Durasi: ${s.durText}\n'
      'Kecepatan rata-rata: ${s.avgSpeed.round()} km/j '
      '(maks ${s.topSpeed.round()} km/j)\n'
      'Rombongan: ${s.riders.length} rider · ${s.count(RiderStatus.aman)} aman · '
      '${s.count(RiderStatus.tertinggal)} tertinggal · '
      '${s.count(RiderStatus.berhenti)} berhenti\n'
      'Rentang rombongan: ${km1(s.spread)} km\n'
      'Sisa perjalanan: ± ${s.etaMin} menit';
}

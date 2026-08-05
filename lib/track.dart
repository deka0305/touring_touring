import 'dart:math' as math;

import 'package:latlong2/latlong.dart' hide Path;

import 'polyline.dart';

// roundResult:false WAJIB. Default Distance() membulatkan hasilnya ke satuan
// bulat, jadi as(Kilometer) pada segmen 40 m mengembalikan 0 — dan rute hasil
// snap ke jalan punya titik tiap ~40 m, sehingga total jaraknya jadi 0 km.
const _dist = Distance(roundResult: false);

/// Jejak perjalananku sendiri: yang benar-benar dilalui, bukan rute rencana.
///
/// Direkam **lokal saja** — tidak ada yang dikirim ke server, jadi nol tambahan
/// kuota. Titik diperkecil ke satu per [_minMeters] meter perjalanan, bukan per
/// satuan waktu: rute 100 km jadi ~500 titik ≈ 10 KB sebagai encoded polyline.
/// Menyimpan tiap fix mentah akan jadi puluhan ribu titik tanpa menambah
/// ketelitian garis yang terlihat.
class Track {
  Track({List<LatLng>? points, double km = 0, this.startedAt})
      : points = points ?? [],
        _km = km;

  static const _minMeters = 200.0;

  final List<LatLng> points;

  /// Detik sejak [startedAt] untuk tiap titik di [points], sejajar indeksnya.
  /// Inilah yang memungkinkan jam checkpoint diambil dari perjalanan nyata,
  /// bukan ditebak linier dari jarak.
  final List<int> secs = [];

  double _km;

  /// Kapan titik pertama direkam. Null berarti belum ada.
  DateTime? startedAt;

  /// Kapan titik terakhir direkam.
  DateTime? updatedAt;

  /// Jeda antar-fix yang lebih lama dari ini dianggap **bukan perjalanan**:
  /// app ditutup, HP dimatikan, atau berhenti panjang. Denyut GPS datang jauh
  /// lebih rapat dari ini saat benar-benar jalan.
  static const _maxGap = Duration(minutes: 5);

  /// Lama perjalanan yang benar-benar terekam, dalam detik.
  double _secsMoving = 0;

  /// Waktu fix terakhir. Dipakai untuk mengukur jeda, terpisah dari
  /// [updatedAt] yang ikut dipersistensi apa adanya.
  DateTime? _lastFixAt;

  /// Jarak tempuh nyata (km), dijumlahkan dari semua fix — termasuk yang
  /// tidak disimpan sebagai titik, jadi lebih teliti dari menjumlahkan
  /// [points].
  double get km => _km;

  bool get isEmpty => points.length < 2;

  /// Lama perjalanan: jumlah jeda antar-fix, tanpa jeda yang lebih panjang
  /// dari [_maxGap].
  ///
  /// Sengaja BUKAN `updatedAt - startedAt`. Jejak bertahan setelah app ditutup,
  /// jadi selisih itu ikut menghitung waktu app mati — perjalanan 0,2 km yang
  /// dilanjutkan besok paginya tercatat 13 jam, dan kecepatan rata-ratanya
  /// jadi 0 km/j.
  Duration get duration => Duration(seconds: _secsMoving.round());

  /// Kecepatan rata-rata sepanjang perjalanan (km/j). Nol kalau belum jalan.
  double get avgKmh {
    final h = duration.inSeconds / 3600;
    return h <= 0 ? 0 : _km / h;
  }

  double topKmh = 0;

  /// Fix terakhir yang diterima — beda dari `points.last`, yang hanya bergerak
  /// tiap [_minMeters]. Dua kursor ini harus dipisah: jarak dijumlahkan dari
  /// fix ke fix, sedangkan keputusan menyimpan titik diukur dari titik
  /// tersimpan terakhir. Menyatukannya membuat jarak dihitung berlebih —
  /// 20 fix @ 50 m jadi 2,98 km, bukan 1 km.
  LatLng? _lastFix;

  /// Catat satu fix. Titik hanya disimpan kalau sudah bergerak cukup jauh,
  /// tapi jarak dan kecepatan maksimum selalu ikut diperbarui.
  void add(LatLng at, double speedKmh, DateTime now) {
    startedAt ??= now;
    updatedAt = now;
    if (speedKmh.isFinite) topKmh = math.max(topKmh, speedKmh);

    final prevAt = _lastFixAt;
    _lastFixAt = now;
    if (prevAt != null) {
      final gap = now.difference(prevAt);
      if (gap > Duration.zero && gap <= _maxGap) {
        _secsMoving += gap.inMilliseconds / 1000;
      }
    }

    final prev = _lastFix;
    if (prev == null) {
      _lastFix = at;
      if (points.isEmpty) _push(at, now);
      return;
    }

    // Lompatan liar dari GPS yang baru "fix" — jangan dihitung sebagai jarak,
    // dan jangan dijadikan acuan berikutnya.
    if (_dist.as(LengthUnit.Meter, prev, at) > 5000) return;

    _km += _dist.as(LengthUnit.Meter, prev, at) / 1000;
    _lastFix = at;

    if (points.isEmpty ||
        _dist.as(LengthUnit.Meter, points.last, at) >= _minMeters) {
      _push(at, now);
    }
  }

  void _push(LatLng at, DateTime now) {
    points.add(at);
    secs.add(now.difference(startedAt!).inSeconds);
  }

  /// Kapan aku melewati [at], dari jejak nyata. Null kalau tidak pernah lewat
  /// lebih dekat dari [withinMeters] — checkpoint yang dilewati jauh lebih baik
  /// ditampilkan "—" daripada ditebak.
  DateTime? passedAt(LatLng at, {double withinMeters = 350}) {
    if (startedAt == null || points.isEmpty) return null;
    var best = -1;
    var bestM = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final m = _dist.as(LengthUnit.Meter, points[i], at);
      if (m < bestM) {
        bestM = m;
        best = i;
      }
    }
    if (best < 0 || bestM > withinMeters) return null;
    final sec = best < secs.length ? secs[best] : 0;
    return startedAt!.add(Duration(seconds: sec));
  }

  void clear() {
    points.clear();
    _km = 0;
    topKmh = 0;
    secs.clear();
    startedAt = null;
    updatedAt = null;
    _lastFix = null;
    _lastFixAt = null;
    _secsMoving = 0;
  }

  Map<String, dynamic> toJson() => {
        'geom': encodePolyline(points),
        'secs': secs,
        'km': _km,
        'top': topKmh,
        'moving': _secsMoving,
        if (startedAt != null) 'start': startedAt!.toIso8601String(),
        if (updatedAt != null) 'end': updatedAt!.toIso8601String(),
      };

  static Track fromJson(Map<String, dynamic> j) {
    final t = Track(
      points: decodePolyline(j['geom'] as String? ?? ''),
      km: (j['km'] as num?)?.toDouble() ?? 0,
      startedAt: j['start'] == null ? null : DateTime.parse(j['start'] as String),
    );
    t.secs.addAll([for (final v in (j['secs'] as List? ?? [])) v as int]);
    t.topKmh = (j['top'] as num?)?.toDouble() ?? 0;
    t.updatedAt = j['end'] == null ? null : DateTime.parse(j['end'] as String);
    // Jejak lama (sebelum durasi dihitung per-jeda) tidak punya 'moving'.
    // Jangan mundur ke end-start: justru angka itulah yang salah. Anggap nol
    // dan biarkan durasinya tumbuh dari perekaman berikutnya.
    t._secsMoving = (j['moving'] as num?)?.toDouble() ?? 0;
    // Lanjutkan menghitung dari ujung jejak, bukan dari nol — kalau tidak,
    // fix pertama setelah app dibuka lagi akan diabaikan jaraknya.
    if (t.points.isNotEmpty) t._lastFix = t.points.last;
    // _lastFixAt sengaja dibiarkan null: jeda dari fix terakhir sebelum app
    // ditutup sampai fix pertama sesudahnya bukan waktu perjalanan.
    return t;
  }
}

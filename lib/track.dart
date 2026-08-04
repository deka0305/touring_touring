import 'dart:math' as math;

import 'package:latlong2/latlong.dart' hide Path;

import 'polyline.dart';

const _dist = Distance();

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

  /// Jarak tempuh nyata (km), dijumlahkan dari semua fix — termasuk yang
  /// tidak disimpan sebagai titik, jadi lebih teliti dari menjumlahkan
  /// [points].
  double get km => _km;

  bool get isEmpty => points.length < 2;

  /// Durasi dari titik pertama sampai terakhir.
  Duration get duration => startedAt == null || updatedAt == null
      ? Duration.zero
      : updatedAt!.difference(startedAt!);

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
  }

  Map<String, dynamic> toJson() => {
        'geom': encodePolyline(points),
        'secs': secs,
        'km': _km,
        'top': topKmh,
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
    // Lanjutkan menghitung dari ujung jejak, bukan dari nol — kalau tidak,
    // fix pertama setelah app dibuka lagi akan diabaikan jaraknya.
    if (t.points.isNotEmpty) t._lastFix = t.points.last;
    return t;
  }
}

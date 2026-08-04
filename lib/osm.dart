import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;

import 'model.dart';
import 'polyline.dart';

/// Layanan OSM publik: gratis, tanpa API key. Keduanya minta User-Agent yang
/// jelas dan pemakaian yang sopan — pencarian di UI didebounce.
const _ua = {'User-Agent': 'touring_touring/1.0 (prototipe touring)'};
const _timeout = Duration(seconds: 12);

class Place {
  final String name, detail;
  final LatLng at;
  const Place(this.name, this.detail, this.at);
}

/// Cari tempat via Nominatim, dibatasi ke Indonesia.
Future<List<Place>> searchPlaces(String query) async {
  final q = query.trim();
  if (q.length < 3) return const [];

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': q,
    'format': 'jsonv2',
    'limit': '6',
    'countrycodes': 'id',
    'accept-language': 'id',
  });
  final res = await http.get(uri, headers: _ua).timeout(_timeout);
  if (res.statusCode != 200) {
    throw OsmException('Pencarian gagal (${res.statusCode})');
  }

  return (jsonDecode(res.body) as List).map((raw) {
    final m = raw as Map<String, dynamic>;
    final full = (m['display_name'] as String).split(', ');
    return Place(
      full.first,
      full.skip(1).take(3).join(', '),
      LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
    );
  }).toList();
}

class SnappedRoute {
  /// Geometri jalan lengkap dari titik awal ke titik akhir.
  final List<LatLng> points;

  /// Indeks di [points] untuk tiap stop yang diminta, urut.
  final List<int> stopIndices;
  final double km;
  final int minutes;

  /// True kalau server rute tidak bisa dihubungi dan rute jadi garis lurus.
  final bool straightLine;

  const SnappedRoute({
    required this.points,
    required this.stopIndices,
    required this.km,
    required this.minutes,
    this.straightLine = false,
  });
}

class OsmException implements Exception {
  OsmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Susun rute lewat [stops] sesuai moda [mode], memakai Valhalla publik
/// FOSSGIS. Kalau jaringan mati, jatuh ke garis lurus supaya penyusunan rute
/// tetap bisa jalan.
///
/// Valhalla dipilih karena satu API melayani keempat moda sekaligus, termasuk
/// **motorcycle dengan `use_tolls: 0`**. OSRM publik tidak bisa: instance-nya
/// hanya punya profil mobil/sepeda/pejalan terpisah, dan parameter `exclude`
/// tidak diaktifkan di build mereka — sudah dicoba, jawabannya
/// "Exclude flag combination is not supported". Tanpa itu, rute motor akan
/// diarahkan masuk tol, yang di Indonesia dilarang.
Future<SnappedRoute> snapToRoads(
  List<LatLng> stops, {
  TripMode mode = TripMode.motor,
}) async {
  if (stops.length < 2) {
    throw OsmException('Butuh minimal 2 titik.');
  }

  final body = jsonEncode({
    'locations': [
      for (final s in stops) {'lat': s.latitude, 'lon': s.longitude},
    ],
    'costing': mode.costing,
    if (mode.costingOptions.isNotEmpty)
      'costing_options': {mode.costing: mode.costingOptions},
    'directions_options': {'units': 'kilometers'},
  });

  try {
    final res = await http
        .post(
          Uri.https('valhalla1.openstreetmap.de', '/route'),
          headers: {..._ua, 'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw OsmException(_routeError(res));
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final trip = j['trip'] as Map<String, dynamic>?;
    if (trip == null) throw OsmException(_routeError(res));

    // Tiap leg = satu ruas antar stop, dengan geometrinya sendiri. Digabung
    // jadi satu garis, dan batas antar-leg jadi indeks stop.
    final legs = (trip['legs'] as List?) ?? const [];
    final points = <LatLng>[];
    final indices = <int>[0];
    for (final leg in legs) {
      final shape = (leg as Map<String, dynamic>)['shape'] as String? ?? '';
      // Valhalla memakai presisi 1e6, bukan 1e5 seperti Google/OSRM.
      final part = decodePolyline(shape, precision: 1e6);
      // Titik sambungan antar-leg dobel; buang satu supaya garisnya bersih.
      points.addAll(points.isEmpty ? part : part.skip(1));
      indices.add(math.max(0, points.length - 1));
    }
    if (points.length < 2) {
      throw OsmException('Rute tidak ditemukan untuk moda ${mode.label}.');
    }

    final summary = (trip['summary'] as Map<String, dynamic>?) ?? const {};
    return SnappedRoute(
      points: points,
      stopIndices: indices,
      km: (summary['length'] as num?)?.toDouble() ?? 0,
      minutes: (((summary['time'] as num?) ?? 0) / 60).round(),
      straightLine: false,
    );
  } on OsmException {
    rethrow;
  } catch (_) {
    return _straight(stops);
  }
}

/// Valhalla menaruh sebabnya di body; pesan itu jauh lebih berguna daripada
/// kode status telanjang.
String _routeError(http.Response res) {
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final msg = j['error'] as String?;
    if (msg != null && msg.isNotEmpty) return 'Rute gagal: $msg';
  } catch (_) {
    // Body bukan JSON — pakai pesan umum.
  }
  return 'Routing gagal (${res.statusCode})';
}

/// ponytail: fallback kasar — jarak haversine antar stop, kecepatan 40 km/j.
/// Cukup untuk menyusun rute saat offline; angka pastinya datang dari Valhalla.
SnappedRoute _straight(List<LatLng> stops) {
  const d = Distance();
  var km = 0.0;
  for (var i = 0; i < stops.length - 1; i++) {
    km += d.as(LengthUnit.Kilometer, stops[i], stops[i + 1]);
  }
  return SnappedRoute(
    points: List.of(stops),
    stopIndices: [for (var i = 0; i < stops.length; i++) i],
    km: km,
    minutes: (km / 40 * 60).round(),
    straightLine: true,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/polyline.dart';

void main() {
  test('fixture resmi Google: encode dan decode cocok persis', () {
    // Contoh dari dokumentasi Encoded Polyline Algorithm Format.
    final points = [
      LatLng(38.5, -120.2),
      LatLng(40.7, -120.95),
      LatLng(43.252, -126.453),
    ];
    const expected = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

    expect(encodePolyline(points), expected);

    final back = decodePolyline(expected);
    expect(back.length, 3);
    for (var i = 0; i < 3; i++) {
      expect(back[i].latitude, closeTo(points[i].latitude, 1e-5));
      expect(back[i].longitude, closeTo(points[i].longitude, 1e-5));
    }
  });

  test('bolak-balik rute demo utuh dalam ± 1 m dan jauh lebih kecil', () {
    final route = buildDemoGroup().geometry;
    final code = encodePolyline(route);
    final back = decodePolyline(code);

    expect(back.length, route.length);
    const d = Distance();
    for (var i = 0; i < route.length; i++) {
      expect(d.as(LengthUnit.Meter, route[i], back[i]), lessThan(1.5),
          reason: 'titik $i bergeser terlalu jauh');
    }

    // Perbandingan dengan array JSON: "[-7.9797,112.6304]," ≈ 19 char/titik.
    expect(code.length, lessThan(route.length * 19 / 3),
        reason: 'panjang ${code.length} untuk ${route.length} titik');
  });

  test('koordinat negatif, nol, dan lompatan besar tetap presisi', () {
    final points = [
      LatLng(0, 0),
      LatLng(-7.9797, 112.6304),
      LatLng(-89.99999, 179.99999),
      LatLng(89.99999, -179.99999),
      LatLng(0, 0),
    ];
    final back = decodePolyline(encodePolyline(points));
    expect(back.length, points.length);
    for (var i = 0; i < points.length; i++) {
      expect(back[i].latitude, closeTo(points[i].latitude, 1e-5));
      expect(back[i].longitude, closeTo(points[i].longitude, 1e-5));
    }
  });

  test('string kosong jadi list kosong, string rusak ditolak', () {
    expect(decodePolyline(''), isEmpty);
    expect(encodePolyline([]), '');
    // Hanya lintang, bujurnya hilang.
    expect(() => decodePolyline('_p~iF'), throwsA(isA<FormatException>()));
    // Byte penerus tanpa penutup.
    expect(() => decodePolyline('_p~iF~ps|'), throwsA(isA<FormatException>()));
  });
}

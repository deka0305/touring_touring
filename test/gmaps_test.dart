import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/screens/map_screen.dart';

void main() {
  test('tautan Google Maps: asal, tujuan, singgah, moda', () {
    final u = googleMapsRoute(const [
      LatLng(-7.1, 112.1),
      LatLng(-7.2, 112.2),
      LatLng(-7.3, 112.3),
    ], TripMode.motor);
    expect(u.host, 'www.google.com');
    expect(u.queryParameters['origin'], '-7.1,112.1');
    expect(u.queryParameters['destination'], '-7.3,112.3');
    expect(u.queryParameters['waypoints'], '-7.2,112.2');
    expect(u.queryParameters['travelmode'], 'driving');

    final dua = googleMapsRoute(
        const [LatLng(0, 0), LatLng(1, 1)], TripMode.sepeda);
    expect(dua.queryParameters.containsKey('waypoints'), isFalse);
    expect(dua.queryParameters['travelmode'], 'bicycling');
  });

  test('lebih dari 9 singgah diambil merata, ujung tetap ikut', () {
    final titik = [for (var i = 0; i < 30; i++) LatLng(i / 10, 0)];
    final w = googleMapsRoute(titik, TripMode.mobil)
        .queryParameters['waypoints']!
        .split('|');
    expect(w.length, 9);
    expect(w.first, '0.1,0.0', reason: 'singgah pertama');
    expect(w.last, '2.8,0.0', reason: 'singgah terakhir');
  });

  test('tekan lama dianggap kena garis hanya kalau dekat di layar', () {
    final cam = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-7.98, 112.63),
      zoom: 14,
      rotation: 0,
      nonRotatedSize: const Size(400, 800),
    );
    const garis = [LatLng(-7.98, 112.62), LatLng(-7.98, 112.64)];
    expect(nearPolyline(cam, garis, const LatLng(-7.98, 112.63)), isTrue);
    expect(nearPolyline(cam, garis, const LatLng(-7.9802, 112.63)), isTrue,
        reason: '~22 m dari garis, beberapa piksel di zoom 14');
    expect(nearPolyline(cam, garis, const LatLng(-7.99, 112.63)), isFalse,
        reason: '~1 km dari garis');
  });
}

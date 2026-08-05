import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

MateTrack _jejak(List<LatLng> pts, {double km = 1.2}) =>
    MateTrack(points: pts, km: km, atMs: 1785000000000);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearRoute();
  });

  test('jejak anggota lain masuk dan bisa digambar', () {
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));

    s.applyMateTracks({
      'uid-rio': _jejak(const [LatLng(-7.98, 112.63), LatLng(-7.97, 112.64)]),
    });

    expect(s.mateTracks, hasLength(1));
    expect(s.mateTracks['uid-rio']!.points, hasLength(2));
  });

  test('jejakku sendiri dibuang dari daftar jejak orang lain', () {
    // Jejak lokal selalu lebih baru daripada yang sudah sampai ke server.
    // Menggambar keduanya membuat dua garis yang ujungnya beda.
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));
    expect(s.myUid, isNull, reason: 'tes ini tanpa Firebase');

    // Tanpa uid, tidak ada yang bisa dikenali sebagai "aku" — semuanya orang
    // lain, dan itu benar: lebih baik satu garis berlebih daripada jejak
    // anggota lain hilang karena salah dianggap milik sendiri.
    s.applyMateTracks({'uid-rio': _jejak(const [LatLng(-7.98, 112.63), LatLng(-7.97, 112.64)])});
    expect(s.mateTracks.keys, ['uid-rio']);
  });

  test('nama diambil dari daftar anggota, bukan uid mentah', () {
    final s = TripState();
    addTearDown(s.dispose);
    pakai(
        s,
        ujiGroup(gid: 'aB3xY9kLmN2pQr7s', members: [
          Member(name: 'Rio Saputra', plat: 'N 2 CD', role: 'RIDER', uid: 'b'),
        ]));

    expect(s.mateName('b'), 'Rio Saputra');
    expect(s.mateName('tidak-dikenal'), 'Anggota',
        reason: 'jangan menampilkan uid mentah ke pengguna');
  });

  test('ganti grup aktif mengosongkan jejak anggota grup sebelumnya', () {
    // Kalau tidak, jejak dari grup lain tergambar di peta grup baru.
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));
    s.groups.add(ujiGroup(id: 'LAIN-01'));
    s.applyMateTracks({
      'uid-rio': _jejak(const [LatLng(-7.98, 112.63), LatLng(-7.97, 112.64)]),
    });
    expect(s.mateTracks, isNotEmpty);

    s.setActive('LAIN-01');
    expect(s.mateTracks, isEmpty);
  });

  test('memberi tahu UI, kalau tidak garisnya tidak pernah muncul', () {
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));
    var kabar = 0;
    s.addListener(() => kabar++);

    s.applyMateTracks({
      'uid-rio': _jejak(const [LatLng(-7.98, 112.63), LatLng(-7.97, 112.64)]),
    });
    expect(kabar, 1);
  });
}

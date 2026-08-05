import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearRoute();
  });

  test('riwayat dibatasi — blob JSON tidak tumbuh tanpa henti', () async {
    // Tiap catatan ikut ditulis ulang tiap penyimpanan. Tanpa batas, app yang
    // dipakai berbulan-bulan menyimpan makin lambat, dan tidak ada yang membaca
    // kejadian bulan lalu.
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup());

    for (var i = 0; i < 350; i++) {
      s.editGroup(s.active, name: 'Ganti $i');
      s.unbanMember(s.active, 'uid-$i'); // memicu catatan
    }
    expect(s.logs.length, lessThanOrEqualTo(200));
    expect(s.logs.first.title, isNotEmpty, reason: 'yang terbaru tetap di atas');
  });

  test('menghapus grup ikut membuang jejaknya', () async {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup();
    pakai(s, g);
    s.track.add(const LatLng(-7.98, 112.63), 30, DateTime(2026, 8, 5, 9));
    expect(s.track.points, isNotEmpty);

    await s.deleteGroup(g.id);

    // Grup lain dibuat: jejak lama tidak boleh muncul kembali di sini, dan
    // tidak boleh ikut tersimpan sebagai sampah yang tak bisa ditampilkan.
    pakai(s, ujiGroup(id: 'LAIN-01'));
    expect(s.track.points, isEmpty);
  });

  test('jejak grup yang aksesnya dicabut ikut dibuang', () async {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'zZ9yX8wV7uT6sR5q', rcUid: 'uid-orang-lain');
    pakai(s, g);
    s.track.add(const LatLng(-7.98, 112.63), 30, DateTime(2026, 8, 5, 9));

    s.onAccessDenied('zZ9yX8wV7uT6sR5q');
    expect(s.hasGroup, isFalse);

    pakai(s, ujiGroup(id: 'LAIN-02'));
    expect(s.track.points, isEmpty);
  });

  test('tiap fix GPS memberi tahu UI — angka berjalan tidak boleh membeku',
      () async {
    // Grup lokal tidak punya feed `live/` yang memicu pemberitahuan, jadi tanpa
    // notify di sini tombol STOP membeku di "MENUNGGU SINYAL GPS..." padahal
    // jejaknya bertambah terus.
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup());
    var kabar = 0;
    s.addListener(() => kabar++);

    final t0 = DateTime(2026, 8, 5, 9);
    s.recordFix(const LatLng(-7.9800, 112.6300), 30, t0);
    expect(kabar, 1);
    s.recordFix(const LatLng(-7.9809, 112.6300), 30,
        t0.add(const Duration(seconds: 30)));
    expect(kabar, 2);
    expect(s.track.km, greaterThan(0), reason: 'jejaknya benar-benar tumbuh');
    expect(s.track.duration.inSeconds, 30);
  });
}

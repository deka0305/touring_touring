import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/main.dart';

import 'fixture.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await trip.init();
  });
  tearDown(trip.pause);

  testWidgets('rekap jejak GPS terbuka walau grup belum punya rute',
      (tester) async {
    // Rekap ini isinya jarak, durasi, dan kecepatan dari jejak GPS. Dulu
    // seluruhnya dikunci di balik "harus ada rute", jadi orang yang sudah
    // merekam perjalanan tidak bisa melihat rekapnya sendiri — dan kartu
    // bagikan pun tak terjangkau, karena hanya bisa dibuka dari layar ini.
    tester.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final g = ujiGroup()
      ..geometry = []
      ..stops = []
      ..stopIndices = [];
    pakai(trip, g);
    expect(g.hasRoute, isFalse);

    final t0 = DateTime(2026, 8, 5, 7);
    for (var i = 0; i < 12; i++) {
      trip.recordFix(
          LatLng(-7.98 - 0.0018 * i, 112.63), 34, t0.add(Duration(minutes: i)));
    }
    expect(trip.track.isEmpty, isFalse);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('REKAP'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Belum ada yang bisa direkap'), findsNothing,
        reason: 'jejaknya ada — rekapnya harus tampil');
    expect(find.text('Rekap perjalanan'), findsOne);
    expect(find.text('JARAK TEMPUH'), findsOne);
    expect(find.text('DURASI'), findsOne);
    // Tidak ada checkpoint tanpa rute: judul kosong terbaca seperti gagal muat.
    expect(find.text('CHECKPOINT'), findsNothing);
    expect(find.text('Bagikan sebagai gambar'), findsOne);
  });

  testWidgets('tanpa jejak DAN tanpa rute: pesan jelas, bukan layar kosong',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    pakai(
        trip,
        ujiGroup()
          ..geometry = []
          ..stops = []
          ..stopIndices = []);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('REKAP'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Belum ada yang bisa direkap'), findsOne);
    expect(find.textContaining('Tekan MULAI'), findsOne);
  });
}

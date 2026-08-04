import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/main.dart';
import 'package:touring_touring/screens/groups_screen.dart';
import 'package:touring_touring/screens/help_screen.dart';
import 'package:touring_touring/screens/route_edit_screen.dart';
import 'package:touring_touring/theme.dart';

/// Setiap layar harus muat di layar ponsel 390×844 tanpa overflow, di tema
/// gelap maupun terang, untuk grup demo (live) dan grup nyata (tanpa live).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // trip itu global: init() ulang mengembalikannya ke keadaan awal.
    await trip.init();
  });

  // Matikan timer simulasi, kalau tidak test dianggap membocorkan timer.
  tearDown(trip.pause);

  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> sweepTabs(WidgetTester tester, String label) async {
    for (final tab in ['PETA', 'TIM', 'SOS', 'GRUP', 'REKAP']) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: '$label / tab $tab');
    }
  }

  testWidgets('kelima tab render di 390x844, tema gelap & terang',
      (tester) async {
    phone(tester);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    await sweepTabs(tester, 'demo gelap');
    await tester.tap(find.byTooltip('Mode terang'));
    await tester.pump(const Duration(milliseconds: 100));
    await sweepTabs(tester, 'demo terang');


  });

  testWidgets('grup nyata tanpa rute: tiap tab kasih arahan, bukan crash',
      (tester) async {
    phone(tester);

    await trip.createGroup(
      name: 'Belum Diisi',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Deden Kurnia', plat: 'N 1 AB', role: 'RC'),
    );
    expect(trip.live, isFalse);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await sweepTabs(tester, 'grup baru');

    // Peta harus menawarkan jalan keluar, bukan layar kosong.
    await tester.tap(find.text('PETA'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Rute belum disusun'), findsOne);
    expect(find.text('Susun rute sekarang'), findsOne);


  });

  testWidgets('grup nyata dengan rute: tab Rekap & kartu bagikan tidak error',
      (tester) async {
    phone(tester);
    final g = await trip.createGroup(
      name: 'Sudah Ada Rute',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Deden Kurnia', plat: 'N 1 AB', role: 'RC'),
    );
    final stops = [
      Stop('Mulai', const LatLng(-7.9797, 112.6304)),
      Stop('Finish', const LatLng(-7.9666, 112.6520)),
    ];
    trip.applyRoute(g,
        stops: stops,
        geometry: [stops[0].at, stops[1].at],
        stopIndices: [0, 1],
        km: 2.6,
        minutes: 8);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await sweepTabs(tester, 'grup berute');

    // Inilah kasus yang dulu melempar "Bad state: No element": kartu bagikan
    // di Rekap membaca leader padahal grup ini tidak punya rider.
    await tester.tap(find.text('REKAP'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Rencana perjalanan'), findsOne);
    expect(find.text('Sudah Ada Rute'), findsWidgets);
  });

  testWidgets('grup demo: semua rider terlacak, tidak ada bagian sisa',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('TIM'));
    await tester.pump(const Duration(milliseconds: 100));

    // Simulasi memberi posisi ke semua anggota, jadi tidak ada yang tersisa.
    expect(trip.untracked, isEmpty);
    expect(find.textContaining('TERLACAK · 50'), findsOne);
    expect(find.textContaining('BELUM TERLACAK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar buat grup menolak form kosong', (tester) async {
    phone(tester);



    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(true),
      home: const NewGroupScreen(),
    ));
    await tester.pump();

    await tester.tap(find.text('Lanjut · atur rute'));
    await tester.pump();
    expect(find.text('Nama touring belum diisi.'), findsOne);
    expect(find.text('Nama kamu belum diisi.'), findsOne);
    // Tidak ada grup baru yang lolos.
    expect(trip.groups.length, 1);
  });

  testWidgets('penyusun rute render dan menampilkan error saat offline',
      (tester) async {
    phone(tester);



    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(true),
      home: RouteEditScreen(group: trip.active),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Titik Kumpul Malang'), findsOne);
    expect(find.text('Finish · Penanjakan'), findsOne);

    // Daftar titik lazy; tombol tambah ada di ujung dan harus terjangkau.
    await tester.drag(
        find.byType(ReorderableListView), const Offset(0, -300));
    await tester.pump();
    expect(find.text('+ Cari & tambah tujuan'), findsOne);

    // Tanpa jaringan, OSRM gagal tapi layarnya tetap hidup.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Simpan rute'), findsOne);
  });

  testWidgets('layar bantuan render lengkap', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(true),
      home: const HelpScreen(),
    ));
    await tester.pump();

    expect(find.text('Buat grup touring'), findsOne);
    expect(find.text('Yang belum bisa'), findsOne);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

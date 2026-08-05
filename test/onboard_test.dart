import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('dari layar awal: buat grup lalu MASUK, bukan kembali ke form',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(trip.hasGroup, isFalse);
    expect(find.text('Buat grup touring'), findsOne);

    await tester.tap(find.text('Buat grup touring'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama touring'), 'Ke Bromo');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama klub / komunitas'), 'Test MC');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama kamu'), 'Deden');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nomor polisi'), 'N 1 AB');
    await tester.tap(find.text('Lanjut · atur rute'));
    await tester.pumpAndSettle();


    expect(trip.hasGroup, isTrue);
    expect(find.text('GROUP ID'), findsOne, reason: 'mendarat di detail grup');

    // Kembali dari detail grup: layar di belakangnya harus sudah jadi shell
    // bertab, bukan layar awal yang basi.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Buat grup touring'), findsNothing,
        reason: 'layar awal harus sudah tergantikan');
    expect(find.text('PETA'), findsOne, reason: 'tab bar muncul');
    expect(find.text('GRUP'), findsOne);
    expect(find.text('Lanjut · atur rute'), findsNothing,
        reason: 'form buat grup tidak boleh muncul lagi');
    expect(find.text('Buat grup touring'), findsNothing,
        reason: 'layar awal tidak boleh muncul lagi');
  });

  group('onAccessDenied — dua sebab yang sangat berbeda', () {
    test('grupku sendiri TIDAK dihapus: RC mustahil dikeluarkan', () async {
      // Inilah bug-nya: grup yang baru dibuat lenyap dan pengguna terlempar
      // kembali ke layar "buat grup" dengan pekerjaannya hilang.
      final s = TripState();
      addTearDown(s.dispose);
      pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));
      expect(s.amRc(s.active), isTrue);

      s.onAccessDenied('aB3xY9kLmN2pQr7s');

      expect(s.hasGroup, isTrue, reason: 'grup sendiri tidak boleh dibuang');
      expect(s.groups.length, 1);
      expect(s.logs.first.title, contains('belum terdaftar'));
    });

    test('grup orang lain dihapus: aku benar-benar dikeluarkan', () async {
      final s = TripState();
      addTearDown(s.dispose);
      pakai(
          s,
          ujiGroup(
              id: 'KML-8802',
              gid: 'zZ9yX8wV7uT6sR5q',
              rcUid: 'uid-orang-lain'));
      expect(s.amRc(s.active), isFalse);

      s.onAccessDenied('zZ9yX8wV7uT6sR5q');

      expect(s.hasGroup, isFalse);
      expect(s.logs.first.title, contains('dicabut'));
    });

    test('gid tak dikenal diabaikan, bukan menghapus grup lain', () async {
      final s = TripState();
      addTearDown(s.dispose);
      pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));

      s.onAccessDenied('gid-yang-tidak-ada');
      expect(s.groups.length, 1);
    });

    test('penolakan berulang berhenti mencoba, grupnya jadi lokal', () async {
      // Tanpa penjaga, watcher error → daftar ulang → error, berputar tanpa
      // henti sambil menumpuk langganan.
      final s = TripState();
      addTearDown(s.dispose);
      pakai(s, ujiGroup(gid: 'aB3xY9kLmN2pQr7s'));

      s.onAccessDenied('aB3xY9kLmN2pQr7s');
      expect(s.logs.first.body, contains('Mencoba mendaftarkan ulang'));

      s.onAccessDenied('aB3xY9kLmN2pQr7s');
      expect(s.hasGroup, isTrue, reason: 'datanya tidak boleh hilang');
      expect(s.groups.single.onCloud, isFalse,
          reason: 'jujur berstatus lokal, bukan menggantung');
      expect(s.logs.first.body, contains('Tersimpan di HP ini saja'));

      // Percobaan ketiga tidak boleh memicu apa pun lagi.
      final sebelum = s.logs.length;
      s.onAccessDenied('aB3xY9kLmN2pQr7s');
      expect(s.logs.length, sebelum);
    });
  });

  testWidgets('header & tab ikut berubah tanpa perlu ketuk apa pun',
      (tester) async {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final g = ujiGroup(name: 'Nama Lama');
    pakai(trip, g);
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nama Lama'), findsWidgets);

    // Data berubah dari luar UI — mis. snapshot server masuk. Tampilan harus
    // menyusul sendiri, tanpa pengguna mengetuk tab apa pun.
    trip.editGroup(g, name: 'Nama Baru');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nama Baru'), findsWidgets,
        reason: 'header harus ikut berubah');
    expect(find.text('Nama Lama'), findsNothing);
    trip.pause();
  });

  testWidgets('sheet peta ikut berubah saat data grup berubah', (tester) async {
    // Widget di dalam peta juga sempat di-const-kan, dan akibatnya sheet
    // ringkasan membeku walau datanya sudah berganti.
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final g = ujiGroup();
    pakai(trip, g);
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Sheet rencana menampilkan road captain grup aktif.
    expect(find.textContaining('Bagas'), findsWidgets);

    trip.updateMember(g, g.roadCaptain!, name: 'Ketua Baru');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Ketua'), findsWidgets,
        reason: 'sheet peta harus menyusul perubahan data');
    trip.pause();
  });

  testWidgets('grup tanpa rute tetap bisa mulai merekam GPS', (tester) async {
    // Merekam jejak tidak butuh rute. Dulu tombol MULAI hanya ada di dalam
    // peta, dan peta itu diganti seluruhnya saat rute belum ada — jadi GPS
    // tidak bisa dinyalakan sama sekali.
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await trip.createGroup(
      name: 'Belum Ada Rute',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Deden', plat: 'N 1 AB', role: 'RC'),
    );
    expect(routeReady, isFalse);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rute belum disusun'), findsOne);
    expect(find.text('MULAI REKAM PERJALANAN'), findsOne,
        reason: 'GPS harus bisa dinyalakan walau rute belum ada');
    trip.pause();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/main.dart';

import 'fixture.dart';

/// Alur navigasi lengkap: buat grup, kelola anggota, hapus grup, susun rute.
/// Error `_dependents.isEmpty` muncul saat pembongkaran tree, jadi jalur
/// push/pop harus benar-benar dijalankan, bukan cuma layarnya dirender.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await trip.init();
    // Shell menampilkan onboarding kalau belum ada grup; alur di sini menguji
    // navigasi di dalam shell, jadi satu grup disiapkan lebih dulu.
    pakai(trip, ujiGroup(id: 'AWL-0001', name: 'Grup Awal'));
  });
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Grup berute milikku. [ikut] adalah anggota yang seolah sudah bergabung
  /// lewat kode — satu-satunya cara anggota masuk sekarang, jadi di test pun
  /// harus disisipkan seperti datang dari server.
  Future<TripGroup> routedGroup(String name, {List<String> ikut = const []}) async {
    final g = await trip.createGroup(
      name: name,
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Deden Kurnia', plat: 'N 1 AB', role: 'RC'),
    );
    for (var i = 0; i < ikut.length; i++) {
      g.members.add(Member(
          name: ikut[i], plat: 'N ${i + 2} ZZ', role: 'RIDER', uid: 'uid-$i'));
    }
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
    return g;
  }

  Future<void> openGroupsTab(WidgetTester tester) async {
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('GRUP'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('buat grup: form → detail grup → kembali ke daftar',
      (tester) async {
    phone(tester);
    await openGroupsTab(tester);

    await tester.tap(find.text('Buat grup'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama touring'), 'Ke Bromo');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama klub / komunitas'), 'Test MC');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama kamu'), 'Deden Kurnia');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nomor polisi'), 'N 1 AB');

    await tester.tap(find.text('Lanjut · atur rute'));
    await tester.pumpAndSettle();

    expect(trip.groups.length, 2);
    expect(find.text('GROUP ID'), findsOne, reason: 'mendarat di detail grup');

    // Kembali ke daftar: di sini tree detail grup dibongkar.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Grup touring'), findsOne);
    trip.pause();
  });

  testWidgets('detail grup tidak menawarkan tambah anggota lagi',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Kelola Anggota', ikut: ['Teman Satu']);
    await openGroupsTab(tester);
    await tester.tap(find.text(g.name).last);
    await tester.pumpAndSettle();

    // Fitur tambah manual dibuang: orang yang didaftarkan dari HP lain tidak
    // akan pernah punya posisi GPS.
    expect(find.text('Tambah'), findsNothing);
    // Test jalan tanpa Firebase, jadi grupnya lokal dan keterangannya versi itu.
    expect(find.textContaining('hanya ada di HP ini'), findsOne);

    // Geser untuk hapus tetap ada, supaya RC bisa mengeluarkan anggota.
    await tester.drag(find.text('Teman Satu'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(g.members.length, 1);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    trip.pause();
  });

  testWidgets('dialog anggota: teks bertahan saat peran diubah, lalu tersimpan',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Isi Anggota', ikut: ['Rizky']);
    await openGroupsTab(tester);
    await tester.tap(find.text(g.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rizky'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama'), 'Rizky Nugroho');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nomor polisi'), 'n 7 gh');

    // Mengubah peran memanggil setLocal → dialog dibangun ulang. Karena
    // fieldnya pakai initialValue (bukan controller), teks yang sudah diketik
    // harus tetap ada.
    await tester.tap(find.text('Rider').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sweeper').last);
    await tester.pumpAndSettle();
    expect(find.text('Rizky Nugroho'), findsOne, reason: 'teks tidak hilang');

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final baru = g.members.firstWhere((m) => m.name == 'Rizky Nugroho');
    expect(baru.plat, 'N 7 GH', reason: 'nopol ikut tersimpan & dikapitalkan');
    expect(baru.role, 'SWP', reason: 'peran pilihan terakhir yang dipakai');
    expect(baru.uid, 'uid-0', reason: 'kunci dipertahankan, bukan bikin kembar');

    // Dialog sempat dibuang saat animasi keluar — dulu ini yang bikin
    // "TextEditingController used after being disposed" lalu layar merah.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    trip.pause();
  });

  testWidgets('hapus grup dari detailnya: dialog → pop → daftar tetap hidup',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Mau Dihapus');
    await openGroupsTab(tester);

    await tester.tap(find.text(g.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus grup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(trip.groups.any((e) => e.id == g.id), isFalse);
    expect(find.text('Grup touring'), findsOne, reason: 'balik ke daftar grup');
    trip.pause();
  });

  testWidgets('hapus anggota: tombolnya terlihat di dialog, bukan cuma geser',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Hapus Anggota', ikut: ['Mau Dihapus']);
    await openGroupsTab(tester);
    await tester.tap(find.text(g.name).last);
    await tester.pumpAndSettle();
    expect(g.members.length, 2);

    // Ketuk barisnya → dialog ubah, dan di sini Hapus harus ada.
    await tester.tap(find.text('Mau Dihapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus'), findsOne, reason: 'harus bisa ditemukan');

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(g.members.length, 1);
    expect(g.members.single.role, 'RC', reason: 'yang tersisa road captain');
    trip.pause();
  });

  testWidgets('anggota biasa: tidak ditawari ubah rute atau daftar anggota',
      (tester) async {
    phone(tester);
    // Grup milik orang lain: aku ikut sebagai anggota, RC-nya uid lain.
    final punyaOrang = TripGroup(
      gid: 'aB3xY9kLmN2pQr7s',
      id: 'KML-8802',
      rcUid: 'uid-orang-lain',
      name: 'Grup Orang Lain',
      club: 'Kalimaya Riders',
      when: DateTime(2026, 8, 17, 6, 0),
      stops: [
        Stop('Mulai', const LatLng(-7.9797, 112.6304)),
        Stop('Finish', const LatLng(-7.9666, 112.6520)),
      ],
      geometry: [const LatLng(-7.9797, 112.6304), const LatLng(-7.9666, 112.6520)],
      stopIndices: [0, 1],
      km: 2.6,
      minutes: 8,
      members: [
        Member(name: 'Ketua Mereka', plat: 'N 1 AA', role: 'RC', uid: 'uid-orang-lain'),
        Member(name: 'Aku', plat: 'N 2 BB', role: 'RIDER', uid: 'uid-aku'),
      ],
    );
    trip.groups.add(punyaOrang);
    trip.setActive(punyaOrang.id);
    expect(trip.amRc(punyaOrang), isFalse);

    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Peta: tombol atur rute tidak boleh ada — server akan menolaknya.
    expect(find.byTooltip('Atur rute'), findsNothing);

    await tester.tap(find.text('GRUP'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(punyaOrang.name).last);
    await tester.pumpAndSettle();

    expect(find.text('Tambah'), findsNothing);
    expect(find.text('Ubah rute'), findsNothing);
    expect(find.text('Rute ditentukan road captain.'), findsOne);
    expect(find.text('Hanya road captain yang bisa mengubah daftar anggota.'),
        findsOne);

    // Menu: keluar dari grup, bukan hapus grup — dan tanpa "Ubah detail".
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari grup'), findsOne);
    expect(find.text('Hapus grup'), findsNothing);
    expect(find.text('Ubah detail'), findsNothing);

    trip.pause();
  });

  testWidgets('grup hilang saat detailnya terbuka: ada pesan, bukan layar kosong',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Hilang Mendadak');
    await openGroupsTab(tester);
    await tester.tap(find.text(g.name).last);
    await tester.pumpAndSettle();
    expect(find.text('GROUP ID'), findsOne);

    // Grup dihapus dari luar layar ini — mis. road captain menutupnya dari
    // HP lain, atau dihapus di tab Grup.
    await trip.deleteGroup(g.id);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Grup ini sudah tidak ada'), findsOne);
    expect(find.text('Kembali ke daftar grup'), findsOne);

    await tester.tap(find.text('Kembali ke daftar grup'));
    await tester.pumpAndSettle();
    expect(find.text('Grup touring'), findsOne);
    trip.pause();
  });

  testWidgets('peta: opsi tampilkan rute & jejak, jejak hanya kalau ada',
      (tester) async {
    phone(tester);
    final g = await routedGroup('Lihat Garis');
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Belum ada jejak → tombol jejak tidak ditawarkan. Tombol yang tidak
    // mengubah apa pun cuma membingungkan.
    expect(find.byTooltip('Sembunyikan rute rencana'), findsOne);
    expect(find.byTooltip('Tampilkan jejak GPS'), findsNothing);
    expect(find.byTooltip('Sembunyikan jejak GPS'), findsNothing);

    // Rute bisa disembunyikan dan dimunculkan lagi.
    await tester.tap(find.byTooltip('Sembunyikan rute rencana'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Tampilkan rute rencana'), findsOne);
    await tester.tap(find.byTooltip('Tampilkan rute rencana'));
    await tester.pump(const Duration(milliseconds: 100));

    // Rekam jejak → tombolnya muncul.
    final t0 = DateTime(2026, 8, 4, 7, 0);
    trip.track.add(const LatLng(-7.9797, 112.6304), 20, t0);
    trip.track.add(const LatLng(-7.9750, 112.6350), 40,
        t0.add(const Duration(minutes: 5)));
    trip.track.add(const LatLng(-7.9700, 112.6400), 42,
        t0.add(const Duration(minutes: 10)));
    expect(trip.track.points.length, greaterThanOrEqualTo(2));

    await tester.tap(find.text('GRUP'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('PETA'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Sembunyikan jejak GPS'), findsOne,
        reason: 'jejak tampil sendiri begitu ada');
    await tester.tap(find.byTooltip('Sembunyikan jejak GPS'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Tampilkan jejak GPS'), findsOne);

    expect(tester.takeException(), isNull);
    expect(g.hasRoute, isTrue);
    trip.pause();
  });

  testWidgets('penyusun rute dari tab Peta: buka, ubah urutan, lalu kembali',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Atur rute'));
    await tester.pumpAndSettle();
    expect(find.text('Atur rute'), findsWidgets);

    // Geser titik pertama ke bawah lewat pegangan drag.
    final handle = find.byIcon(Icons.drag_handle).first;
    await tester.drag(handle, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    trip.pause();
  });

  testWidgets('ganti grup aktif dari daftar sambil peta hidup', (tester) async {
    phone(tester);
    final g = await routedGroup('Grup Kedua');
    await openGroupsTab(tester);

    await tester.tap(find.text('Pakai').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // setActive memindahkan tab ke Peta; petanya harus terbangun ulang bersih.
    for (final tab in ['TIM', 'REKAP', 'PETA', 'GRUP']) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
    // "Pakai" hanya muncul di grup non-aktif, jadi grup yang tadinya pasif
    // sekarang yang aktif — bukan grup yang baru dibuat.
    expect(trip.activeId, 'AWL-0001');
    expect(g.id, isNot(trip.activeId));
    trip.pause();
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:touring_touring/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

/// Posisi anggota yang baru saja masuk dari server.
LivePos _pos(LatLng at, {double speedKmh = 32}) => LivePos(
      at: at,
      speedKmh: speedKmh,
      heading: 90,
      battery: 80,
      atMs: DateTime.now().millisecondsSinceEpoch,
      online: true,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    clearRoute();
  });

  test('anggota yang GPS-nya jalan tetap terlacak walau rute belum disusun',
      () {
    // Inilah bug-nya: seluruh jalur posisi live dikunci di balik `routeReady`,
    // padahal marker digambar di posisi GPS asli. Grup baru yang rutenya belum
    // disusun jadi tidak pernah menampilkan rombongan sama sekali.
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup()
      ..geometry = []
      ..stops = []
      ..stopIndices = [];
    pakai(s, g);
    expect(routeReady, isFalse, reason: 'grup ini sengaja tanpa rute');

    final m = g.members.first..uid = 'uid-anggota';
    s.applyLive({'uid-anggota': _pos(const LatLng(-7.9797, 112.6304))});

    expect(s.riders, hasLength(1), reason: 'posisinya harus terpakai');
    expect(s.live, isTrue, reason: 'peta harus masuk mode live');
    expect(s.riders.single.name, m.name);
    expect(s.riders.single.pos, const LatLng(-7.9797, 112.6304),
        reason: 'marker memakai posisi GPS asli, bukan proyeksi ke rute');
    expect(s.untracked, isEmpty);
  });

  test('tanpa rute, angka yang butuh rute tetap nol — bukan angka bohong', () {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(members: [
      Member(name: 'Bagas', plat: 'N 1 AB', role: 'RC', uid: 'a'),
      Member(name: 'Rio', plat: 'N 2 CD', role: 'Sweeper', uid: 'b'),
    ])
      ..geometry = []
      ..stops = []
      ..stopIndices = [];
    pakai(s, g);
    s.applyLive({
      'a': _pos(const LatLng(-7.9797, 112.6304)),
      'b': _pos(const LatLng(-7.9666, 112.6520)),
    });

    expect(s.riders, hasLength(2));
    // Keduanya di progres 0 karena tidak ada rute untuk diproyeksikan. Yang
    // penting: tidak ada yang dicap tertinggal karena selisih fiktif.
    expect(s.spread, 0);
    expect(s.riders.every((r) => r.behindKm == 0), isTrue);
    expect(s.etaMin, 0);
  });

  testWidgets('peta tampil, bukan layar "rute belum disusun", saat ada rider',
      (tester) async {
    // Bagian yang benar-benar dilihat pengguna: dulu MapScreen mengganti
    // seluruh peta dengan layar "Rute belum disusun", jadi anggota yang GPS-nya
    // jalan tetap tidak terlihat walau posisinya sudah masuk.
    tester.view
      ..physicalSize = const Size(390, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await trip.init();
    // Layar nama di awal dilewati; alurnya diuji sendiri di onboard_test.
    trip.myName = 'Penguji';
    addTearDown(trip.pause);

    final g = ujiGroup()
      ..geometry = []
      ..stops = []
      ..stopIndices = [];
    pakai(trip, g);
    await tester.pumpWidget(const TouringApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Rute belum disusun'), findsOne,
        reason: 'belum ada posisi: layar pengganti memang benar di sini');

    trip.applyLive({'uid-rc': _pos(const LatLng(-7.9797, 112.6304))});
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rute belum disusun'), findsNothing,
        reason: 'ada rider yang bisa digambar — peta harus tampil');
    expect(find.byType(FlutterMap), findsOne);
    // Angka yang butuh rute tidak boleh menyamar jadi rentang rombongan.
    expect(find.text('PANJANG RUTE'), findsOne);
    expect(find.text('RENTANG ROMBONGAN'), findsNothing);
  });

  test('anggota tanpa uid tetap masuk untracked, bukan ditaruh di km 0', () {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup()
      ..geometry = []
      ..stops = []
      ..stopIndices = [];
    pakai(s, g);
    s.applyLive({'uid-orang-lain': _pos(const LatLng(-7.98, 112.63))});

    expect(s.riders, isEmpty);
    expect(s.untracked, hasLength(g.members.length));
    expect(s.live, isFalse, reason: 'tidak ada posisi yang bisa digambar');
  });

  test('tanda SOS tetap menempel di orangnya walau daftar rider berubah', () {
    // Rider.id itu indeks yang dibuat ulang tiap kiriman posisi. Dulu SOS
    // disimpan pakai indeks itu, jadi begitu ada anggota yang berhenti berbagi
    // lokasi indeksnya bergeser dan tanda SOS pindah ke orang lain.
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(members: [
      Member(name: 'Bagas', plat: 'N 1 AB', role: 'RC', uid: 'a'),
      Member(name: 'Rio', plat: 'N 2 CD', role: 'Sweeper', uid: 'b'),
    ]);
    pakai(s, g);
    s.applyLive({
      'a': _pos(const LatLng(-7.9797, 112.6304)),
      'b': _pos(const LatLng(-7.9666, 112.6520)),
    });

    s.sosUid = 'b';
    s.applyLive({
      'a': _pos(const LatLng(-7.9797, 112.6304)),
      'b': _pos(const LatLng(-7.9666, 112.6520)),
    });
    expect(s.sosRider?.name, 'Rio');

    // Bagas berhenti berbagi lokasi: daftar rider menyusut dan indeks bergeser.
    s.applyLive({'b': _pos(const LatLng(-7.9666, 112.6520))});
    expect(s.sosRider?.name, 'Rio',
        reason: 'SOS harus tetap di Rio, bukan pindah karena indeks bergeser');
    expect(s.riders.single.status, RiderStatus.sos);
  });

  group('SOS dari server', () {
    TripState siap() {
      final s = TripState();
      final g = ujiGroup(members: [
        Member(name: 'Bagas Pratama', plat: 'N 1 AB', role: 'RC', uid: 'a'),
        Member(name: 'Rio Saputra', plat: 'N 2 CD', role: 'Sweeper', uid: 'b'),
      ]);
      pakai(s, g);
      s.applyLive({
        'a': _pos(const LatLng(-7.9797, 112.6304)),
        'b': _pos(const LatLng(-7.9666, 112.6520)),
      });
      return s;
    }

    test('alarm: bunyi saat SOS masuk, berhenti saat teratasi + dicatat', () {
      final s = siap();
      addTearDown(s.dispose);
      final kejadian = <String>[];
      s.onSosAlert = (nama) => kejadian.add('bunyi $nama');
      s.onSosEnd = () => kejadian.add('diam');
      final ms = DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch;

      s.applySos({'b': ms});
      s.applySos({'b': ms}); // kiriman ulang tidak membunyikan lagi
      expect(kejadian, ['bunyi Rio Saputra']);

      s.applySos({});
      expect(kejadian, ['bunyi Rio Saputra', 'diam']);
      expect(s.logs.first.title, 'SOS Rio Saputra sudah ditangani');
    });

    test('tandai teratasi: server gagal = SOS TETAP aktif dan ada pesan',
        () async {
      final s = siap();
      addTearDown(s.dispose);
      s.active.gid = 'TRG-7KQ2MX';
      s.applySos({'b': DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch});
      var diam = 0;
      s.onSosEnd = () => diam++;

      s.serverClearSos = (gid, uid) async => throw StateError('tanpa sinyal');
      expect(await s.clearSos(), isNotNull);
      expect(s.sosRider?.uid, 'b', reason: 'anggota lain masih dengar alarm');
      expect(diam, 0);

      final ditutup = <String>[];
      s.serverClearSos = (gid, uid) async => ditutup.add(uid);
      expect(await s.clearSos(), isNull);
      expect(ditutup, ['b']);
      expect(s.sosRider, isNull);
      expect(diam, 1, reason: 'alarm di HP ini ikut berhenti');
    });

    test('SOS anggota lain memunculkan tanda dan masuk riwayat', () {
      final s = siap();
      addTearDown(s.dispose);
      s.applySos({'b': DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch});

      expect(s.sosRider?.name, 'Rio Saputra');
      expect(s.sosAt, DateTime(2026, 8, 5, 9, 30));
      expect(s.riders.firstWhere((r) => r.uid == 'b').status, RiderStatus.sos);
      expect(s.logs.first.title, contains('Rio Saputra minta bantuan'),
          reason: 'harus ada jejaknya walau spanduknya sudah ditutup');
    });

    test('dua SOS sekaligus: yang paling dulu menekan yang ditampilkan', () {
      // Layar SOS dibuat untuk satu orang. Menampilkan yang terbaru akan
      // menutupi orang pertama, yang bisa jadi keadaannya lebih berat.
      final s = siap();
      addTearDown(s.dispose);
      s.applySos({
        'b': DateTime(2026, 8, 5, 9, 40).millisecondsSinceEpoch,
        'a': DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch,
      });
      expect(s.sosRider?.uid, 'a');
    });

    test('server mengosongkan sos: tanda hilang, status kembali normal', () {
      final s = siap();
      addTearDown(s.dispose);
      s.applySos({'b': DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch});
      expect(s.sosRider, isNotNull);

      s.applySos({});
      expect(s.sosRider, isNull);
      expect(s.sosAt, isNull);
      expect(s.riders.any((r) => r.status == RiderStatus.sos), isFalse);
    });

    test('kiriman berulang tidak menumpuk catatan yang sama', () {
      final s = siap();
      addTearDown(s.dispose);
      final ms = DateTime(2026, 8, 5, 9, 30).millisecondsSinceEpoch;
      s.applySos({'b': ms});
      final jumlah = s.logs.length;
      s.applySos({'b': ms});
      s.applySos({'b': ms});
      expect(s.logs.length, jumlah,
          reason: 'stream RTDB mengirim ulang tiap ada perubahan apa pun');
    });
  });
}

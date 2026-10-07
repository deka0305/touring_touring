import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

Future<TripState> freshState() async {
  SharedPreferences.setMockInitialValues({});
  final s = TripState(random: math.Random(7));
  await s.init();
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pertama kali buka: belum ada grup sama sekali', () async {
    // Dulu di sini muncul grup demo berisi 50 rider palsu, dan angka
    // simulasinya bocor ke rekap serta kartu bagikan yang dilihat pengguna.
    final s = await freshState();
    addTearDown(s.dispose);

    expect(s.hasGroup, isFalse);
    expect(s.groups, isEmpty);
    expect(s.activeId, isNull);
    expect(s.activeOrNull, isNull);
    expect(s.riders, isEmpty);
    expect(s.live, isFalse);
    expect(routeReady, isFalse);
    // active melempar terang-terangan, bukan mengembalikan grup kosong yang
    // angkanya menyesatkan.
    expect(() => s.active, throwsA(isA<StateError>()));
  });

  test('hapus grup terakhir berakhir tanpa grup, bukan diisi data palsu',
      () async {
    final s = await freshState();
    addTearDown(s.dispose);

    final g = await s.createGroup(
      name: 'Satu-satunya',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
    );
    expect(s.hasGroup, isTrue);

    await s.deleteGroup(g.id);
    expect(s.hasGroup, isFalse);
    expect(s.activeId, isNull);
    expect(routeReady, isFalse);
  });

  test('alur buat grup: jadi RC, aktif, belum siap sampai rute & anggota ada',
      () async {
    final s = await freshState();
    addTearDown(s.dispose);

    final g = await s.createGroup(
      name: 'Ke Bromo Lagi',
      club: 'Kalimaya Riders',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Deden Kurnia', plat: 'n 4321 zr', role: 'RC'),
    );

    expect(s.groups.length, 1);
    expect(s.activeId, g.id);
    expect(g.id, matches(RegExp(r'^[A-Z]{3}-\d{4}$')));
    expect(g.roadCaptain?.name, 'Deden Kurnia');
    expect(g.todo, ['Rute belum disusun']);

    // Grup nyata tidak punya sumber lokasi, jadi tidak ada simulasi.
    expect(s.live, isFalse);
    expect(s.riders, isEmpty);
    expect(routeReady, isFalse);
    expect(s.logs.first.title, contains('dibuat'));
  });

  test('applyRoute mengisi rute grup dan cache global kalau grup itu aktif',
      () async {
    final s = await freshState();
    addTearDown(s.dispose);

    final g = await s.createGroup(
      name: 'Test',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
    );
    final stops = [
      Stop('Mulai', const LatLng(-7.9797, 112.6304)),
      Stop('Finish', const LatLng(-7.9666, 112.6520)),
    ];
    s.applyRoute(g,
        stops: stops,
        geometry: [stops[0].at, stops[1].at],
        stopIndices: [0, 1],
        km: 2.6,
        minutes: 8);

    expect(g.hasRoute, isTrue);
    expect(g.ready, isTrue);
    expect(routeReady, isTrue, reason: 'grup aktif → cache global ikut terisi');
    expect(totalKm, closeTo(2.6, 1));
    // Grup nyata tetap tanpa simulasi walau rutenya sudah ada.
    expect(s.live, isFalse);
  });

  test('peran RC dan sweeper unik: yang lama diturunkan jadi Rider', () async {
    final s = await freshState();
    addTearDown(s.dispose);

    final g = await s.createGroup(
      name: 'Test',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Satu Orang', plat: 'N 1 AB', role: 'RC'),
    );
    final lama = g.roadCaptain!;

    // Anggota masuk dari server sebagai RIDER — Rules memaksa itu. Peran
    // khusus baru diberikan road captain lewat updateMember.
    final dua = Member(name: 'Dua Orang', plat: 'N 2 CD', role: 'RIDER', uid: 'uid-2');
    final tiga = Member(name: 'Tiga Orang', plat: 'N 3 EF', role: 'RIDER', uid: 'uid-3');
    final empat = Member(name: 'Empat Orang', plat: 'N 4 GH', role: 'RIDER', uid: 'uid-4');
    g.members.addAll([dua, tiga, empat]);

    s.updateMember(g, dua, role: 'RC');
    expect(g.roadCaptain?.name, 'Dua Orang');
    expect(lama.role, 'RIDER', reason: 'RC lama diturunkan');
    expect(g.members.where((m) => m.role == 'RC').length, 1);

    s.updateMember(g, lama, role: 'RC');
    expect(g.roadCaptain?.name, 'Satu Orang');
    expect(g.members.where((m) => m.role == 'RC').length, 1);

    s.updateMember(g, tiga, role: 'SWP');
    s.updateMember(g, empat, role: 'SWP');
    expect(g.members.where((m) => m.role == 'SWP').length, 1);
    expect(g.sweeper?.name, 'Empat Orang');

    await s.removeMember(g, g.sweeper!);
    expect(g.sweeper, isNull);
  });

  test('tidak ada jalan menambah anggota manual — GPS itu milik HP', () async {
    final s = await freshState();
    addTearDown(s.dispose);

    // Grup baru hanya berisi pembuatnya. Anggota lain wajib memasang app dan
    // menempel kode; orang yang didaftarkan dari HP lain tidak akan pernah
    // punya posisi, jadi barisnya cuma menipu.
    final g = await s.createGroup(
      name: 'Test',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'Satu Orang', plat: 'N 1 AB', role: 'RC'),
    );
    expect(g.members.length, 1);
    expect(g.members.single.role, 'RC');
  });

  group('kunci anggota', () {
    test('pembuat grup selalu punya kunci, termasuk saat offline', () async {
      // Tanpa kunci dia tidak bisa ditulis ke members/ dan akan lenyap begitu
      // snapshot server masuk.
      final s = await freshState();
      addTearDown(s.dispose);
      expect(s.online, isFalse, reason: 'test jalan tanpa Firebase');

      final g = await s.createGroup(
        name: 'Test',
        club: 'Test MC',
        when: DateTime(2026, 9, 1, 6, 0),
        you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
      );
      expect(g.members.single.uid, isNotNull);
      expect(g.members.every((m) => m.uid != null), isTrue);
    });

    test('newLocalMemberKey tidak pernah kembar', () {
      final rnd = math.Random(7);
      final kunci = {for (var i = 0; i < 500; i++) newLocalMemberKey(rnd)};
      expect(kunci.length, 500, reason: 'ada kunci kembar');
    });

    test('putMember menolak anggota tanpa kunci, tidak menimpa baris RC',
        () async {
      // Dulu ada fallback ke uid sendiri: satu anggota tanpa kunci akan
      // menimpa baris road captain tanpa suara.
      final cloud = Cloud();
      final g = TripGroup(
        gid: 'aB3xY9kLmN2pQr7s',
        id: 'GRC-2026',
        name: 'X',
        club: 'Y',
        when: DateTime(2026, 1, 1),
      );
      expect(
        () => cloud.putMember(g, Member(name: 'Tanpa Kunci', plat: '', role: 'RIDER')),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'pesan', contains('Tanpa Kunci'))),
      );
    });

    test('menyunting anggota memakai kunci yang sama, bukan bikin kembar',
        () async {
      final s = await freshState();
      addTearDown(s.dispose);
      final g = await s.createGroup(
        name: 'Test',
        club: 'Test MC',
        when: DateTime(2026, 9, 1, 6, 0),
        you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
      );
      final m = Member(
          name: 'Rizky', plat: 'N 7 GH', role: 'RIDER', uid: 'uid-rizky');
      g.members.add(m);

      s.updateMember(g, m, name: 'Rizky Nugroho', role: 'SWP');
      expect(m.uid, 'uid-rizky');
      expect(g.members.length, 2, reason: 'tidak boleh jadi tiga');
      expect(g.sweeper?.name, 'Rizky Nugroho');
    });
  });

  test('impor: kode diterima sekali, duplikat ditolak', () async {
    final s = await freshState();
    addTearDown(s.dispose);

    final asal = TripGroup(
      id: 'KML-8802',
      name: 'Touring Kemerdekaan',
      club: 'Kalimaya Riders',
      when: DateTime(2026, 8, 17, 6, 0),
      stops: [
        Stop('Malang', const LatLng(-7.98, 112.63)),
        Stop('Bandung', const LatLng(-6.91, 107.61)),
      ],
    );

    await s.importGroup(TripGroup.fromShareCode(asal.shareCode));
    expect(s.groups.any((g) => g.id == 'KML-8802'), isTrue);
    expect(s.activeId, 'KML-8802');

    // Async: pakai expectLater, kalau tidak error-nya lolos tanpa tertangkap.
    await expectLater(
      s.importGroup(TripGroup.fromShareCode(asal.shareCode)),
      throwsA(isA<StateError>()),
    );
  });

  test('ganti grup aktif menukar rute yang dipakai layar', () async {
    final s = await freshState();
    addTearDown(s.dispose);

    // Grup panjang disiapkan seolah sudah ada di HP.
    pakai(s, ujiGroup());
    final kmPanjang = totalKm;
    expect(kmPanjang, greaterThan(40));

    final g = await s.createGroup(
      name: 'Pendek',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
    );
    final stops = [
      Stop('Mulai', const LatLng(-7.9797, 112.6304)),
      Stop('Finish', const LatLng(-7.9666, 112.6520)),
    ];
    s.applyRoute(g,
        stops: stops,
        geometry: [stops[0].at, stops[1].at],
        stopIndices: [0, 1],
        km: 2.6,
        minutes: 8);
    expect(totalKm, lessThan(kmPanjang));

    s.setActive(ujiGroupId);
    expect(totalKm, closeTo(kmPanjang, 1e-9));
  });

  test('simpanan bertahan: grup dan grup aktif kembali setelah restart',
      () async {
    final s1 = await freshState();
    final g = await s1.createGroup(
      name: 'Nanti Dibuka Lagi',
      club: 'Persist MC',
      when: DateTime(2026, 12, 25, 7, 0),
      you: Member(name: 'Deden Kurnia', plat: 'N 9 ZZ', role: 'RC'),
    );
    final teman = Member(
        name: 'Teman Satu', plat: 'N 8 YY', role: 'RIDER', uid: 'uid-teman');
    g.members.add(teman);
    s1.updateMember(g, teman, role: 'SWP');
    s1.toggleTheme(false);
    final id = g.id;
    // Beri kesempatan penulisan async selesai sebelum "restart".
    await Future<void>.delayed(const Duration(milliseconds: 50));
    s1.dispose();

    // Instance baru membaca SharedPreferences yang sama (mock tidak direset).
    final s2 = TripState(random: math.Random(7));
    await s2.init();
    addTearDown(s2.dispose);

    expect(s2.groups.length, 1);
    expect(s2.activeId, id);
    expect(s2.dark, isFalse);
    final back = s2.groups.firstWhere((e) => e.id == id);
    expect(back.name, 'Nanti Dibuka Lagi');
    expect(back.when, DateTime(2026, 12, 25, 7, 0));
    expect(back.members.map((m) => m.name),
        containsAll(['Deden Kurnia', 'Teman Satu']));
    expect(back.sweeper?.name, 'Teman Satu');
  });

  group('tanpa server', () {
    test('grup baru hanya lokal, dan riwayat mengatakannya', () async {
      final s = await freshState();
      addTearDown(s.dispose);

      expect(s.online, isFalse);
      final g = await s.createGroup(
        name: 'Offline Dulu',
        club: 'Test MC',
        when: DateTime(2026, 9, 1, 6, 0),
        you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
      );

      expect(g.onCloud, isFalse, reason: 'tidak ada gid tanpa server');
      expect(g.gid, isNull);
      expect(s.logs.first.body, contains('lokal saja'));
      // Kode gabungnya jatuh ke v2 yang membawa titik rute.
      expect(TripGroup.fromShareCode(g.shareCode).onCloud, isFalse);
    });

    test('gabung grup server saat offline ditolak dengan alasan jelas',
        () async {
      final s = await freshState();
      addTearDown(s.dispose);

      final undangan = TripGroup(
        gid: 'aB3xY9kLmN2pQr7s',
        id: 'GRC-2026',
        name: 'Bromo Etape 2',
        club: 'Garuda Rider Club',
        when: DateTime(2026, 8, 3, 13, 30),
      );

      await expectLater(
        s.importGroup(undangan,
            you: Member(name: 'Rizky', plat: 'N 7 GH', role: 'RIDER')),
        throwsA(isA<StateError>()),
      );
      expect(s.groups.any((g) => g.gid == undangan.gid), isFalse,
          reason: 'grup tidak boleh setengah masuk',);
    });

    test('amRc: grup lokal selalu milikku, grup server ikut rcUid', () async {
      final s = await freshState();
      addTearDown(s.dispose);

      final lokal = await s.createGroup(
        name: 'Punyaku',
        club: 'Test MC',
        when: DateTime(2026, 9, 1, 6, 0),
        you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
      );
      expect(s.amRc(lokal), isTrue);
      expect(s.amRc(ujiGroup()), isTrue);

      // Grup server milik orang lain: aku bukan RC, jadi tidak boleh mengubah.
      final orangLain = TripGroup(
        gid: 'aB3xY9kLmN2pQr7s',
        id: 'KML-8802',
        rcUid: 'uid-orang-lain',
        name: 'Grup Orang',
        club: 'Kalimaya',
        when: DateTime(2026, 8, 17, 6, 0),
      );
      expect(s.amRc(orangLain), isFalse);
    });
  });

  test('SOS menolak menandai siapa pun kalau server tidak tahu siapa aku',
      () async {
    // Tanpa sambungan server, myUid null. Dulu SOS memakai indeks rider, jadi
    // tetap "berhasil" dan menandai rider pertama yang uid-nya juga null —
    // orang yang salah. Sekarang identitasnya wajib jelas.
    final s = await freshState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup());
    expect(s.myUid, isNull, reason: 'tes ini berjalan tanpa Firebase');

    s.riders.add(Rider(
      id: 0,
      uid: null,
      name: 'Orang Lain',
      plat: 'N 9 ZZ',
      role: 'RIDER',
      p: .3,
      v: 40,
      batt: 80,
    ));

    s.fireSos();
    expect(s.sosRider, isNull,
        reason: 'jangan menempelkan SOS ke rider tanpa identitas');
    expect(s.sosAt, isNull);
    expect(s.logs.first.title, contains('SOS tidak bisa dikirim'));
    expect(s.logs.first.body, contains('hanya tersimpan di HP ini'));
  });

  test('clearSos membersihkan tanda dan mencatatnya', () async {
    final s = await freshState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup());
    s.sosUid = 'uid-rc';
    s.sosAt = DateTime(2026, 8, 5, 9, 0);

    await s.clearSos();
    expect(s.sosUid, isNull);
    expect(s.sosAt, isNull);
    expect(s.logs.first.title, contains('SOS ditutup'));
  });

  test('grup tanpa rider: leader/sweeper/rekap tidak melempar Bad state',
      () async {
    final s = await freshState();
    addTearDown(s.dispose);

    await s.createGroup(
      name: 'Kosong',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
    );
    expect(s.riders, isEmpty);

    // Semua turunan ini dulu memanggil reduce() pada daftar kosong.
    expect(s.leader.p, 0);
    expect(s.sweeper.p, 0);
    expect(s.spread, 0);
    expect(s.progress, 0);
    expect(s.etaMin, 0);
    expect(s.avgSpeed, 0);
    expect(s.topSpeed, 0);
    expect(s.count(RiderStatus.aman), 0);
    // Teks bagikan juga harus jadi tanpa exception.
    expect(shareText(s), contains('Rencana Touring'));
  });

  test('SOS diabaikan kalau tidak ada rider (grup tanpa pelacakan)', () async {
    final s = await freshState();
    addTearDown(s.dispose);

    await s.createGroup(
      name: 'Kosong',
      club: 'Test MC',
      when: DateTime(2026, 9, 1, 6, 0),
      you: Member(name: 'A B', plat: 'N 1 AB', role: 'RC'),
    );
    s.fireSos();
    expect(s.sosRider, isNull, reason: 'tanpa posisi, SOS tidak punya lokasi');
    expect(s.logs.first.title, contains('tidak bisa dikirim'),
        reason: 'katakan sebabnya, jangan diam-diam gagal');
  });
}

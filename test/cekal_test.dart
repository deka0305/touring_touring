import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearRoute();
  });

  test('mengeluarkan anggota mencatat namanya supaya bisa dibatalkan',
      () async {
    // Tanpa catatan nama, cekalan jadi permanen: server hanya menyimpan uid,
    // dan uid tidak bisa dikenali manusia untuk dipilih di UI.
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'aB3xY9kLmN2pQr7s', members: [
      Member(name: 'Bagas Pratama', plat: 'N 1 AB', role: 'RC', uid: 'a'),
      Member(name: 'Rio Saputra', plat: 'N 2 CD', role: 'RIDER', uid: 'b'),
    ]);
    pakai(s, g);
    final dicekal = <bool>[];
    s.serverRemove = (g, m, {required ban}) async => dicekal.add(ban);

    final err =
        await s.removeMember(g, g.members.firstWhere((m) => m.uid == 'b'));

    expect(err, isNull);
    expect(dicekal, [true], reason: 'dikeluarkan orang lain = dicekal');
    expect(g.members.map((m) => m.uid), ['a']);
    expect(g.banned, {'b': 'Rio Saputra'});
  });

  test('server gagal: anggota TIDAK hilang dan TIDAK tercatat dicekal',
      () async {
    // Dulu dihapus di HP dulu: kalau server gagal, namanya terlanjur masuk
    // daftar dicekal padahal di server dia tidak pernah dicekal.
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'TRG-7KQ2MX', members: [
      Member(name: 'Bagas Pratama', plat: 'N 1 AB', role: 'RC', uid: 'a'),
      Member(name: 'Rio Saputra', plat: 'N 2 CD', role: 'RIDER', uid: 'b'),
    ]);
    pakai(s, g);
    s.serverRemove = (g, m, {required ban}) async =>
        throw StateError('tidak ada sinyal');

    final err =
        await s.removeMember(g, g.members.firstWhere((m) => m.uid == 'b'));

    expect(err, contains('Rio Saputra'), reason: 'RC harus tahu gagal');
    expect(g.members.map((m) => m.uid), ['a', 'b']);
    expect(g.banned, isEmpty);
  });

  test('izinkan lagi menghapusnya dari daftar cekal dan mencatatnya', () {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'aB3xY9kLmN2pQr7s');
    pakai(s, g);
    g.banned['b'] = 'Rio Saputra';

    s.unbanMember(g, 'b');

    expect(g.banned, isEmpty);
    expect(s.logs.map((l) => l.title),
        contains('Rio Saputra diizinkan gabung lagi'));
    // Tanpa server, cekalannya masih berlaku di sana walau daftar lokal sudah
    // bersih — kegagalan itu harus terlihat, bukan diam.
    expect(s.logs.first.title, contains('Cekalan gagal dibatalkan di server'));
  });

  test('keluar sendiri TIDAK dicekal — harus bisa gabung lagi', () async {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'aB3xY9kLmN2pQr7s', members: [
      Member(name: 'Aku', plat: 'N 1 AB', role: 'RC', uid: null),
    ]);
    pakai(s, g);

    await s.removeMember(g, g.members.first);
    expect(g.banned, isEmpty);
  });

  test('daftar cekal bertahan lewat JSON', () {
    final g = ujiGroup(gid: 'aB3xY9kLmN2pQr7s');
    g.banned['b'] = 'Rio Saputra';
    final ulang = TripGroup.fromJson(g.toJson());
    expect(ulang.banned, {'b': 'Rio Saputra'});
  });

  test('snapshot server TIDAK menghapus daftar cekal lokal', () {
    // Ini yang paling mudah rusak: `banned` hanya ada di HP ini, jadi salinan
    // dari server selalu kosong. Kalau applyFrom menyalinnya, nama-namanya
    // hilang tiap kali ada kiriman dari server dan cekalan jadi permanen lagi.
    final lokal = ujiGroup(gid: 'aB3xY9kLmN2pQr7s');
    lokal.banned['b'] = 'Rio Saputra';
    final dariServer = ujiGroup(gid: 'aB3xY9kLmN2pQr7s', name: 'Nama Baru');

    lokal.applyFrom(dariServer);

    expect(lokal.name, 'Nama Baru', reason: 'sisanya tetap ikut server');
    expect(lokal.banned, {'b': 'Rio Saputra'},
        reason: 'daftar cekal lokal tidak boleh tersapu snapshot server');
  });
}

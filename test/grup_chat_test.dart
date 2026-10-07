import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touring_touring/data.dart';

import 'fixture.dart';

ChatMsg _msg(String key, String uid, {int voice = 0, int at = 0}) => ChatMsg(
  key: key,
  uid: uid,
  name: uid,
  text: voice > 0 ? '' : 'halo',
  voiceSec: voice,
  atMs: at,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearRoute();
  });

  test('kode undangan: dibuat acak, diketik berantakan tetap terbaca', () {
    final code = newInviteCode(math.Random(1));
    expect(isInviteCode(code), isTrue);
    expect(code, startsWith('TRG-'));
    expect(code.length, 10);

    expect(normInviteCode(' trg 7kq2mx '), 'TRG-7KQ2MX');
    expect(normInviteCode('TRG7KQ2MX'), 'TRG-7KQ2MX');
    // Huruf/angka yang gampang tertukar memang tidak dipakai, jadi ditolak.
    expect(normInviteCode('TRG-7KQ2M0'), isNull);
    expect(normInviteCode('TRG-ABC'), isNull);
    // Kode panjang versi lama bukan kode pendek — jatuh ke jalur lama.
    expect(normInviteCode('MnxBQkMtMTIzNHxY'), isNull);
  });

  test('grup baru membagikan kode pendek, grup lama tetap kode panjang', () {
    final baru = ujiGroup(gid: 'TRG-7KQ2MX');
    expect(baru.inviteCode, 'TRG-7KQ2MX');
    final lama = ujiGroup(gid: 'aB3xY9kLmN2pQr7s');
    expect(lama.inviteCode, lama.shareCode);
    expect(TripGroup.fromShareCode(lama.inviteCode).gid, 'aB3xY9kLmN2pQr7s');
  });

  test('riwayat grup buatan bertahan bolak-balik JSON', () {
    final c = CreatedGroupRef(
      gid: 'TRG-7KQ2MX',
      name: 'Bromo',
      club: 'GRC',
      createdAt: DateTime(2026, 9, 1),
      myName: 'Deden',
      myPlat: 'N 1 AB',
      leftAt: DateTime(2026, 9, 2),
    );
    final b = CreatedGroupRef.fromJson(c.toJson());
    expect(
      [b.gid, b.name, b.club, b.myName, b.myPlat],
      ['TRG-7KQ2MX', 'Bromo', 'GRC', 'Deden', 'N 1 AB'],
    );
    expect(b.leftAt, DateTime(2026, 9, 2));
  });

  test(
    'RC keluar saja: riwayat ditandai keluar; hapus: riwayat dibuang',
    () async {
      final s = TripState();
      addTearDown(s.dispose);
      final g1 = ujiGroup(id: 'AAA-0001', gid: 'TRG-AAAAAA');
      final g2 = ujiGroup(id: 'BBB-0002', gid: 'TRG-BBBBBB');
      pakai(s, g1);
      s.groups.add(g2);
      for (final g in [g1, g2]) {
        s.createdGroups.add(
          CreatedGroupRef(
            gid: g.gid!,
            name: g.name,
            club: g.club,
            createdAt: DateTime(2026),
            myName: 'Deden',
            myPlat: '',
          ),
        );
      }

      await s.deleteGroup(g1.id, leaveOnly: true);
      expect(s.groups.contains(g1), isFalse);
      expect(
        s.createdGroups.firstWhere((c) => c.gid == 'TRG-AAAAAA').leftAt,
        isNotNull,
        reason: 'masih bisa dimasuki lagi',
      );

      await s.deleteGroup(g2.id);
      expect(
        s.createdGroups.any((c) => c.gid == 'TRG-BBBBBB'),
        isFalse,
        reason: 'grupnya sudah dihapus, tidak ada yang bisa dimasuki',
      );

      // Riwayat ikut tersimpan walau sudah tidak punya grup sama sekali.
      await Future<void>.delayed(Duration.zero);
      final s2 = TripState();
      addTearDown(s2.dispose);
      await s2.init();
      expect(s2.createdGroups.map((c) => c.gid), ['TRG-AAAAAA']);
    },
  );

  test('identitas diisi sekali, bertahan walau app ditutup tanpa grup',
      () async {
    final s = TripState();
    addTearDown(s.dispose);
    await s.init();
    expect(s.myName, isEmpty, reason: 'pemasangan baru');

    s.setIdentity(name: '  Deden ', plat: 'n 1 ab');
    expect([s.myName, s.myPlat], ['Deden', 'N 1 AB']);

    await Future<void>.delayed(Duration.zero);
    final s2 = TripState();
    addTearDown(s2.dispose);
    await s2.init();
    expect([s2.myName, s2.myPlat], ['Deden', 'N 1 AB']);
  });

  test('ganti identitas ikut memperbarui barisku di grup yang diikuti', () {
    final s = TripState();
    addTearDown(s.dispose);
    // Tanpa Firebase myUid null; anggota tanpa uid tidak boleh ikut berubah.
    final g = ujiGroup(members: [
      Member(name: 'Orang Lain', plat: 'N 9 ZZ', role: 'RC', uid: 'x'),
    ]);
    pakai(s, g);
    s.setIdentity(name: 'Deden', plat: 'n 1 ab', hp: '0812-3456 7890');
    expect(s.myHp, '081234567890', reason: 'hanya angka, siap untuk tel:');
    expect(g.members.single.name, 'Orang Lain',
        reason: 'baris orang lain tidak boleh tertimpa');
  });

  test('nomor HP anggota bertahan bolak-balik JSON', () {
    final m = Member(name: 'A', plat: '', role: 'RIDER', uid: 'u', hp: '0812');
    expect(Member.fromJson(m.toJson()).hp, '0812');
    expect(Member.fromJson({'n': 'A', 'p': '', 'r': 'RIDER'}).hp, '',
        reason: 'data lama tanpa HP tetap terbaca');
  });

  test('obrolan: belum dibaca hanya pesan orang lain yang baru', () {
    final s = TripState();
    addTearDown(s.dispose);
    final g = ujiGroup(gid: 'TRG-7KQ2MX');
    pakai(s, g);
    s.setActive(g.id); // membuka grup = titik mulai hitungan belum dibaca
    final now = DateTime.now().millisecondsSinceEpoch;

    s.applyChat([
      _msg('a', 'orang', at: now - 60000), // riwayat lama
      _msg('b', 'orang', at: now + 1000),
    ]);
    expect(s.chat.length, 2);
    expect(s.chatUnread, 1);

    s.markChatSeen();
    expect(s.chatUnread, 0);
  });

  test('walkie-talkie: hanya pesan suara BARU yang diputar, riwayat tidak', () {
    final s = TripState();
    addTearDown(s.dispose);
    pakai(s, ujiGroup(gid: 'TRG-7KQ2MX'));
    final diputar = <String>[];
    s.onNewVoice = (m) => diputar.add(m.key);
    s.setAutoVoice(true);

    s.applyChat([_msg('a', 'orang', voice: 3)]);
    expect(diputar, isEmpty, reason: 'snapshot pertama itu riwayat');

    s.applyChat([
      _msg('a', 'orang', voice: 3),
      _msg('b', 'orang', voice: 5),
      _msg('c', 'orang'), // teks
    ]);
    expect(diputar, ['b']);

    s.setAutoVoice(false);
    s.applyChat([
      _msg('a', 'orang', voice: 3),
      _msg('b', 'orang', voice: 5),
      _msg('c', 'orang'),
      _msg('d', 'orang', voice: 2),
    ]);
    expect(diputar, ['b'], reason: 'mode mati = tidak diputar');
  });

  test(
    'kirim pesan di grup lokal ditolak dengan alasan, tidak melempar',
    () async {
      final s = TripState();
      addTearDown(s.dispose);
      pakai(s, ujiGroup());
      expect(await s.sendChat('halo'), isNotNull);
      expect(await s.sendChat('   '), isNull, reason: 'pesan kosong diabaikan');
    },
  );
}

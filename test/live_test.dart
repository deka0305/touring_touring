import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';

void main() {
  group('LivePos.stale — deteksi rider hilang', () {
    final now = DateTime(2026, 8, 3, 14, 0, 0);

    LivePos pos({required bool online, required int detikLalu}) => LivePos(
          at: const LatLng(-7.98, 112.63),
          speedKmh: 45,
          heading: 90,
          battery: 70,
          atMs: now
              .subtract(Duration(seconds: detikLalu))
              .millisecondsSinceEpoch,
          online: online,
        );

    test('baru saja kirim dan online = tidak hilang', () {
      expect(pos(online: true, detikLalu: 5).stale(now), isFalse);
      expect(pos(online: true, detikLalu: 89).stale(now), isFalse);
    });

    test('server bilang offline = hilang, walau datanya baru', () {
      // Inilah gunanya onDisconnect: server menandainya sebelum data menua.
      expect(pos(online: false, detikLalu: 1).stale(now), isTrue);
    });

    test('data lebih tua dari 90 detik = hilang walau masih online', () {
      // onDisconnect butuh beberapa detik; umur data jadi jaring keduanya.
      expect(pos(online: true, detikLalu: 91).stale(now), isTrue);
      expect(pos(online: true, detikLalu: 600).stale(now), isTrue);
    });

    test('age menghitung umur data dengan benar', () {
      expect(pos(online: true, detikLalu: 42).age(now).inSeconds, 42);
    });
  });

  group('status rider dari server', () {
    /// Rute lurus ~2,6 km supaya progres mudah dihitung.
    final a = LatLng(-7.9797, 112.6304);
    final b = LatLng(-7.9666, 112.6520);

    setUp(() {
      setRoute([a, b], [const Waypoint(0, 'Mulai'), const Waypoint(1, 'Finish')]);
    });

    test('urutan status: SOS di atas, lalu hilang, tertinggal, berhenti, aman',
        () {
      final urut = RiderStatus.values.toList()
        ..sort((x, y) => x.rank - y.rank);
      expect(urut, [
        RiderStatus.sos,
        RiderStatus.hilang,
        RiderStatus.tertinggal,
        RiderStatus.berhenti,
        RiderStatus.aman,
      ]);
    });

    test('tiap status punya warna berbeda — bisa dibedakan sekilas', () {
      final warna = RiderStatus.values.map((s) => s.color).toSet();
      expect(warna.length, RiderStatus.values.length,
          reason: 'ada dua status berwarna sama');
    });

    test('HILANG punya label sendiri, bukan menumpang BERHENTI', () {
      expect(RiderStatus.hilang.label, 'HILANG');
      expect(RiderStatus.hilang.color, isNot(RiderStatus.berhenti.color));
    });
  });

  group('Cloud.isPermissionDenied — beda "dicabut" dan "jaringan bermasalah"',
      () {
    test('penolakan izin dikenali dari code maupun message', () {
      expect(
          Cloud.isPermissionDenied(FirebaseException(
              plugin: 'database', code: 'permission-denied')),
          isTrue);
      expect(
          Cloud.isPermissionDenied(FirebaseException(
              plugin: 'database',
              code: 'unknown',
              message: 'Client doesn\'t have permission to access')),
          isFalse);
      expect(
          Cloud.isPermissionDenied(FirebaseException(
              plugin: 'database',
              code: 'unknown',
              message: 'Permission denied')),
          isTrue);
      // Bentuk mentah dari SDK lain.
      expect(Cloud.isPermissionDenied('permission denied at /groups'), isTrue);
    });

    test('gangguan jaringan JANGAN dianggap dicabut', () {
      // Kalau ini salah, sinyal hilang sebentar akan menghapus grup dari HP.
      expect(
          Cloud.isPermissionDenied(FirebaseException(
              plugin: 'database',
              code: 'network-error',
              message: 'Connection lost')),
          isFalse);
      expect(Cloud.isPermissionDenied('unavailable'), isFalse);
      expect(Cloud.isPermissionDenied(TimeoutException('lambat')), isFalse);
    });
  });

  group('baterai tidak dilaporkan', () {
    test('Rider.batt null tidak jadi 0 dan tidak bikin simulasi meledak', () {
      final r = Rider(
        id: 0,
        name: 'A B',
        plat: 'N 1 AB',
        role: 'RIDER',
        p: .5,
        v: 40,
        batt: null,
        stopUntil: 0,
      );
      expect(r.batt, isNull);
      // LivePos juga boleh tanpa baterai.
      const pos = LivePos(
        at: LatLng(-7.98, 112.63),
        speedKmh: 0,
        heading: 0,
        battery: null,
        atMs: 0,
        online: true,
      );
      expect(pos.battery, isNull);
    });
  });
}

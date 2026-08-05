import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/share_card.dart';

import 'fixture.dart';

/// Titik [m] meter di utara [from] — cukup teliti untuk jarak sependek ini.
LatLng utara(LatLng from, double m) =>
    LatLng(from.latitude + m / 111320, from.longitude);

void main() {
  final awal = LatLng(-7.9797, 112.6304);
  final t0 = DateTime(2026, 8, 4, 8, 0);

  group('Track — jejak yang benar-benar dilalui', () {
    test('titik diperkecil per 200 m, tapi jarak tetap dihitung penuh', () {
      final t = Track();
      // 20 fix @ 50 m = 1000 m. Kalau tiap fix disimpan, jejak 100 km jadi
      // puluhan ribu titik tanpa menambah ketelitian garis yang terlihat.
      var at = awal;
      t.add(at, 40, t0);
      for (var i = 1; i <= 20; i++) {
        at = utara(awal, i * 50);
        t.add(at, 40, t0.add(Duration(seconds: i * 10)));
      }

      expect(t.km, closeTo(1.0, 0.05), reason: 'jarak dari semua fix');
      expect(t.points.length, lessThanOrEqualTo(7),
          reason: '1000 m / 200 m + titik awal');
      expect(t.points.length, greaterThanOrEqualTo(5));
      expect(t.points.first, awal);
    });

    test('durasi, rata-rata, dan kecepatan maksimum', () {
      // 5 km dalam 59 menit, fix tiap menit — bentuk yang wajar dari GPS nyata.
      final t = Track();
      for (var i = 0; i < 60; i++) {
        t.add(utara(awal, 5000 * i / 59), i == 30 ? 72 : 30,
            t0.add(Duration(minutes: i)));
      }

      expect(t.duration, const Duration(minutes: 59));
      expect(t.km, closeTo(5, 0.1));
      expect(t.avgKmh, closeTo(5.08, 0.2));
      expect(t.topKmh, 72, reason: 'maksimum dari semua fix, bukan yang akhir');
    });

    test('dua fix berjarak satu jam: durasinya nol, bukan satu jam', () {
      // Tidak mungkin bergerak 5 km tanpa satu pun fix selama sejam kecuali
      // app-nya mati di tengahnya. Menghitungnya sebagai perjalanan membuat
      // rata-rata jadi ngawur — inilah sumber "13j 09m" untuk jejak 0,2 km.
      final t = Track();
      t.add(awal, 30, t0);
      t.add(utara(awal, 5000), 30, t0.add(const Duration(hours: 1)));

      expect(t.duration, Duration.zero);
      expect(t.km, closeTo(5, 0.1), reason: 'jaraknya tetap nyata');
    });

    test('lompatan liar GPS tidak dihitung sebagai jarak', () {
      // Fix pertama sesudah GPS "dingin" kadang meleset puluhan km. Kalau
      // dihitung, rekapnya jadi 300 km padahal baru keluar gang.
      final t = Track();
      t.add(awal, 0, t0);
      t.add(utara(awal, 300), 40, t0.add(const Duration(seconds: 30)));
      final sebelum = t.km;

      t.add(LatLng(-6.2, 106.8), 40, t0.add(const Duration(seconds: 40)));
      expect(t.km, sebelum, reason: 'lompatan >5 km diabaikan');
    });

    test('kosong sampai ada dua titik, dan bisa direset', () {
      final t = Track();
      expect(t.isEmpty, isTrue);
      expect(t.duration, Duration.zero);
      expect(t.avgKmh, 0);

      t.add(awal, 0, t0);
      expect(t.isEmpty, isTrue, reason: 'satu titik belum jadi garis');
      t.add(utara(awal, 300), 40, t0.add(const Duration(minutes: 1)));
      expect(t.isEmpty, isFalse);

      t.clear();
      expect(t.isEmpty, isTrue);
      expect(t.km, 0);
      expect(t.topKmh, 0);
      expect(t.startedAt, isNull);
    });

    test('bolak-balik JSON utuh — jejak harus bertahan app ditutup', () {
      final t = Track();
      t.add(awal, 30, t0);
      for (var i = 1; i <= 10; i++) {
        t.add(utara(awal, i * 250), 55, t0.add(Duration(minutes: i)));
      }

      final back = Track.fromJson(t.toJson());
      expect(back.points.length, t.points.length);
      expect(back.km, closeTo(t.km, 1e-9));
      expect(back.topKmh, t.topKmh);
      expect(back.startedAt, t.startedAt);
      expect(back.updatedAt, t.updatedAt);
      const d = Distance();
      for (var i = 0; i < t.points.length; i++) {
        expect(d.as(LengthUnit.Meter, t.points[i], back.points[i]),
            lessThan(1.5));
      }
    });
  });

  group('ShareStats', () {
    test('tanpa jejak: pakai rute rencana dan tandai fromTrack false', () {
      // Penting: kalau ini salah, kartu mengaku "sudah dilalui" padahal yang
      // digambar cuma rencana.
      setRoute(ujiGroup().geometry,
          [const Waypoint(0, 'A'), const Waypoint(18, 'B')]);
      final s = TripState();
      addTearDown(s.dispose);
      s.groups.add(ujiGroup());
      s.activeId = ujiGroupId;

      final stats = ShareStats.of(s, source: ShareSource.rute);
      expect(stats.fromTrack, isFalse);
      expect(stats.trace.length, greaterThan(2));
    });
  });
}

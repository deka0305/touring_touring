import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';
import 'package:touring_touring/polyline.dart';
import 'package:touring_touring/share_card.dart';

import 'fixture.dart';

void main() {
  group('TripMode', () {
    test('motor menghindari tol — di Indonesia motor dilarang masuk tol', () {
      // Ini bukan preferensi, ini aturan. Memakai profil mobil untuk motor
      // menghasilkan rute yang tidak boleh dijalani.
      expect(TripMode.motor.costing, 'motorcycle');
      expect(TripMode.motor.costingOptions['use_tolls'], 0);
    });

    test('mobil boleh tol supaya dapat yang tercepat', () {
      expect(TripMode.mobil.costing, 'auto');
      expect(TripMode.mobil.costingOptions['use_tolls'], 1);
    });

    test('sepeda dan lari pakai profil sendiri, bukan profil mobil', () {
      expect(TripMode.sepeda.costing, 'bicycle');
      expect(TripMode.lari.costing, 'pedestrian');
      // Tidak ada opsi tol: profilnya sendiri sudah tidak memakai jalan bebas.
      expect(TripMode.sepeda.costingOptions, isEmpty);
      expect(TripMode.lari.costingOptions, isEmpty);
    });

    test('costing tiap moda berbeda — kalau sama, pilihannya cuma hiasan', () {
      final costings = TripMode.values.map((m) => m.costing).toSet();
      expect(costings.length, TripMode.values.length);
    });

    test('key bolak-balik, dan nilai asing jatuh ke motor', () {
      for (final m in TripMode.values) {
        expect(TripModeX.fromKey(m.key), m);
      }
      expect(TripModeX.fromKey(null), TripMode.motor);
      expect(TripModeX.fromKey('helikopter'), TripMode.motor);
    });

    test('moda ikut tersimpan di cache grup', () {
      final g = TripGroup(
        id: 'ABC-1234',
        name: 'X',
        club: 'Y',
        when: DateTime(2026, 8, 4, 6, 0),
        mode: TripMode.sepeda,
      );
      expect(TripGroup.fromJson(g.toJson()).mode, TripMode.sepeda);
      // Grup dari versi app lama tidak punya field ini.
      final lama = g.toJson()..remove('mode');
      expect(TripGroup.fromJson(lama).mode, TripMode.motor);
    });
  });

  group('presisi polyline', () {
    test('Valhalla 1e6 vs OSRM/Google 1e5 — salah presisi meleset 10×', () {
      final pts = [
        LatLng(-7.97970, 112.63040),
        LatLng(-7.94250, 112.95300),
      ];
      final enc6 = encodePolyline(pts, precision: 1e6);

      final benar = decodePolyline(enc6, precision: 1e6);
      expect(benar[0].latitude, closeTo(-7.9797, 1e-6));
      expect(benar[0].longitude, closeTo(112.6304, 1e-6));

      // Dibaca dengan presisi salah tidak melempar error — cuma salah tempat,
      // jadi ini jenis bug yang gampang lolos tanpa disadari.
      final salah = decodePolyline(enc6);
      expect(salah[0].latitude, closeTo(-79.797, .01));
      expect(salah[0].longitude, closeTo(1126.3, .1));
    });

    test('presisi 1e6 lebih teliti dari 1e5', () {
      final asli = LatLng(-7.9797123, 112.6304987);
      final k5 = decodePolyline(encodePolyline([asli])).first;
      final k6 =
          decodePolyline(encodePolyline([asli], precision: 1e6), precision: 1e6)
              .first;

      // Dibandingkan lewat koordinat, bukan Distance(): Distance() default
      // membulatkan hasilnya ke meter bulat, jadi kedua galat jadi 0 dan
      // perbandingannya kehilangan makna.
      double galat(LatLng a) =>
          (a.latitude - asli.latitude).abs() +
          (a.longitude - asli.longitude).abs();

      expect(galat(k6), lessThan(galat(k5)));
      expect(galat(k6), lessThan(2e-6), reason: '1e6 ≈ ketelitian 0,1 m');
      expect(galat(k5), greaterThan(1e-6), reason: '1e5 ≈ ketelitian 1 m');
    });
  });

  group('ShareStats — pilihan garis kartu', () {
    TripState siap() {
      final s = TripState();
      s.groups.add(ujiGroup());
      s.activeId = ujiGroupId;
      setRoute(ujiGroup().geometry,
          [const Waypoint(0, 'A'), const Waypoint(18, 'B')]);
      return s;
    }

    test('jejak dan rencana memberi angka masing-masing, tidak tercampur', () {
      final s = siap();
      addTearDown(s.dispose);
      final t0 = DateTime(2026, 8, 4, 7, 0);
      // Jejak pendek yang jelas beda dari rute demo ±43 km.
      s.track.add(const LatLng(-7.9797, 112.6304), 20, t0);
      s.track.add(const LatLng(-7.9700, 112.6400), 40,
          t0.add(const Duration(minutes: 10)));

      final jejak = ShareStats.of(s, source: ShareSource.jejak);
      expect(jejak.fromTrack, isTrue);
      expect(jejak.km, closeTo(s.track.km, 1e-9));
      expect(jejak.trace.length, s.track.points.length);

      final rencana = ShareStats.of(s, source: ShareSource.rute);
      expect(rencana.fromTrack, isFalse,
          reason: 'jangan mengaku sudah dilalui untuk garis rencana');
      expect(rencana.km, closeTo(s.active.km, 1e-9));
      expect(rencana.badge, 'RENCANA');
      // Rute rencana digambar utuh, bukan dipotong sepanjang progres.
      expect(rencana.trace.length, s.active.geometry.length);
    });

    test('rute rencana tidak pernah memakai jam simulasi grup demo', () {
      // Bug nyata: kartu pernah menampilkan "0,0 km" berdampingan dengan
      // "2j 32m", karena durasinya diambil dari clock simulasi '14:32' yang
      // di-hardcode, bukan dari perjalanan.
      final s = siap();
      addTearDown(s.dispose);
      final stats = ShareStats.of(s, source: ShareSource.rute);

      final waktu = stats.metrics.firstWhere((m) => m.label == 'Estimasi');
      expect(waktu.value, fmtDur(s.active.minutes));
      expect(stats.metrics.any((m) => m.value.contains('2j 32m')), isFalse);
      // Jarak dan waktu harus berasal dari sumber yang sama.
      expect(stats.km, s.active.km);
    });

    test('garis dua titik ditandai terlalu pendek, tidak digambar lurus', () {
      final s = siap();
      addTearDown(s.dispose);
      final t0 = DateTime(2026, 8, 4, 7, 0);
      s.track.add(const LatLng(-7.9797, 112.6304), 20, t0);
      s.track.add(const LatLng(-7.9700, 112.6400), 40,
          t0.add(const Duration(minutes: 10)));

      // Dua titik hanya menghasilkan batang lurus yang terlihat seperti bug.
      expect(ShareStats.of(s, source: ShareSource.jejak).traceTooShort, isTrue);
      expect(
          ShareStats.of(s, source: ShareSource.rute).traceTooShort, isFalse);
    });

    test('tanpa rute, sumber rencana tidak melempar dan garisnya kosong', () {
      final s = TripState();
      addTearDown(s.dispose);
      s.groups.add(TripGroup(
          id: 'A-1', name: 'Kosong', club: 'X', when: DateTime(2026, 1, 1)));
      s.activeId = 'A-1';
      clearRoute();

      final stats = ShareStats.of(s, source: ShareSource.rute);
      expect(stats.trace, isEmpty);
      expect(stats.traceTooShort, isTrue);
      expect(stats.km, 0);
    });
  });

  group('jam checkpoint dari jejak nyata', () {
    test('passedAt memberi waktu titik terdekat, dan null kalau tidak lewat',
        () {
      final t = Track();
      final t0 = DateTime(2026, 8, 4, 6, 0);
      t.add(const LatLng(-7.9797, 112.6304), 30, t0);
      t.add(const LatLng(-7.9700, 112.6304), 40,
          t0.add(const Duration(minutes: 20)));
      t.add(const LatLng(-7.9600, 112.6304), 40,
          t0.add(const Duration(minutes: 40)));

      // Checkpoint tepat di jalur → dapat waktunya.
      final lewat = t.passedAt(const LatLng(-7.9700, 112.6304));
      expect(lewat, isNotNull);
      expect(lewat!.difference(t0).inMinutes, 20);

      // Checkpoint jauh dari jalur → null, bukan waktu tebakan.
      expect(t.passedAt(const LatLng(-6.2, 106.8)), isNull);
    });

    test('jejak kosong tidak memberi waktu palsu', () {
      expect(Track().passedAt(const LatLng(-7.98, 112.63)), isNull);
    });

    test('secs ikut tersimpan, jadi jam checkpoint bertahan app ditutup', () {
      final t = Track();
      final t0 = DateTime(2026, 8, 4, 6, 0);
      t.add(const LatLng(-7.9797, 112.6304), 30, t0);
      t.add(const LatLng(-7.9700, 112.6304), 40,
          t0.add(const Duration(minutes: 25)));

      final back = Track.fromJson(t.toJson());
      expect(back.secs, t.secs);
      final lewat = back.passedAt(const LatLng(-7.9700, 112.6304));
      expect(lewat!.difference(t0).inMinutes, 25);
    });
  });
}

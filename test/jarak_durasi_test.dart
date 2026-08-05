import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:touring_touring/data.dart';

void main() {
  setUp(clearRoute);

  group('jarak rute — Distance() default membulatkan ke satuan bulat', () {
    test('rute rapat (titik tiap ~40 m) tidak boleh jadi 0 km', () {
      // Inilah bug yang membuat header menampilkan "KM 0 / 0", rentang
      // rombongan 0,0 km, dan ETA 0 menit pada rute yang jelas ada di peta:
      // rute hasil snap ke jalan punya titik tiap ~40 m, dan as(Kilometer)
      // dengan pembulatan default mengembalikan 0 untuk tiap segmennya.
      const langkah = 0.00036; // ± 40 m per titik
      final pts = [
        for (var i = 0; i < 250; i++) LatLng(-6.2 + langkah * i, 106.63),
      ];
      setRoute(pts, const [Waypoint(0, 'Mulai'), Waypoint(249, 'Finish')]);

      expect(totalKm, greaterThan(9),
          reason: 'rute ~10 km tidak boleh dihitung 0 km');
      expect(totalKm, lessThan(11));
      // Progres di tengah harus benar-benar di tengah, bukan nol.
      expect(distAt(125) / totalKm, closeTo(0.5, 0.02));
    });

    test('satu segmen 300 m tetap terhitung, bukan dibulatkan ke 0', () {
      setRoute(
        [const LatLng(-6.2, 106.63), const LatLng(-6.1973, 106.63)],
        const [Waypoint(0, 'A'), Waypoint(1, 'B')],
      );
      expect(totalKm, closeTo(0.3, 0.02));
    });
  });

  group('durasi jejak — hanya waktu yang benar-benar direkam', () {
    final t0 = DateTime(2026, 8, 4, 19, 40);

    test('jeda panjang (app ditutup) tidak dihitung sebagai perjalanan', () {
      // Persis kasus di lapangan: 0,2 km direkam malam, app ditutup, lalu
      // dilanjut besok pagi — dulu durasinya jadi 13j 09m dan rata-rata 0 km/j.
      final t = Track();
      t.add(const LatLng(-6.2000, 106.6300), 30, t0);
      t.add(const LatLng(-6.2009, 106.6300), 30, t0.add(const Duration(seconds: 20)));
      // Ditutup, dibuka lagi 13 jam kemudian.
      t.add(const LatLng(-6.2018, 106.6300), 30,
          t0.add(const Duration(hours: 13, seconds: 20)));

      expect(t.duration.inHours, 0, reason: '13 jam app mati bukan perjalanan');
      expect(t.duration.inSeconds, 20);
      expect(t.km, greaterThan(0.15), reason: 'jaraknya tetap dijumlahkan');
      expect(t.avgKmh, greaterThan(10),
          reason: 'rata-rata harus wajar, bukan 0 km/j');
    });

    test('jeda wajar antar-fix tetap dihitung', () {
      final t = Track();
      for (var i = 0; i < 5; i++) {
        t.add(LatLng(-6.2 - 0.0009 * i, 106.63), 40,
            t0.add(Duration(seconds: 30 * i)));
      }
      expect(t.duration.inSeconds, 120, reason: '4 jeda × 30 detik');
    });

    test('durasi bertahan lewat JSON, dan jejak lama tidak membawa angka palsu',
        () {
      final t = Track();
      t.add(const LatLng(-6.2, 106.63), 40, t0);
      t.add(const LatLng(-6.2009, 106.63), 40, t0.add(const Duration(minutes: 1)));
      final bolakBalik = Track.fromJson(t.toJson());
      expect(bolakBalik.duration, t.duration);

      // Data versi lama tanpa 'moving': lebih baik 0 daripada selisih
      // end-start yang justru angka salahnya.
      final lama = Track.fromJson({
        'geom': '',
        'secs': <int>[],
        'km': 0.2,
        'top': 40.0,
        'start': t0.toIso8601String(),
        'end': t0.add(const Duration(hours: 13)).toIso8601String(),
      });
      expect(lama.duration, Duration.zero);
    });

    test('clear() mengosongkan durasi juga', () {
      final t = Track();
      t.add(const LatLng(-6.2, 106.63), 40, t0);
      t.add(const LatLng(-6.2009, 106.63), 40, t0.add(const Duration(minutes: 1)));
      expect(t.duration, isNot(Duration.zero));
      t.clear();
      expect(t.duration, Duration.zero);
      expect(t.km, 0);
    });
  });

  test('chip header menjumlahkan semua rider terlacak, tanpa ada yang hilang',
      () {
    // Dulu HILANG dan SOS tidak masuk chip mana pun, jadi 3 rider terlacak
    // bisa tampil sebagai 0 / 0 / 1 dan sisanya lenyap dari hitungan.
    final semua = [
      RiderStatus.aman,
      RiderStatus.tertinggal,
      RiderStatus.hilang,
      RiderStatus.sos,
      RiderStatus.berhenti,
    ];
    expect(semua.toSet(), RiderStatus.values.toSet(),
        reason: 'kalau ada status baru, chip header harus ikut diperbarui');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';

void main() {
  group('kode bagikan', () {
    test('bolak-balik utuh: identitas dan titik rute kembali sama', () {
      final g = TripGroup(
        id: 'ABC-1234',
        name: 'Bromo Etape 2',
        club: 'Garuda Rider Club',
        when: DateTime(2026, 8, 3, 13, 30),
        stops: [
          Stop('Titik Kumpul Malang', const LatLng(-7.9797, 112.6304)),
          Stop('Finish · Penanjakan', const LatLng(-7.9425, 112.9530)),
        ],
      );

      final back = TripGroup.fromShareCode(g.shareCode);
      expect(back.id, g.id);
      expect(back.name, g.name);
      expect(back.club, g.club);
      expect(back.when, g.when);
      expect(back.stops.length, 2);
      expect(back.stops[1].label, 'Finish · Penanjakan');
      expect(back.stops[0].at.latitude, closeTo(-7.9797, 1e-9));
      expect(back.stops[0].at.longitude, closeTo(112.6304, 1e-9));

      // Geometri jalan sengaja tidak dibawa — penerima menghitung ulang.
      expect(back.hasRoute, isFalse);
    });

    test('kode tetap pendek: rute 5 titik di bawah 280 karakter', () {
      final demo = buildDemoGroup();
      final code = demo.shareCode;
      // Terukur 255 char untuk grup demo (versi JSON dulu ~510). Sisanya
      // hampir semuanya nama tempat; ambang ini menjaga agar overhead format
      // tidak diam-diam tumbuh lagi.
      expect(code.length, lessThan(280), reason: 'panjang ${code.length}');
      // Tidak ada padding '=' yang bisa hilang saat disalin.
      expect(code, isNot(contains('=')));
      // Bolak-balik tetap utuh walau formatnya diperas.
      final back = TripGroup.fromShareCode(code);
      expect(back.stops.length, demo.stops.length);
      for (var i = 0; i < demo.stops.length; i++) {
        expect(back.stops[i].at.latitude,
            closeTo(demo.stops[i].at.latitude, 1e-5));
        expect(back.stops[i].at.longitude,
            closeTo(demo.stops[i].at.longitude, 1e-5));
      }
    });

    test('label dengan pemisah | ; , tidak merusak kode', () {
      final g = TripGroup(
        id: 'SEP-0001',
        name: 'Touring | Etape, 2; Lanjut',
        club: 'A|B,C;D',
        when: DateTime(2026, 8, 3, 13, 30),
        stops: [
          Stop('Pos 1, jalur | atas; kanan', const LatLng(-7.98, 112.63)),
          Stop('Pos 2', const LatLng(-7.94, 112.95)),
        ],
      );
      final back = TripGroup.fromShareCode(g.shareCode);
      expect(back.stops.length, 2);
      expect(back.stops[0].label, 'Pos 1  jalur   atas  kanan');
      expect(back.stops[1].label, 'Pos 2');
      expect(back.name, 'Touring   Etape  2  Lanjut');
    });

    test('label sangat panjang dipotong, bukan bikin kode membengkak', () {
      final g = TripGroup(
        id: 'LNG-0002',
        name: 'X',
        club: 'Y',
        when: DateTime(2026, 8, 3),
        stops: [
          Stop('Rest Area Tumpang Sebelah Warung Bu Sri Yang Di Pojok',
              const LatLng(-7.98, 112.63)),
          Stop('B', const LatLng(-7.94, 112.95)),
        ],
      );
      final back = TripGroup.fromShareCode(g.shareCode);
      expect(back.stops[0].label.length, lessThanOrEqualTo(28));
      expect(back.stops[0].label, startsWith('Rest Area Tumpang'));
    });

    test('grup di server: kode hanya membawa kunci, jauh lebih pendek', () {
      final demo = buildDemoGroup();
      final lokal = demo.shareCode.length;

      // Grup yang sama, tapi sudah terdaftar di server.
      final cloud = TripGroup(
        gid: 'aB3xY9kLmN2pQr7s',
        id: demo.id,
        rcUid: 'uid-rc',
        name: demo.name,
        club: demo.club,
        when: demo.when,
        stops: demo.stops,
        geometry: demo.geometry,
        stopIndices: demo.stopIndices,
        km: demo.km,
        minutes: demo.minutes,
      );

      final code = cloud.shareCode;
      expect(code.length, lessThan(lokal ~/ 2),
          reason: 'v3 ${code.length} char vs v2 $lokal char');
      expect(code, isNot(contains('=')));

      final back = TripGroup.fromShareCode(code);
      expect(back.gid, 'aB3xY9kLmN2pQr7s');
      expect(back.onCloud, isTrue);
      expect(back.id, demo.id);
      expect(back.name, demo.name);
      expect(back.club, demo.club);
      expect(back.when, demo.when);
      // Titik & rute sengaja tidak dibawa: itu diambil dari server.
      expect(back.stops, isEmpty);
      expect(back.hasRoute, isFalse);
    });

    test('kode v3 tanpa kunci server ditolak', () {
      // "3||GRC-2026|X|Y|29762310" — bidang gid kosong.
      const noKey = 'M3x8R1JDLTIwMjZ8WHxZfDI5NzYyMzEw';
      expect(() => TripGroup.fromShareCode(noKey),
          throwsA(isA<FormatException>()));
    });

    test('kode dengan spasi/baris baru tetap terbaca', () {
      final g = TripGroup(
        id: 'XYZ-9999',
        name: 'Sunday Ride',
        club: 'Sunset Jaya',
        when: DateTime(2026, 1, 1, 5, 30),
        stops: [Stop('A', const LatLng(-7, 112))],
      );
      // WhatsApp sering menyisipkan baris baru saat pesan panjang disalin.
      final messy = '${g.shareCode.substring(0, 10)}\n '
          '${g.shareCode.substring(10)}';
      expect(TripGroup.fromShareCode(messy).id, 'XYZ-9999');
    });

    test('kode rusak, kosong, atau versi lain ditolak dengan pesan jelas', () {
      expect(() => TripGroup.fromShareCode(''),
          throwsA(isA<FormatException>()));
      expect(() => TripGroup.fromShareCode('bukan-kode-valid!!'),
          throwsA(isA<FormatException>()));
      // Base64 sah tapi isinya bukan format kode.
      expect(() => TripGroup.fromShareCode('aGFsbG8gZHVuaWE'),
          throwsA(isA<FormatException>()));
      // Bidang kurang.
      expect(() => TripGroup.fromShareCode('MnxBQkMtMTIzNHxY'),
          throwsA(isA<FormatException>()));
      // JSON sah tapi versi 99 → ditolak, bukan crash.
      const v99 =
          'eyJ2Ijo5OSwiaWQiOiJBQkMtMTIzNCIsIm5hbWUiOiJYIiwiY2x1YiI6IlkiLCJ3aGVuIjoiMjAyNi0wMS0wMVQwMDowMDowMC4wMDAiLCJzdG9wcyI6W119';
      expect(() => TripGroup.fromShareCode(v99),
          throwsA(isA<FormatException>()));
    });
  });

  group('kesiapan grup', () {
    test('todo menyebut apa yang kurang, satu per satu', () {
      final g = TripGroup(
        id: 'A-1',
        name: 'X',
        club: 'Y',
        when: DateTime(2026, 1, 1),
      );
      expect(g.todo, ['Rute belum disusun', 'Belum ada anggota']);
      expect(g.ready, isFalse);

      g.members.add(Member(name: 'Budi', plat: 'N 1 AB', role: 'RIDER'));
      expect(g.todo, ['Rute belum disusun', 'Belum ada road captain']);

      g.members.first.role = 'RC';
      g.stops = [
        Stop('A', const LatLng(-7.98, 112.63)),
        Stop('B', const LatLng(-7.94, 112.95)),
      ];
      g.geometry = [g.stops[0].at, g.stops[1].at];
      g.stopIndices = [0, 1];
      expect(g.todo, isEmpty);
      expect(g.ready, isTrue);
    });

    test('stopKmAt naik sepanjang rute dan aman di indeks tepi', () {
      final demo = buildDemoGroup();
      expect(demo.stopKmAt(0), 0);
      expect(demo.stopKmAt(4), closeTo(demo.km, 0.001));
      for (var i = 1; i < demo.stops.length; i++) {
        expect(demo.stopKmAt(i), greaterThan(demo.stopKmAt(i - 1)));
      }
    });
  });

  group('applyFrom', () {
    TripGroup penuh() => TripGroup(
          gid: 'aB3xY9kLmN2pQr7s',
          id: 'GRC-2026',
          rcUid: 'uid-rc',
          name: 'Bromo Etape 2',
          club: 'Garuda Rider Club',
          when: DateTime(2026, 8, 3, 13, 30),
          stops: [
            Stop('Malang', const LatLng(-7.9797, 112.6304)),
            Stop('Penanjakan', const LatLng(-7.9425, 112.9530)),
          ],
          geometry: [
            const LatLng(-7.9797, 112.6304),
            const LatLng(-7.9600, 112.8000),
            const LatLng(-7.9425, 112.9530),
          ],
          stopIndices: [0, 2],
          km: 43.2,
          minutes: 96,
          members: [
            Member(name: 'Bagas', plat: 'N 1 AB', role: 'RC', uid: 'uid-rc'),
            Member(name: 'Rizky', plat: 'N 7 GH', role: 'RIDER', uid: 'uid-2'),
          ],
        );

    test('menyalin semua bidang — tidak ada yang tertinggal', () {
      final sumber = penuh();
      final target = TripGroup(
          id: '—', name: '', club: '', when: DateTime(2000));

      target.applyFrom(sumber);

      // Bandingkan lewat toJson: kalau nanti ada bidang baru yang lupa
      // disalin di applyFrom, test ini yang gagal — bukan pengguna.
      expect(target.toJson(), sumber.toJson());
    });

    test('identitas objek tetap: inilah yang bikin layar jadi hitam blank', () {
      // Layar detail grup memegang referensi ini. Kalau data server masuk
      // dengan cara menukar objek, referensinya jadi yatim dan layarnya kosong.
      final dipegangLayar = TripGroup(
          id: 'GRC-2026', gid: 'aB3xY9kLmN2pQr7s',
          name: 'Belum lengkap', club: '', when: DateTime(2000));
      final daftar = [dipegangLayar];

      daftar.first.applyFrom(penuh());

      expect(identical(daftar.first, dipegangLayar), isTrue);
      expect(daftar.contains(dipegangLayar), isTrue,
          reason: 'objek yang dipegang layar harus masih ada di daftar');
      // Dan isinya benar-benar terbarui.
      expect(dipegangLayar.name, 'Bromo Etape 2');
      expect(dipegangLayar.members.length, 2);
      expect(dipegangLayar.hasRoute, isTrue);
      expect(dipegangLayar.km, 43.2);
    });
  });

  test('initials tahan nama satu kata, spasi ganda, dan huruf kecil', () {
    expect(initials('Bagas Pratama'), 'BP');
    expect(initials('bagas'), 'B');
    expect(initials('  Reza   Fauzi Nugroho '), 'RF');
    expect(initials(''), '?');
  });

  test('rute aktif: setRoute hitung totalKm, clearRoute matikan routeReady', () {
    setRoute(
      [const LatLng(-7.9797, 112.6304), const LatLng(-7.9666, 112.6520)],
      [const Waypoint(0, 'Mulai'), const Waypoint(1, 'Finish')],
    );
    expect(routeReady, isTrue);
    expect(totalKm, closeTo(2.6, 1));
    expect(pointAt(0), route.first);
    expect(pointAt(1), route.last);
    expect(distAt(0), 0);
    expect(distAt(1), closeTo(totalKm, 1e-9));

    clearRoute();
    expect(routeReady, isFalse);
    expect(totalKm, 0);
    // Tanpa rute, pointAt tidak boleh melempar — layar bisa render kosong.
    expect(pointAt(0.5), const LatLng(0, 0));
    expect(distAt(3), 0);
  });
}

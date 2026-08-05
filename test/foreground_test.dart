import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:touring_touring/location.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android merekam lewat layanan foreground, bukan stream biasa', () {
    // Kalau setelan ini turun jadi LocationSettings biasa, perekaman berhenti
    // beberapa menit setelah layar mati — gejalanya jejak terpotong di tengah
    // touring, bukan error, jadi tidak akan terlihat tanpa cek ini.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final s = LocationSharer.settings();

    expect(s, isA<AndroidSettings>());
    final fg = (s as AndroidSettings).foregroundNotificationConfig;
    expect(fg, isNotNull, reason: 'tanpa ini app dibekukan saat layar mati');
    expect(fg!.enableWakeLock, isTrue,
        reason: 'fix harus datang satu per satu, bukan menumpuk');
    expect(fg.setOngoing, isTrue);
    expect(s.distanceFilter, 25, reason: 'saringan kuota tetap terpakai');
  });

  test('platform lain tetap pakai setelan biasa', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(LocationSharer.settings(), isNot(isA<AndroidSettings>()));
  });
}

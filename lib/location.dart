import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'cloud.dart';

/// Hasil percobaan menyalakan berbagi lokasi.
enum LocationShareResult {
  ok,

  /// Pengguna menolak izin lokasi kali ini.
  ditolak,

  /// Ditolak permanen — harus dibuka lewat Pengaturan aplikasi.
  ditolakPermanen,

  /// GPS/layanan lokasi HP-nya mati.
  layananMati,

  /// Grup ini tidak ada di server, atau server tidak tersambung. Perekaman
  /// jejak tetap jalan — hanya pengiriman ke anggota lain yang tidak.
  tanpaServer,
}

/// Mengirim posisiku ke `live/{uid}` selama app dibuka.
///
/// Dua saringan menentukan biaya kuota Firebase, dan keduanya penting:
/// interval minimum [_minInterval] dan pergeseran minimum [_minMeters].
/// Rider yang sedang berhenti jadi hampir tidak memakai kuota. Lihat
/// perhitungannya di RENCANA_BACKEND.md §5.
///
/// ponytail: baterai belum dikirim — butuh paket lagi (`battery_plus`) dan
/// nilainya kecil dibanding posisi. `live/b` sudah disiapkan di Rules, jadi
/// menambahkannya nanti cuma satu pemanggilan.
class LocationSharer {
  LocationSharer(this._cloud);

  Cloud _cloud;

  /// Ganti sambungan server. Perlu karena sharer bisa dibuat saat masih
  /// offline; tanpa ini ia memegang Cloud mati selamanya dan posisinya tidak
  /// pernah terkirim walau server sudah tersambung.
  set cloud(Cloud c) => _cloud = c;

  static const _minInterval = Duration(seconds: 10);
  static const _minMeters = 25;
  static const _dist = Distance(roundResult: false);

  /// Setelan pembacaan GPS. [distanceFilter] adalah saringan pertama dan
  /// dikerjakan OS — hemat baterai karena callback-nya tidak dipanggil untuk
  /// pergeseran kecil.
  ///
  /// Di Android dipakai layanan foreground. Tanpa itu sistem membekukan app
  /// beberapa menit setelah layar mati, dan jejaknya berhenti persis saat HP
  /// masuk kantong — kondisi normal sepanjang touring.
  @visibleForTesting
  static LocationSettings settings() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _minMeters,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _minMeters,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Merekam perjalanan',
        notificationText: 'Jejak GPS dicatat walau layar mati',
        notificationChannelName: 'Rekam perjalanan',
        // Wake lock menjaga fix tetap datang satu per satu. Tanpa itu Android
        // menahannya lalu mengirim menumpuk saat layar dinyalakan, dan jejak
        // di antaranya jadi garis lurus.
        enableWakeLock: true,
        // Tidak bisa di-swipe: notifikasinya satu-satunya tanda perekaman
        // masih jalan, dan menghilangkannya menyesatkan.
        setOngoing: true,
      ),
    );
  }

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  String? _gid;
  LatLng? _lastSent;
  DateTime? _lastSentAt;

  /// Grup yang posisinya sedang dikirim ke server, null kalau hanya merekam.
  String? get sharingGid => _gid;

  /// True kalau GPS sedang dibaca — dengan atau tanpa server.
  bool get running => _sub != null;

  /// Mulai membaca GPS. Perekaman jejak selalu jalan; pengiriman ke anggota
  /// lain hanya kalau grupnya ada di server dan server terjangkau, sehingga
  /// rider yang offline pun tetap dapat rekap perjalanannya sendiri.
  Future<LocationShareResult> start(String? gid) async {
    if (running && _gid == gid) return LocationShareResult.ok;
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationShareResult.layananMati;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return LocationShareResult.ditolakPermanen;
    }
    if (perm == LocationPermission.denied) return LocationShareResult.ditolak;

    final bisaKirim = gid != null && _cloud.ready;
    _gid = bisaKirim ? gid : null;
    if (bisaKirim) {
      // Titipkan penanda offline ke server SEBELUM mulai mengirim, supaya
      // sinyal yang putus di kiriman pertama pun tetap terdeteksi.
      try {
        await _cloud.markOfflineOnDisconnect(gid);
      } catch (e) {
        debugPrint('location: onDisconnect gagal ($e)');
      }
    }

    _sub = Geolocator.getPositionStream(locationSettings: settings())
        .listen(_onFix, onError: (Object e) {
      debugPrint('location: stream GPS error ($e)');
    });

    // Rider yang berhenti tidak menghasilkan fix baru, jadi posisinya akan
    // dianggap kedaluwarsa oleh anggota lain. Denyut ini menjaganya tetap
    // terlihat hidup tanpa menunggu dia bergerak.
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) => _repeat());
    return bisaKirim
        ? LocationShareResult.ok
        : LocationShareResult.tanpaServer;
  }

  Future<void> stop() async {
    final gid = _gid;
    _gid = null;
    _lastSent = null;
    _lastSentAt = null;
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (gid == null) return;
    try {
      await _cloud.clearLive(gid);
    } catch (e) {
      debugPrint('location: gagal membersihkan live ($e)');
    }
  }

  void _onFix(Position pos) {
    final now = DateTime.now();
    final at = LatLng(pos.latitude, pos.longitude);

    // Saringan kedua, dikerjakan app: OS bisa mengirim fix lebih rapat dari
    // distanceFilter saat akurasinya membaik.
    if (_lastSentAt != null && now.difference(_lastSentAt!) < _minInterval) {
      return;
    }
    if (_lastSent != null &&
        _dist.as(LengthUnit.Meter, _lastSent!, at) < _minMeters) {
      return;
    }
    _send(at, pos.speed * 3.6, pos.heading, now);
  }

  /// Kirim ulang posisi terakhir supaya anggota lain tahu aku masih hidup.
  void _repeat() {
    final at = _lastSent;
    if (at == null || _gid == null) return;
    // Hanya untuk menjaga status online; jangan lewat _send supaya titik yang
    // sama tidak dicatat ulang ke jejak.
    _cloud
        .putLive(_gid!,
            lat: at.latitude, lng: at.longitude, speedKmh: 0, heading: 0)
        .catchError((Object e) => debugPrint('location: denyut gagal (\$e)'));
  }

  void _send(LatLng at, double speedKmh, double heading, DateTime now) {
    _lastSent = at;
    _lastSentAt = now;
    // Jejak direkam lebih dulu dan tanpa syarat: itu milik pengguna sendiri.
    onFix?.call(at, speedKmh);

    final gid = _gid;
    if (gid == null) return;
    _cloud
        .putLive(gid,
            lat: at.latitude,
            lng: at.longitude,
            speedKmh: speedKmh.isFinite && speedKmh > 0 ? speedKmh : 0,
            heading: heading.isFinite ? heading : 0)
        .catchError((Object e) => debugPrint('location: kirim gagal ($e)'));
  }

  /// Dipanggil tiap posisi terkirim. Dipakai TripState untuk merekam jejak
  /// perjalanan sendiri — jejak itu lokal, tidak menambah kuota server.
  void Function(LatLng at, double speedKmh)? onFix;
}

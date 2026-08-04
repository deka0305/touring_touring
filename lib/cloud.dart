import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'model.dart';
import 'polyline.dart';

/// Satu-satunya tempat yang tahu tentang Firebase. Sisanya app hanya bicara
/// dengan kelas ini, jadi mode lokal dan mode server memakai jalur yang sama.
///
/// App harus tetap jalan tanpa Firebase terkonfigurasi: [ready] false berarti
/// semua grup hanya hidup di HP ini, dan tidak ada satu pun panggilan di bawah
/// yang dilakukan.
class Cloud {
  Cloud({FirebaseOptions? options}) : _options = options;

  final FirebaseOptions? _options;

  DatabaseReference? _root;
  String? _uid;
  String? _error;

  /// True kalau Firebase tersambung dan sudah punya uid anonim.
  bool get ready => _root != null && _uid != null;

  /// uid anonim milik HP ini. Bertahan sampai app dihapus.
  String? get uid => _uid;

  /// Alasan kegagalan terakhir, untuk ditampilkan di UI. Null berarti aman.
  String? get error => _error;

  /// Coba sambungkan. Tidak pernah melempar — kegagalan hanya membuat [ready]
  /// tetap false supaya app jatuh ke mode lokal, bukan gagal dibuka.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      final cred = await FirebaseAuth.instance.signInAnonymously();
      _uid = cred.user?.uid;
      if (_uid == null) throw StateError('Firebase tidak memberi uid.');

      final db = FirebaseDatabase.instance;
      // Cache lokal Firebase: grup yang sudah pernah dibuka tetap terbaca
      // saat sinyal hilang di tengah touring.
      db.setPersistenceEnabled(true);
      _root = db.ref('groups');
      _error = null;
    } catch (e) {
      _root = null;
      _uid = null;
      _error = _readable(e);
      debugPrint('cloud: mode lokal ($e)');
    }
  }

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('configuration') || s.contains('options')) {
      return 'Firebase belum dikonfigurasi di app ini.';
    }
    if (s.contains('operation-not-allowed') || s.contains('ADMIN_ONLY')) {
      return 'Anonymous sign-in belum diaktifkan di konsol Firebase.';
    }
    if (s.contains('network') || s.contains('unavailable')) {
      return 'Tidak ada koneksi ke server.';
    }
    return 'Gagal menyambung ke server.';
  }

  /// Kunci grup 16 karakter: sekaligus rahasia yang dibagikan lewat kode.
  /// Random.secure() supaya tidak bisa diramalkan dari kunci lain.
  static String newGid() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random.secure();
    return List.generate(16, (_) => alphabet[rnd.nextInt(alphabet.length)])
        .join();
  }

  // ── Tulis ────────────────────────────────────────────────────────────────

  /// Daftarkan grup baru. Penulis otomatis jadi rcUid — Rules menuntut itu.
  Future<void> createGroup(TripGroup g) async {
    final ref = _need(g.gid);
    await ref.update({
      'meta': {
        'displayId': g.id,
        'name': g.name,
        'club': g.club,
        'whenMs': g.when.millisecondsSinceEpoch,
        'mode': g.mode.key,
        'rcUid': _uid,
        'createdMs': DateTime.now().millisecondsSinceEpoch,
      },
    });
    // Anggota ditulis terpisah: Rules memvalidasi members/$uid per node.
    for (final m in g.members) {
      await ref.child('members/$_uid').set(_member(m));
    }
  }

  /// Simpan rute. Hanya road captain yang lolos Rules di sini.
  ///
  /// Moda perjalanan ikut disimpan ke `meta` — bukan sebagai anak `groups/$gid`
  /// langsung, karena Rules menolak anak yang tidak dikenal di situ.
  Future<void> putRoute(TripGroup g) async {
    final ref = _need(g.gid);
    await ref.child('meta').update({'mode': g.mode.key});
    await ref.update({
      'stops': [
        for (final s in g.stops)
          {'l': s.label, 'lat': s.at.latitude, 'lng': s.at.longitude},
      ],
      'route': {
        'km': g.km,
        'minutes': g.minutes,
        'geom': encodePolyline(g.geometry),
        'idx': g.stopIndices,
      },
    });
  }

  Future<void> putMeta(TripGroup g) => _need(g.gid).child('meta').update({
        'name': g.name,
        'club': g.club,
        'whenMs': g.when.millisecondsSinceEpoch,
        'mode': g.mode.key,
      });

  /// Tulis anggota ke `members/{m.uid}`.
  ///
  /// [Member.uid] wajib ada. Dulu di sini ada fallback ke uid-ku sendiri, dan
  /// itu jebakan: satu anggota tanpa kunci akan menimpa baris road captain
  /// tanpa suara. Lebih baik gagal terang-terangan.
  Future<void> putMember(TripGroup g, Member m) {
    final key = m.uid;
    if (key == null) {
      throw StateError('Anggota "${m.name}" belum punya kunci.');
    }
    return _need(g.gid).child('members/$key').set(_member(m));
  }

  /// Keluarkan anggota. [ban] mencekalnya supaya tidak bisa mendaftar ulang
  /// pakai kode gabung yang masih dia pegang — tanpa itu, mengeluarkan orang
  /// tidak berlaku sama sekali. Dipakai false saat seseorang keluar sendiri.
  Future<void> removeMember(TripGroup g, Member m, {bool ban = false}) async {
    final target = m.uid;
    if (target == null) {
      throw StateError('Anggota ini belum punya uid di server.');
    }
    final ref = _need(g.gid);
    await ref.child('members/$target').remove();
    // Posisinya juga dihapus; kalau tidak, markernya menggantung di peta
    // anggota lain sampai ada yang menimpanya.
    await ref.child('live/$target').remove();
    if (ban) await ref.child('banned/$target').set(true);
  }

  /// Izinkan lagi orang yang tadinya dicekal.
  Future<void> unban(TripGroup g, String memberUid) =>
      _need(g.gid).child('banned/$memberUid').remove();

  /// True kalau [e] adalah penolakan izin dari Security Rules — bukan gangguan
  /// jaringan. Bedanya penting: yang ini berarti aksesku memang dicabut, jadi
  /// grupnya harus dilepas, bukan dicoba ulang.
  static bool isPermissionDenied(Object e) {
    if (e is FirebaseException) {
      if (e.code.contains('permission-denied')) return true;
      return (e.message ?? '').toLowerCase().contains('permission denied');
    }
    return e.toString().toLowerCase().contains('permission denied');
  }

  Future<void> deleteGroup(TripGroup g) => _need(g.gid).remove();

  Map<String, Object?> _member(Member m) => {
        'name': m.name,
        'plat': m.plat,
        'role': m.role,
        'joinedMs': DateTime.now().millisecondsSinceEpoch,
      };

  // ── Baca ─────────────────────────────────────────────────────────────────

  /// Ambil satu grup sekali. Null kalau tidak ada atau tidak boleh dibaca.
  ///
  /// Catatan: Rules menuntut keanggotaan untuk membaca, jadi urutan bergabung
  /// adalah tulis-dulu-baru-baca — lihat [join].
  Future<TripGroup?> fetchGroup(String gid) async {
    final snap = await _need(gid).get();
    if (!snap.exists) return null;
    return _parse(gid, snap.value);
  }

  /// Ikuti perubahan grup: anggota masuk, rute diubah RC, detail diedit.
  Stream<TripGroup> watchGroup(String gid) =>
      _need(gid).onValue.map((e) => _parse(gid, e.snapshot.value)).where(
          (g) => g.name.isNotEmpty);

  /// Bergabung: tulis diri sebagai anggota lebih dulu (Rules mengizinkan itu
  /// tanpa keanggotaan sebelumnya), baru grupnya bisa dibaca.
  Future<TripGroup?> join(String gid, Member me) async {
    final ref = _need(gid);
    await ref.child('members/$_uid').set(_member(
        Member(name: me.name, plat: me.plat, role: 'RIDER')));
    return fetchGroup(gid);
  }

  // ── Lokasi live ───────────────────────────────────────────────────────────

  /// Kirim posisiku. Rules hanya mengizinkan menulis `live/{uid-ku}`, jadi
  /// tidak ada cara memalsukan posisi orang lain.
  Future<void> putLive(
    String gid, {
    required double lat,
    required double lng,
    required double speedKmh,
    required double heading,
    int? battery,
  }) =>
      _need(gid).child('live/$_uid').set({
        'lat': lat,
        'lng': lng,
        's': speedKmh.clamp(0, 300).roundToDouble(),
        'h': (heading % 360).clamp(0, 359).roundToDouble(),
        't': DateTime.now().millisecondsSinceEpoch,
        'online': true,
        if (battery != null) 'b': battery.clamp(0, 100),
      });

  /// Titipkan ke server: begitu koneksiku putus, tandai aku offline. Ini
  /// dieksekusi server, jadi tetap jalan walau app mati mendadak atau sinyal
  /// hilang di tengah jalan — inti dari deteksi "ada yang tertinggal".
  Future<void> markOfflineOnDisconnect(String gid) =>
      _need(gid).child('live/$_uid/online').onDisconnect().set(false);

  /// Berhenti berbagi: hapus posisiku dan batalkan titipan onDisconnect.
  Future<void> clearLive(String gid) async {
    final ref = _need(gid).child('live/$_uid');
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  /// Posisi semua anggota, di-key oleh uid.
  Stream<Map<String, LivePos>> watchLive(String gid) =>
      _need(gid).child('live').onValue.map((e) {
        final out = <String, LivePos>{};
        for (final entry in _map(e.snapshot.value).entries) {
          final v = _map(entry.value);
          final lat = (v['lat'] as num?)?.toDouble();
          final lng = (v['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          out[entry.key] = LivePos(
            at: LatLng(lat, lng),
            speedKmh: (v['s'] as num?)?.toDouble() ?? 0,
            heading: (v['h'] as num?)?.toDouble() ?? 0,
            battery: (v['b'] as num?)?.toInt(),
            atMs: (v['t'] as num?)?.toInt() ?? 0,
            online: v['online'] as bool? ?? false,
          );
        }
        return out;
      });

  DatabaseReference _need(String? gid) {
    final r = _root;
    if (r == null) throw StateError('Firebase belum siap.');
    if (gid == null) throw StateError('Grup ini belum ada di server.');
    return r.child(gid);
  }

  /// Bentuk data dari RTDB → TripGroup. Toleran: node yang belum ada
  /// (mis. rute belum disusun) menghasilkan nilai kosong, bukan error.
  TripGroup _parse(String gid, Object? raw) {
    final m = _map(raw);
    final meta = _map(m['meta']);
    final route = _map(m['route']);

    return TripGroup(
      gid: gid,
      id: meta['displayId'] as String? ?? '—',
      rcUid: meta['rcUid'] as String?,
      name: meta['name'] as String? ?? '',
      club: meta['club'] as String? ?? '',
      when: DateTime.fromMillisecondsSinceEpoch(
          (meta['whenMs'] as num?)?.toInt() ?? 0),
      mode: TripModeX.fromKey(meta['mode'] as String?),
      stops: [
        for (final s in _list(m['stops']))
          Stop(
            _map(s)['l'] as String? ?? '',
            LatLng((_map(s)['lat'] as num?)?.toDouble() ?? 0,
                (_map(s)['lng'] as num?)?.toDouble() ?? 0),
          ),
      ],
      geometry: decodePolyline(route['geom'] as String? ?? ''),
      stopIndices: [
        for (final i in _list(route['idx'])) (i as num?)?.toInt() ?? 0,
      ],
      km: (route['km'] as num?)?.toDouble() ?? 0,
      minutes: (route['minutes'] as num?)?.toInt() ?? 0,
      members: [
        for (final e in _map(m['members']).entries)
          if (_map(e.value) case final mm when mm.isNotEmpty)
            Member(
              uid: e.key,
              name: mm['name'] as String? ?? '—',
              plat: mm['plat'] as String? ?? '',
              role: mm['role'] as String? ?? 'RIDER',
            ),
      ],
    );
  }

  /// RTDB mengembalikan `Map<Object?, Object?>`; rapikan jadi berkunci String.
  Map<String, Object?> _map(Object? v) => v is Map
      ? {for (final e in v.entries) e.key.toString(): e.value}
      : const {};

  /// Node berindeks bisa datang sebagai List (indeks padat) atau Map (berlubang).
  List<Object?> _list(Object? v) {
    if (v is List) return v;
    if (v is Map) {
      final keys = v.keys.map((k) => int.tryParse(k.toString()) ?? -1).toList()
        ..sort();
      return [for (final k in keys) v[k.toString()] ?? v[k]];
    }
    return const [];
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';
import 'track.dart';

/// Penyimpanan lokal: grup, grup aktif, riwayat, jejak perjalanan, dan
/// preferensi tema disimpan sebagai satu blob JSON di SharedPreferences.
///
/// ponytail: satu key, tulis-ulang seluruhnya tiap simpan. Datanya puluhan KB,
/// jadi cukup. Kalau nanti ratusan grup atau butuh query, pindah ke sqflite.
const _key = 'touring_state_v1';

class Saved {
  const Saved({
    required this.groups,
    required this.activeId,
    required this.logs,
    required this.dark,
    required this.tracks,
  });

  final List<TripGroup> groups;
  final String? activeId;
  final List<LogEntry> logs;
  final bool dark;

  /// Jejak perjalanan per Group ID. Lokal saja — tidak pernah dikirim ke
  /// server, jadi ini satu-satunya tempat ia bertahan kalau app ditutup.
  final Map<String, Track> tracks;
}

Future<Saved?> loadState() async {
  try {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Saved(
      groups: [
        for (final g in (j['groups'] as List))
          TripGroup.fromJson(g as Map<String, dynamic>),
      ],
      activeId: j['active'] as String?,
      logs: [
        for (final l in (j['logs'] as List? ?? []))
          LogEntry.fromJson(l as Map<String, dynamic>),
      ],
      dark: j['dark'] as bool? ?? true,
      tracks: {
        for (final e in (j['tracks'] as Map? ?? const {}).entries)
          e.key.toString(): Track.fromJson(e.value as Map<String, dynamic>),
      },
    );
  } catch (e) {
    // Data rusak atau dari versi lama: mulai bersih daripada gagal buka app.
    debugPrint('touring: gagal baca simpanan, mulai baru ($e)');
    return null;
  }
}

Future<void> saveState(Saved s) async {
  final body = jsonEncode({
    'groups': [for (final g in s.groups) g.toJson()],
    'active': s.activeId,
    // Riwayat dibatasi biar blob-nya tidak tumbuh tanpa batas.
    'logs': [for (final l in s.logs.take(50)) l.toJson()],
    'dark': s.dark,
    'tracks': {
      for (final e in s.tracks.entries)
        if (e.value.points.isNotEmpty) e.key: e.value.toJson(),
    },
  });
  await (await SharedPreferences.getInstance()).setString(_key, body);
}

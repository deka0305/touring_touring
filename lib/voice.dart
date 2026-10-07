import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'data.dart';

/// Rekam & putar pesan suara. Satu-satunya tempat yang memakai plugin audio,
/// supaya [TripState] tetap bisa dites tanpa plugin.
class Voice extends ChangeNotifier {
  final _rec = AudioRecorder();
  final _player = AudioPlayer();
  DateTime? _startedAt;

  /// Kunci pesan yang sedang diputar, untuk ikon di gelembung obrolan.
  String? playing;

  static const maxSec = 60;

  bool get recording => _startedAt != null;

  Future<bool> start() async {
    if (recording) return true;
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    // 16 kHz mono 16 kbps: cukup jelas untuk suara, dan 60 detik muat di
    // batas 200.000 karakter Rules setelah jadi base64.
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 16000,
        numChannels: 1,
      ),
      path: '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _startedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  /// Berhenti dan kirim. Rekaman di bawah 1 detik dianggap salah pencet.
  Future<String?> stopAndSend() async {
    final mulai = _startedAt;
    if (mulai == null) return null;
    _startedAt = null;
    notifyListeners();
    final path = await _rec.stop();
    if (path == null) return 'Rekaman gagal.';
    final file = File(path);
    final sec = DateTime.now().difference(mulai).inSeconds.clamp(0, maxSec);
    try {
      if (sec < 1) return null;
      return await trip.sendVoice(await file.readAsBytes(), sec);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> cancel() async {
    if (!recording) return;
    _startedAt = null;
    notifyListeners();
    final path = await _rec.stop();
    if (path != null && await File(path).exists()) await File(path).delete();
  }

  Future<void> play(String key) async {
    try {
      final bytes = await trip.fetchVoice(key);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/play_$key.m4a');
      await f.writeAsBytes(bytes, flush: true);
      playing = key;
      notifyListeners();
      await _player.play(DeviceFileSource(f.path));
      // Batas waktu: kalau diputus pesan lain, event selesai tak pernah datang.
      await _player.onPlayerComplete.first.timeout(
        const Duration(seconds: maxSec + 5),
      );
    } catch (e) {
      debugPrint('voice: gagal memutar ($e)');
    } finally {
      if (playing == key) {
        playing = null;
        notifyListeners();
      }
    }
  }
}

final voice = Voice();

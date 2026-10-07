import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Sirene SOS: bunyi berulang + getar sampai SOS teratasi atau dimatikan di
/// HP ini. Bunyinya dibuat di sini (tanpa berkas aset) dan diputar lewat jalur
/// ALARM HP, jadi tetap terdengar walau volume media kecil.
///
/// Tetap jalan saat layar mati selama perekaman aktif: layanan foreground GPS
/// menjaga app hidup. Kalau app benar-benar ditutup, tidak ada yang bisa
/// membunyikannya tanpa server push (berbayar) — lihat catatan di SOS.
class SosAlarm extends ChangeNotifier {
  AudioPlayer? _player;
  Timer? _buzz;
  File? _file;

  bool get ringing => _buzz != null;

  Future<void> start() async {
    if (ringing) return;
    _buzz = Timer.periodic(
        const Duration(milliseconds: 900), (_) => HapticFeedback.vibrate());
    notifyListeners();
    try {
      final p = _player ??= AudioPlayer();
      if (_file == null) {
        final dir = await getTemporaryDirectory();
        _file = File('${dir.path}/sos_sirene.wav');
        await _file!.writeAsBytes(sireneWav(), flush: true);
      }
      await p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await p.setReleaseMode(ReleaseMode.loop);
      // Bisa sudah dimatikan selagi menyiapkan berkas.
      if (!ringing) return;
      await p.play(DeviceFileSource(_file!.path), volume: 1);
    } catch (e) {
      debugPrint('alarm: gagal bunyi ($e)');
    }
  }

  Future<void> stop() async {
    _buzz?.cancel();
    _buzz = null;
    notifyListeners();
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('alarm: gagal berhenti ($e)');
    }
  }
}

final sosAlarm = SosAlarm();

/// Dua nada bergantian 960/770 Hz — pola sirene ambulans Eropa, mudah dikenali
/// dan menembus suara angin/mesin. 1,6 detik, diputar berulang.
@visibleForTesting
Uint8List sireneWav() {
  const rate = 16000;
  const nadaMs = 400;
  const nada = [960.0, 770.0, 960.0, 770.0];
  final perNada = rate * nadaMs ~/ 1000;
  final n = perNada * nada.length;
  final b = ByteData(44 + n * 2);

  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  // Header WAV PCM 16-bit mono.
  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);

  var fasa = 0.0;
  for (var i = 0; i < n; i++) {
    final f = nada[i ~/ perNada];
    // Fasa dijumlahkan, bukan dihitung dari i: pergantian nada jadi mulus
    // tanpa bunyi "klik".
    fasa += 2 * math.pi * f / rate;
    // Gelombang kotak yang dihaluskan: lebih nyaring dari sinus.
    final v = (math.sin(fasa) * 3).clamp(-1.0, 1.0) * .8;
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:touring_touring/alarm.dart';

void main() {
  test('sirene: WAV PCM 16-bit mono 16 kHz yang sah, 1,6 detik', () {
    final w = sireneWav();
    final b = ByteData.sublistView(w);
    String str(int at) => String.fromCharCodes(w.sublist(at, at + 4));

    expect(str(0), 'RIFF');
    expect(str(8), 'WAVE');
    expect(str(36), 'data');
    expect(b.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(b.getUint32(24, Endian.little), 16000);
    expect(b.getUint16(34, Endian.little), 16);
    final data = b.getUint32(40, Endian.little);
    expect(w.length, 44 + data);
    expect(data, 16000 * 2 * 1.6);
    // Tidak sunyi: ada sampel yang mendekati puncak.
    var puncak = 0;
    for (var i = 44; i < w.length; i += 2) {
      final v = b.getInt16(i, Endian.little).abs();
      if (v > puncak) puncak = v;
    }
    expect(puncak, greaterThan(20000));
  });
}

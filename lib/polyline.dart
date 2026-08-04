import 'package:latlong2/latlong.dart' hide Path;

/// Encoded polyline (algoritma Google, presisi 5 desimal ≈ 1 m).
///
/// Rute 43 km dari OSRM punya ~2000 titik: sebagai array JSON itu ~60 KB,
/// sebagai string ini ~10 KB. Enam kali lebih kecil di penyimpanan Firebase
/// maupun di setiap unduhan anggota — dan jadi satu node, bukan 2000.
///
/// Ditulis tangan alih-alih menambah paket: algoritmanya 25 baris tiap arah dan
/// diuji dengan fixture resmi Google di test/polyline_test.dart.
String encodePolyline(List<LatLng> points, {double precision = 1e5}) {
  final out = StringBuffer();
  var prevLat = 0, prevLng = 0;
  for (final p in points) {
    final lat = (p.latitude * precision).round();
    final lng = (p.longitude * precision).round();
    _chunk(out, lat - prevLat);
    _chunk(out, lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return out.toString();
}

void _chunk(StringBuffer out, int value) {
  // Nilai negatif dibalik bitwise, lalu digeser 1 bit ke kiri.
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

/// Baca encoded polyline. Mengembalikan list kosong untuk string kosong.
/// Melempar [FormatException] kalau isinya rusak.
///
/// [precision] harus cocok dengan yang dipakai saat meng-encode: Google dan
/// OSRM memakai 1e5, **Valhalla memakai 1e6**. Salah presisi tidak melempar
/// error — rutenya hanya melenceng sepuluh kali lipat, jadi ini gampang lolos
/// tanpa disadari.
List<LatLng> decodePolyline(String encoded, {double precision = 1e5}) {
  final points = <LatLng>[];
  var i = 0, lat = 0, lng = 0;

  while (i < encoded.length) {
    lat += _readChunk(encoded, i, (n) => i = n);
    if (i >= encoded.length) {
      throw const FormatException('Polyline terpotong: bujur tidak lengkap.');
    }
    lng += _readChunk(encoded, i, (n) => i = n);
    points.add(LatLng(lat / precision, lng / precision));
  }
  return points;
}

int _readChunk(String s, int start, void Function(int) setIndex) {
  var result = 0, shift = 0, i = start, byte = 0;
  do {
    if (i >= s.length) {
      throw const FormatException('Polyline terpotong.');
    }
    byte = s.codeUnitAt(i++) - 63;
    if (byte < 0) throw const FormatException('Polyline berisi karakter asing.');
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  setIndex(i);
  return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
}

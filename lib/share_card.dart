import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';
import 'theme.dart';

/// Sumber garis dan angka di kartu. Dipilih pengguna di layar bagikan.
enum ShareSource {
  /// Jejak GPS yang benar-benar dilalui.
  jejak,

  /// Rute rencana dari maps, digambar utuh.
  rute,
}

/// Satu angka di kartu.
class ShareMetric {
  const ShareMetric(this.label, this.value, [this.unit = '']);
  final String label, value, unit;
}

/// Isi kartu bagikan.
///
/// Angka **hanya** berasal dari dua sumber: jejak GPS, atau rute rencana.
/// Dulu ada jalur ketiga yang memakai simulasi grup demo (`clock`, `elapsedMin`,
/// `leader.km`) — untuk grup nyata jalur itu menghasilkan angka karangan,
/// mis. "0,0 km" berdampingan dengan "2j 32m" yang datang dari jam simulasi
/// `'14:32'` yang di-hardcode. Jalur itu dibuang.
class ShareStats {
  const ShareStats({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.trace,
    required this.km,
    required this.metrics,
    required this.source,
  });

  final String title;
  final String subtitle;
  final String badge;

  /// Garis yang digambar di kartu.
  final List<LatLng> trace;

  /// Angka besar di kartu, selalu jarak.
  final double km;

  /// Angka pendamping — beda isinya untuk jejak dan rencana.
  final List<ShareMetric> metrics;

  final ShareSource source;

  bool get fromTrack => source == ShareSource.jejak;

  /// True kalau garisnya terlalu pendek untuk dikenali sebagai bentuk rute.
  /// Dua titik hanya menghasilkan garis lurus, dan itu terlihat seperti bug.
  bool get traceTooShort => trace.length < 3;

  static ShareStats of(TripState s, {required ShareSource source}) {
    final g = s.active;
    final t = s.track;

    if (source == ShareSource.jejak) {
      return ShareStats(
        title: g.name,
        subtitle: '${g.club} · ${_shortWhen(t.startedAt ?? g.when)}',
        badge: g.mode.label.toUpperCase(),
        trace: t.points,
        km: t.km,
        metrics: [
          ShareMetric('Waktu', fmtDur(t.duration.inMinutes)),
          if (t.avgKmh > 0)
            ShareMetric('Rata-rata', '${t.avgKmh.round()}', 'km/j'),
          if (t.topKmh > 0) ShareMetric('Maks', '${t.topKmh.round()}', 'km/j'),
        ],
        source: source,
      );
    }

    // Rute rencana: digambar utuh, dan angkanya jelas ditandai perkiraan.
    return ShareStats(
      title: g.name,
      subtitle: '${g.club} · ${_shortWhen(g.when)}',
      badge: 'RENCANA',
      trace: g.hasRoute ? g.geometry : const [],
      km: g.km,
      metrics: [
        ShareMetric('Estimasi', fmtDur(g.minutes)),
        ShareMetric('Moda', g.mode.label),
        ShareMetric('Titik', '${g.stops.length}'),
      ],
      source: source,
    );
  }

  /// Tanggal pendek untuk kartu — `fmtWhen` lengkap membuat subjudulnya
  /// terpotong ellipsis di lebar kartu.
  static String _shortWhen(DateTime d) =>
      '${fmtWhen(d).split(' · ').first.replaceAll(RegExp(r' \d{4}$'), '')} · '
      '${fmtClock(d)}';
}

/// Kartu bagikan ala Strava: foto sebagai latar (opsional), jejak rute, dan
/// statistik besar di tengah.
///
/// Rasio dikunci 4:5 — muat di feed Instagram, status WhatsApp, maupun chat
/// biasa tanpa terpotong.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.stats, this.photo});

  static const aspect = 4 / 5;

  final ShareStats stats;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return AspectRatio(
      aspectRatio: aspect,
      child: ColoredBox(
        color: const Color(0xFF0B0D10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null) ...[
              Image.file(photo!, fit: BoxFit.cover),
              // Gradien gelap di atas & bawah: tanpa ini teks putih hilang di
              // foto yang terang.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xB3000000),
                      Color(0x40000000),
                      Color(0xCC000000),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(s),
                  const Spacer(),
                  _bigStat('Jarak', km1(s.km), 'km'),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final m in s.metrics)
                        Expanded(child: _smallStat(m.label, m.value, m.unit)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Jejaknya sendiri jadi tanda tangan visual, seperti Strava.
                  // Garis dua titik hanya jadi batang lurus yang terlihat
                  // seperti kerusakan, jadi lebih baik tidak digambar.
                  if (!s.traceTooShort)
                    SizedBox(
                      height: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AspectRatio(
                          aspectRatio: 1.6,
                          child: CustomPaint(painter: TracePainter(s.trace)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          s.fromTrack
                              ? 'Jejak masih terlalu pendek\nuntuk digambar'
                              : 'Rute belum disusun',
                          style: mono(
                            600,
                            12,
                            color: Colors.white.withValues(alpha: .5),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'TRACKER',
                    style: mono(
                      700,
                      11,
                      color: Colors.white.withValues(alpha: .55),
                      spacing: 2.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ShareStats s) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          initials(s.subtitle.split(' · ').first),
          style: arch(800, 15, color: const Color(0xFF12140F)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arch(800, 20, color: Colors.white, height: 1.15),
            ),
            Text(
              s.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(
                500,
                11,
                color: Colors.white.withValues(alpha: .75),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          s.badge,
          style: mono(700, 10, color: const Color(0xFF12140F)),
        ),
      ),
    ],
  );

  Widget _bigStat(String label, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: mono(
          500,
          11,
          color: Colors.white.withValues(alpha: .7),
          spacing: 2,
        ),
      ),
      Text.rich(
        TextSpan(
          text: value,
          style: arch(800, 50, color: Colors.white, height: 1, spacing: -2),
          children: [
            TextSpan(
              text: ' $unit',
              style: mono(600, 20, color: Colors.white.withValues(alpha: .75)),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _smallStat(String label, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: mono(
          500,
          9,
          color: Colors.white.withValues(alpha: .65),
          spacing: 1.4,
        ),
      ),
      const SizedBox(height: 1),
      Text.rich(
        TextSpan(
          text: value,
          style: arch(800, 22, color: Colors.white, height: 1.05),
          children: [
            TextSpan(
              text: unit.isEmpty ? '' : ' $unit',
              style: mono(600, 10, color: Colors.white.withValues(alpha: .7)),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Menggambar jejak apa adanya, diskalakan agar pas di kotaknya. Bentuk garis
/// inilah yang orang kenali — jangan diperhalus atau disederhanakan.
class TracePainter extends CustomPainter {
  TracePainter(this.trace);
  final List<LatLng> trace;

  @override
  void paint(Canvas canvas, Size size) {
    if (trace.length < 2) return;

    final lat = trace.map((p) => p.latitude);
    final lng = trace.map((p) => p.longitude);
    final la0 = lat.reduce(math.min), la1 = lat.reduce(math.max);
    final lo0 = lng.reduce(math.min), lo1 = lng.reduce(math.max);
    // Koreksi bujur agar bentuknya tidak melebar di lintang tinggi.
    final kx = math.cos((la0 + la1) / 2 * math.pi / 180);
    final spanX = math.max((lo1 - lo0) * kx, 1e-9);
    final spanY = math.max(la1 - la0, 1e-9);
    const pad = 6.0;
    final sc = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final ox = (size.width - spanX * sc) / 2;
    final oy = (size.height - spanY * sc) / 2;

    final pts = [
      for (final p in trace)
        Offset(
          ox + (p.longitude - lo0) * kx * sc,
          size.height - oy - (p.latitude - la0) * sc,
        ),
    ];

    final path = ui.Path()..addPolygon(pts, false);
    // Garis gelap di bawah supaya jejaknya terbaca di atas foto apa pun.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );
    canvas.drawCircle(pts.first, 5, Paint()..color = Colors.white);
    canvas.drawCircle(pts.last, 6, Paint()..color = accent);
    canvas.drawCircle(
      pts.last,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(TracePainter old) => old.trace != trace;
}

/// Ambil gambar dari [key] jadi PNG, lalu buka lembar bagikan bawaan sistem.
///
/// Lewat lembar bagikan, kartunya bisa dikirim ke WhatsApp, Instagram,
/// Telegram, atau disimpan ke galeri — tanpa app ini perlu tahu satu pun dari
/// mereka.
Future<void> shareCardImage(
  GlobalKey key, {
  String? text,
  double targetWidth = 1080,
}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('Kartu belum siap digambar.');
  }

  // Kartu dirender seukuran layar; skalakan agar hasilnya tetap 1080 px lebar
  // walau di HP dengan layar kecil.
  final ratio = targetWidth / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) throw StateError('Gagal menyusun gambar.');

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/rekap-touring-${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: text,
    ),
  );
}

/// Byte PNG kartu, tanpa membuka lembar bagikan — dipakai test.
Future<Uint8List> renderCardPng(
  GlobalKey key, {
  double targetWidth = 1080,
}) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(
    pixelRatio: targetWidth / boundary.size.width,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

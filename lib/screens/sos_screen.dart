import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../alarm.dart';
import '../data.dart';
import '../theme.dart';

/// Layar C — darurat. Tombol tahan 3 detik, kartu status kalau SOS aktif,
/// dan riwayat kejadian.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = trip.sosRider;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      children: [
        if (s != null)
          _ActiveSos(s)
        else if (!trip.live) ...[
          // Tanpa pelacakan live, SOS tidak punya lokasi untuk dikirim.
          Panel(
            padding: const EdgeInsets.all(18),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SOS belum aktif untuk grup ini',
                    style: arch(800, 16, color: p.tx, height: 1.3)),
                const SizedBox(height: 6),
                Text(
                  trip.active.onCloud
                      // Servernya ada; yang belum ada adalah posisi.
                      ? 'Tombol darurat butuh lokasi. Tekan MULAI di tab Peta '
                          'dulu — SOS-mu langsung terlihat anggota lain setelah '
                          'itu.'
                      : 'Grup ini hanya ada di HP ini, jadi SOS tidak bisa '
                          'sampai ke siapa pun. Simpan nomor road captain '
                          '${trip.active.roadCaptain?.name ?? "(belum ditentukan)"} '
                          'dan sweeper di kontak HP.',
                  style: arch(400, 13, color: p.tx2, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Panel(
            padding: const EdgeInsets.all(18),
            radius: 18,
            child: Column(
              children: [
                Text('Semua aman', style: arch(800, 17, color: ok, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  'Nggak ada panggilan darurat. Kalau butuh bantuan, tahan tombol di bawah.',
                  textAlign: TextAlign.center,
                  style: arch(400, 13, color: p.tx2, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: _HoldButton()),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 4),
        const SectionLabel('RIWAYAT KEJADIAN'),
        for (final l in trip.logs) _LogRow(l),
      ],
    );
  }
}

class _ActiveSos extends StatelessWidget {
  const _ActiveSos(this.r);
  final Rider r;

  static const _dist = Distance(roundResult: false);

  /// Sudah berapa lama SOS-nya aktif, dari waktu nyata.
  static String _sejak(Duration? d) {
    if (d == null) return 'baru saja';
    final m = d.inMinutes;
    if (m < 1) return 'baru saja';
    return m < 60 ? '$m menit lalu' : '${fmtDur(m)} lalu';
  }

  /// Checkpoint terdekat dari posisinya — hanya kalau grup punya rute; tanpa
  /// rute "KM 0" cuma menyesatkan.
  String get _dekat {
    if (!routeReady || waypoints.isEmpty) return '';
    var best = waypoints.first;
    var bestKm = double.infinity;
    for (final w in waypoints) {
      final d = (distAt(w.at) - r.km).abs();
      if (d < bestKm) {
        bestKm = d;
        best = w;
      }
    }
    return 'KM ${r.km.round()}, dekat ${best.label}. ';
  }

  /// Jarak lurus dari rider [uid] ke korban, kalau posisinya diketahui.
  String? _jarakDari(String? uid) {
    final x = trip.riders.where((e) => e.uid != null && e.uid == uid).firstOrNull;
    if (x == null) return null;
    return '${km1(_dist.as(LengthUnit.Kilometer, x.pos, r.pos))} km';
  }

  String get _info {
    final aku = _jarakDari(trip.myUid);
    final swp = trip.active.sweeper;
    final swpJarak = swp == null || swp.uid == r.uid ? null : _jarakDari(swp.uid);
    return [
      _dekat,
      if (aku != null) 'Jarakmu $aku.',
      if (swpJarak != null) 'Sweeper ${swp!.name} $swpJarak.',
      r.batt == null ? '' : 'Baterai ${r.batt}%.',
    ].where((e) => e.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final saya = r.uid != null && r.uid == trip.myUid;
    final hp = trip.active.members
            .where((m) => m.uid == r.uid)
            .firstOrNull
            ?.hp ??
        '';

    Widget action(String label, IconData icon, Color bg, Color fg,
            VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(label, style: arch(800, 13, color: fg)),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bad,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .22),
                  shape: BoxShape.circle,
                ),
                child: Text(initials(r.name),
                    style: mono(800, 13, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saya ? 'SOS-mu aktif' : r.name,
                        style: arch(800, 17, color: Colors.white)),
                    Text(
                      'SOS aktif · ${_sejak(trip.sosFor)}',
                      style: mono(600, 12,
                          color: Colors.white.withValues(alpha: .82),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('DARURAT', style: mono(800, 10, color: bad)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              saya
                  ? 'Semua anggota mendapat alarm dan lokasimu. Tetap di tempat '
                      'aman kalau bisa. Tahan tombol di bawah kalau sudah aman.'
                  : _info.isEmpty
                      ? 'Lokasinya ada di peta.'
                      : _info,
              style: arch(600, 13, color: Colors.white, height: 1.5),
            ),
          ),
          if (!saya) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (hp.isNotEmpty) ...[
                  action('Telepon', Icons.call, Colors.white, bad,
                      () => launchUrl(Uri(scheme: 'tel', path: hp))),
                  const SizedBox(width: 8),
                ],
                action(
                  'Rute ke lokasi',
                  Icons.navigation_outlined,
                  Colors.black.withValues(alpha: .25),
                  Colors.white,
                  () => launchUrl(
                    Uri.https('www.google.com', '/maps/dir/', {
                      'api': '1',
                      'destination':
                          '${r.pos.latitude},${r.pos.longitude}',
                    }),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
          ListenableBuilder(
            listenable: sosAlarm,
            builder: (context, _) => sosAlarm.ringing
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: sosAlarm.stop,
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.volume_off, size: 18),
                        label: Text('Matikan alarm di HP ini',
                            style: arch(700, 13, color: Colors.white)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _HoldBar(
            label: saya
                ? 'TAHAN 3 DETIK · SAYA SUDAH AMAN'
                : 'TAHAN 3 DETIK · MASALAH TERATASI',
            onDone: () async {
              final err = await trip.clearSos();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Batang yang harus ditahan 3 detik — menutup SOS tidak boleh kepencet.
class _HoldBar extends StatefulWidget {
  const _HoldBar({required this.label, required this.onDone});
  final String label;
  final VoidCallback onDone;

  @override
  State<_HoldBar> createState() => _HoldBarState();
}

class _HoldBarState extends State<_HoldBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _a.value = 0;
        widget.onDone();
      }
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _a.forward(),
        onTapUp: (_) => _a.reverse(),
        onTapCancel: () => _a.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: .55), width: 1.5),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _a,
                  builder: (_, _) => FractionallySizedBox(
                    widthFactor: _a.value,
                    child: Container(color: Colors.white.withValues(alpha: .3)),
                  ),
                ),
                Center(
                  child: Text(widget.label,
                      style: mono(700, 12, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Tahan 3 detik supaya SOS nggak kepencet tanpa sengaja saat riding.
class _HoldButton extends StatefulWidget {
  const _HoldButton();

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _a.value = 0;
        trip.fireSos();
      }
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _a.forward(),
        onTapUp: (_) => _a.reverse(),
        onTapCancel: () => _a.reverse(),
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bad,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: bad.withValues(alpha: .5),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _a,
                builder: (_, _) => SizedBox(
                  width: 182,
                  height: 182,
                  child: CircularProgressIndicator(
                    value: _a.value,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SOS',
                      style: arch(800, 40, color: Colors.white, spacing: -.8)),
                  const SizedBox(height: 8),
                  Text('TAHAN 3 DETIK',
                      style: mono(600, 11,
                          color: Colors.white.withValues(alpha: .85))),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LogRow extends StatelessWidget {
  const _LogRow(this.l);
  final LogEntry l;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(l.time,
                style: mono(500, 11, color: p.tx2, height: 1.5)),
          ),
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(color: Color(l.color), shape: BoxShape.circle),
              ),
              Container(width: 1.5, height: 26, color: p.line),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: arch(700, 13, color: p.tx, height: 1.3)),
                Text(l.body, style: arch(400, 12, color: p.tx2, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

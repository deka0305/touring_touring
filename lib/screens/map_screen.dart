import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data.dart';
import '../theme.dart';
import 'route_edit_screen.dart';

/// Layar A — peta live. Rute, 50 marker rider, pin RC/sweeper/SOS,
/// dan sheet ringkasan di bawah.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onSeeSos});
  final VoidCallback onSeeSos;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _ctrl = MapController();
  bool _follow = true;

  /// Apa yang digambar di peta. Keduanya bisa hidup bersamaan — justru itu yang
  /// paling berguna: kelihatan seberapa jauh jalur nyata menyimpang dari rute.
  bool _showRoute = true;
  bool _showTrack = true;

  @override
  void initState() {
    super.initState();
    trip.addListener(_onTick);
  }

  @override
  void dispose() {
    trip.removeListener(_onTick);
    super.dispose();
  }

  /// False selama FlutterMap belum sekali pun digambar. MapController melempar
  /// exception kalau kameranya dibaca sebelum itu — dan itu benar-benar terjadi:
  /// grup tanpa rute menampilkan layar pengganti (tanpa peta), lalu posisi
  /// pertama masuk dan langsung memicu _fit().
  bool _mapReady = false;

  void _onTick() {
    if (_follow && mounted && trip.live) _fit();
  }

  /// Bingkai leader + sweeper. Hanya digeser kalau salah satu keluar frame,
  /// biar peta nggak "gelisah" tiap kiriman posisi.
  void _fit({bool force = false}) {
    if (!_mapReady) return;
    if (!trip.live) return _fitRoute();
    final cam = _ctrl.camera;
    final inset = 70.0;
    bool framed(LatLng ll) {
      final o = cam.latLngToScreenOffset(ll);
      return o.dx > inset &&
          o.dx < cam.size.width - inset &&
          o.dy > inset &&
          o.dy < cam.size.height - inset;
    }

    if (!force && framed(trip.leader.pos) && framed(trip.sweeper.pos)) return;
    _ctrl.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(trip.leader.pos, trip.sweeper.pos),
      padding: const EdgeInsets.all(78),
      maxZoom: 15,
    ));
  }

  void _fitRoute() {
    if (!routeReady) return;
    _ctrl.fitCamera(CameraFit.coordinates(
      coordinates: route,
      padding: const EdgeInsets.all(50),
      maxZoom: 14,
    ));
  }

  /// Mulai/hentikan perekaman. Kegagalan izin dijelaskan apa adanya — pengguna
  /// perlu tahu harus ke Pengaturan, bukan cuma "gagal".
  Future<void> _toggleRecording() async {
    if (trip.recording) {
      await _confirmStop();
      return;
    }
    final r = await trip.startRecording();
    if (!mounted || r == LocationShareResult.ok) return;

    final pesan = switch (r) {
      LocationShareResult.ditolak =>
        'Izin lokasi ditolak. Coba lagi dan pilih Izinkan.',
      LocationShareResult.ditolakPermanen =>
        'Izin lokasi diblokir. Buka Pengaturan → Aplikasi → Touring Tracker → '
            'Izin → Lokasi.',
      LocationShareResult.layananMati =>
        'GPS mati. Nyalakan lokasi di HP-mu dulu.',
      // Bukan kegagalan: jejak tetap direkam, hanya anggota lain yang belum
      // bisa melihat posisimu.
      LocationShareResult.tanpaServer =>
        'Merekam jejak. Grup ini belum di server, jadi anggota lain belum bisa '
            'melihat posisimu.',
      LocationShareResult.ok => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _confirmStop() async {
    final t = trip.track;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hentikan perekaman?'),
        content: Text(t.isEmpty
            ? 'Belum ada jejak yang tercatat.'
            : 'Tercatat ${km1(t.km)} km dalam ${fmtDur(t.duration.inMinutes)}. '
                'Jejaknya tetap tersimpan dan bisa dilihat di tab Rekap.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Lanjut merekam')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hentikan')),
        ],
      ),
    );
    if (yes == true) await trip.stopRecording();
  }

  /// Buka penyusun rute grup aktif; kalau rute berganti, bingkai ulang.
  Future<void> _editRoute() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RouteEditScreen(group: trip.active)),
    );
    if (changed == true && mounted) {
      setState(() => _follow = true);
      _fit(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final live = trip.live;
    final sosR = live ? trip.sosRider : null;
    // Layar pengganti ini hanya dipakai kalau memang tidak ada apa pun untuk
    // digambar. Kalau ada posisi rider, petanya harus tampil walau rutenya
    // belum disusun — melacak anggota tidak butuh rute, dan dulu syarat
    // `!routeReady` di sini menyembunyikan seluruh rombongan.
    if (!routeReady && !live) {
      // FlutterMap dilepas di cabang ini, jadi kameranya tidak sah lagi.
      _mapReady = false;
      // Tombol MULAI tetap ada di sini. Merekam jejak GPS tidak butuh rute —
      // dulu tombolnya hanya hidup di dalam peta, dan peta ini menggantikannya
      // seluruhnya, jadi GPS tidak bisa dinyalakan sama sekali sebelum rute
      // disusun.
      return Stack(
        children: [
          _EmptyRoute(onEdit: _editRoute, canEdit: trip.amRc(trip.active)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: _RecordBar(onTap: _toggleRecording),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                  // Tanpa rute, pointAt() memberi LatLng(0,0) — Teluk Guinea,
                  // ribuan km dari rombongan. Pakai posisi rider kalau ada.
                  initialCenter: routeReady
                      ? pointAt(0.575)
                      : trip.riders.first.pos,
                  initialZoom: 12.6,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _follow) setState(() => _follow = false);
                  },
                  onMapReady: () {
                    _mapReady = true;
                    _fit(force: true);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/${trip.dark ? "dark_all" : "light_all"}/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.example.touring_touring',
                  ),
                  PolylineLayer(polylines: [
                    // Rute rencana. Diredupkan saat jejak ditampilkan supaya
                    // jejaknya yang menonjol, tapi tidak pernah disembunyikan:
                    // rutenya masih dipakai untuk tahu arah.
                    // `routeReady` wajib: dulu build() keluar lebih awal saat
                    // rute kosong, jadi ini aman. Sekarang peta juga tampil
                    // tanpa rute, dan Polyline berisi list kosong membuat
                    // flutter_map gagal assert.
                    if (_showRoute && routeReady) ...[
                      Polyline(
                        points: route,
                        strokeWidth: 9,
                        color: Colors.black.withValues(alpha: .22),
                      ),
                      Polyline(
                        points: route,
                        strokeWidth: 4.5,
                        color: _showTrack
                            ? accent.withValues(alpha: .45)
                            : accent,
                      ),
                    ],
                    // Jejak anggota lain, digambar LEBIH DULU supaya jejakku
                    // sendiri ada di atasnya. Warnanya sama-sama hijau tapi
                    // lebih pudar dan lebih tipis: yang penting terbaca "ini
                    // jalur yang sudah dilewati rombongan", bukan siapa persisnya
                    // — untuk itu ada markernya.
                    if (_showTrack)
                      for (final t in trip.mateTracks.values)
                        Polyline(
                          points: t.points,
                          strokeWidth: 3,
                          color: ok.withValues(alpha: .38),
                        ),
                    // Jejak GPS yang benar-benar dilalui. Hijau, jadi bedanya
                    // dengan rute rencana yang oranye terbaca sekilas.
                    if (_showTrack && trip.track.points.length >= 2) ...[
                      Polyline(
                        points: trip.track.points,
                        strokeWidth: 8,
                        color: Colors.black.withValues(alpha: .3),
                      ),
                      Polyline(
                        points: trip.track.points,
                        strokeWidth: 4,
                        color: ok,
                      ),
                    ],
                  ]),
                  _WaypointLayer(),
                  if (live) ...[
                    _RiderLayer(),
                    _PinLayer(onSeeSos: widget.onSeeSos),
                  ] else
                    _StopLayer(),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution('OpenStreetMap · CARTO',
                          onTap: null),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 16,
                top: 16,
                right: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rentang rombongan diukur di sepanjang rute, jadi
                          // tanpa rute angkanya selalu 0 — tampilkan panjang
                          // rute (yang juga 0) daripada angka bohong.
                          Text(
                              live && routeReady
                                  ? 'RENTANG ROMBONGAN'
                                  : 'PANJANG RUTE',
                              style: mono(500, 10, color: p.tx2, spacing: 1.2)),
                          Text.rich(TextSpan(
                            text: km1(live && routeReady
                                ? trip.spread
                                : trip.active.km),
                            style: arch(800, 20, color: p.tx),
                            children: [
                              TextSpan(
                                  text: ' km',
                                  style: mono(600, 12, color: p.tx2)),
                            ],
                          )),
                        ],
                      ),
                    ),
                    if (sosR != null) ...[
                      const SizedBox(height: 8),
                      _SosBanner(rider: sosR, onSee: widget.onSeeSos),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 14,
                top: 16,
                child: Column(
                  children: [
                    _MapButton(
                      icon: Icons.center_focus_strong,
                      active: _follow && live,
                      tooltip: live ? 'Ikuti rombongan' : 'Lihat seluruh rute',
                      onTap: () {
                        setState(() => _follow = true);
                        _fit(force: true);
                      },
                    ),
                    if (trip.amRc(trip.active)) ...[
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.edit_road_outlined,
                        active: false,
                        tooltip: 'Atur rute',
                        onTap: _editRoute,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.route,
                      active: _showRoute,
                      activeColor: accent,
                      tooltip: _showRoute
                          ? 'Sembunyikan rute rencana'
                          : 'Tampilkan rute rencana',
                      onTap: () => setState(() => _showRoute = !_showRoute),
                    ),
                    // Hanya ditawarkan kalau ada jejak untuk disembunyikan —
                    // tombol yang tidak mengubah apa pun cuma membingungkan.
                    // Jejak anggota lain ikut dihitung: anggota yang belum
                    // merekam apa pun tetap perlu bisa menyembunyikan jalur
                    // rombongan kalau petanya jadi penuh.
                    if (trip.track.points.length >= 2 ||
                        trip.mateTracks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.timeline,
                        active: _showTrack,
                        activeColor: ok,
                        tooltip: _showTrack
                            ? 'Sembunyikan jejak GPS'
                            : 'Tampilkan jejak GPS',
                        onTap: () => setState(() => _showTrack = !_showTrack),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _RecordBar(onTap: _toggleRecording),
              ),
            ],
          ),
        ),
        if (live) _Sheet() else _PlanSheet(),
      ],
    );
  }
}

/// Grup aktif belum punya rute — tidak ada yang bisa digambar di peta.
class _EmptyRoute extends StatelessWidget {
  const _EmptyRoute({required this.onEdit, required this.canEdit});
  final VoidCallback onEdit;

  /// False untuk anggota biasa — rute ditentukan road captain.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 48, color: p.tx2),
            const SizedBox(height: 16),
            Text('Rute belum disusun',
                style: arch(800, 18, color: p.tx, height: 1.3)),
            const SizedBox(height: 6),
            Text(
              canEdit
                  ? 'Grup "${trip.active.name}" belum punya rute. Susun dulu '
                      'titik mulai sampai tujuan akhir.'
                  : 'Road captain belum menyusun rute untuk '
                      '"${trip.active.name}". Rutenya akan muncul di sini '
                      'begitu dia menyimpannya.',
              textAlign: TextAlign.center,
              style: arch(400, 13, color: p.tx2, height: 1.5),
            ),
            if (canEdit) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Susun rute sekarang',
                      style: arch(800, 14, color: const Color(0xFF12140F))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Marker bernomor untuk grup tanpa pelacakan live: yang ada cuma rencana.
///
/// Dipakai tanpa `const` di build: widget const dikanonikalisasi, jadi
/// instansinya identik tiap build dan Flutter melewati subtree-nya — apa pun
/// yang membaca `trip` di sini akan membeku menampilkan data basi.
class _StopLayer extends StatelessWidget {
  const _StopLayer();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final stops = trip.active.stops;
    return MarkerLayer(
      markers: [
        for (var i = 0; i < stops.length; i++)
          Marker(
            point: stops[i].at,
            width: 26,
            height: 26,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == 0
                    ? ok
                    : i == stops.length - 1
                        ? accent
                        : p.surf,
                shape: BoxShape.circle,
                border: Border.all(color: p.tx, width: 2),
              ),
              child: Text('${i + 1}',
                  style: mono(800, 11,
                      color: i == 0 || i == stops.length - 1
                          ? const Color(0xFF0B0D10)
                          : p.tx)),
            ),
          ),
      ],
    );
  }
}

/// Sheet untuk grup yang belum jalan: ringkasan rencana, bukan status live.
class _PlanSheet extends StatelessWidget {
  const _PlanSheet();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = trip.active;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: p.surf,
        border: Border(top: BorderSide(color: p.line)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'JADWAL',
                  value: fmtClock(g.when),
                  note: fmtWhen(g.when).split(' · ').first,
                  noteColor: p.tx2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'ROAD CAPTAIN',
                  value: g.roadCaptain?.name.split(' ').first ?? 'Belum ada',
                  note: '${g.members.length} anggota',
                  noteColor: g.roadCaptain == null ? warn : ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: p.tx2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.recording
                      ? g.onCloud
                          ? 'Merekam. Menunggu anggota lain menekan MULAI juga.'
                          : 'Merekam jejak di HP ini. Grup lokal, jadi posisi '
                              'anggota lain tidak bisa dilacak.'
                      : 'Tekan MULAI di bawah untuk merekam perjalanan'
                          '${g.onCloud ? " dan menampilkan posisimu ke anggota" : ""}.',
                  style: mono(500, 10, color: p.tx2, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tombol MULAI/STOP perekaman, plus angka yang berjalan saat merekam.
///
/// Sengaja lebar dan di bawah tengah: ini tombol yang ditekan sambil pakai
/// sarung tangan, di pinggir jalan, sebelum berangkat.
class _RecordBar extends StatelessWidget {
  const _RecordBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final on = trip.recording;
    final t = trip.track;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: on ? bad : accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 26,
                color: on ? Colors.white : const Color(0xFF12140F)),
            const SizedBox(width: 10),
            Expanded(
              child: !on
                  ? Text('MULAI REKAM PERJALANAN',
                      style: mono(700, 13,
                          color: const Color(0xFF12140F), spacing: 1))
                  // Sudah merekam tapi belum ada satu titik pun: GPS masih
                  // mencari sinyal. Tanpa keterangan ini, "0,0 km" terlihat
                  // seperti perekamannya rusak.
                  : t.points.isEmpty
                      ? Text('MENUNGGU SINYAL GPS…',
                          style: mono(700, 12,
                              color: Colors.white, spacing: 1))
                      : Row(
                          children: [
                            _live('JARAK', '${km1(t.km)} km'),
                            const SizedBox(width: 16),
                            _live('WAKTU', fmtDur(t.duration.inMinutes)),
                            if (t.avgKmh > 0) ...[
                              const SizedBox(width: 16),
                              _live('RATA²', '${t.avgKmh.round()} km/j'),
                            ],
                          ],
                        ),
            ),
            if (!on && !trip.active.onCloud)
              Icon(Icons.cloud_off, size: 15, color: p.tx2),
          ],
        ),
      ),
    );
  }

  Widget _live(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: mono(600, 8,
                  color: Colors.white.withValues(alpha: .7), spacing: 1)),
          Text(value, style: arch(800, 15, color: Colors.white, height: 1.2)),
        ],
      );
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.activeColor,
  });
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  /// Warna saat aktif. Dipakai agar tombol cocok dengan warna garisnya di
  /// peta — oranye untuk rute rencana, hijau untuk jejak GPS.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = activeColor ?? accent;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active ? c : p.glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? c : p.line),
          ),
          child: Icon(icon,
              size: 20, color: active ? const Color(0xFF12140F) : p.tx2),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

class _SosBanner extends StatelessWidget {
  const _SosBanner({required this.rider, required this.onSee});
  final Rider rider;
  final VoidCallback onSee;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bad,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text('SOS', style: arch(800, 16, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${rider.name.split(" ").first} di KM ${rider.km.round()}, '
                '2 anggota terdekat sudah menuju',
                style: arch(600, 13, color: Colors.white, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSee,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('LIHAT', style: mono(700, 11, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
}

class _WaypointLayer extends StatelessWidget {
  const _WaypointLayer();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // Label disembunyikan saat zoom rendah supaya peta nggak penuh teks.
    final showLabel = MapCamera.of(context).zoom >= 11.6;
    return MarkerLayer(
      markers: [
        for (final w in waypoints)
          Marker(
            point: route[w.at],
            width: showLabel ? 190 : 12,
            height: 22,
            alignment: showLabel ? const Alignment(0.87, 0) : Alignment.center,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.tx,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: p.surf, width: 2),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.surf,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: p.line),
                      ),
                      child: Text(w.label,
                          overflow: TextOverflow.ellipsis,
                          style: arch(600, 10, color: p.tx2, height: 1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Rider yang berdempet di layar diciutkan jadi titik kecil; yang punya ruang
/// dapat panah arah. Mencegah 50 marker saling tumpuk.
class _RiderLayer extends StatelessWidget {
  const _RiderLayer();

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    final order = trip.riders.toList()..sort((a, b) => b.p.compareTo(a.p));
    final taken = <Offset>[];
    final big = <int>{};
    for (final r in order) {
      final o = cam.latLngToScreenOffset(r.pos);
      if (taken.every((t) => (t - o).distance > 17)) {
        taken.add(o);
        big.add(r.id);
      }
    }
    final hidden = trip.riders.length - big.length;

    return Stack(
      children: [
        MarkerLayer(
          markers: [
            for (final r in order)
              if (big.contains(r.id))
                Marker(
                  point: r.pos,
                  width: 22,
                  height: 22,
                  child: NavArrow(size: 18, color: Color(r.status.color), deg: r.head),
                )
              else
                Marker(
                  point: r.pos,
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(r.status.color),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: .7),
                            blurRadius: 0,
                            spreadRadius: 1.5),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        if (hidden > 6)
          Positioned(left: 16, bottom: 16, child: _PackNote(hidden: hidden)),
      ],
    );
  }
}

class _PackNote extends StatelessWidget {
  const _PackNote({required this.hidden});
  final int hidden;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: p.surf,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(Icons.two_wheeler,
                size: 16, color: Color(0xFF12140F)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rombongan rapat', style: arch(700, 12, color: p.tx)),
              Text('$hidden rider berdempet · zoom untuk lihat',
                  style: mono(600, 10, color: p.tx2, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pin besar berlabel untuk road captain, sweeper, dan rider SOS.
class _PinLayer extends StatelessWidget {
  const _PinLayer({required this.onSeeSos});
  final VoidCallback onSeeSos;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cam = MapCamera.of(context);
    final sosR = trip.sosRider;
    final pins = <(Rider, String, bool)>[
      (trip.leader, '${trip.leader.name.split(" ").first} · Road Captain', false),
      (trip.sweeper, 'Sweeper', false),
      if (sosR != null) (sosR, '${sosR.name.split(" ").first} butuh bantuan', true),
    ];

    return MarkerLayer(
      markers: [
        for (final (r, label, ring) in pins)
          () {
            // Label dibalik ke kiri kalau pin sudah dekat tepi kanan.
            final flip =
                cam.latLngToScreenOffset(r.pos).dx > cam.size.width - 150;
            final arrow = NavArrow(
                size: 32, color: Color(r.status.color), deg: r.head, ring: ring);
            return Marker(
              point: r.pos,
              width: 230,
              height: 40,
              alignment:
                  flip ? const Alignment(0.72, 0) : const Alignment(-0.72, 0),
              child: Row(
                mainAxisAlignment:
                    flip ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: flip
                    ? [_pinLabel(label, p), arrow]
                    : [arrow, _pinLabel(label, p)],
              ),
            );
          }(),
      ],
    );
  }

  Widget _pinLabel(String text, Pal p) => Flexible(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: p.surf,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.line),
            ),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arch(600, 11, color: p.tx, height: 1)),
          ),
        ),
      );
}

/// Penanda rider: bulatan berwarna + segitiga arah + (opsional) ring denyut.
class NavArrow extends StatelessWidget {
  const NavArrow({
    super.key,
    required this.size,
    required this.color,
    required this.deg,
    this.ring = false,
  });

  final double size;
  final Color color;
  final double deg;
  final bool ring;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (ring) _PulseRing(color: color, size: size),
            Transform.rotate(
              angle: deg * math.pi / 180,
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, -size * 0.3),
                  child: CustomPaint(
                    size: Size(size * 0.42, size * 0.34),
                    painter: _Triangle(color),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF08090B).withValues(alpha: .8),
                    width: 2),
              ),
              child: Icon(Icons.two_wheeler,
                  size: size * 0.58, color: const Color(0xFF0B0D10)),
            ),
          ],
        ),
      );
}

class _Triangle extends CustomPainter {
  _Triangle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.color != color;
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, _) => Transform.scale(
          scale: 1 + _a.value * 1.8,
          child: Opacity(
            opacity: (1 - _a.value) * .6,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ),
        ),
      );
}

/// Sheet bawah: kartu RC & sweeper, plus chip anggota yang perlu dipantau.
class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final watch = trip.sorted
        .where((r) => r.status != RiderStatus.aman)
        .take(3)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: p.surf,
        border: Border(top: BorderSide(color: p.line)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  // "ROAD CAPTAIN" itu jabatan, sedangkan ini dihitung dari
                  // posisi. Kalau RC-nya tertinggal, label lama menempelkan
                  // namanya ke orang lain.
                  label: 'DI DEPAN',
                  value: trip.leader.name.split(' ').first,
                  note: '${trip.leader.v.round()} km/j',
                  noteColor: ok,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'PALING BELAKANG',
                  // Dengan satu rider terlacak, yang terdepan dan terbelakang
                  // adalah orang yang sama — menampilkan namanya dua kali
                  // terbaca seolah ada dua rider.
                  value: trip.riders.length < 2
                      ? '—'
                      : trip.sweeper.name.split(' ').first,
                  note: trip.riders.length < 2
                      ? 'baru 1 rider terlacak'
                      : '${km1(trip.spread)} km di belakang',
                  noteColor: warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionLabel('PERLU DIPANTAU'),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: watch.isEmpty
                ? Text('Semua anggota dalam formasi.',
                    style: arch(400, 12, color: p.tx2))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: watch.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _WatchChip(watch[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.note,
    required this.noteColor,
  });
  final String label, value, note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surf2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: mono(500, 10, color: p.tx2, spacing: 1)),
          Text(value, style: arch(700, 14, color: p.tx, height: 1.4)),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(500, 11, color: noteColor)),
        ],
      ),
    );
  }
}

class _WatchChip extends StatelessWidget {
  const _WatchChip(this.r);
  final Rider r;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = Color(r.status.color);
    final note = switch (r.status) {
      RiderStatus.berhenti => 'tidak bergerak',
      RiderStatus.sos => 'minta bantuan',
      _ => '-${km1(r.behindKm)} km',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: p.surf2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            child: Text(initials(r.name),
                style: mono(800, 10, color: const Color(0xFF0B0D10))),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(r.name.split(' ').first, style: arch(700, 12, color: p.tx)),
              Text(note, style: mono(500, 10, color: c)),
            ],
          ),
        ],
      ),
    );
  }
}

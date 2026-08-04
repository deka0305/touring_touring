import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data.dart';
import '../osm.dart';
import '../theme.dart';

/// Penyusun rute ala Google Maps: daftar tujuan yang bisa digeser urutannya,
/// pencarian nama tempat, dan garis rute yang menempel ke jalan asli.
/// Pop `true` kalau rute grup berhasil disimpan.
class RouteEditScreen extends StatefulWidget {
  const RouteEditScreen({super.key, required this.group});
  final TripGroup group;

  @override
  State<RouteEditScreen> createState() => _RouteEditScreenState();
}

class _RouteEditScreenState extends State<RouteEditScreen> {
  final _map = MapController();
  late final List<Stop> _stops = [
    for (final s in widget.group.stops) Stop(s.label, s.at),
  ];

  /// Moda yang sedang dipilih. Mengubahnya menghitung ulang rute — jalur
  /// motor, mobil, sepeda, dan lari benar-benar berbeda.
  late TripMode _mode = widget.group.mode;

  SnappedRoute? _snapped;
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_stops.length >= 2) _recompute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Didebounce: menggeser urutan atau menghapus titik sering terjadi
  /// beruntun, dan OSRM publik tidak perlu dihujani request.
  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _recompute);
  }

  Future<void> _recompute() async {
    if (!mounted) return;
    if (_stops.length < 2) {
      setState(() {
        _snapped = null;
        _error = 'Tambah minimal 2 titik: tempat mulai dan tujuan akhir.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await snapToRoads([for (final s in _stops) s.at], mode: _mode);
      if (!mounted) return;
      setState(() {
        _snapped = r;
        _loading = false;
      });
      _fitDraft(r.points);
    } on OsmException catch (e) {
      if (!mounted) return;
      setState(() {
        _snapped = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _fitDraft(List<LatLng> pts) => _map.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(50),
        maxZoom: 14,
      ));

  Future<Place?> _search() => showModalBottomSheet<Place>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const SearchSheet(),
      );

  Future<void> _replaceStop(int index) async {
    final place = await _search();
    if (place == null) return;
    setState(() {
      _stops[index]
        ..label = place.name
        ..at = place.at;
    });
    _scheduleRecompute();
  }

  Future<void> _addStop() async {
    final place = await _search();
    if (place == null) return;
    setState(() => _stops.add(Stop(place.name, place.at)));
    _scheduleRecompute();
  }

  void _addStopAt(LatLng at) {
    setState(() => _stops.add(Stop('Titik ${_stops.length + 1}', at)));
    _scheduleRecompute();
  }

  Future<void> _rename(int i) async {
    var draft = _stops[i].label;
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ganti nama titik'),
        content: TextFormField(
          initialValue: draft,
          onChanged: (v) => draft = v,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'mis. Titik Kumpul'),
          onFieldSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(c, draft),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => _stops[i].label = name.trim());
  }

  void _remove(int i) {
    setState(() => _stops.removeAt(i));
    _scheduleRecompute();
  }

  void _save() {
    final r = _snapped!;
    trip.applyRoute(
      widget.group,
      mode: _mode,
      stops: _stops,
      geometry: r.points,
      stopIndices: r.stopIndices,
      km: r.km,
      minutes: r.minutes,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final draft = _snapped?.points ?? [for (final s in _stops) s.at];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Atur rute', style: arch(700, 17, color: p.tx)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: p.line),
        ),
      ),
      body: Column(
        children: [
          _modePicker(p),
          Flexible(child: _stopList(p)),
          Expanded(child: _mapPane(draft, p)),
          _footer(p),
        ],
      ),
    );
  }

  /// Pilihan moda, seperti baris kendaraan di Google Maps.
  Widget _modePicker(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        child: Row(
          children: [
            for (final m in TripMode.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      if (m == _mode) return;
                      setState(() => _mode = m);
                      _scheduleRecompute();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: m == _mode
                            ? accent.withValues(alpha: .16)
                            : p.surf,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: m == _mode ? accent : p.line),
                      ),
                      child: Column(
                        children: [
                          Icon(_modeIcon(m),
                              size: 19,
                              color: m == _mode ? accent : p.tx2),
                          const SizedBox(height: 3),
                          Text(m.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mono(700, 9,
                                  color: m == _mode ? accent : p.tx2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  static IconData _modeIcon(TripMode m) => switch (m) {
        TripMode.motor => Icons.two_wheeler,
        TripMode.mobil => Icons.directions_car,
        TripMode.sepeda => Icons.pedal_bike,
        TripMode.lari => Icons.directions_run,
      };

  Widget _stopList(Pal p) => ReorderableListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        itemCount: _stops.length + 1,
        // Tombol "tambah" ikut jadi item supaya daftar tetap satu scroll view.
        itemBuilder: (_, i) => i == _stops.length
            ? _addRow(p)
            : _StopRow(
                key: ObjectKey(_stops[i]),
                index: i,
                total: _stops.length,
                stop: _stops[i],
                onReplace: () => _replaceStop(i),
                onRename: () => _rename(i),
                onRemove: () => _remove(i),
              ),
        onReorder: (from, to) {
          if (from >= _stops.length || to > _stops.length) return;
          setState(() {
            if (to > from) to -= 1;
            _stops.insert(to, _stops.removeAt(from));
          });
          _scheduleRecompute();
        },
      );

  Widget _addRow(Pal p) => Padding(
        key: const ValueKey('add'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: _addStop,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line),
            ),
            child:
                Text('+ Cari & tambah tujuan', style: arch(700, 13, color: p.tx2)),
          ),
        ),
      );

  Widget _mapPane(List<LatLng> draft, Pal p) => Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _stops.isEmpty
                  ? const LatLng(-7.9797, 112.6304)
                  : _stops.first.at,
              initialZoom: 11,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onLongPress: (_, at) => _addStopAt(at),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/${trip.dark ? "dark_all" : "light_all"}/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.example.touring_touring',
              ),
              // Grup baru bisa punya 0–1 titik; polyline butuh minimal 2.
              if (draft.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: draft,
                    strokeWidth: 5,
                    color: accent,
                    pattern: _snapped?.straightLine ?? true
                        ? StrokePattern.dashed(segments: const [8, 6])
                        : const StrokePattern.solid(),
                  ),
                ]),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _stops.length; i++)
                    Marker(
                      point: _stops[i].at,
                      width: 26,
                      height: 26,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? ok
                              : i == _stops.length - 1
                                  ? accent
                                  : p.surf,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.tx, width: 2),
                        ),
                        child: Text('${i + 1}',
                            style: mono(800, 11,
                                color: i == 0 || i == _stops.length - 1
                                    ? const Color(0xFF0B0D10)
                                    : p.tx)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.line),
              ),
              child: Text('Tahan peta untuk tambah titik',
                  style: mono(500, 10, color: p.tx2)),
            ),
          ),
        ],
      );

  Widget _footer(Pal p) {
    final r = _snapped;
    final canSave = r != null && !_loading;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: p.surf,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading)
                    Text('Menghitung rute…', style: arch(600, 14, color: p.tx2))
                  else if (_error != null)
                    Text(_error!, style: arch(600, 13, color: bad, height: 1.3))
                  else if (r != null) ...[
                    Text.rich(TextSpan(
                      text: km1(r.km),
                      style: arch(800, 20, color: p.tx),
                      children: [
                        TextSpan(
                            text: ' km · ± ${fmtDur(r.minutes)}',
                            style: mono(600, 12, color: p.tx2)),
                      ],
                    )),
                    Text(
                      r.straightLine
                          ? 'Garis lurus — jaringan jalan tidak terjangkau'
                          : '${_stops.length} titik · ikut jalan raya',
                      style: mono(500, 10, color: r.straightLine ? warn : p.tx2),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: canSave ? _save : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: canSave ? accent : p.surf2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Simpan rute',
                    style: arch(800, 14,
                        color:
                            canSave ? const Color(0xFF12140F) : p.tx2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.index,
    required this.total,
    required this.stop,
    required this.onReplace,
    required this.onRename,
    required this.onRemove,
  });

  final int index, total;
  final Stop stop;
  final VoidCallback onReplace, onRename, onRemove;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final role = index == 0
        ? 'MULAI'
        : index == total - 1
            ? 'FINISH'
            : 'MAMPIR';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: p.surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0
                    ? ok
                    : index == total - 1
                        ? accent
                        : p.surf2,
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}',
                  style: mono(800, 10,
                      color: index == 0 || index == total - 1
                          ? const Color(0xFF0B0D10)
                          : p.tx2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onReplace,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role, style: mono(600, 9, color: p.tx2, spacing: 1)),
                    Text(stop.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: arch(700, 14, color: p.tx)),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: p.tx2),
              onSelected: (v) => switch (v) {
                'rename' => onRename(),
                'replace' => onReplace(),
                _ => onRemove(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Ganti nama')),
                PopupMenuItem(value: 'replace', child: Text('Cari tempat lain')),
                PopupMenuItem(value: 'remove', child: Text('Hapus titik')),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, size: 20, color: p.tx2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pencarian tempat Nominatim, didebounce agar tidak satu request per ketikan.
class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        _error = r.isEmpty
            ? 'Tidak ada hasil untuk "$q". Coba nama yang lebih umum, '
                'mis. "Tumpang Malang".'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pencarian gagal. Cek koneksi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * .72,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: p.bg,
          border: Border(top: BorderSide(color: p.line)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: arch(600, 14, color: p.tx),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari tempat, mis. Tumpang Malang',
                hintStyle: arch(500, 14, color: p.tx2),
                prefixIcon: Icon(Icons.search, size: 20, color: p.tx2),
                filled: true,
                fillColor: p.surf,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: arch(500, 13, color: p.tx2, height: 1.4)),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: p.line),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.place_outlined, color: p.tx2),
                    title: Text(r.name, style: arch(700, 14, color: p.tx)),
                    subtitle: Text(r.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: arch(400, 12, color: p.tx2)),
                    onTap: () => Navigator.pop(context, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

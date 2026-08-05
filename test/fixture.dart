import 'package:latlong2/latlong.dart';
import 'package:touring_touring/data.dart';

/// Data untuk test saja. Sengaja hidup di `test/`, bukan di `lib/` — dulu ada
/// grup demo di dalam app, dan angka simulasinya bocor ke rekap serta kartu
/// bagikan yang dilihat pengguna.
///
/// Rute Malang – Tumpang – Gubugklakah – Jemplang – Penanjakan, dipakai sebagai
/// bentuk rute yang wajar untuk diuji.
final ujiGeometry = <LatLng>[
  const LatLng(-7.9797, 112.6304), const LatLng(-7.9866, 112.6520),
  const LatLng(-7.9930, 112.6720), const LatLng(-8.0010, 112.6950),
  const LatLng(-8.0092, 112.7180), const LatLng(-8.0170, 112.7380),
  const LatLng(-8.0245, 112.7600), const LatLng(-8.0290, 112.7800),
  const LatLng(-8.0325, 112.8060), const LatLng(-8.0330, 112.8300),
  const LatLng(-8.0295, 112.8520), const LatLng(-8.0260, 112.8700),
  const LatLng(-8.0312, 112.8880), const LatLng(-8.0350, 112.9020),
  const LatLng(-8.0140, 112.9200), const LatLng(-7.9990, 112.9280),
  const LatLng(-7.9770, 112.9360), const LatLng(-7.9560, 112.9420),
  const LatLng(-7.9425, 112.9530),
];

const ujiStopIndices = [0, 4, 7, 13, 18];
const ujiStopLabels = [
  'Titik Kumpul Malang',
  'Rest Area Tumpang',
  'SPBU Gubugklakah',
  'Jemplang',
  'Finish · Penanjakan',
];

const ujiGroupId = 'GRC-2026';

/// Grup berute lengkap untuk test. [members] diisi seolah datang dari server.
TripGroup ujiGroup({
  String id = ujiGroupId,
  String name = 'Bromo Etape 2',
  String club = 'Garuda Rider Club',
  String? gid,
  String? rcUid,
  TripMode mode = TripMode.motor,
  List<Member>? members,
}) {
  const d = Distance(roundResult: false);
  var km = 0.0;
  for (var i = 0; i < ujiGeometry.length - 1; i++) {
    km += d.as(LengthUnit.Kilometer, ujiGeometry[i], ujiGeometry[i + 1]);
  }
  return TripGroup(
    id: id,
    gid: gid,
    rcUid: rcUid,
    name: name,
    club: club,
    when: DateTime(2026, 8, 3, 13, 30),
    mode: mode,
    stops: [
      for (var i = 0; i < ujiStopIndices.length; i++)
        Stop(ujiStopLabels[i], ujiGeometry[ujiStopIndices[i]]),
    ],
    geometry: List.of(ujiGeometry),
    stopIndices: List.of(ujiStopIndices),
    km: km,
    minutes: (km / 32 * 60).round(),
    members: members ??
        [
          Member(
              name: 'Bagas Pratama',
              plat: 'N 1 AB',
              role: 'RC',
              uid: 'uid-rc'),
        ],
  );
}

/// Pasang [g] sebagai grup aktif di [s], termasuk cache rute globalnya.
void pakai(TripState s, TripGroup g) {
  s.groups.add(g);
  s.activeId = g.id;
  if (g.hasRoute) {
    setRoute(g.geometry, g.waypoints);
  } else {
    clearRoute();
  }
}

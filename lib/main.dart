import 'package:flutter/material.dart';

import 'data.dart';
import 'firebase_config.dart';
import 'screens/groups_screen.dart';
import 'screens/map_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/team_screen.dart';
import 'screens/trip_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache lokal dibaca lebih dulu, jadi app terbuka walau server tidak
  // terjangkau; data server menyusul begitu tersambung.
  await trip.init(cloud: Cloud(options: defaultOptions));
  runApp(const TouringApp());
}

class TouringApp extends StatelessWidget {
  const TouringApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: trip,
        builder: (_, _) => MaterialApp(
          title: 'Touring Tracker',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(trip.dark),
          home: const Shell(),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  static const _tabs = [
    (Icons.my_location, 'PETA'),
    (Icons.groups_2_outlined, 'TIM'),
    (Icons.warning_amber_rounded, 'SOS'),
    (Icons.add_circle_outline, 'GRUP'),
    (Icons.history, 'REKAP'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListenableBuilder(
                listenable: trip,
                builder: (_, _) => switch (tab) {
                  0 => MapScreen(onSeeSos: () => setState(() => tab = 2)),
                  1 => const TeamScreen(),
                  2 => const SosScreen(),
                  3 => GroupsScreen(onOpenMap: () => setState(() => tab = 0)),
                  _ => const TripScreen(),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surf,
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => tab = i),
                      behavior: HitTestBehavior.opaque,
                      child: _NavItem(
                        icon: _tabs[i].$1,
                        label: _tabs[i].$2,
                        active: tab == i,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon, required this.label, required this.active});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Pal.of(context).tx2;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: .14) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 4),
          Text(label, style: mono(700, 10, color: color)),
        ],
      ),
    );
  }
}

/// Baris atas: grup aktif, progres (kalau live), dan toggle tema.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = trip.active;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(initials(g.club),
                style: arch(800, 14, color: const Color(0xFF12140F))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arch(700, 16, color: p.tx)),
                Text(
                  trip.live
                      ? 'KM ${trip.leader.km.round()} / ${totalKm.round()} · '
                          '± ${trip.etaMin} mnt lagi'
                      : '${g.id} · ${g.members.length} rider'
                          '${g.hasRoute ? " · ${km1(g.km)} km" : " · rute belum ada"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(500, 12, color: p.tx2),
                ),
              ],
            ),
          ),
          if (trip.live) ...[
            _StatChip(trip.count(RiderStatus.aman), ok),
            const SizedBox(width: 6),
            _StatChip(trip.count(RiderStatus.tertinggal), warn),
            const SizedBox(width: 6),
            _StatChip(trip.count(RiderStatus.berhenti), p.tx2, flat: true),
          ],
          IconButton(
            tooltip: trip.dark ? 'Mode terang' : 'Mode gelap',
            onPressed: () => trip.toggleTheme(!trip.dark),
            icon: Icon(
                trip.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20,
                color: p.tx2),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.n, this.color, {this.flat = false});
  final int n;
  final Color color;
  final bool flat;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: flat ? Pal.of(context).surf2 : color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('$n', style: mono(700, 12, color: color)),
      );
}

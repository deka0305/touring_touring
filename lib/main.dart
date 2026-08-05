import 'package:flutter/material.dart';

import 'data.dart';
import 'firebase_config.dart';
import 'screens/group_screen.dart';
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

  /// Seluruh isi Shell dibangun di dalam ListenableBuilder ini.
  ///
  /// Penting: `home: const Shell()` itu widget const, jadi saat MaterialApp
  /// dibangun ulang Flutter melihat widget yang identik dan **melewati subtree
  /// ini**. Tanpa listener di sini, `trip.hasGroup` tidak pernah dievaluasi
  /// ulang — dan orang yang baru membuat grup tetap melihat layar "buat grup".
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: trip,
        builder: (context, _) =>
            trip.hasGroup ? _tabShell(context) : const _NoGroup(),
      );

  Widget _tabShell(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sengaja TIDAK const, dan jangan diubah jadi const. Widget const
            // dikanonikalisasi: instansinya identik tiap build, dan Flutter
            // melewati subtree yang widget-nya identik. Semua widget di bawah
            // ini membaca `trip`, jadi kalau di-const-kan tampilannya membeku
            // menampilkan data basi sampai pengguna mengetuk tab.
            _Header(),
            Expanded(
              child: switch (tab) {
                0 => MapScreen(onSeeSos: () => setState(() => tab = 2)),
                1 => TeamScreen(),
                2 => SosScreen(),
                3 => GroupsScreen(onOpenMap: () => setState(() => tab = 0)),
                _ => TripScreen(),
              },
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

/// Layar pertama di pemasangan baru: belum ada grup sama sekali.
///
/// Dua jalan masuk saja, karena memang cuma ada dua: bikin sendiri, atau
/// gabung pakai kode dari road captain.
class _NoGroup extends StatelessWidget {
  const _NoGroup();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.two_wheeler,
                      size: 30, color: Color(0xFF12140F)),
                ),
                const SizedBox(height: 20),
                Text('Touring Tracker',
                    style: arch(800, 26, color: p.tx, height: 1.15)),
                const SizedBox(height: 8),
                Text(
                  'Belum ada grup touring di HP ini. Buat grup sendiri sebagai '
                  'road captain, atau gabung pakai kode yang dikirim road '
                  'captain-mu.',
                  textAlign: TextAlign.center,
                  style: arch(400, 14, color: p.tx2, height: 1.6),
                ),
                const SizedBox(height: 24),
                _NoGroupBtn(
                  icon: Icons.add,
                  label: 'Buat grup touring',
                  primary: true,
                  onTap: () => _create(context),
                ),
                const SizedBox(height: 10),
                _NoGroupBtn(
                  icon: Icons.download_outlined,
                  label: 'Gabung pakai kode',
                  primary: false,
                  onTap: () => joinByCode(context),
                ),
                if (!trip.online) ...[
                  const SizedBox(height: 20),
                  Text(
                    trip.cloudError ?? 'Server tidak tersambung',
                    textAlign: TextAlign.center,
                    style: arch(400, 12, color: warn, height: 1.5),
                  ),
                  Text(
                    'Grup masih bisa dibuat, tapi belum bisa dibagikan ke '
                    'anggota.',
                    textAlign: TextAlign.center,
                    style: arch(400, 12, color: p.tx2, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    // Navigator diambil SEBELUM await. Begitu grupnya ada, Shell berganti
    // tampilan dan layar ini dibongkar — context-nya jadi tidak sah, dan
    // `context.mounted` akan memblokir langkah berikutnya. NavigatorState
    // hidup di MaterialApp, jadi tetap sah.
    final nav = Navigator.of(context);
    final g = await nav.push<TripGroup>(
      MaterialPageRoute(builder: (_) => const NewGroupScreen()),
    );
    if (g == null) return;
    await nav.push(MaterialPageRoute(builder: (_) => GroupScreen(group: g)));
  }
}

class _NoGroupBtn extends StatelessWidget {
  const _NoGroupBtn({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = primary ? const Color(0xFF12140F) : p.tx;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primary ? accent : p.surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary ? accent : p.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Text(label, style: arch(700, 15, color: fg)),
          ],
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

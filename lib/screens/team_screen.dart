import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';

/// Layar B — daftar tim. Cari nama/nopol, filter status, urut yang butuh
/// perhatian di atas.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _q = '';
  RiderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    // Grup tanpa pelacakan live: tampilkan daftar anggota, bukan status live.
    if (!trip.live) {
      return _MemberList(
          query: q, onChanged: (v) => setState(() => _q = v));
    }

    final list = trip.sorted
        .where((r) => _filter == null || r.status == _filter)
        .where((r) =>
            q.isEmpty ||
            r.name.toLowerCase().contains(q) ||
            r.plat.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        _SearchField(onChanged: (v) => setState(() => _q = v)),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _chip('SEMUA ${trip.riders.length}', null),
              for (final s in [
                RiderStatus.hilang,
                RiderStatus.tertinggal,
                RiderStatus.berhenti,
                RiderStatus.aman,
              ])
                _chip('${s.label} ${trip.count(s)}', s),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            children: [
              if (list.isNotEmpty) ...[
                SectionLabel('TERLACAK · ${trip.riders.length}'),
                const SizedBox(height: 8),
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RiderRow(r),
                  ),
              ],
              // Anggota tanpa posisi dulu dibuang begitu saja dari daftar ini,
              // jadi RC tidak pernah tahu siapa yang belum menyalakan lokasi —
              // padahal itu yang paling perlu dia tahu sebelum berangkat.
              if (_untracked(q).isNotEmpty) ...[
                const SizedBox(height: 8),
                SectionLabel('BELUM TERLACAK · ${trip.untracked.length}'),
                const SizedBox(height: 8),
                for (final m in _untracked(q))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _UntrackedRow(m),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Filter status tidak berlaku untuk yang belum terlacak — mereka belum punya
  /// status. Saat salah satu chip status dipilih, bagian ini disembunyikan.
  List<Member> _untracked(String q) => _filter != null
      ? const []
      : trip.untracked
          .where((m) =>
              q.isEmpty ||
              m.name.toLowerCase().contains(q) ||
              m.plat.toLowerCase().contains(q))
          .toList();

  Widget _chip(String text, RiderStatus? s) {
    final p = Pal.of(context);
    final on = _filter == s;
    final fg = on
        ? const Color(0xFF12140F)
        : s == null
            ? p.tx
            : Color(s.color);
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () => setState(() => _filter = s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? accent : p.line),
          ),
          child: Text(text, style: mono(700, 11, color: fg)),
        ),
      ),
    );
  }
}

/// Anggota yang sudah gabung tapi belum menyalakan berbagi lokasi. Tampil
/// redup dan tanpa angka apa pun — tidak ada data untuk ditebak-tebak.
class _UntrackedRow extends StatelessWidget {
  const _UntrackedRow(this.m);
  final Member m;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: p.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surf2,
              shape: BoxShape.circle,
              border: Border.all(color: p.line),
            ),
            child: Text(initials(m.name), style: mono(800, 12, color: p.tx2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: arch(700, 14, color: p.tx2)),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.surf2,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(m.role,
                          style: mono(600, 9, color: p.tx2, spacing: .8)),
                    ),
                  ],
                ),
                Text(m.plat.isEmpty ? '—' : m.plat,
                    style: mono(500, 11, color: p.tx2, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('BELUM BERBAGI\nLOKASI',
              textAlign: TextAlign.right,
              style: mono(700, 9, color: p.tx2, height: 1.5)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: TextField(
        onChanged: onChanged,
        style: arch(500, 13, color: p.tx),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Cari nama atau nopol…',
          hintStyle: arch(500, 13, color: p.tx2),
          filled: true,
          fillColor: p.surf,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
    );
  }
}

/// Daftar anggota grup yang belum jalan: peran dan nopol, tanpa status live.
class _MemberList extends StatelessWidget {
  const _MemberList({required this.query, required this.onChanged});
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = trip.active;
    final list = g.members
        .where((m) =>
            query.isEmpty ||
            m.name.toLowerCase().contains(query) ||
            m.plat.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final r = roleOrder.indexOf(a.role) - roleOrder.indexOf(b.role);
        return r != 0 ? r : a.name.compareTo(b.name);
      });

    return Column(
      children: [
        _SearchField(onChanged: onChanged),
        Expanded(
          child: g.members.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Belum ada anggota di "${g.name}".\n'
                      'Tambahkan dari tab Grup → pilih grup → Anggota.',
                      textAlign: TextAlign.center,
                      style: arch(400, 13, color: p.tx2, height: 1.6),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final special = m.role == 'RC' || m.role == 'SWP';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: p.surf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.surf2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: special ? accent : p.line,
                                  width: special ? 2 : 1),
                            ),
                            child: Text(initials(m.name),
                                style: mono(800, 12,
                                    color: special ? accent : p.tx2)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: arch(700, 14, color: p.tx)),
                                Text(m.plat.isEmpty ? '—' : m.plat,
                                    style: mono(500, 11,
                                        color: p.tx2, height: 1.4)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: special
                                  ? accent.withValues(alpha: .14)
                                  : p.surf2,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(roleNames[m.role] ?? m.role,
                                style: mono(700, 10,
                                    color: special ? accent : p.tx2)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow(this.r);
  final Rider r;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = Color(r.status.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: p.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: c),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surf2,
              shape: BoxShape.circle,
              border: Border.all(color: c, width: 2),
            ),
            child: Text(initials(r.name), style: mono(800, 12, color: c)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(r.name,
                          overflow: TextOverflow.ellipsis,
                          style: arch(700, 14, color: p.tx)),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.surf2,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(r.role,
                          style: mono(600, 9, color: p.tx2, spacing: .8)),
                    ),
                  ],
                ),
                Text(
                  // KM dihitung sebagai posisi di sepanjang rute, jadi tanpa
                  // rute nilainya 0 untuk semua orang — lebih baik tidak
                  // ditulis daripada menampilkan "KM 0" berjajar.
                  routeReady
                      ? '${r.plat} · ${r.v.round()} km/j · KM ${r.km.round()}'
                      : '${r.plat} · ${r.v.round()} km/j',
                  style: mono(500, 11, color: p.tx2, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(r.status.label, style: mono(700, 11, color: c)),
              // Baterai bisa tidak dilaporkan — "—" lebih jujur dari "0%".
              Text(r.batt == null ? '—' : '${r.batt}%',
                  style: mono(500, 11, color: p.tx2, height: 1.6)),
            ],
          ),
        ],
      ),
    );
  }
}

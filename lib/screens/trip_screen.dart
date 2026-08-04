import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../theme.dart';
import 'share_screen.dart';

/// Layar E — rekap perjalanan, checkpoint, dan kartu bagikan.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = trip;
    final g = s.active;
    final live = s.live;

    if (!g.hasRoute) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Rekap muncul setelah grup "${g.name}" punya rute.\n'
            'Susun rutenya dari tab Peta atau tab Grup.',
            textAlign: TextAlign.center,
            style: arch(400, 13, color: p.tx2, height: 1.6),
          ),
        ),
      );
    }

    // Prioritas: jejak GPS nyata > simulasi live > rencana. Rekap tanpa jejak
    // nyata bukan rekap, cuma perkiraan.
    final t = s.track;
    final punyaJejak = !t.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      children: [
        const SizedBox(height: 8),
        Text(
            punyaJejak
                ? 'Rekap perjalanan'
                : live
                    ? 'Rekap rombongan'
                    : 'Rencana perjalanan',
            style: arch(800, 24, color: p.tx, height: 1.15)),
        Text(
            '${g.name} · ${g.mode.label} · '
            '${fmtWhen(punyaJejak ? t.startedAt! : g.when)}',
            style: arch(400, 13, color: p.tx2, height: 1.5)),
        const SizedBox(height: 16),

        if (punyaJejak) ...[
          Row(
            children: [
              Expanded(child: _Stat('JARAK TEMPUH', km1(t.km), 'km')),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat('DURASI', fmtDur(t.duration.inMinutes), '')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _Stat('RATA-RATA', '${t.avgKmh.round()}', 'km/j',
                      color: accent)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat('KEC. MAKS', '${t.topKmh.round()}', 'km/j')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Soft('TITIK JEJAK', '${t.points.length}')),
              const SizedBox(width: 10),
              Expanded(
                  child: _Soft('RUTE RENCANA',
                      g.hasRoute ? '${km1(g.km)} km' : '—')),
              const SizedBox(width: 10),
              Expanded(
                  child: _Soft(
                      'STATUS', trip.recording ? 'Merekam' : 'Berhenti')),
            ],
          ),
        ] else if (!live)
          _PlanStats(group: g)
        else ...[
          Row(
            children: [
              Expanded(child: _Stat('JARAK TEMPUH', km1(s.leader.km), 'km')),
              const SizedBox(width: 10),
              Expanded(child: _Stat('DURASI', s.durText, '')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _Stat('RATA-RATA', '${s.avgSpeed.round()}', 'km/j',
                      color: accent)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat('KEC. MAKS', '${s.topSpeed.round()}', 'km/j')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Soft('RENTANG', '${km1(s.spread)} km')),
              const SizedBox(width: 10),
              Expanded(child: _Soft('SISA', '± ${s.etaMin} menit')),
              const SizedBox(width: 10),
              Expanded(child: _Soft('BERHENTI', '${s.stopCount} rider')),
            ],
          ),
        ],
        const SizedBox(height: 22),
        const SectionLabel('CHECKPOINT'),
        for (var i = 0; i < g.stops.length; i++)
          _CheckpointRow(index: i, group: g, live: live),
        const SizedBox(height: 22),
        const SectionLabel('BAGIKAN'),
        const SizedBox(height: 8),
        // Pratinjau kartunya ada di layar Bagikan — satu desain kartu saja,
        // dan yang dilihat di sana persis yang terkirim.
        const SizedBox(height: 4),
        // Bagikan sebagai gambar, bukan teks: kartunya bisa dikirim ke mana
        // saja lewat lembar bagikan sistem, dan orang membaca satu gambar jauh
        // lebih cepat daripada delapan baris angka.
        Row(
          children: [
            Expanded(
              child: _Btn(
                'Bagikan sebagai gambar',
                accent,
                const Color(0xFF12140F),
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShareScreen()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Btn('Salin teks', p.surf, p.tx, () async {
              await Clipboard.setData(ClipboardData(text: shareText(s)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Rekap tersalin'),
                      duration: Duration(seconds: 2)),
                );
              }
            }, border: p.line),
          ],
        ),
        const SizedBox(height: 8),
        Text(
            'Kartu gambar bisa ditambahi foto, lalu dikirim ke WhatsApp, '
            'Instagram, atau disimpan ke galeri.',
            textAlign: TextAlign.center,
            style: arch(400, 11, color: p.tx2, height: 1.5)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit, {this.color});
  final String label, value, unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: mono(500, 10, color: p.tx2, spacing: 1.2)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(
            text: value,
            style: arch(800, 24, color: color ?? p.tx, height: 1.1),
            children: [
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: mono(600, 11, color: p.tx2)),
            ],
          )),
        ],
      ),
    );
  }
}

class _Soft extends StatelessWidget {
  const _Soft(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: p.surf2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: mono(500, 10, color: p.tx2, spacing: 1)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arch(700, 16, color: p.tx, height: 1.3)),
        ],
      ),
    );
  }
}

/// Statistik rencana untuk grup yang belum jalan.
class _PlanStats extends StatelessWidget {
  const _PlanStats({required this.group});
  final TripGroup group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _Stat('JARAK RUTE', km1(g.km), 'km')),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat('ESTIMASI', fmtDur(g.minutes), '', color: accent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Soft('TITIK', '${g.stops.length} stop')),
            const SizedBox(width: 10),
            Expanded(child: _Soft('ANGGOTA', '${g.members.length} rider')),
            const SizedBox(width: 10),
            Expanded(
                child: _Soft('BERANGKAT', fmtClock(g.when))),
          ],
        ),
      ],
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  const _CheckpointRow({
    required this.index,
    required this.group,
    required this.live,
  });
  final int index;
  final TripGroup group;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final km = group.stopKmAt(index);
    final label = group.stops[index].label;

    // Jam lintas dari jejak GPS nyata kalau ada — itu yang sebenarnya terjadi.
    // Jejak juga yang menentukan checkpoint mana sudah dilewati: rider bisa
    // saja belum sampai KM-nya tapi sudah lewat titiknya (atau sebaliknya,
    // lewat jauh dari titiknya sehingga tidak dihitung).
    final lewat = trip.track.isEmpty
        ? null
        : trip.track.passedAt(group.stops[index].at);

    final bool done;
    final String time;
    if (lewat != null) {
      done = true;
      time = fmtClock(lewat);
    } else if (!trip.track.isEmpty) {
      // Ada jejak, tapi titik ini tidak pernah didekati.
      done = false;
      time = '—';
    } else if (live && trip.leader.km >= km) {
      done = true;
      final m = trip.startMinute +
          (trip.elapsedMin * (km / math.max(.1, trip.leader.km))).round();
      time = '${(m ~/ 60).toString().padLeft(2, "0")}:'
          '${(m % 60).toString().padLeft(2, "0")}';
    } else if (!live && group.km > 0) {
      done = false;
      final m = trip.startMinute + (group.minutes * (km / group.km)).round();
      time = '${((m ~/ 60) % 24).toString().padLeft(2, "0")}:'
          '${(m % 60).toString().padLeft(2, "0")}';
    } else {
      done = false;
      time = '—';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: done ? ok : p.line, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arch(600, 13, color: done ? p.tx : p.tx2)),
          ),
          Text('KM ${km.round()}', style: mono(600, 12, color: p.tx2)),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(time,
                textAlign: TextAlign.right,
                style: mono(700, 12, color: done ? ok : p.tx2)),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.bg, this.fg, this.onTap, {this.border});
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Text(label, style: arch(800, 14, color: fg)),
        ),
      );
}

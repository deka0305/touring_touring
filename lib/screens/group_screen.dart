import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'route_edit_screen.dart';

/// Halaman detail satu grup — dibuka setelah buat/gabung grup. Isinya sama
/// dengan tab Grup ([GroupBody]), ditambah tombol menjadikannya grup aktif.
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.group});
  final TripGroup group;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: trip,
      builder: (context, _) {
        // Grup bisa hilang saat layar ini terbuka: dihapus dari daftar, atau
        // road captain menghapusnya dari HP lain. Katakan apa yang terjadi —
        // layar kosong hanya terlihat seperti app-nya rusak.
        if (!trip.groups.contains(group)) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: p.surf,
              surfaceTintColor: Colors.transparent,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 40, color: p.tx2),
                    const SizedBox(height: 14),
                    Text('Grup ini sudah tidak ada',
                        style: arch(800, 17, color: p.tx, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(
                      'Mungkin kamu menghapusnya, atau road captain '
                      'menutup grupnya dari HP lain.',
                      textAlign: TextAlign.center,
                      style: arch(400, 13, color: p.tx2, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    _Btn('Kembali ke daftar grup', accent,
                        const Color(0xFF12140F), () => Navigator.pop(context)),
                  ],
                ),
              ),
            ),
          );
        }
        final g = group;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.surf,
            surfaceTintColor: Colors.transparent,
            title: Text(g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arch(700, 17, color: p.tx)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              if (g.id != trip.activeId) ...[
                _Btn('Jadikan grup aktif', accent, const Color(0xFF12140F),
                    () => trip.setActive(g.id)),
                const SizedBox(height: 14),
              ],
              GroupBody(group: g, popOnLeave: true),
            ],
          ),
        );
      },
    );
  }
}

/// Isi grup: kode undangan, rute, obrolan, anggota + status live, dan menu
/// kelola. Dipakai langsung di tab Grup dan di [GroupScreen].
class GroupBody extends StatelessWidget {
  const GroupBody({super.key, required this.group, this.popOnLeave = false});
  final TripGroup group;

  /// True kalau dibuka sebagai halaman sendiri: setelah keluar/hapus grup,
  /// halamannya ditutup.
  final bool popOnLeave;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = group;
    final rc = trip.amRc(g);
    final active = g.id == trip.activeId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _idCard(context, g, rc, active),
        const SizedBox(height: 14),
        if (g.todo.isNotEmpty) ...[
          _todoCard(g, p),
          const SizedBox(height: 14),
        ],
        if (active && g.onCloud) ...[
          _chatCard(context, p),
          const SizedBox(height: 20),
        ],
        const SectionLabel('RUTE'),
        const SizedBox(height: 8),
        _routeCard(context, g, p),
        const SizedBox(height: 20),
        SectionLabel('ANGGOTA · ${g.members.length}'
            '${rc && g.onCloud ? " · RC BISA MENGELUARKAN" : ""}'),
        const SizedBox(height: 6),
        // Tidak ada tombol tambah: anggota masuk sendiri dengan memasang
        // app dan mengetik kode. Lokasi itu milik HP, jadi orang yang
        // didaftarkan dari HP lain tidak akan pernah punya posisi.
        if (!g.onCloud)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Grup ini hanya ada di HP ini, jadi anggota lain belum bisa '
              'gabung. Cek koneksi lalu buat ulang.',
              style: arch(400, 12, color: p.tx2, height: 1.5),
            ),
          ),
        if (g.members.isEmpty)
          Text('Belum ada anggota.', style: arch(400, 13, color: p.tx2))
        else
          for (final m in _sortedMembers(g))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MemberRow(
                group: g,
                member: m,
                active: active,
                editable: rc,
                onTap: () => _editMember(context, g, m),
              ),
            ),
        // Cekalan wajib bisa dibatalkan. Mengeluarkan anggota otomatis
        // mencekalnya — kalau tidak, dia tinggal mengetik kode lagi — dan
        // tanpa bagian ini satu salah tekan jadi permanen.
        if (rc && g.banned.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionLabel('DICEKAL · ${g.banned.length}'),
          const SizedBox(height: 6),
          Text(
            'Mereka tidak bisa gabung walau punya kode. Izinkan lagi '
            'kalau salah dikeluarkan.',
            style: arch(400, 12, color: p.tx2, height: 1.5),
          ),
          const SizedBox(height: 10),
          for (final e in g.banned.entries.toList())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BannedRow(
                name: e.value,
                onAllow: () => trip.unbanMember(g, e.key),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _menu(context, g, rc, p),
      ],
    );
  }

  /// Road captain dan sweeper selalu di atas — mereka yang paling dicari.
  List<Member> _sortedMembers(TripGroup g) => g.members.toList()
    ..sort((a, b) {
      final r = roleOrder.indexOf(a.role) - roleOrder.indexOf(b.role);
      return r != 0 ? r : a.name.compareTo(b.name);
    });

  String _invite(TripGroup g) =>
      'Ikut touring "${g.name}" bareng ${g.club}?\n'
      'Jadwal: ${fmtWhen(g.when)}\n'
      '${g.hasRoute ? "Rute: ${g.stops.map((s) => s.label).join(" → ")}\n"
          "Jarak: ${km1(g.km)} km · ± ${fmtDur(g.minutes)}\n" : ""}'
      '\nBuka app Konvoi → Grup → Gabung pakai kode, lalu ketik:\n'
      '${g.inviteCode}';

  Widget _idCard(BuildContext context, TripGroup g, bool rc, bool active) {
    final p = Pal.of(context);
    final pendek = isInviteCode(g.inviteCode);
    return Panel(
      padding: const EdgeInsets.all(16),
      radius: 18,
      border: active ? ok : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(initials(g.club),
                    style: arch(800, 16, color: const Color(0xFF12140F))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.club, style: arch(700, 15, color: p.tx)),
                    Text('${fmtWhen(g.when)} · ${g.mode.label}',
                        style: mono(500, 11, color: p.tx2, height: 1.5)),
                  ],
                ),
              ),
              _Tag(rc ? 'ROAD CAPTAIN' : 'ANGGOTA', rc ? accent : p.tx2),
              if (active) ...[
                const SizedBox(width: 6),
                const _Tag('AKTIF', ok),
              ],
            ],
          ),
          if (g.onCloud) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
              decoration: BoxDecoration(
                color: p.surf2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KODE UNDANGAN',
                            style: mono(500, 10, color: p.tx2, spacing: 1.4)),
                        const SizedBox(height: 2),
                        Text(
                          g.inviteCode,
                          maxLines: pendek ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: pendek
                              ? mono(700, 20, color: p.tx, spacing: 2)
                              : mono(500, 11, color: p.tx),
                        ),
                      ],
                    ),
                  ),
                  _SmallBtn(
                    icon: Icons.copy_rounded,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: g.inviteCode));
                      if (context.mounted) _toast(context, 'Kode tersalin');
                    },
                  ),
                  const SizedBox(width: 8),
                  _SmallBtn(
                    icon: Icons.share_outlined,
                    filled: true,
                    onTap: () => SharePlus.instance.share(ShareParams(
                      text: _invite(g),
                      subject: 'Undangan touring — ${g.name}',
                    )),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chatCard(BuildContext context, Pal p) {
    final unread = trip.chatUnread;
    final last = trip.chat.lastOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ChatScreen())),
      child: Panel(
        child: Row(
          children: [
            Icon(Icons.forum_outlined, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Obrolan grup', style: arch(700, 14, color: p.tx)),
                  Text(
                    last == null
                        ? 'Chat & pesan suara sesama anggota'
                        : '${last.name}: '
                            '${last.isVoice ? "🎤 pesan suara" : last.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arch(400, 12, color: p.tx2),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: bad, borderRadius: BorderRadius.circular(99)),
                child: Text('$unread',
                    style: mono(700, 11, color: Colors.white)),
              )
            else
              Icon(Icons.chevron_right, color: p.tx2),
          ],
        ),
      ),
    );
  }

  Widget _todoCard(TripGroup g, Pal p) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warn.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warn),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Belum siap jalan', style: arch(700, 14, color: warn)),
            const SizedBox(height: 6),
            for (final t in g.todo)
              Text('• $t', style: arch(400, 13, color: p.tx2, height: 1.5)),
          ],
        ),
      );

  Widget _routeCard(BuildContext context, TripGroup g, Pal p) => Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!g.hasRoute)
              Text('Rute belum disusun.',
                  style: arch(500, 13, color: p.tx2, height: 1.5))
            else ...[
              Text.rich(TextSpan(
                text: km1(g.km),
                style: arch(800, 22, color: p.tx),
                children: [
                  TextSpan(
                      text: ' km · ± ${fmtDur(g.minutes)}',
                      style: mono(600, 12, color: p.tx2)),
                ],
              )),
              const SizedBox(height: 8),
              for (var i = 0; i < g.stops.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('${i + 1}', style: mono(700, 11, color: accent)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(g.stops[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: arch(500, 13, color: p.tx)),
                      ),
                      Text('KM ${g.stopKmAt(i).round()}',
                          style: mono(500, 11, color: p.tx2)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            // Server hanya menerima rute dari road captain.
            if (trip.amRc(g))
              _Btn(
                g.hasRoute ? 'Ubah rute' : 'Susun rute sekarang',
                g.hasRoute ? p.surf2 : accent,
                g.hasRoute ? p.tx : const Color(0xFF12140F),
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RouteEditScreen(group: g)),
                ),
              )
            else
              Text(
                g.hasRoute
                    ? 'Rute ditentukan road captain.'
                    : 'Menunggu road captain menyusun rute.',
                style: arch(400, 12, color: p.tx2, height: 1.5),
              ),
          ],
        ),
      );

  Widget _menu(BuildContext context, TripGroup g, bool rc, Pal p) {
    // Grup lokal tidak punya "keluar": tidak ada server tempat dia tetap ada.
    final bisaKeluarSaja = rc && g.onCloud;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        children: [
          if (rc)
            _MenuRow(Icons.edit_outlined, 'Ubah detail grup', p.tx,
                () => _edit(context, g)),
          if (rc)
            _MenuRow(Icons.delete_outline, 'Hapus grup', bad, () async {
              final ya = await _confirm(
                context,
                'Hapus "${g.name}"?',
                g.onCloud
                    ? 'Grup ini dihapus dari server juga, jadi semua anggota '
                        'kehilangan aksesnya. Tidak bisa dibatalkan.'
                    : 'Rute dan daftar anggota grup ini akan hilang dari HP ini.',
                'Hapus',
              );
              if (ya && context.mounted) await _leave(context, g, leaveOnly: false);
            }),
          if (!rc)
            _MenuRow(Icons.logout, 'Keluar dari grup', p.tx, () async {
              final ya = await _confirm(
                context,
                'Keluar dari "${g.name}"?',
                'Namamu dihapus dari daftar anggota. Kamu bisa gabung lagi '
                    'pakai kode yang sama.',
                'Keluar',
              );
              if (ya && context.mounted) await _leave(context, g, leaveOnly: false);
            }),
          if (bisaKeluarSaja)
            _MenuRow(Icons.logout, 'Keluar sebagai road captain', p.tx,
                () async {
              final ya = await _confirm(
                context,
                'Keluar dari "${g.name}"?',
                'Grupnya tetap jalan, tapi anggota lain tidak bisa mengubah rute '
                    'atau mengelola anggota sampai kamu kembali. Masuk lagi '
                    'kapan saja lewat "Grup yang pernah kamu buat" di tab Grup.',
                'Keluar',
              );
              if (ya && context.mounted) await _leave(context, g, leaveOnly: true);
            }),
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context, TripGroup g,
      {required bool leaveOnly}) async {
    final nav = Navigator.of(context);
    await trip.deleteGroup(g.id, leaveOnly: leaveOnly);
    if (popOnLeave && nav.canPop()) nav.pop();
  }

  Future<void> _edit(BuildContext context, TripGroup g) async {
    var name = g.name;
    var club = g.club;
    var when = g.when;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Ubah detail grup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (v) => name = v,
                decoration: const InputDecoration(labelText: 'Nama touring'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: club,
                onChanged: (v) => club = v,
                decoration: const InputDecoration(labelText: 'Klub'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadwal'),
                subtitle: Text(fmtWhen(when)),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: when,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d == null || !c.mounted) return;
                  final t = await showTimePicker(
                      context: c, initialTime: TimeOfDay.fromDateTime(when));
                  setLocal(() => when = DateTime(d.year, d.month, d.day,
                      t?.hour ?? when.hour, t?.minute ?? when.minute));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (saved == true) {
      trip.editGroup(g, name: name, club: club, when: when);
    }
  }

  Future<void> _editMember(BuildContext context, TripGroup g, Member m) async {
    final edited = await showMemberDialog(context, group: g, existing: m);
    if (edited != null) {
      trip.updateMember(g, m,
          name: edited.name, plat: edited.plat, role: edited.role);
    }
  }
}

Future<bool> _confirm(
    BuildContext context, String title, String body, String ok) async {
  final ya = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(foregroundColor: bad),
          child: Text(ok),
        ),
      ],
    ),
  );
  return ya == true;
}

void _toast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(text, style: mono(700, 9, color: color)),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: color),
        title: Text(label, style: arch(600, 14, color: color)),
        onTap: onTap,
      );
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.icon, required this.onTap, this.filled = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : p.surf,
          border: filled ? null : Border.all(color: p.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 17, color: filled ? const Color(0xFF12140F) : p.tx),
      ),
    );
  }
}

/// Satu orang yang dicekal, dengan jalan keluarnya.
class _BannedRow extends StatelessWidget {
  const _BannedRow({required this.name, required this.onAllow});
  final String name;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: p.surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: p.tx2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arch(700, 13, color: p.tx)),
          ),
          TextButton(
            onPressed: onAllow,
            child: Text('Izinkan lagi', style: arch(700, 12, color: accent)),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.group,
    required this.member,
    required this.active,
    required this.editable,
    required this.onTap,
  });
  final TripGroup group;
  final Member member;

  /// Status live hanya ada untuk grup aktif — hanya grup itu yang diikuti.
  final bool active;

  /// False untuk anggota biasa: server menolak dia mengubah anggota lain.
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final m = member;
    final me = m.uid != null && m.uid == trip.myUid;
    final special = m.role == 'RC' || m.role == 'SWP';
    final rider = active
        ? trip.riders.where((r) => r.uid != null && r.uid == m.uid).firstOrNull
        : null;

    // Baris status di bawah nama: plat + keadaan live kalau ada.
    final sub = [
      if (m.plat.isNotEmpty) m.plat,
      if (rider != null) ...[
        '${rider.v.round()} km/j',
        if (rider.staleness != null) fmtAgo(rider.staleness!),
      ] else if (active && group.onCloud && !me)
        'belum berbagi lokasi',
    ].join(' · ');

    return GestureDetector(
      onTap: editable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
        decoration: BoxDecoration(
          color: p.surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surf2,
                shape: BoxShape.circle,
                border: Border.all(
                    color: special ? accent : p.line, width: special ? 2 : 1),
              ),
              child: Text(initials(m.name),
                  style: mono(800, 12, color: special ? accent : p.tx2)),
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
                            style: arch(700, 14, color: p.tx)),
                      ),
                      if (me)
                        Text(' · SAYA', style: mono(600, 10, color: p.tx2)),
                    ],
                  ),
                  Text(sub.isEmpty ? '—' : sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono(500, 11, color: p.tx2, height: 1.4)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(roleNames[m.role] ?? m.role,
                    style: mono(700, 10, color: special ? accent : p.tx2)),
                if (rider != null)
                  Text(rider.status.label,
                      style: mono(700, 10, color: Color(rider.status.color))),
              ],
            ),
            if (editable && !me && m.role != 'RC')
              IconButton(
                tooltip: 'Keluarkan',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 16, color: bad),
                onPressed: () async {
                  final ya = await _confirm(
                    context,
                    'Keluarkan ${m.name}?',
                    'Dia berhenti berbagi lokasi ke grup ini dan tidak bisa '
                        'gabung lagi pakai kode yang sama, kecuali kamu '
                        'izinkan lagi.',
                    'Keluarkan',
                  );
                  if (!ya) return;
                  final err = await trip.removeMember(group, m);
                  if (err != null && context.mounted) _toast(context, err);
                },
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Dialog ubah anggota. Mengembalikan Member baru (belum dipasang).
///
/// Tanpa TextEditingController: `initialValue` + `onChanged` sudah cukup, dan
/// itu menghilangkan seluruh urusan siklus hidup controller. Membuang
/// controller setelah `showDialog` kembali itu terlalu cepat — dialognya masih
/// dibangun selama animasi keluar.
Future<Member?> showMemberDialog(
  BuildContext context, {
  required TripGroup group,
  required Member existing,
}) async {
  var name = existing.name;
  var plat = existing.plat;
  var role = existing.role;
  final form = GlobalKey<FormState>();

  return showDialog<Member>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        title: const Text('Ubah anggota'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (v) => name = v,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nama', hintText: 'mis. Rizky Nugroho'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Nama belum diisi.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: plat,
                onChanged: (v) => plat = v,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Nomor polisi', hintText: 'mis. N 1234 AB'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Peran'),
                items: [
                  for (final r in roleOrder)
                    DropdownMenuItem(value: r, child: Text(roleNames[r]!)),
                ],
                onChanged: (v) => setLocal(() => role = v ?? 'RIDER'),
              ),
              if (role == 'RC' &&
                  group.roadCaptain != null &&
                  group.roadCaptain != existing)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${group.roadCaptain!.name} akan turun jadi rider — '
                    'road captain hanya satu.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(
                c,
                Member(
                  // Kunci anggota dipertahankan supaya suntingan menimpa baris
                  // yang sama di server, bukan membuat anggota kembar.
                  uid: existing.uid,
                  name: name.trim(),
                  plat: plat.trim().toUpperCase(),
                  role: role,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.bg, this.fg, this.onTap);
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, style: arch(800, 14, color: fg)),
        ),
      );
}

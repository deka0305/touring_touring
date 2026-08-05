import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../theme.dart';
import 'route_edit_screen.dart';

/// Detail satu grup: checklist kesiapan, rute, anggota, dan bagikan.
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
        final active = g.id == trip.activeId;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.surf,
            surfaceTintColor: Colors.transparent,
            title: Text(g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arch(700, 17, color: p.tx)),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'edit' => _edit(context, g),
                  _ => _delete(context, g),
                },
                itemBuilder: (_) => [
                  if (trip.amRc(g))
                    const PopupMenuItem(
                        value: 'edit', child: Text('Ubah detail')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(
                          trip.amRc(g) ? 'Hapus grup' : 'Keluar dari grup')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              _idCard(context, g),
              const SizedBox(height: 14),
              if (g.todo.isNotEmpty) ...[
                _todoCard(g, p),
                const SizedBox(height: 14),
              ],
              const SectionLabel('RUTE'),
              const SizedBox(height: 8),
              _routeCard(context, g, p),
              const SizedBox(height: 20),
              SectionLabel('ANGGOTA · ${g.members.length}'),
              const SizedBox(height: 6),
              // Tidak ada tombol tambah: anggota masuk sendiri dengan memasang
              // app dan menempel kode. Lokasi itu milik HP, jadi orang yang
              // didaftarkan dari HP lain tidak akan pernah punya posisi.
              Text(
                g.onCloud
                    ? 'Anggota masuk sendiri dengan menempel kode gabung. '
                        'Bagikan kodenya di bawah.'
                    : 'Grup ini hanya ada di HP ini, jadi anggota lain belum '
                        'bisa masuk.',
                style: arch(400, 12, color: p.tx2, height: 1.5),
              ),
              const SizedBox(height: 10),
              if (g.members.isEmpty)
                Text('Belum ada anggota.', style: arch(400, 13, color: p.tx2))
              else
                for (final m in _sortedMembers(g))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberRow(
                      group: g,
                      member: m,
                      editable: trip.amRc(g),
                      onTap: () => _editMember(context, g, m),
                    ),
                  ),
              if (!trip.amRc(g) && g.members.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Hanya road captain yang bisa mengubah daftar anggota.',
                    style: arch(400, 12, color: p.tx2, height: 1.5),
                  ),
                ),
              // Cekalan wajib bisa dibatalkan. Mengeluarkan anggota otomatis
              // mencekalnya — kalau tidak, dia tinggal menempel kode lagi —
              // dan tanpa bagian ini satu salah tekan jadi permanen.
              if (trip.amRc(g) && g.banned.isNotEmpty) ...[
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
              const SizedBox(height: 20),
              const SectionLabel('BAGIKAN'),
              const SizedBox(height: 6),
              Text(
                'Anggota memasang app ini, lalu tempel kode gabung di menu '
                'Grup → Gabung pakai kode.',
                style: arch(400, 12, color: p.tx2, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Btn(
                      'Kirim via WhatsApp',
                      const Color(0xFF25D366),
                      const Color(0xFF0A2E18),
                      () => launchUrl(
                        Uri.https('wa.me', '/', {'text': _invite(g)}),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Btn('Salin kode', p.surf, p.tx, () async {
                    await Clipboard.setData(ClipboardData(text: g.shareCode));
                    if (context.mounted) _toast(context, 'Kode gabung tersalin');
                  }, border: p.line),
                ],
              ),
              const SizedBox(height: 20),
              if (!active)
                _Btn('Jadikan grup aktif', accent, const Color(0xFF12140F),
                    () => trip.setActive(g.id)),
            ],
          ),
        );
      },
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
      '\nTempel kode ini di app Touring Tracker → Grup → Gabung pakai kode:\n'
      '${g.shareCode}';

  Widget _idCard(BuildContext context, TripGroup g) {
    final p = Pal.of(context);
    return Panel(
      padding: const EdgeInsets.all(16),
      radius: 18,
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
                    Text(fmtWhen(g.when),
                        style: mono(500, 11, color: p.tx2, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surf2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('GROUP ID', style: mono(500, 10, color: p.tx2, spacing: 1.4)),
                const SizedBox(height: 4),
                Text(g.id, style: mono(700, 22, color: p.tx, spacing: 3)),
              ],
            ),
          ),
        ],
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
                      Text('${i + 1}',
                          style: mono(700, 11, color: accent)),
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

  Future<void> _delete(BuildContext context, TripGroup g) async {
    // Anggota biasa tidak menghapus grup orang — dia hanya keluar. Security
    // Rules memang menolaknya, jadi jangan menjanjikan yang lain di UI.
    final rc = trip.amRc(g);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(rc ? 'Hapus "${g.name}"?' : 'Keluar dari "${g.name}"?'),
        content: Text(rc
            ? g.onCloud
                ? 'Grup ini dihapus dari server juga, jadi semua anggota '
                    'kehilangan aksesnya. Tidak bisa dibatalkan.'
                : 'Rute dan daftar anggota grup ini akan hilang dari HP ini.'
            : 'Namamu dihapus dari daftar anggota, dan grupnya hilang dari '
                'HP ini. Kamu bisa gabung lagi pakai kode yang sama.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(rc ? 'Hapus' : 'Keluar'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await trip.deleteGroup(g.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _editMember(
      BuildContext context, TripGroup g, Member m) async {
    final edited = await showMemberDialog(
      context,
      group: g,
      existing: m,
      // Geser-ke-kiri saja tidak cukup: tidak ada petunjuk visualnya, jadi
      // orang menyangka fitur hapus belum ada.
      onDelete: () => trip.removeMember(g, m),
    );
    if (edited != null) {
      trip.updateMember(g, m,
          name: edited.name, plat: edited.plat, role: edited.role);
    }
  }
}

void _toast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

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
    required this.editable,
    required this.onTap,
  });
  final TripGroup group;
  final Member member;

  /// False untuk anggota biasa: server menolak dia mengubah anggota lain.
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final m = member;
    final special = m.role == 'RC' || m.role == 'SWP';
    if (!editable) return _card(context, p, m, special);

    return Dismissible(
      key: ObjectKey(m),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: bad.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: bad),
      ),
      // Hapus di onDismissed, bukan confirmDismiss: kalau daftarnya diubah
      // sebelum animasi selesai, Dismissible menganimasikan baris yang sudah
      // tidak ada di tree.
      onDismissed: (_) => trip.removeMember(group, m),
      child: GestureDetector(
        onTap: onTap,
        child: _card(context, p, m, special),
      ),
    );
  }

  Widget _card(BuildContext context, Pal p, Member m, bool special) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
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
                  Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: arch(700, 14, color: p.tx)),
                  Text(m.plat.isEmpty ? '—' : m.plat,
                      style: mono(500, 11, color: p.tx2, height: 1.4)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: special ? accent.withValues(alpha: .14) : p.surf2,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(roleNames[m.role] ?? m.role,
                  style: mono(700, 10, color: special ? accent : p.tx2)),
            ),
          ],
        ),
      );
}

/// Dialog tambah/ubah anggota. Mengembalikan Member baru (belum dipasang).
///
/// Tanpa TextEditingController: `initialValue` + `onChanged` sudah cukup, dan
/// itu menghilangkan seluruh urusan siklus hidup controller. Membuang
/// controller setelah `showDialog` kembali itu terlalu cepat — dialognya masih
/// dibangun selama animasi keluar.
Future<Member?> showMemberDialog(
  BuildContext context, {
  required TripGroup group,
  required Member existing,
  VoidCallback? onDelete,
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
          if (onDelete != null)
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                onDelete();
              },
              style: TextButton.styleFrom(foregroundColor: bad),
              child: const Text('Hapus'),
            ),
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
  const _Btn(this.label, this.bg, this.fg, this.onTap, {this.border});
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

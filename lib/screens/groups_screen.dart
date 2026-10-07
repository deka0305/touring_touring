import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import 'group_screen.dart';
import 'help_screen.dart';
import 'identity_screen.dart';

/// Tab Grup — dibuat seperti Keluarr: buat/gabung di atas, pilih grup aktif,
/// lalu isi grup aktif langsung di bawahnya.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.onOpenMap});
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = trip.active;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text('Grup touring',
                  style: arch(800, 24, color: p.tx, height: 1.15)),
            ),
            IconButton(
              tooltip: 'Cara pakai',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
              icon: Icon(Icons.help_outline, size: 22, color: p.tx2),
            ),
          ],
        ),
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const IdentityScreen(editing: true))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: p.tx2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kamu: ${trip.myName}'
                    '${trip.myPlat.isEmpty ? "" : " · ${trip.myPlat}"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arch(500, 13, color: p.tx2),
                  ),
                ),
                Text('Ubah', style: arch(700, 13, color: accent)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BigAction(
                icon: Icons.add,
                label: 'Buat grup',
                primary: true,
                onTap: () => _create(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigAction(
                icon: Icons.download_outlined,
                label: 'Gabung pakai kode',
                primary: false,
                onTap: () => joinByCode(context),
              ),
            ),
          ],
        ),
        if (trip.createdGroups.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MyCreatedGroupsScreen())),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: p.tx2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Grup yang pernah kamu buat',
                        style: arch(600, 14, color: p.tx)),
                  ),
                  Text('${trip.createdGroups.length}',
                      style: mono(700, 12, color: p.tx2)),
                  Icon(Icons.chevron_right, color: p.tx2),
                ],
              ),
            ),
          ),
        ],
        if (trip.groups.length > 1) ...[
          const SizedBox(height: 18),
          const SectionLabel('PILIH GRUP AKTIF'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final grp in trip.groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(grp.name),
                      selected: grp.id == g.id,
                      selectedColor: accent,
                      labelStyle: arch(600, 13,
                          color: grp.id == g.id
                              ? const Color(0xFF12140F)
                              : p.tx),
                      onSelected: (_) => trip.setActive(grp.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        GroupBody(group: g),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final nav = Navigator.of(context);
    final created = await nav.push<TripGroup>(
      MaterialPageRoute(builder: (_) => const NewGroupScreen()),
    );
    if (created == null) return;
    // Langsung ke detail grup: dari sini rute disusun.
    await nav
        .push(MaterialPageRoute(builder: (_) => GroupScreen(group: created)));
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: primary ? accent : p.surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary ? accent : p.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: arch(700, 13, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Grup yang pernah dibuat di HP ini — termasuk yang sudah ditinggalkan.
/// Kodenya tersimpan lokal, jadi road captain bisa masuk lagi tanpa diundang.
class MyCreatedGroupsScreen extends StatefulWidget {
  const MyCreatedGroupsScreen({super.key});

  @override
  State<MyCreatedGroupsScreen> createState() => _MyCreatedGroupsScreenState();
}

class _MyCreatedGroupsScreenState extends State<MyCreatedGroupsScreen> {
  String? _busy;

  Future<void> _open(CreatedGroupRef c) async {
    setState(() => _busy = c.gid);
    final err = await trip.rejoinCreated(c);
    if (!mounted) return;
    setState(() => _busy = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = [...trip.createdGroups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Grup yang pernah kamu buat',
            style: arch(700, 17, color: p.tx)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          for (final c in list) ...[
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: arch(700, 15, color: p.tx)),
                        Text('${c.gid} · ${c.club}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mono(500, 11, color: p.tx2, height: 1.5)),
                        Text(
                          c.leftAt == null
                              ? 'Kamu masih di grup ini'
                              : 'Kamu keluar '
                                  '${fmtAgo(DateTime.now().difference(c.leftAt!))}',
                          style: arch(400, 12, color: p.tx2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF12140F)),
                    onPressed: _busy == null ? () => _open(c) : null,
                    child: Text(_busy == c.gid
                        ? '…'
                        : c.leftAt == null
                            ? 'Buka'
                            : 'Masuk lagi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Langkah 1 buat grup: identitas grup + data diri sebagai road captain.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _club = TextEditingController();
  final _me = TextEditingController(text: trip.myName);
  final _plat = TextEditingController(text: trip.myPlat);
  DateTime _when = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    for (final c in [_name, _club, _me, _plat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;
    setState(() => _when = DateTime(
        d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute));
  }

  var _saving = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    trip.setIdentity(name: _me.text, plat: _plat.text);
    final g = await trip.createGroup(
      name: _name.text,
      club: _club.text,
      when: _when,
      you: Member(
        name: _me.text.trim(),
        plat: _plat.text.trim().toUpperCase(),
        role: 'RC',
        hp: trip.myHp,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, g);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Buat grup touring', style: arch(700, 17, color: p.tx)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const SectionLabel('TENTANG TOURING'),
            const SizedBox(height: 10),
            _Field(
              controller: _name,
              label: 'Nama touring',
              hint: 'mis. Bromo Etape 2',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _club,
              label: 'Nama klub / komunitas',
              hint: 'mis. Garuda Rider Club',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickWhen,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: p.surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: p.tx2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jadwal keberangkatan',
                              style: mono(500, 10, color: p.tx2, spacing: 1)),
                          Text(fmtWhen(_when),
                              style: arch(700, 14, color: p.tx)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: p.tx2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('KAMU · ROAD CAPTAIN'),
            const SizedBox(height: 6),
            Text(
              'Pembuat grup otomatis jadi road captain. Peran ini bisa '
              'dipindah ke anggota lain nanti.',
              style: arch(400, 12, color: p.tx2, height: 1.5),
            ),
            const SizedBox(height: 10),
            _Field(controller: _me, label: 'Nama kamu', hint: 'mis. Bagas Pratama'),
            const SizedBox(height: 12),
            _Field(
              controller: _plat,
              label: 'Nomor polisi',
              hint: 'mis. N 1234 AB',
              caps: true,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _saving ? p.surf2 : accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                    _saving ? 'Menyimpan…' : 'Lanjut · atur rute',
                    style: arch(800, 15,
                        color: _saving ? p.tx2 : const Color(0xFF12140F))),
              ),
            ),
            if (!trip.online) ...[
              const SizedBox(height: 12),
              Text(
                trip.cloudError ?? 'Server tidak tersambung',
                textAlign: TextAlign.center,
                style: arch(400, 12, color: warn, height: 1.5),
              ),
              Text(
                'Grup tetap bisa dibuat, tapi hanya tersimpan di HP ini dan '
                'belum bisa dibagikan ke anggota.',
                textAlign: TextAlign.center,
                style: arch(400, 12, color: p.tx2, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.caps = false,
  });
  final TextEditingController controller;
  final String label, hint;
  final bool caps;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return TextFormField(
      controller: controller,
      textCapitalization:
          caps ? TextCapitalization.characters : TextCapitalization.words,
      style: arch(600, 14, color: p.tx),
      validator: (v) =>
          (v == null || v.trim().length < 2) ? '$label belum diisi.' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: arch(500, 13, color: p.tx2),
        hintText: hint,
        hintStyle: arch(400, 13, color: p.tx2),
        filled: true,
        fillColor: p.surf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
      ),
    );
  }
}

/// Gabung grup pakai kode. Fungsi tingkat atas supaya dipakai baik dari tab
/// Grup maupun dari layar awal yang belum punya grup — satu alur, satu tempat
/// memperbaikinya.
Future<void> joinByCode(BuildContext context) async {
  // Diambil sebelum await: layar awal dibongkar begitu grupnya masuk, jadi
  // context-nya tidak lagi sah untuk push.
  final nav = Navigator.of(context);
  final joined = await nav.push<TripGroup>(
    MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
  );
  if (joined == null) return;
  await nav.push(MaterialPageRoute(builder: (_) => GroupScreen(group: joined)));
}

/// Nama + nomor polisi + kode undangan. Perannya dipaksa Rider — Security
/// Rules menolak orang mengangkat dirinya jadi road captain.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _me = TextEditingController(text: trip.myName);
  final _plat = TextEditingController(text: trip.myPlat);
  final _code = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_me, _plat, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Kode pendek `TRG-XXXXXX`, atau kode panjang versi lama yang ditempel.
  TripGroup? _parse(String raw) {
    final pendek = normInviteCode(raw);
    if (pendek != null) {
      return TripGroup(
          gid: pendek, id: '', name: '', club: '', when: DateTime.now());
    }
    try {
      return TripGroup.fromShareCode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    final g = _parse(_code.text);
    if (g == null) {
      setState(() => _error = 'Kode tidak dikenali. Contoh: TRG-7KQ2MX');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    trip.setIdentity(name: _me.text, plat: _plat.text);
    String? err;
    try {
      await trip.importGroup(
        g,
        // Grup lokal versi lama tidak punya server untuk didaftari.
        you: g.onCloud
            ? Member(
                name: _me.text.trim(),
                plat: _plat.text.trim().toUpperCase(),
                role: 'RIDER',
                hp: trip.myHp)
            : null,
      );
    } on StateError catch (e) {
      err = e.message;
    } catch (e) {
      err = Cloud.isPermissionDenied(e)
          ? 'Kamu tidak diizinkan gabung ke grup ini.'
          : 'Gagal gabung. Cek sinyal lalu coba lagi.';
    }
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // importGroup memasang versi dari server, lengkap dengan rute dan anggota.
    final joined = trip.groups.firstWhere(
        (e) => (g.onCloud && e.gid == g.gid) || e.id == g.id,
        orElse: () => trip.active);
    Navigator.pop(context, joined);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Gabung grup', style: arch(700, 17, color: p.tx)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const SectionLabel('KODE UNDANGAN'),
            const SizedBox(height: 6),
            Text('Ketik kode dari road captain, mis. TRG-7KQ2MX.',
                style: arch(400, 12, color: p.tx2, height: 1.5)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: mono(700, 22, color: p.tx, spacing: 3),
              onChanged: (_) => setState(() => _error = null),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Kode belum diisi.' : null,
              decoration: InputDecoration(
                hintText: 'TRG-XXXXXX',
                hintStyle: mono(500, 22, color: p.tx2, spacing: 3),
                errorText: _error,
                errorMaxLines: 3,
                filled: true,
                fillColor: p.surf,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('KAMU · RIDER'),
            const SizedBox(height: 6),
            Text('Namamu terlihat oleh road captain dan anggota lain.',
                style: arch(400, 12, color: p.tx2, height: 1.5)),
            const SizedBox(height: 10),
            _Field(controller: _me, label: 'Nama kamu', hint: 'mis. Rizky Nugroho'),
            const SizedBox(height: 12),
            _Field(
              controller: _plat,
              label: 'Nomor polisi',
              hint: 'mis. N 1234 AB',
              caps: true,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _busy ? p.surf2 : accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_busy ? 'Menggabungkan…' : 'Gabung grup',
                    style: arch(800, 15,
                        color: _busy ? p.tx2 : const Color(0xFF12140F))),
              ),
            ),
            if (!trip.online) ...[
              const SizedBox(height: 12),
              Text(
                trip.cloudError ?? 'Butuh koneksi untuk gabung grup.',
                textAlign: TextAlign.center,
                style: arch(400, 12, color: warn, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

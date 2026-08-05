import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import 'group_screen.dart';
import 'help_screen.dart';

/// Layar D — pusat grup. Bikin grup baru, gabung pakai kode, pilih grup aktif.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.onOpenMap});
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
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
        Text(
          'Grup aktif menentukan rute dan anggota yang tampil di layar lain.',
          style: arch(400, 13, color: p.tx2, height: 1.5),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 22),
        SectionLabel('GRUP SAYA · ${trip.groups.length}'),
        const SizedBox(height: 8),
        for (final g in trip.groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GroupRow(
              group: g,
              active: g.id == trip.activeId,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GroupScreen(group: g)),
              ),
              onActivate: () {
                trip.setActive(g.id);
                onOpenMap();
              },
            ),
          ),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final nav = Navigator.of(context);
    final created = await nav.push<TripGroup>(
      MaterialPageRoute(builder: (_) => const NewGroupScreen()),
    );
    if (created == null) return;
    // Langsung ke detail grup: dari sini rute dan anggota diisi.
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

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.active,
    required this.onTap,
    required this.onActivate,
  });
  final TripGroup group;
  final bool active;
  final VoidCallback onTap, onActivate;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = group;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: p.surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? ok : p.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surf2,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child:
                      Text(initials(g.club), style: mono(800, 12, color: p.tx2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: arch(700, 14, color: p.tx)),
                      Text(
                        '${g.id} · ${g.members.length} rider'
                        '${g.hasRoute ? " · ${km1(g.km)} km" : ""}',
                        style: mono(500, 11, color: p.tx2, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: ok.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('AKTIF', style: mono(700, 10, color: ok)),
                  )
                else
                  TextButton(
                    onPressed: onActivate,
                    child: Text('Pakai', style: arch(700, 12, color: accent)),
                  ),
              ],
            ),
            if (g.todo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: warn),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(g.todo.join(' · '),
                        style: mono(500, 10, color: warn)),
                  ),
                ],
              ),
            ],
          ],
        ),
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
  final _me = TextEditingController();
  final _plat = TextEditingController();
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
    final g = await trip.createGroup(
      name: _name.text,
      club: _club.text,
      when: _when,
      you: Member(
        name: _me.text.trim(),
        plat: _plat.text.trim().toUpperCase(),
        role: 'RC',
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

/// Gabung grup dengan menempel kode. Fungsi tingkat atas supaya dipakai baik
/// dari tab Grup maupun dari layar awal yang belum punya grup — satu alur, satu
/// tempat memperbaikinya.
Future<void> joinByCode(BuildContext context) async {
  // Diambil sebelum await: layar awal dibongkar begitu grupnya masuk, jadi
  // context-nya tidak lagi sah untuk push maupun SnackBar.
  final nav = Navigator.of(context);
  final pesan = ScaffoldMessenger.of(context);
  var code = '';
  String? error;

  final group = await showDialog<TripGroup>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        title: const Text('Gabung grup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempel kode gabung yang dikirim road captain lewat WhatsApp.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              onChanged: (v) => code = v,
              autofocus: true,
              maxLines: 3,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'MnxHUkMtMjAyNnxCcm9tby...',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              try {
                Navigator.pop(c, TripGroup.fromShareCode(code));
              } on FormatException catch (e) {
                setLocal(() => error = e.message);
              }
            },
            child: const Text('Gabung'),
          ),
        ],
      ),
    ),
  );
  if (group == null || !context.mounted) return;

  // Grup di server: tanya identitas, lalu daftarkan diri sungguhan supaya
  // road captain melihatnya. Grup dari kode lama hanya disalin ke HP ini.
  Member? me;
  if (group.onCloud) {
    me = await _askIdentity(context, group);
    if (me == null) return;
  }

  try {
    await trip.importGroup(group, you: me);
  } on StateError catch (e) {
    pesan.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  // Ambil grup yang sudah terpasang: importGroup mengganti objeknya dengan
  // versi dari server, lengkap dengan rute dan daftar anggota.
  final joined = trip.groups.firstWhere(
      (e) => e.gid == group.gid || e.id == group.id,
      orElse: () => group);
  await nav.push(MaterialPageRoute(builder: (_) => GroupScreen(group: joined)));
}

/// Siapa yang bergabung. Perannya dipaksa Rider — Security Rules menolak orang
/// mengangkat dirinya jadi road captain, jadi jangan ditawarkan.
Future<Member?> _askIdentity(BuildContext context, TripGroup g) {
  var name = '';
  var plat = '';
  final form = GlobalKey<FormState>();

  return showDialog<Member>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Gabung "${g.name}"'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${g.club} · ${fmtWhen(g.when)}'),
            const SizedBox(height: 4),
            const Text(
              'Namamu akan terlihat oleh road captain dan anggota lain.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              onChanged: (v) => name = v,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nama kamu', hintText: 'mis. Rizky Nugroho'),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nama belum diisi.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              onChanged: (v) => plat = v,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Nomor polisi', hintText: 'mis. N 1234 AB'),
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
                  name: name.trim(),
                  plat: plat.trim().toUpperCase(),
                  role: 'RIDER',
                ));
          },
          child: const Text('Gabung'),
        ),
      ],
    ),
  );
}

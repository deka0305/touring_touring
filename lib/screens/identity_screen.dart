import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';

/// Nama + nomor polisi, diisi sekali di awal (seperti Keluarr) lalu otomatis
/// terisi di form buat/gabung grup. [editing] = dibuka dari tab Grup untuk
/// diubah, jadi ada tombol kembali dan layar ditutup sesudah simpan.
class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  late final _name = TextEditingController(
      text: trip.myName.isNotEmpty ? trip.myName : trip.guessMe?.name ?? '');
  late final _plat = TextEditingController(
      text: trip.myPlat.isNotEmpty ? trip.myPlat : trip.guessMe?.plat ?? '');
  late final _hp = TextEditingController(text: trip.myHp);

  bool get _ok => _name.text.trim().length >= 2;

  @override
  void dispose() {
    _name.dispose();
    _plat.dispose();
    _hp.dispose();
    super.dispose();
  }

  void _save() {
    if (!_ok) return;
    trip.setIdentity(name: _name.text, plat: _plat.text, hp: _hp.text);
    if (widget.editing) Navigator.pop(context);
  }

  InputDecoration _deco(Pal p, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: arch(400, 15, color: p.tx2),
        filled: true,
        fillColor: p.surf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: widget.editing
          ? AppBar(
              backgroundColor: p.surf,
              surfaceTintColor: Colors.transparent,
              title: Text('Identitas kamu', style: arch(700, 17, color: p.tx)),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          children: [
            if (!widget.editing) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
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
              ),
              const SizedBox(height: 28),
              Text('Halo! Siapa\nnama kamu?',
                  style: arch(800, 28, color: p.tx, height: 1.15)),
              const SizedBox(height: 12),
            ],
            Text(
              'Jadi nama yang dilihat road captain dan anggota grup. Bisa '
              'diubah kapan saja di tab Grup.',
              style: arch(400, 14, color: p.tx2, height: 1.55),
            ),
            const SizedBox(height: 26),
            const SectionLabel('NAMA'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: !widget.editing,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: arch(600, 16, color: p.tx),
              decoration: _deco(p, 'mis. Bagas Pratama'),
            ),
            const SizedBox(height: 20),
            const SectionLabel('NOMOR POLISI · OPSIONAL'),
            const SizedBox(height: 8),
            TextField(
              controller: _plat,
              textCapitalization: TextCapitalization.characters,
              style: arch(600, 16, color: p.tx),
              decoration: _deco(p, 'mis. N 1234 AB'),
            ),
            const SizedBox(height: 20),
            const SectionLabel('NO. HP · OPSIONAL'),
            const SizedBox(height: 8),
            TextField(
              controller: _hp,
              keyboardType: TextInputType.phone,
              style: arch(600, 16, color: p.tx),
              decoration: _deco(p, 'mis. 0812 3456 7890'),
            ),
            const SizedBox(height: 6),
            Text(
              'Hanya terlihat anggota grupmu — dipakai untuk meneleponmu kalau '
              'kamu kirim SOS.',
              style: arch(400, 12, color: p.tx2, height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 15, color: ok),
                const SizedBox(width: 8),
                Text('DISIMPAN DI HP INI',
                    style: mono(600, 10, color: ok, spacing: .8)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _ok ? _save : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ok ? accent : p.surf2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(widget.editing ? 'Simpan' : 'Lanjut',
                    style: arch(800, 15,
                        color: _ok ? const Color(0xFF12140F) : p.tx2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../share_card.dart';
import '../theme.dart';

/// Pratinjau kartu bagikan. Ditampilkan sebagaimana akan terkirim — kartunya
/// dirender dari widget yang sama yang nanti diambil jadi PNG, jadi tidak ada
/// kejutan antara yang dilihat dan yang terkirim.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();
  File? _photo;
  bool _busy = false;

  /// Pilihan pengguna: gambar jejak GPS, atau rute rencana dari maps.
  ShareSource? _pilihan;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Kartu diekspor 1080 px lebar; foto lebih besar hanya memperlambat
        // dan memakan memori tanpa terlihat bedanya.
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      setState(() => _photo = File(picked.path));
    } catch (e) {
      if (mounted) _toast('Tidak bisa membuka gambar: $e');
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final g = trip.active;
      await shareCardImage(
        _cardKey,
        text: '${g.name} · ${g.club}',
      );
    } catch (e) {
      if (mounted) _toast('Gagal membagikan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = trip.track;
    final g = trip.active;
    final adaJejak = !t.isEmpty;

    // Default: jejak kalau ada, kalau tidak rute rencana. Pilihan pengguna
    // menang, kecuali jejaknya memang belum ada.
    final sumber = !adaJejak
        ? ShareSource.rute
        : (_pilihan ?? ShareSource.jejak);
    final stats = ShareStats.of(trip, source: sumber);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Bagikan', style: arch(700, 17, color: p.tx)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          // Pilihan garis selalu ditampilkan, walau salah satunya belum
          // tersedia — kalau disembunyikan, orang tidak tahu pilihannya ada.
          const SectionLabel('GARIS DI KARTU'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Pilih(
                  label: 'Jejak GPS',
                  note: adaJejak
                      ? '${km1(t.km)} km · ${t.points.length} titik'
                      : 'belum ada rekaman',
                  on: sumber == ShareSource.jejak,
                  aktif: adaJejak,
                  onTap: () => setState(() => _pilihan = ShareSource.jejak),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pilih(
                  label: 'Rute rencana',
                  note: g.hasRoute
                      ? '${km1(g.km)} km · ${g.mode.label}'
                      : 'belum ada rute',
                  on: sumber == ShareSource.rute,
                  aktif: g.hasRoute,
                  onTap: () => setState(() => _pilihan = ShareSource.rute),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!adaJejak)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warn.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: warn),
                ),
                child: Text(
                  'Belum ada jejak GPS yang terekam, jadi yang bisa digambar '
                  'baru rute rencana. Tekan MULAI di tab Peta saat berangkat '
                  'supaya jejak aslinya tercatat.',
                  style: arch(400, 12, color: p.tx2, height: 1.5),
                ),
              ),
            ),

          // RepaintBoundary inilah yang diambil jadi PNG.
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: RepaintBoundary(
              key: _cardKey,
              child: ShareCard(stats: stats, photo: _photo),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _Btn(
                  icon: Icons.photo_library_outlined,
                  label: _photo == null ? 'Pilih foto' : 'Ganti foto',
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Btn(
                  icon: Icons.photo_camera_outlined,
                  label: 'Kamera',
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              if (_photo != null) ...[
                const SizedBox(width: 8),
                _Btn(
                  icon: Icons.close,
                  label: 'Hapus',
                  onTap: () => setState(() => _photo = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _busy ? null : _share,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _busy ? p.surf2 : accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _busy ? 'Menyiapkan gambar…' : 'Bagikan gambar',
                style: arch(800, 15,
                    color: _busy ? p.tx2 : const Color(0xFF12140F)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Terkirim sebagai gambar, jadi bisa ke WhatsApp, Instagram, '
            'Telegram, atau disimpan ke galeri — pilih di lembar bagikan.',
            textAlign: TextAlign.center,
            style: arch(400, 11, color: p.tx2, height: 1.5),
          ),
          if (!trip.track.isEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('JEJAK TEREKAM'),
            const SizedBox(height: 6),
            Text(
              '${trip.track.points.length} titik · ${km1(trip.track.km)} km · '
              'mulai ${fmtWhen(trip.track.startedAt!)}',
              style: mono(500, 11, color: p.tx2, height: 1.5),
            ),
            const SizedBox(height: 10),
            _Btn(
              icon: Icons.restart_alt,
              label: 'Hapus jejak & mulai ulang',
              onTap: () => _confirmReset(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus jejak perjalanan?'),
        content: const Text(
            'Rekaman rute yang sudah dilalui akan hilang dan tidak bisa '
            'dikembalikan. Rute rencana grup tidak terpengaruh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true) {
      trip.resetTrack();
      if (mounted) setState(() {});
    }
  }
}

/// Kartu pilihan dua arah, dipakai memilih sumber garis kartu.
class _Pilih extends StatelessWidget {
  const _Pilih({
    required this.label,
    required this.note,
    required this.on,
    required this.aktif,
    required this.onTap,
  });
  final String label, note;
  final bool on;

  /// False kalau sumbernya belum tersedia — tetap ditampilkan supaya pilihannya
  /// terlihat ada, tapi tidak bisa dipilih.
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = !aktif
        ? p.tx2
        : on
            ? accent
            : p.tx;
    return Opacity(
      opacity: aktif ? 1 : .5,
      child: GestureDetector(
        onTap: aktif ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: .14) : p.surf,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: on ? accent : p.line, width: on ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 15, color: on ? accent : p.tx2),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: arch(700, 13, color: fg)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(500, 10, color: p.tx2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: p.surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: p.tx),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: arch(700, 12, color: p.tx)),
            ),
          ],
        ),
      ),
    );
  }
}

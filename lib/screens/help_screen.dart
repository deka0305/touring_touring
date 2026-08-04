import 'package:flutter/material.dart';

import '../theme.dart';

/// Langkah singkat di dalam app. Versi lengkapnya ada di CARA_PAKAI.md.
const _steps = <(String, String, List<String>)>[
  (
    'Buat grup touring',
    'Grup → Buat grup',
    [
      'Isi nama touring, klub, dan jadwal keberangkatan.',
      'Isi nama dan nopol kamu — pembuat grup otomatis jadi road captain.',
      'App membuat Group ID acak, mis. GRC-2026. ID ini yang dipakai anggota.',
    ],
  ),
  (
    'Susun rute',
    'Detail grup → Susun rute sekarang',
    [
      'Tekan "Cari & tambah tujuan" lalu ketik nama tempat, mis. "Tumpang Malang".',
      'Atau tahan lama di peta untuk menaruh titik di lokasi bebas.',
      'Geser ikon garis tiga untuk mengubah urutan; titik pertama jadi MULAI, terakhir jadi FINISH.',
      'Rute otomatis mengikuti jalan raya. Jarak dan estimasi waktu muncul di bawah.',
      'Tekan "Simpan rute".',
    ],
  ),
  (
    'Tambah anggota',
    'Detail grup → Anggota → Tambah',
    [
      'Isi nama, nopol, dan peran: Road Captain, Sweeper, Marshal, atau Rider.',
      'Road captain dan sweeper hanya boleh satu; yang lama otomatis jadi Rider.',
      'Geser baris anggota ke kiri untuk menghapus.',
    ],
  ),
  (
    'Bagikan ke anggota',
    'Detail grup → Bagikan',
    [
      'Tekan "Kirim via WhatsApp" — pesan undangan berisi jadwal, rute, dan kode gabung.',
      'Anggota memasang app ini, buka Grup → Gabung pakai kode, lalu tempel kodenya.',
      'Kode hanya memuat daftar titik; app penerima menyusun ulang rutenya sendiri.',
    ],
  ),
  (
    'Pilih grup aktif',
    'Grup → tombol "Pakai"',
    [
      'Grup aktif menentukan rute dan anggota yang tampil di tab Peta, Tim, dan Rekap.',
      'Tanda AKTIF hijau menunjukkan grup yang sedang dipakai.',
    ],
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.surf,
        surfaceTintColor: Colors.transparent,
        title: Text('Cara pakai', style: arch(700, 17, color: p.tx)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: warn.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: warn),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yang belum bisa', style: arch(700, 14, color: warn)),
                const SizedBox(height: 6),
                Text(
                  'Pelacakan lokasi live antar-HP belum ada — itu butuh server. '
                  'Sekarang app ini merencanakan touring: grup, rute, anggota, '
                  'dan berbagi. Tab Peta hanya bergerak untuk grup contoh '
                  '"Bromo Etape 2 (contoh)".',
                  style: arch(400, 13, color: p.tx2, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < _steps.length; i++) ...[
            _Step(index: i + 1, step: _steps[i]),
            const SizedBox(height: 20),
          ],
          const SectionLabel('DATA KAMU'),
          const SizedBox(height: 8),
          Text(
            'Semua grup, rute, dan anggota disimpan di HP ini saja — tidak '
            'dikirim ke mana pun. Menghapus app berarti menghapus datanya, '
            'jadi simpan kode gabung tiap grup kalau perlu.\n\n'
            'Pencarian tempat memakai Nominatim OpenStreetMap dan penyusunan '
            'rute memakai OSRM. Keduanya butuh internet saat menyusun rute; '
            'setelah tersimpan, rute bisa dilihat offline.',
            style: arch(400, 13, color: p.tx2, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.step});
  final int index;
  final (String, String, List<String>) step;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: accent, shape: BoxShape.circle),
              child: Text('$index',
                  style: mono(800, 12, color: const Color(0xFF12140F))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(step.$1, style: arch(800, 17, color: p.tx)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(step.$2, style: mono(600, 11, color: accent)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in step.$3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•', style: arch(700, 13, color: p.tx2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line,
                            style: arch(400, 13, color: p.tx2, height: 1.5)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

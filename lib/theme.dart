import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data.dart';

const accent = Color(kAcc);
const ok = Color(kOk);
const warn = Color(kWarn);
const grey = Color(kGrey);
const bad = Color(kBad);

/// Palet dari desain, dipilih berdasarkan brightness tema aktif.
class Pal {
  final Color bg, surf, surf2, line, tx, tx2, glass;
  const Pal({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.line,
    required this.tx,
    required this.tx2,
    required this.glass,
  });

  static const _dark = Pal(
    bg: Color(0xFF0B0D10),
    surf: Color(0xFF15181D),
    surf2: Color(0xFF1D2127),
    line: Color(0xFF262B33),
    tx: Color(0xFFF1F3F6),
    tx2: Color(0xFF8B95A3),
    glass: Color(0xC70B0D10),
  );

  static const _light = Pal(
    bg: Color(0xFFF6F4F0),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFEEEBE5),
    line: Color(0xFFDDD8CE),
    tx: Color(0xFF15181D),
    tx2: Color(0xFF6B7280),
    glass: Color(0xDBFFFFFF),
  );

  static Pal of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? _dark : _light;
}

/// `mono(700, 13)` ≈ `font: 700 13px/1 'JetBrains Mono'` di desain.
TextStyle mono(int w, double size,
        {Color? color, double? spacing, double height = 1}) =>
    GoogleFonts.jetBrainsMono(
      fontWeight: FontWeight.values[(w ~/ 100) - 1],
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      height: height,
    );

/// `arch(800, 34)` ≈ `font: 800 34px Archivo`.
TextStyle arch(int w, double size,
        {Color? color, double height = 1.2, double? spacing}) =>
    GoogleFonts.archivo(
      fontWeight: FontWeight.values[(w ~/ 100) - 1],
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

ThemeData buildTheme(bool dark) {
  final p = dark ? Pal._dark : Pal._light;
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: p.bg,
    ),
    textTheme: GoogleFonts.archivoTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Label kecil huruf kapital berjarak, dipakai di seluruh layar.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: mono(600, 11,
            color: color ?? Pal.of(context).tx2, spacing: 1.3),
      );
}

/// Kartu dasar: surface + border 1px, sudut membulat.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.color,
    this.border,
    this.borderStyle,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? border;
  final BorderStyle? borderStyle;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surf,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? p.line),
      ),
      child: child,
    );
  }
}

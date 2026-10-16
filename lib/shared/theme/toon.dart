import 'package:flutter/material.dart';

import '../state/providers.dart';
import 'toon_icons.dart';

class Toon {
  const Toon._();

  static const mint = Color(0xFFDDE8DF);
  static const mintDeep = Color(0xFFC6D8CB);
  static const paper = Color(0xFFFFFDF7);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF26282E);
  static const inkSoft = Color(0xFF666B78);
  static const sun = Color(0xFFF8CB46);
  static const pink = Color(0xFFF7A1C2);
  static const butter = Color(0xFFF7D26A);
  static const sky = Color(0xFF93CFF3);
  static const coral = Color(0xFFF59A78);
  static const lilac = Color(0xFFC3A4EE);
  static const steel = Color(0xFFCDD2D9);
  static const leaf = Color(0xFFB4DE8A);
  static const lime = Color(0xFFF0F8DC);
  static const cream = Color(0xFFFFF1C7);
  static const red = Color(0xFFF26D6D);
  static const navy = Color(0xFF34406A);
  static const orange = Color(0xFFF7A33B);
  static const green = Color(0xFF55B57A);

  static const radius = 18.0;
  static const border = BorderSide(color: ink, width: 2.2);
  static const lift = [BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 0)];

  static const rainbow = LinearGradient(colors: [pink, butter, leaf, sky, lilac]);
}

extension MenuLook on AppMenu {
  Color get color => switch (this) {
    AppMenu.schedules => Toon.pink,
    AppMenu.balance => Toon.butter,
    AppMenu.weather => Toon.sky,
    AppMenu.exchange => Toon.coral,
    AppMenu.news => Toon.lilac,
    AppMenu.calculator => Toon.steel,
  };

  ToonGlyph get glyph => switch (this) {
    AppMenu.schedules => ToonGlyph.calendar,
    AppMenu.balance => ToonGlyph.wallet,
    AppMenu.weather => ToonGlyph.weather,
    AppMenu.exchange => ToonGlyph.exchange,
    AppMenu.news => ToonGlyph.news,
    AppMenu.calculator => ToonGlyph.calculator,
  };
}

ThemeData toonTheme(TextTheme textTheme) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: Toon.border);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Toon.sky,
      primary: Toon.ink,
      onPrimary: Toon.white,
      secondary: Toon.orange,
      surface: Toon.paper,
      error: Toon.red,
    ),
    scaffoldBackgroundColor: Toon.mint,
    dividerColor: Toon.ink.withValues(alpha: 0.15),
  );
  return base.copyWith(
    textTheme: textTheme.apply(bodyColor: Toon.ink, displayColor: Toon.ink),
    iconTheme: const IconThemeData(color: Toon.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Toon.ink,
        foregroundColor: Toon.white,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Toon.ink,
        backgroundColor: Toon.white,
        side: Toon.border,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Toon.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Toon.white,
      isDense: true,
      hintStyle: TextStyle(color: Toon.ink.withValues(alpha: 0.42), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: Toon.border),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: Toon.border),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Toon.navy, width: 2.6),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(Toon.border),
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        foregroundColor: const WidgetStatePropertyAll(Toon.ink),
        backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Toon.butter : Toon.white),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Toon.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: Toon.border),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Toon.ink,
      contentTextStyle: const TextStyle(color: Toon.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Toon.white),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Toon.green : Toon.steel),
      trackOutlineColor: const WidgetStatePropertyAll(Toon.ink),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Toon.orange, linearTrackColor: Toon.cream),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Toon.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Toon.white, fontSize: 12, fontWeight: FontWeight.w700),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Toon.ink, textColor: Toon.ink),
  );
}

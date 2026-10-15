import 'package:flutter/material.dart';

import '../state/providers.dart';
import 'ink_icons.dart';

ThemeData inkTheme(TextTheme textTheme) {
  const inkSide = BorderSide(color: InkPalette.ink, width: 2);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: inkSide);
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: InkPalette.teal,
      primary: InkPalette.ink,
      onPrimary: InkPalette.mustard,
      secondary: InkPalette.coral,
      surface: InkPalette.panel,
    ),
    scaffoldBackgroundColor: InkPalette.paper,
    useMaterial3: true,
    dividerColor: InkPalette.ink,
    cardTheme: CardThemeData(
      color: InkPalette.cream,
      elevation: 0,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: InkPalette.ink, width: 2),
      ),
    ),
  );
  return base.copyWith(
    textTheme: textTheme.apply(bodyColor: InkPalette.ink, displayColor: InkPalette.ink),
    iconTheme: const IconThemeData(color: InkPalette.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: InkPalette.ink,
        foregroundColor: InkPalette.mustard,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: InkPalette.ink,
        side: inkSide,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: InkPalette.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: InkPalette.cream,
      selectedColor: InkPalette.mustard,
      side: const BorderSide(color: InkPalette.ink, width: 1.8),
      labelStyle: const TextStyle(color: InkPalette.ink, fontWeight: FontWeight.w800, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: InkPalette.cream,
      hintStyle: TextStyle(color: InkPalette.ink.withValues(alpha: 0.45)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: inkSide),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: inkSide),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: InkPalette.ink, width: 2.6)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(inkSide),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        foregroundColor: const WidgetStatePropertyAll(InkPalette.ink),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return InkPalette.mustard;
          }
          return InkPalette.cream;
        }),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: InkPalette.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: InkPalette.ink, width: 2.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: InkPalette.ink,
      contentTextStyle: const TextStyle(color: InkPalette.mustard, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    checkboxTheme: CheckboxThemeData(
      side: inkSide,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return InkPalette.mustard;
        }
        return InkPalette.cream;
      }),
      checkColor: const WidgetStatePropertyAll(InkPalette.ink),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: InkPalette.coral),
    listTileTheme: const ListTileThemeData(iconColor: InkPalette.ink, textColor: InkPalette.ink),
    dividerTheme: const DividerThemeData(color: InkPalette.ink, thickness: 1.2, space: 1),
  );
}

class DotPaper extends StatelessWidget {
  const DotPaper({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _DotPainter(), child: SizedBox.expand());
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = InkPalette.ink.withValues(alpha: 0.08);
    const step = 18.0;
    for (var y = 8.0; y < size.height; y += step) {
      for (var x = 8.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ComicFrame extends StatelessWidget {
  const ComicFrame({
    super.key,
    required this.child,
    required this.caption,
    this.accent = InkPalette.mustard,
    this.glyph,
  });

  final Widget child;
  final String caption;
  final Color accent;
  final InkGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: InkPalette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: InkPalette.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: InkPalette.ink, offset: Offset(5, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: accent,
              child: SizedBox(
                height: 38,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const _RegistrationMark(),
                      const SizedBox(width: 8),
                      if (glyph != null) ...[
                        InkIcon(glyph!, size: 18),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: InkPalette.ink),
                        ),
                      ),
                      const _RegistrationMark(),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 2.5, color: InkPalette.ink),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _RegistrationMark extends StatelessWidget {
  const _RegistrationMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: InkPalette.ink, width: 1.6),
      ),
      child: Center(
        child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: InkPalette.ink, shape: BoxShape.circle)),
      ),
    );
  }
}

class SpeechCard extends StatelessWidget {
  const SpeechCard({super.key, required this.color, required this.alignLeft, required this.child});

  final Color color;
  final bool alignLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: alignLeft ? const Radius.circular(4) : null,
            bottomRight: alignLeft ? null : const Radius.circular(4),
          ),
          border: Border.all(color: InkPalette.ink, width: 2),
          boxShadow: const [BoxShadow(color: InkPalette.ink, offset: Offset(3, 3))],
        ),
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }
}

class ComicNav extends StatelessWidget {
  const ComicNav({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelect,
    required this.onAccount,
    this.onLogout,
    this.axis = Axis.vertical,
    this.showLabels = true,
  });

  final AppMenu selected;
  final Map<AppMenu, String> labels;
  final ValueChanged<AppMenu> onSelect;
  final VoidCallback onAccount;
  final VoidCallback? onLogout;
  final Axis axis;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in AppMenu.values)
        _ComicNavButton(
          glyph: inkGlyphFor(item),
          label: labels[item] ?? '',
          selected: item == selected,
          showLabel: showLabels,
          onPressed: () => onSelect(item),
        ),
    ];
    final account = _ComicNavButton(
      glyph: InkGlyph.badge,
      label: '',
      selected: false,
      showLabel: false,
      onPressed: onAccount,
    );
    if (axis == Axis.horizontal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            for (final item in items) Expanded(child: item),
            Expanded(child: account),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: item),
              ],
            ),
          ),
          account,
          if (onLogout != null) ...[
            const SizedBox(height: 8),
            _ComicNavButton(
              glyph: InkGlyph.exit,
              label: '',
              selected: false,
              showLabel: false,
              onPressed: onLogout!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComicNavButton extends StatelessWidget {
  const _ComicNavButton({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onPressed,
  });

  final InkGlyph glyph;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      decoration: BoxDecoration(
        color: selected ? InkPalette.mustard : InkPalette.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InkPalette.ink, width: selected ? 2.4 : 1.8),
        boxShadow: selected ? const [BoxShadow(color: InkPalette.ink, offset: Offset(3, 3))] : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: showLabel ? 8 : 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkIcon(glyph, size: 22),
                if (showLabel && label.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, height: 1.1, fontWeight: FontWeight.w800, color: InkPalette.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

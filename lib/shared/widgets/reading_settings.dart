import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_text.dart';
import '../state/providers.dart';
import '../theme/toon.dart';
import '../theme/toon_widgets.dart';

/// Applies the chosen text size and line spacing to everything below it.
class ReadingScale extends ConsumerWidget {
  const ReadingScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final lineHeight = lineHeightFor(ref.watch(lineLevelProvider));
    return MediaQuery(
      data: media
          .copyWith(textScaler: TextScaler.linear(media.textScaler.scale(10) / 10 * fontScaleFor(ref.watch(fontLevelProvider))))
          .applyTextStyleOverrides(
            lineHeightScaleFactorOverride: lineHeight ?? media.lineHeightScaleFactorOverride,
            letterSpacingOverride: media.letterSpacingOverride,
            wordSpacingOverride: media.wordSpacingOverride,
            paragraphSpacingOverride: media.paragraphSpacingOverride,
          ),
      child: child,
    );
  }
}

enum _Setting { font, line }

/// Text size and line spacing buttons; each opens a five-level bar that changes every screen at once.
class ReadingSettings extends ConsumerStatefulWidget {
  const ReadingSettings({super.key});

  @override
  ConsumerState<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends ConsumerState<ReadingSettings> {
  _Setting? _open;

  void _toggle(_Setting setting) => setState(() => _open = _open == setting ? null : setting);

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final fontLevel = ref.watch(fontLevelProvider);
    final lineLevel = ref.watch(lineLevelProvider);
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ToonButton(
              label: '${text.fontSize} · ${text.levelOf(fontLevel)}',
              compact: true,
              color: open == _Setting.font ? Toon.sun : Toon.white,
              onPressed: () => _toggle(_Setting.font),
            ),
            ToonButton(
              label: '${text.lineSpacing} · ${text.levelOf(lineLevel)}',
              compact: true,
              color: open == _Setting.line ? Toon.sun : Toon.white,
              onPressed: () => _toggle(_Setting.line),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (open) {
            null => const SizedBox(width: double.infinity),
            _Setting.font => _LevelBar(
              key: const ValueKey(_Setting.font),
              title: text.fontSize,
              level: fontLevel,
              fallback: ref.read(fontLevelProvider.notifier).fallback,
              lowLabel: text.smaller,
              highLabel: text.larger,
              text: text,
              onChanged: ref.read(fontLevelProvider.notifier).set,
            ),
            _Setting.line => _LevelBar(
              key: const ValueKey(_Setting.line),
              title: text.lineSpacing,
              level: lineLevel,
              fallback: ref.read(lineLevelProvider.notifier).fallback,
              lowLabel: text.narrower,
              highLabel: text.wider,
              text: text,
              onChanged: ref.read(lineLevelProvider.notifier).set,
            ),
          },
        ),
      ],
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    super.key,
    required this.title,
    required this.level,
    required this.fallback,
    required this.lowLabel,
    required this.highLabel,
    required this.text,
    required this.onChanged,
  });

  final String title;
  final int level;
  final int fallback;
  final String lowLabel;
  final String highLabel;
  final AppText text;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Toon.inkSoft);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Toon.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Toon.ink, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title · ${text.levelOf(level)}${level == fallback ? ' (${text.defaultLevel})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              if (level != fallback) ToonButton(label: text.defaultLevel, compact: true, onPressed: () => onChanged(fallback)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: Toon.sun,
              inactiveTrackColor: Toon.white,
              thumbColor: Toon.ink,
              overlayColor: Toon.sun.withValues(alpha: 0.25),
              activeTickMarkColor: Toon.ink,
              inactiveTickMarkColor: Toon.inkSoft,
              valueIndicatorColor: Toon.ink,
              showValueIndicator: ShowValueIndicator.onDrag,
            ),
            child: Slider(
              min: LevelController.min.toDouble(),
              max: LevelController.max.toDouble(),
              divisions: LevelController.max - LevelController.min,
              value: level.toDouble(),
              label: text.levelOf(level),
              semanticFormatterCallback: (value) => text.levelOf(value.round()),
              onChanged: (value) {
                if (value.round() != level) {
                  onChanged(value.round());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (var step = LevelController.min; step <= LevelController.max; step++) ...[
                  if (step > LevelController.min) const Spacer(),
                  Text(
                    '$step',
                    style: small.copyWith(
                      color: step == level ? Toon.ink : Toon.inkSoft,
                      fontWeight: step == level ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(lowLabel, style: small),
              const Spacer(),
              Text(highLabel, style: small),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Toon.white, borderRadius: BorderRadius.circular(10)),
            child: Text(text.readingPreview, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_text.dart';
import '../state/providers.dart';
import '../theme/toon.dart';
import '../theme/toon_icons.dart';
import '../theme/toon_widgets.dart';

const _languageOptions = [('ko', '한국어'), ('en', 'English'), ('ja', '日本語')];

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (code, label) in _languageOptions)
          ToonButton(
            label: label,
            compact: true,
            color: code == current ? Toon.sun : Toon.white,
            onPressed: code == current ? () {} : () => ref.read(localeProvider.notifier).setCode(code),
          ),
      ],
    );
  }
}

/// Header button showing the current language; each tap moves to the next one (ko, en, ja, then ko again).
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.showGlyph = true});

  final bool showGlyph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final current = ref.watch(localeProvider).languageCode;
    final index = _languageOptions.indexWhere((option) => option.$1 == current);
    final next = _languageOptions[(index + 1) % _languageOptions.length].$1;
    return ToonButton(
      label: _languageOptions[index < 0 ? 0 : index].$2,
      glyph: showGlyph ? ToonGlyph.globe : null,
      compact: true,
      color: Toon.white,
      tooltip: text.language,
      onPressed: () => ref.read(localeProvider.notifier).setCode(next),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/toon.dart';
import '../theme/toon_widgets.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  static const _options = [('ko', '한국어'), ('en', 'English'), ('ja', '日本語')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (code, label) in _options)
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

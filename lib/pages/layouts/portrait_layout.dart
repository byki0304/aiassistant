import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_prompt/ai_panel.dart';
import '../../shared/app_text.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_widgets.dart';
import '../app_shell.dart';

/// Phone held upright: header, chat on top, menu below, sticker tab bar at the thumb.
class PortraitLayout extends ConsumerWidget {
  const PortraitLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final menu = ref.watch(menuProvider);
    final account = ref.watch(accountOpenProvider);
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final open = paneOpen(ref);
    final narrow = MediaQuery.sizeOf(context).width < 370;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
          child: Row(
            children: [
              Tooltip(
                excludeFromSemantics: true,
                message: text.homeChat,
                child: Pressable(label: text.homeChat, onTap: () => goHome(ref), child: const Wordmark(size: 19)),
              ),
              const Spacer(),
              const AccountButton(size: 36),
              const SizedBox(width: 8),
              LogoutButton(iconOnly: narrow),
            ],
          ),
        ),
        Expanded(
          flex: 42,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: ToonCard(color: Toon.paper, padding: EdgeInsets.zero, child: const ChatPane(compact: true)),
          ),
        ),
        if (!keyboardUp && open)
          Expanded(
            flex: 58,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ToonCard(padding: EdgeInsets.zero, child: const MenuPane()),
            ),
          ),
        if (!keyboardUp)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
            decoration: BoxDecoration(
              color: Toon.sun,
              borderRadius: BorderRadius.circular(20),
              border: const Border.fromBorderSide(Toon.border),
              boxShadow: Toon.lift,
            ),
            child: Row(
              children: [
                for (final item in AppMenu.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Tooltip(
                        excludeFromSemantics: true,
                        message: text.menuName(item.name),
                        child: MenuTile(
                          glyph: item.glyph,
                          color: item.color,
                          label: text.menuName(item.name),
                          selected: !account && item == menu,
                          showLabel: false,
                          iconSize: 26,
                          onTap: () => selectMenu(ref, item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

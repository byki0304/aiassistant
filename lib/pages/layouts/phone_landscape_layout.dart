import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_prompt/ai_panel.dart';
import '../../shared/app_text.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/language_picker.dart';
import '../app_shell.dart';

/// Phone held sideways: a slim sticker rail on the left, a thin strip with log out at the top right,
/// and the conversation alone until a menu opens beside it.
class PhoneLandscapeLayout extends ConsumerWidget {
  const PhoneLandscapeLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final menu = ref.watch(menuProvider);
    final account = ref.watch(accountOpenProvider);
    final open = paneOpen(ref);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Toon.sun,
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(Toon.border),
              boxShadow: Toon.lift,
            ),
            child: Column(
              children: [
                Tooltip(
                  excludeFromSemantics: true,
                  message: text.homeChat,
                  child: Pressable(label: text.homeChat, onTap: () => goHome(ref), child: const RobotArt(RobotPose.logo, height: 26)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
                      children: [
                        for (final item in AppMenu.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Tooltip(
                              excludeFromSemantics: true,
                              message: text.menuName(item.name),
                              child: MenuTile(
                                glyph: item.glyph,
                                color: item.color,
                                label: text.menuName(item.name),
                                selected: !account && item == menu,
                                showLabel: false,
                                iconSize: 24,
                                onTap: () => selectMenu(ref, item),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const AccountButton(size: 36),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 0, 0, 6),
                  child: Row(children: [Wordmark(size: 16), Spacer(), LanguageButton(), SizedBox(width: 8), LogoutButton()]),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 47,
                        child: ToonCard(color: Toon.paper, padding: EdgeInsets.zero, child: const ChatPane(compact: true)),
                      ),
                      if (open) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 53,
                          child: ToonCard(padding: EdgeInsets.zero, child: const MenuPane()),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

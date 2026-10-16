import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_prompt/ai_panel.dart';
import '../../shared/app_text.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_widgets.dart';
import '../app_shell.dart';

/// Desktop and tablet landscape: one big board with the menu sticker bar on top.
/// Home is the conversation alone; opening a menu splits it into chat (left) and menu (right).
class DesktopLayout extends ConsumerWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final menu = ref.watch(menuProvider);
    final account = ref.watch(accountOpenProvider);
    final open = paneOpen(ref);
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Align(alignment: Alignment.centerLeft, child: Wordmark(size: 22)),
          ),
          Expanded(
            child: ToonCard(
              color: Toon.paper,
              padding: EdgeInsets.zero,
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: wide ? 128 : 118,
                    padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
                    decoration: const BoxDecoration(
                      color: Toon.sun,
                      border: Border(bottom: Toon.border),
                    ),
                    child: Row(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tooltip(
                              excludeFromSemantics: true,
                              message: text.homeChat,
                              child: Pressable(
                                label: text.homeChat,
                                onTap: () => goHome(ref),
                                child: RobotArt(RobotPose.wave, height: wide ? 70 : 62, bob: true),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const LogoutButton(),
                          ],
                        ),
                        const SizedBox(width: 10),
                        for (final item in AppMenu.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 14),
                              child: MenuTile(
                                glyph: item.glyph,
                                color: item.color,
                                label: text.menuName(item.name),
                                selected: !account && item == menu,
                                iconSize: wide ? 38 : 32,
                                onTap: () => selectMenu(ref, item),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        AccountButton(size: wide ? 54 : 46),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 46,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: open ? double.infinity : 980),
                              child: const ChatPane(),
                            ),
                          ),
                        ),
                        if (open) ...[
                          const DashedDivider(),
                          Expanded(
                            flex: 54,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
                              child: ToonCard(padding: EdgeInsets.zero, child: const MenuPane()),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

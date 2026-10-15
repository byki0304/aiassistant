import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account_page.dart';
import '../features/ai_prompt/ai_panel.dart';
import '../features/balance/balance_screen.dart';
import '../features/calculator/calculator_widget.dart';
import '../features/exchange_rate/exchange_screen.dart';
import '../features/news/news_screen.dart';
import '../features/schedules/schedules_screen.dart';
import '../features/weather/weather_screen.dart';
import '../shared/app_text.dart';
import '../shared/state/providers.dart';
import '../shared/theme/ink_icons.dart';
import '../shared/theme/ink_theme.dart';

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final menu = ref.watch(menuProvider);
    final account = ref.watch(accountOpenProvider);
    final width = MediaQuery.sizeOf(context).width;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final body = account ? const AccountPage() : _menuBody(menu);
    final labels = {for (final item in AppMenu.values) item: text.menuName(item.name)};

    void select(AppMenu item) {
      ref.read(accountOpenProvider.notifier).close();
      ref.read(menuProvider.notifier).select(item);
    }

    void selectIndex(int index) => select(AppMenu.values[index]);

    final chat = ComicFrame(
      caption: text.appTitle,
      accent: InkPalette.sky,
      glyph: InkGlyph.send,
      child: const AiPanel(),
    );
    final menuPane = ComicFrame(
      caption: account ? text.myPage : text.menuName(menu.name),
      accent: account ? InkPalette.blush : InkPalette.mustard,
      glyph: account ? InkGlyph.badge : inkGlyphFor(menu),
      child: body,
    );

    final Widget shell;
    if (width >= 1024) {
      shell = Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: ComicNav(
                selected: menu,
                labels: labels,
                showLabels: true,
                onSelect: select,
                onAccount: () => ref.read(accountOpenProvider.notifier).open(),
                onLogout: () => FirebaseAuth.instance.signOut(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(flex: 42, child: chat),
            const SizedBox(width: 14),
            Expanded(flex: 58, child: menuPane),
          ],
        ),
      );
    } else if (landscape) {
      shell = Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: ComicNav(
                selected: menu,
                labels: labels,
                showLabels: false,
                onSelect: select,
                onAccount: () => ref.read(accountOpenProvider.notifier).open(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 45, child: chat),
            const SizedBox(width: 8),
            Expanded(flex: 55, child: menuPane),
          ],
        ),
      );
    } else {
      shell = Column(
        children: [
          const SizedBox(height: 8),
          Expanded(flex: 4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: chat)),
          const SizedBox(height: 8),
          Expanded(flex: 6, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: menuPane)),
          ComicNav(
            selected: menu,
            labels: labels,
            showLabels: false,
            axis: Axis.horizontal,
            onSelect: (item) => selectIndex(item.index),
            onAccount: () => ref.read(accountOpenProvider.notifier).open(),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DotPaper(),
            shell,
            const FloatingCalculator(),
          ],
        ),
      ),
    );
  }

  Widget _menuBody(AppMenu menu) {
    return switch (menu) {
      AppMenu.schedules => const SchedulesScreen(),
      AppMenu.balance => const BalanceScreen(),
      AppMenu.weather => const WeatherScreen(),
      AppMenu.exchange => const ExchangeScreen(),
      AppMenu.news => const NewsScreen(),
      AppMenu.calculator => const CalculatorWidget(popupMode: false),
    };
  }
}

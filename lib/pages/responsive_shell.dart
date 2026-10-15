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

    Widget shell;
    if (width >= 1024) {
      shell = Row(
        children: [
          NavigationRail(
            selectedIndex: menu.index,
            onDestinationSelected: (index) {
              ref.read(accountOpenProvider.notifier).close();
              ref.read(menuProvider.notifier).select(AppMenu.values[index]);
            },
            labelType: NavigationRailLabelType.all,
            destinations: _destinations(text),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _desktopBar(context, ref, text, menu),
                Expanded(
                  child: Row(
                    children: [
                      const Expanded(flex: 42, child: AiPanel()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 58, child: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (landscape) {
      shell = Row(
        children: [
          NavigationRail(
            selectedIndex: menu.index,
            minWidth: 72,
            trailing: IconButton(
              tooltip: text.myPage,
              onPressed: () => ref.read(accountOpenProvider.notifier).open(),
              icon: const Icon(Icons.person),
            ),
            onDestinationSelected: (index) {
              ref.read(accountOpenProvider.notifier).close();
              ref.read(menuProvider.notifier).select(AppMenu.values[index]);
            },
            destinations: _destinations(text),
          ),
          const Expanded(flex: 45, child: AiPanel()),
          const VerticalDivider(width: 1),
          Expanded(flex: 55, child: body),
        ],
      );
    } else {
      shell = Column(
        children: [
          _mobileBar(context, ref, text),
          const Expanded(flex: 4, child: AiPanel()),
          const Divider(height: 1),
          Expanded(flex: 6, child: body),
          NavigationBar(
            selectedIndex: menu.index,
            onDestinationSelected: (index) {
              ref.read(accountOpenProvider.notifier).close();
              ref.read(menuProvider.notifier).select(AppMenu.values[index]);
            },
            destinations: [
              for (final item in AppMenu.values)
                NavigationDestination(icon: Icon(_icon(item)), label: text.menuName(item.name)),
            ],
          ),
        ],
      );
    }

    return Stack(
      children: [
        shell,
        const FloatingCalculator(),
      ],
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

  List<NavigationRailDestination> _destinations(AppText text) {
    return [
      for (final item in AppMenu.values)
        NavigationRailDestination(icon: Icon(_icon(item)), label: Text(text.menuName(item.name))),
    ];
  }

  Widget _desktopBar(BuildContext context, WidgetRef ref, AppText text, AppMenu menu) {
    return Material(
      color: const Color(0xFFF4F7F8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in AppMenu.values)
                    TextButton(
                      onPressed: () {
                        ref.read(accountOpenProvider.notifier).close();
                        ref.read(menuProvider.notifier).select(item);
                      },
                      child: Text(
                        text.menuName(item.name),
                        style: TextStyle(
                          fontWeight: item == menu ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(onPressed: () => ref.read(accountOpenProvider.notifier).open(), child: Text(text.myPage)),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text(text.logout)),
        ],
      ),
    );
  }

  Widget _mobileBar(BuildContext context, WidgetRef ref, AppText text) {
    return Material(
      color: const Color(0xFFF4F7F8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(text.appTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(tooltip: text.myPage, onPressed: () => ref.read(accountOpenProvider.notifier).open(), icon: const Icon(Icons.person)),
          ],
        ),
      ),
    );
  }

  IconData _icon(AppMenu menu) {
    return switch (menu) {
      AppMenu.schedules => Icons.calendar_month,
      AppMenu.balance => Icons.account_balance_wallet,
      AppMenu.weather => Icons.wb_sunny,
      AppMenu.exchange => Icons.currency_exchange,
      AppMenu.news => Icons.newspaper,
      AppMenu.calculator => Icons.calculate,
    };
  }
}

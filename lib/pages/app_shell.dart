import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account_page.dart';
import '../features/balance/balance_screen.dart';
import '../features/calculator/calculator_widget.dart';
import '../features/exchange_rate/exchange_screen.dart';
import '../features/news/news_screen.dart';
import '../features/schedules/schedules_screen.dart';
import '../features/weather/weather_screen.dart';
import '../shared/app_text.dart';
import '../shared/state/providers.dart';
import '../shared/theme/toon.dart';
import '../shared/theme/toon_icons.dart';
import '../shared/theme/toon_widgets.dart';
import 'layouts/desktop_layout.dart';
import 'layouts/phone_landscape_layout.dart';
import 'layouts/portrait_layout.dart';

enum ShellForm { desktop, phoneLandscape, portrait }

ShellForm shellFormOf(Size size) {
  if (size.width <= size.height) {
    return ShellForm.portrait;
  }
  if (size.height < 600 || size.width < 820) {
    return ShellForm.phoneLandscape;
  }
  return ShellForm.desktop;
}

/// Picks one of three independent layouts; each owns its own structure and spacing.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final form = shellFormOf(MediaQuery.sizeOf(context));
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ToonBackground(),
          SafeArea(
            child: switch (form) {
              ShellForm.desktop => const DesktopLayout(),
              ShellForm.phoneLandscape => const PhoneLandscapeLayout(),
              ShellForm.portrait => const PortraitLayout(),
            },
          ),
          const FloatingCalculator(),
        ],
      ),
    );
  }
}

void selectMenu(WidgetRef ref, AppMenu menu) {
  ref.read(accountOpenProvider.notifier).close();
  ref.read(menuProvider.notifier).select(menu);
}

void goHome(WidgetRef ref) {
  ref.read(accountOpenProvider.notifier).close();
  ref.read(menuProvider.notifier).home();
}

/// True when the right-hand pane (a menu or my page) is showing next to the chat.
bool paneOpen(WidgetRef ref) => ref.watch(accountOpenProvider) || ref.watch(menuProvider) != null;

Future<void> logOut(BuildContext context, WidgetRef ref) async {
  final text = AppText.of(Localizations.localeOf(context));
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text.guestLogoutWarn, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Toon.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.logout),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
  }
  goHome(ref);
  await FirebaseAuth.instance.signOut();
}

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    return ToonButton(
      label: iconOnly ? '' : text.logout,
      glyph: ToonGlyph.logout,
      compact: true,
      color: Toon.white,
      tooltip: text.logout,
      onPressed: () => logOut(context, ref),
    );
  }
}

/// Right-hand pane: the selected menu (or my page) under a colored caption strip.
class MenuPane extends ConsumerWidget {
  const MenuPane({super.key, this.showCaption = true});

  final bool showCaption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final menu = ref.watch(menuProvider);
    final account = ref.watch(accountOpenProvider);
    final api = ref.watch(apiProvider);
    if (!account && menu == null) {
      return const SizedBox.shrink();
    }
    final body = account
        ? const AccountPage()
        : switch (menu!) {
            AppMenu.schedules => const SchedulesScreen(),
            AppMenu.balance => const BalanceScreen(),
            AppMenu.weather => const WeatherScreen(),
            AppMenu.exchange => const ExchangeScreen(),
            AppMenu.news => const NewsScreen(),
            AppMenu.calculator => const CalculatorWidget(popupMode: false),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCaption)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: account ? Toon.cream : menu!.color,
              border: const Border(bottom: Toon.border),
            ),
            child: Row(
              children: [
                ToonIcon(account ? ToonGlyph.user : menu!.glyph, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account ? text.myPage : text.menuName(menu!.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                ToonButton(
                  label: '',
                  glyph: ToonGlyph.close,
                  compact: true,
                  tooltip: account ? text.closeAccount : text.closeMenu,
                  onPressed: () => account ? ref.read(accountOpenProvider.notifier).close() : goHome(ref),
                ),
              ],
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: api.servingFromBackup,
          builder: (context, fromBackup, _) => fromBackup
              ? Container(
                  color: Toon.cream,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const ToonIcon(ToonGlyph.cloudSync, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(text.backupBanner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(account ? 'account' : menu!.name), child: body),
          ),
        ),
      ],
    );
  }
}

class AccountButton extends ConsumerWidget {
  const AccountButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final user = ref.watch(authUserProvider).value;
    final open = ref.watch(accountOpenProvider);
    return Tooltip(
      excludeFromSemantics: true,
      message: text.myPage,
      child: Pressable(
        label: text.myPage,
        selected: open,
        onTap: () {
          final notifier = ref.read(accountOpenProvider.notifier);
          open ? notifier.close() : notifier.open();
        },
        child: UserAvatar(size: size, photoUrl: user?.photoURL, color: open ? Toon.sun : Toon.cream),
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.axis = Axis.vertical});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: axis == Axis.vertical ? const Size(14, double.infinity) : const Size(double.infinity, 14),
      painter: _DashPainter(axis),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.axis);

  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Toon.ink.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 6.0;
    if (axis == Axis.vertical) {
      final x = size.width / 2;
      for (var y = 10.0; y < size.height - 10; y += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
      }
    } else {
      final y = size.height / 2;
      for (var x = 10.0; x < size.width - 10; x += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => oldDelegate.axis != axis;
}

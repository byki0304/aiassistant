import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/auth/intro_screen.dart';
import 'features/auth/login_screen.dart';
import 'firebase_options.dart';
import 'pages/app_shell.dart';
import 'shared/state/providers.dart';
import 'shared/theme/toon.dart';
import 'shared/theme/toon_widgets.dart';
import 'shared/widgets/reading_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: AiAssistantApp()));
}

class AiAssistantApp extends ConsumerWidget {
  const AiAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final seed = ThemeData(useMaterial3: true);
    final textTheme = switch (locale.languageCode) {
      'ja' => GoogleFonts.notoSansJpTextTheme(seed.textTheme),
      'en' => GoogleFonts.notoSansTextTheme(seed.textTheme),
      _ => GoogleFonts.notoSansKrTextTheme(seed.textTheme),
    };
    return MaterialApp(
      title: 'aiAssistant',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: toonTheme(textTheme),
      builder: (context, child) => ReadingScale(child: child!),
      home: const AppGate(),
    );
  }
}

/// Intro video (once per launch, if enabled), then login when signed out, then the app.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    final introEnabled = ref.watch(introEnabledProvider);
    final user = ref.watch(authUserProvider);
    final Widget page;
    if (introEnabled && !_introDone) {
      page = IntroScreen(key: const ValueKey('intro'), onDone: () => setState(() => _introDone = true));
    } else if (user.isLoading && !user.hasValue) {
      page = const _Splash(key: ValueKey('splash'));
    } else if (user.value == null) {
      page = const LoginScreen(key: ValueKey('login'));
    } else {
      page = const AppShell(key: ValueKey('shell'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 380), child: page);
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ToonBackground(),
          Center(child: RobotArt(RobotPose.run, height: 120, bob: true)),
        ],
      ),
    );
  }
}

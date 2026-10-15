import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'pages/responsive_shell.dart';
import 'shared/app_text.dart';
import 'shared/state/providers.dart';
import 'shared/theme/ink_icons.dart';
import 'shared/theme/ink_theme.dart';

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
    final seed = ThemeData(useMaterial3: true, scaffoldBackgroundColor: InkPalette.paper);
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
      theme: inkTheme(textTheme),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return _AnonymousSignIn(message: text.signingIn, failure: text.authFailed);
        }
        return const ResponsiveShell();
      },
    );
  }
}

class _AnonymousSignIn extends StatefulWidget {
  const _AnonymousSignIn({required this.message, required this.failure});

  final String message;
  final String failure;

  @override
  State<_AnonymousSignIn> createState() => _AnonymousSignInState();
}

class _AnonymousSignInState extends State<_AnonymousSignIn> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error == null ? widget.message : widget.failure, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

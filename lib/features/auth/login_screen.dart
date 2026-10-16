import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/app_text.dart';
import '../../shared/phone_login.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/language_picker.dart';

enum _Mode { options, email, signup, phone, phoneSignup }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  _Mode _mode = _Mode.options;
  bool _busy = false;
  bool _hidePassword = true;
  bool _keepSignedIn = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    _country.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _go(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _passwordAgain.clear();
      if (_country.text.isEmpty) {
        _country.text = '+${defaultCountryCode(Localizations.localeOf(context).languageCode)}';
      }
    });
  }

  Future<void> _run(Future<void> Function() action, AppText text) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (mounted && error.code != 'popup-closed-by-user' && error.code != 'cancelled-popup-request') {
        setState(() => _error = text.authError(error.code));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = text.authFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _applyPersistence() async {
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(_keepSignedIn ? Persistence.LOCAL : Persistence.SESSION);
    }
  }

  Future<void> _emailSignIn() async {
    await _applyPersistence();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
  }

  Future<void> _emailSignUp() async {
    if (_password.text != _passwordAgain.text) {
      throw FirebaseAuthException(code: 'password-mismatch');
    }
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
  }

  Future<void> _sendReset(AppText text) async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = text.needEmailForReset);
      return;
    }
    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _notice = text.resetSent(email));
      }
    }, text);
  }

  String _phoneEmail(AppText text) {
    if (_phone.text.trim().isEmpty) {
      throw FirebaseAuthException(code: 'missing-phone-number');
    }
    final e164 = toE164(_country.text, _phone.text);
    if (e164 == null) {
      throw FirebaseAuthException(code: 'invalid-phone-number');
    }
    return phoneLoginEmail(e164);
  }

  /// Rewrites email-flavoured errors so phone users are not told about an email address.
  Future<void> _asPhone(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-login-credentials' => FirebaseAuthException(code: 'phone-invalid-credential'),
        'email-already-in-use' => FirebaseAuthException(code: 'phone-already-in-use'),
        'invalid-email' => FirebaseAuthException(code: 'invalid-phone-number'),
        _ => error,
      };
    }
  }

  Future<void> _phoneSignIn(AppText text) => _asPhone(() async {
    final email = _phoneEmail(text);
    await _applyPersistence();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _password.text);
  });

  Future<void> _phoneSignUp(AppText text) => _asPhone(() async {
    final email = _phoneEmail(text);
    if (_password.text != _passwordAgain.text) {
      throw FirebaseAuthException(code: 'password-mismatch');
    }
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: _password.text);
  });

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final roomy = landscape && size.width >= 820 && size.height >= 600;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ToonCard(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Toon.butter,
                  borderRadius: BorderRadius.circular(14),
                  border: const Border.fromBorderSide(Toon.border),
                ),
                child: const Wordmark(size: 22),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text.loginTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6),
            ),
            const SizedBox(height: 6),
            Text(
              text.loginSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Toon.inkSoft, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: AutofillGroup(
                child: switch (_mode) {
                  _Mode.options => _options(text),
                  _Mode.email => _emailForm(text),
                  _Mode.signup => _signupForm(text),
                  _Mode.phone => _phoneForm(text),
                  _Mode.phoneSignup => _phoneSignupForm(text),
                },
              ),
            ),
            if (_busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
            if (_notice != null) ...[const SizedBox(height: 10), ToonPill(_notice!, color: Toon.leaf)],
            if (_error != null) ...[const SizedBox(height: 10), ToonPill(_error!, color: Toon.pink)],
            const SizedBox(height: 14),
            const Center(child: LanguagePicker()),
          ],
        ),
      ),
    );

    final Widget body;
    if (roomy) {
      body = Stack(
        children: [
          const Positioned(left: 24, top: 18, child: Wordmark(size: 22)),
          const Positioned(left: 70, top: 170, child: RobotArt(RobotPose.wave, height: 150, bob: true)),
          const Positioned(left: 40, bottom: 30, child: RobotArt(RobotPose.point, height: 130)),
          const Positioned(right: 70, top: 190, child: RobotArt(RobotPose.run, height: 150, bob: true)),
          Center(
            child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: card),
          ),
        ],
      );
    } else if (landscape) {
      body = Row(
        children: [
          const Expanded(flex: 2, child: Center(child: RobotArt(RobotPose.wave, height: 130, bob: true))),
          Expanded(
            flex: 3,
            child: Center(
              child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: card),
            ),
          ),
        ],
      );
    } else {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [RobotArt(RobotPose.wave, height: 96, bob: true), SizedBox(width: 12), RobotArt(RobotPose.run, height: 80)],
              ),
              const SizedBox(height: 12),
              card,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ToonBackground(),
          SafeArea(child: body),
        ],
      ),
    );
  }

  Widget _options(AppText text) {
    return Column(
      key: const ValueKey('options'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToonButton(label: text.emailLogin, glyph: ToonGlyph.mail, color: Toon.sky, onPressed: _busy ? null : () => _go(_Mode.email)),
        const SizedBox(height: 12),
        ToonButton(label: text.phoneLogin, glyph: ToonGlyph.phone, color: Toon.leaf, onPressed: _busy ? null : () => _go(_Mode.phone)),
        const SizedBox(height: 12),
        ToonButton(
          label: text.googleLogin,
          glyph: ToonGlyph.google,
          color: Toon.white,
          onPressed: _busy ? null : () => _run(() => FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider()), text),
        ),
        const SizedBox(height: 12),
        ToonButton(
          label: text.guestStart,
          glyph: ToonGlyph.sparkle,
          color: Toon.navy,
          textColor: Toon.white,
          onPressed: _busy ? null : () => _run(() => FirebaseAuth.instance.signInAnonymously(), text),
        ),
        const SizedBox(height: 16),
        Center(child: _link(text.signupPrompt, () => _go(_Mode.signup), strong: true)),
      ],
    );
  }

  Widget _emailForm(AppText text) {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(text.emailLabel),
        _emailField(),
        const SizedBox(height: 10),
        _label(text.passwordLabel),
        _passwordField(_password, text.passwordLabel, text, onSubmit: () => _run(_emailSignIn, text)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _keepSignedInToggle(text)),
            _link(text.findPassword, () => _sendReset(text)),
          ],
        ),
        const SizedBox(height: 14),
        ToonButton(
          label: text.loginAction,
          color: Toon.navy,
          textColor: Toon.white,
          onPressed: _busy ? null : () => _run(_emailSignIn, text),
        ),
        const SizedBox(height: 12),
        Center(child: _link(text.signup, () => _go(_Mode.signup), strong: true)),
        const SizedBox(height: 4),
        Center(child: _link(text.backToOptions, () => _go(_Mode.options))),
      ],
    );
  }

  Widget _signupForm(AppText text) {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(text.emailLabel),
        _emailField(),
        const SizedBox(height: 10),
        _label('${text.passwordLabel} (${text.passwordRule})'),
        _passwordField(_password, text.passwordLabel, text, newPassword: true),
        const SizedBox(height: 10),
        _label(text.passwordConfirmLabel),
        _passwordField(_passwordAgain, text.passwordConfirmLabel, text, newPassword: true, onSubmit: () => _run(_emailSignUp, text)),
        const SizedBox(height: 14),
        ToonButton(label: text.signup, color: Toon.coral, onPressed: _busy ? null : () => _run(_emailSignUp, text)),
        const SizedBox(height: 12),
        Center(child: _link(text.haveAccount, () => _go(_Mode.email), strong: true)),
        const SizedBox(height: 4),
        Center(child: _link(text.phoneSignupInstead, () => _go(_Mode.phoneSignup))),
        Center(child: _link(text.backToOptions, () => _go(_Mode.options))),
      ],
    );
  }

  Widget _phoneForm(AppText text) {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(text.phoneLabel),
        _phoneField(text),
        const SizedBox(height: 10),
        _label(text.passwordLabel),
        _passwordField(_password, text.passwordLabel, text, onSubmit: () => _run(() => _phoneSignIn(text), text)),
        const SizedBox(height: 8),
        _keepSignedInToggle(text),
        const SizedBox(height: 14),
        ToonButton(
          label: text.loginAction,
          color: Toon.navy,
          textColor: Toon.white,
          onPressed: _busy ? null : () => _run(() => _phoneSignIn(text), text),
        ),
        const SizedBox(height: 12),
        Center(child: _link(text.signup, () => _go(_Mode.phoneSignup), strong: true)),
        const SizedBox(height: 4),
        Center(child: _link(text.backToOptions, () => _go(_Mode.options))),
      ],
    );
  }

  Widget _phoneSignupForm(AppText text) {
    return Column(
      key: const ValueKey('phoneSignup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(text.phoneLabel),
        _phoneField(text),
        const SizedBox(height: 10),
        _label('${text.passwordLabel} (${text.passwordRule})'),
        _passwordField(_password, text.passwordLabel, text, newPassword: true),
        const SizedBox(height: 10),
        _label(text.passwordConfirmLabel),
        _passwordField(
          _passwordAgain,
          text.passwordConfirmLabel,
          text,
          newPassword: true,
          onSubmit: () => _run(() => _phoneSignUp(text), text),
        ),
        const SizedBox(height: 14),
        ToonButton(label: text.signup, color: Toon.coral, onPressed: _busy ? null : () => _run(() => _phoneSignUp(text), text)),
        const SizedBox(height: 12),
        Center(child: _link(text.haveAccount, () => _go(_Mode.phone), strong: true)),
        const SizedBox(height: 4),
        Center(child: _link(text.emailSignupInstead, () => _go(_Mode.signup))),
        Center(child: _link(text.backToOptions, () => _go(_Mode.options))),
      ],
    );
  }

  Widget _phoneField(AppText text) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Semantics(
            label: text.countryCodeLabel,
            child: TextField(
              controller: _country,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberCountryCode],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')), LengthLimitingTextInputFormatter(4)],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '+82'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: text.phoneLabel,
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]'))],
              decoration: InputDecoration(hintText: text.phoneHint, prefixIcon: const Icon(Icons.smartphone_rounded)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _keepSignedInToggle(AppText text) {
    return Semantics(
      checked: _keepSignedIn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
        child: Row(
          children: [
            ToonCheck(checked: _keepSignedIn),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text.keepSignedIn, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 5),
      child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    );
  }

  Widget _emailField() {
    return TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(hintText: 'example@email.com', prefixIcon: Icon(Icons.mail_outline_rounded)),
    );
  }

  Widget _passwordField(TextEditingController controller, String label, AppText text, {bool newPassword = false, VoidCallback? onSubmit}) {
    return Semantics(
      label: label,
      child: TextField(
        controller: controller,
        obscureText: _hidePassword,
        autofillHints: [newPassword ? AutofillHints.newPassword : AutofillHints.password],
        onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: text.showPassword,
            isSelected: !_hidePassword,
            icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap, {bool strong = false}) {
    return TextButton(
      onPressed: _busy ? null : onTap,
      style: TextButton.styleFrom(foregroundColor: strong ? Toon.ink : Toon.inkSoft),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          fontSize: strong ? 14 : 13,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

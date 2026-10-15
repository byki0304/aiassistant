import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/state/providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final user = FirebaseAuth.instance.currentUser;
    final linked = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.accountTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(linked ? text.linked : text.guest),
          const SizedBox(height: 16),
          Text(text.language),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ko', label: Text('한국어')),
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ja', label: Text('日本語')),
            ],
            selected: {Localizations.localeOf(context).languageCode},
            onSelectionChanged: (value) => ref.read(localeProvider.notifier).setCode(value.first),
          ),
          const SizedBox(height: 16),
          if (!linked)
            FilledButton(
              onPressed: () => _link(context, text),
              child: Text(text.linkGoogle),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: Text(text.logout),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _withdraw(context, ref, text),
            child: Text(text.withdraw),
          ),
          const Spacer(),
          TextButton(onPressed: () => ref.read(accountOpenProvider.notifier).close(), child: Text(text.closeAccount)),
        ],
      ),
    );
  }

  Future<void> _link(BuildContext context, AppText text) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final provider = GoogleAuthProvider();
      if (user != null && user.isAnonymous) {
        await user.linkWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithPopup(provider);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, AppText text) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text.withdrawConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(text.withdraw)),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(apiProvider).withdraw();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }
}

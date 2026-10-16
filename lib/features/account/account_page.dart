import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/phone_login.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/language_picker.dart';
import '../../shared/widgets/menu_body.dart';
import '../../shared/widgets/reading_settings.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  Future<DbStatus>? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = ref.read(apiProvider).dbStatus();
  }

  void _refreshStatus() => setState(() => _status = ref.read(apiProvider).dbStatus());

  Future<void> _guard(Future<void> Function() action, AppText text) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showToonMessage(context, explainError(error, text));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(String message, String action) async {
    final text = AppText.of(Localizations.localeOf(context));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(text.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Toon.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final user = ref.watch(authUserProvider).value;
    final linked = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;
    final phone = phoneOfLoginEmail(user?.email);
    final turns = ref.watch(turnsProvider).asData?.value ?? const <ChatTurn>[];

    final profile = _Section(
      title: text.profile,
      color: Toon.pink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(size: 76, photoUrl: user?.photoURL, color: Toon.butter),
                  const Positioned(right: -18, bottom: -6, child: RobotArt(RobotPose.head, height: 30)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName?.isNotEmpty == true ? user!.displayName! : phone ?? text.guest,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      phone ?? (user?.email?.isNotEmpty == true ? user!.email! : text.noEmail),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Toon.inkSoft, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ToonPill(
                          linked ? text.linked : text.guest,
                          color: linked ? Toon.leaf : Toon.cream,
                          glyph: linked ? ToonGlyph.google : ToonGlyph.user,
                        ),
                        ToonPill(text.chatCount(turns.length), color: Toon.sky),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ToonButton(
                label: text.resetMemory,
                glyph: ToonGlyph.trash,
                compact: true,
                color: Toon.sun,
                onPressed: _busy || turns.isEmpty
                    ? null
                    : () async {
                        if (await _confirm(text.resetConfirm(turns.length), text.delete)) {
                          await _guard(() => ref.read(apiProvider).deleteByIds('turns', [for (final turn in turns) turn.id]), text);
                          ref.read(localTurnsProvider.notifier).dropIds({for (final turn in ref.read(localTurnsProvider)) turn.id});
                        }
                      },
              ),
              if (!linked)
                ToonButton(
                  label: text.linkGoogle,
                  glyph: ToonGlyph.google,
                  compact: true,
                  onPressed: _busy ? null : () => _guard(() => _link(user), text),
                ),
            ],
          ),
        ],
      ),
    );

    final settings = _Section(
      title: text.settings,
      color: Toon.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.language, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 6),
          const LanguagePicker(),
          const SizedBox(height: 12),
          const ReadingSettings(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(text.introSetting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
              Switch(value: ref.watch(introEnabledProvider), onChanged: (value) => ref.read(introEnabledProvider.notifier).set(value)),
            ],
          ),
        ],
      ),
    );

    final services = _Section(
      title: text.services,
      color: Toon.leaf,
      trailing: ToonButton(label: '', glyph: ToonGlyph.cloudSync, compact: true, tooltip: text.refresh, onPressed: _refreshStatus),
      child: FutureBuilder<DbStatus>(
        future: _status,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          final status = snapshot.data ?? (snapshot.hasError ? _statusFromStreams() : null);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DbRow(label: text.primaryDb, glyph: ToonGlyph.database, side: status?.primary, waiting: waiting, text: text),
              const SizedBox(height: 8),
              _DbRow(label: text.backupDb, glyph: ToonGlyph.cloudSync, side: status?.backup, waiting: waiting, text: text),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ToonButton(
                  label: text.syncBackup,
                  glyph: ToonGlyph.cloudSync,
                  compact: true,
                  color: Toon.leaf,
                  onPressed: _busy
                      ? null
                      : () => _guard(() async {
                          final copied = await ref.read(apiProvider).syncBackup();
                          if (mounted) {
                            showToonMessage(this.context, text.synced(copied));
                          }
                          _refreshStatus();
                        }, text),
                ),
              ),
            ],
          );
        },
      ),
    );

    final footer = Row(
      children: [
        TextButton(
          onPressed: _busy ? null : () => _withdraw(text),
          child: Text(
            text.withdraw,
            style: const TextStyle(fontSize: 12, color: Toon.inkSoft, decoration: TextDecoration.underline),
          ),
        ),
        const Spacer(),
        ToonButton(
          label: text.logout,
          glyph: ToonGlyph.logout,
          color: Toon.red,
          textColor: Toon.white,
          onPressed: _busy ? null : () => _logout(user, text),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 16 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: [profile, const SizedBox(height: 14), settings])),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          services,
                          if (constraints.maxHeight > 420) ...[
                            const SizedBox(height: 16),
                            const RobotArt(RobotPose.wave, height: 104, bob: true),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                profile,
                const SizedBox(height: 12),
                settings,
                const SizedBox(height: 12),
                services,
              ],
              const SizedBox(height: 14),
              footer,
            ],
          ),
        );
      },
    );
  }

  /// Used when the status function cannot be reached: the live Firebase streams still
  /// tell whether the primary answers, while the backup can only be checked server-side.
  DbStatus _statusFromStreams() {
    final streams = [
      ref.read(schedulesProvider),
      ref.read(balancesProvider),
      ref.read(newsProvider),
      ref.read(weatherProvider),
      ref.read(exchangeProvider),
      ref.read(turnsProvider),
    ];
    final primaryOk = streams.every((value) => value.hasValue) && !ref.read(apiProvider).servingFromBackup.value;
    final total = streams.fold<int>(0, (sum, value) => sum + (value.value?.length ?? 0));
    return DbStatus(
      primary: DbSide(ok: primaryOk, total: total),
      backup: const DbSide(ok: false, total: 0),
    );
  }

  Future<void> _link(User? user) async {
    final provider = GoogleAuthProvider();
    if (user != null && user.isAnonymous) {
      await user.linkWithPopup(provider);
      await user.reload();
    } else {
      await FirebaseAuth.instance.signInWithPopup(provider);
    }
  }

  Future<void> _logout(User? user, AppText text) async {
    if (user != null && user.isAnonymous && !await _confirm(text.guestLogoutWarn, text.logout)) {
      return;
    }
    ref.read(accountOpenProvider.notifier).close();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _withdraw(AppText text) async {
    if (!await _confirm(text.withdrawConfirm, text.withdraw)) {
      return;
    }
    await _guard(() async {
      await ref.read(apiProvider).withdraw();
      ref.read(accountOpenProvider.notifier).close();
      await FirebaseAuth.instance.signOut();
    }, text);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.color, required this.child, this.trailing});

  final String title;
  final Color color;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ToonCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            decoration: BoxDecoration(
              color: color,
              border: const Border(bottom: Toon.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _DbRow extends StatelessWidget {
  const _DbRow({required this.label, required this.glyph, required this.side, required this.waiting, required this.text});

  final String label;
  final ToonGlyph glyph;
  final DbSide? side;
  final bool waiting;
  final AppText text;

  @override
  Widget build(BuildContext context) {
    final current = side;
    final ok = current?.ok == true;
    final status = waiting
        ? text.dbChecking
        : ok
        ? text.dbCount(current!.total)
        : text.dbUnavailable;
    final mirrored = current?.lastMirroredAt;
    return Row(
      children: [
        ToonIcon(glyph, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              if (mirrored != null)
                Text(
                  text.lastMirrored(DateFormat.MMMd().add_Hm().format(mirrored.toLocal())),
                  style: const TextStyle(fontSize: 11, color: Toon.inkSoft),
                ),
            ],
          ),
        ),
        ToonPill(status, color: waiting ? Toon.cream : (ok ? Toon.leaf : Toon.pink)),
      ],
    );
  }
}

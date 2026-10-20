import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/chart_block.dart';

/// Chat column: input card on top, quick presets, then results with the newest turn first.
class ChatPane extends ConsumerStatefulWidget {
  const ChatPane({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  PlatformFile? _file;
  bool _listening = false;
  bool _spoken = false;
  bool _deleting = false;

  /// Bumped whenever a listening session is abandoned, so its late results cannot refill the input.
  int _voiceSession = 0;

  /// Checked bubbles, keyed by [_promptKey] and [_answerKey].
  final _checked = <String>{};

  static String _promptKey(String id) => '$id|prompt';
  static String _answerKey(String id) => '$id|answer';

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).languageCode;
    final user = ref.watch(authUserProvider).value;
    ref.listen(insertProvider, (_, next) {
      if (next != null) {
        _input.text = next.text;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      }
    });
    ref.listen(turnsProvider, (_, next) {
      next.whenData((remote) {
        ref.read(localTurnsProvider.notifier).dropIds(remote.map((turn) => turn.id).toSet());
        _scrollToNewest();
      });
    });
    final remote = ref.watch(turnsProvider).asData?.value ?? const <ChatTurn>[];
    final local = ref.watch(localTurnsProvider);
    final turns = [
      ...remote,
      ...local.where((turn) => remote.every((item) => item.id != turn.id)),
    ].where((turn) => !(turn.userHidden && turn.aiHidden)).toList().reversed.toList();
    final selectable = {
      for (final turn in turns)
        if (!turn.pending) ...[if (!turn.userHidden) _promptKey(turn.id), if (!turn.aiHidden) _answerKey(turn.id)],
    };
    _checked.retainAll(selectable);
    final selection = selectable.isEmpty ? null : _selectionButton(text, turns, selectable);
    final compact = widget.compact;
    final gap = compact ? 8.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gap, gap, gap, 0),
          child: compact ? _compactInput(text, locale) : _fullInput(text, locale, selection),
        ),
        if (compact)
          _compactPresets(text, locale, gap, selection)
        else
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(gap, 6, gap, 4),
              children: [
                _preset(text.presetBalance, ToonGlyph.wallet, Toon.butter, () => _presetBalance(text, locale)),
                _preset(text.presetNews, ToonGlyph.news, Toon.lilac, () => _presetNews(text, locale)),
                _preset(text.presetWeather, ToonGlyph.weather, Toon.sky, () => _presetWeather(text, locale)),
              ],
            ),
          ),
        if (!compact)
          Padding(
            padding: EdgeInsets.fromLTRB(gap + 2, 6, gap, 2),
            child: ToonTitle(text.outputTitle, dot: Toon.leaf, size: 14.5),
          ),
        Expanded(
          child: turns.isEmpty
              ? ToonEmpty(text.welcome, pose: RobotPose.point, compact: compact)
              : ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(gap, 8, gap, gap),
                  itemCount: turns.length,
                  itemBuilder: (context, index) => _turn(turns[index], text, user?.photoURL),
                ),
        ),
      ],
    );
  }

  Widget _preset(String label, ToonGlyph glyph, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ToonButton(label: label, glyph: glyph, color: color, compact: true, onPressed: onTap),
      ),
    );
  }

  /// Phones: presets and the selection toggle on two lines, scaled down together when the screen is too narrow.
  Widget _compactPresets(AppText text, String locale, double gap, Widget? selection) {
    Widget button(String label, ToonGlyph glyph, Color color, VoidCallback onTap) =>
        ToonButton(label: label, glyph: glyph, color: color, compact: true, onPressed: onTap);
    Widget fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child);
    return Padding(
      padding: EdgeInsets.fromLTRB(gap, 6, gap, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fit(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(text.presetBalance, ToonGlyph.wallet, Toon.butter, () => _presetBalance(text, locale)),
                const SizedBox(width: 8),
                button(text.presetNews, ToonGlyph.news, Toon.lilac, () => _presetNews(text, locale)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: fit(button(text.presetWeather, ToonGlyph.weather, Toon.sky, () => _presetWeather(text, locale)))),
              if (selection != null) ...[const SizedBox(width: 8), selection],
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(AppText text, String locale, {required int minLines, required int maxLines}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
          _send(text, locale);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          TextField(
            controller: _input,
            focusNode: _inputFocus,
            minLines: minLines,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: _listening ? text.listening : text.inputHint,
              fillColor: Toon.cream.withValues(alpha: 0.55),
              contentPadding: const EdgeInsets.fromLTRB(14, 12, 28, 12),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : Tooltip(
                      message: text.clearInput,
                      child: Semantics(
                        button: true,
                        label: text.clearInput,
                        child: InkResponse(
                          onTap: () => _clearInput(locale),
                          radius: 14,
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empties the input and gets ready for the same kind of input again: listening if the text was spoken, typing otherwise.
  Future<void> _clearInput(String locale) async {
    final wasVoice = _listening || _spoken;
    _voiceSession += 1;
    if (_listening) {
      await _speech.cancel();
    }
    _input.clear();
    setState(() {
      _listening = false;
      _spoken = false;
    });
    if (wasVoice) {
      await _toggleVoice(locale);
    } else {
      _inputFocus.requestFocus();
    }
  }

  Widget _fileTag() {
    final file = _file;
    if (file == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Pressable(
          onTap: () => setState(() => _file = null),
          child: ToonPill('${file.name}  ✕', color: Toon.sky, glyph: ToonGlyph.clip),
        ),
      ),
    );
  }

  /// "Select all" while nothing is checked, "Delete" as soon as one bubble is.
  Widget _selectionButton(AppText text, List<ChatTurn> turns, Set<String> selectable) {
    if (_checked.isEmpty) {
      return ToonButton(
        label: text.selectAll,
        glyph: ToonGlyph.check,
        compact: true,
        onPressed: _deleting ? null : () => setState(() => _checked.addAll(selectable)),
      );
    }
    return ToonButton(
      label: text.delete,
      glyph: ToonGlyph.trash,
      compact: true,
      color: Toon.coral,
      onPressed: _deleting ? null : () => _deleteChecked(turns, text),
    );
  }

  Future<void> _deleteChecked(List<ChatTurn> turns, AppText text) async {
    final parts = <String, ({bool user, bool ai})>{
      for (final turn in turns)
        if (_checked.contains(_promptKey(turn.id)) || _checked.contains(_answerKey(turn.id)))
          turn.id: (
            user: turn.userHidden || _checked.contains(_promptKey(turn.id)),
            ai: turn.aiHidden || _checked.contains(_answerKey(turn.id)),
          ),
    };
    setState(() {
      _checked.clear();
      _deleting = true;
    });
    ref.read(localTurnsProvider.notifier).hideParts(parts);
    final stored = {
      for (final entry in parts.entries)
        if (!entry.key.startsWith('local-')) entry.key: entry.value,
    };
    try {
      if (stored.isNotEmpty) {
        await ref.read(apiProvider).deleteTurnParts(stored);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Widget _checkBox(String key, String label) {
    final checked = _checked.contains(key);
    void toggle() => setState(() => checked ? _checked.remove(key) : _checked.add(key));
    final box = Semantics(
      container: true,
      checked: checked,
      label: label,
      onTap: _deleting ? null : toggle,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _deleting ? null : toggle,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ToonCheck(checked: checked, size: 20),
          ),
        ),
      ),
    );
    return Align(alignment: Alignment.topCenter, child: box);
  }

  Widget _fullInput(AppText text, String locale, Widget? selection) {
    return ToonCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToonTitle(text.inputTitle, glyph: ToonGlyph.sparkle, size: 14.5, trailing: selection),
          const SizedBox(height: 10),
          _field(text, locale, minLines: 2, maxLines: 5),
          _fileTag(),
          const SizedBox(height: 10),
          Row(
            children: [
              ToonButton(label: text.uploadFile, glyph: ToonGlyph.upload, compact: true, color: Toon.sky, onPressed: _pickFile),
              const SizedBox(width: 8),
              ToonButton(
                label: _listening ? text.listening : text.voiceBadge,
                glyph: ToonGlyph.mic,
                compact: true,
                color: _listening ? Toon.coral : Toon.pink,
                onPressed: () => _toggleVoice(locale),
              ),
              const Spacer(),
              ToonButton(
                label: text.runAi,
                glyph: ToonGlyph.send,
                color: Toon.ink,
                textColor: Toon.white,
                onPressed: () => _send(text, locale),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactInput(AppText text, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ToonButton(label: '', glyph: ToonGlyph.upload, compact: true, color: Toon.sky, tooltip: text.uploadFile, onPressed: _pickFile),
            const SizedBox(width: 6),
            ToonButton(
              label: '',
              glyph: ToonGlyph.mic,
              compact: true,
              color: _listening ? Toon.coral : Toon.pink,
              tooltip: text.voiceBadge,
              onPressed: () => _toggleVoice(locale),
            ),
            const SizedBox(width: 6),
            Expanded(child: _field(text, locale, minLines: 1, maxLines: 3)),
            const SizedBox(width: 6),
            ToonButton(
              label: '',
              glyph: ToonGlyph.send,
              compact: true,
              color: Toon.ink,
              tooltip: text.runAi,
              onPressed: () => _send(text, locale),
            ),
          ],
        ),
        _fileTag(),
      ],
    );
  }

  Widget _bubble({required Widget child, required Color color, required bool fromUser}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(fromUser ? 4 : 18),
          topRight: Radius.circular(fromUser ? 18 : 4),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        border: const Border.fromBorderSide(Toon.border),
        boxShadow: Toon.lift,
      ),
      child: child,
    );
  }

  Widget _turn(ChatTurn turn, AppText text, String? photoUrl) {
    final avatar = widget.compact ? 28.0 : 36.0;
    const checkSlot = 30.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!turn.userHidden)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(size: avatar, photoUrl: photoUrl),
                const SizedBox(width: 8),
                Flexible(
                  child: _bubble(
                    color: Toon.white,
                    fromUser: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (turn.isVoice || turn.fileName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (turn.isVoice) ToonPill(text.voiceBadge, color: Toon.pink, glyph: ToonGlyph.mic),
                                if (turn.fileName != null) ToonPill(turn.fileName!, color: Toon.sky, glyph: ToonGlyph.clip),
                              ],
                            ),
                          ),
                        Text(turn.userText, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(width: checkSlot, child: turn.pending ? null : _checkBox(_promptKey(turn.id), text.selectPrompt)),
              ],
            ),
          if (!turn.userHidden && !turn.aiHidden) const SizedBox(height: 8),
          if (!turn.aiHidden)
            LayoutBuilder(
              builder: (context, constraints) {
                final bubbleWidth = constraints.maxWidth - 2 * (avatar + 8);
                final answerIndent = avatar + 8 + bubbleWidth * 0.2 - checkSlot - 4;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: answerIndent.clamp(0.0, double.infinity)),
                    SizedBox(width: checkSlot, child: turn.pending ? null : _checkBox(_answerKey(turn.id), text.selectAnswer)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _bubble(
                        color: turn.failed ? Toon.pink.withValues(alpha: 0.45) : Toon.lime,
                        fromUser: false,
                        child: _aiBody(turn, text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RobotAvatar(size: avatar, color: turn.failed ? Toon.pink : Toon.sky),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _aiBody(ChatTurn turn, AppText text) {
    if (turn.pending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text.aiThinking, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: const LinearProgressIndicator(minHeight: 6)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(turn.aiText, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
        if (turn.table != null) TableBlock(table: turn.table!),
        if (turn.chart != null) ChartBlock(chart: turn.chart!, height: widget.compact ? 140 : 170),
        if (turn.awaitingConfirm && turn.extractedSchedules.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ToonButton(
              label: text.approveSchedules(turn.extractedSchedules.length),
              glyph: ToonGlyph.calendar,
              compact: true,
              color: Toon.pink,
              onPressed: () => _confirm(turn.id, 'schedules', text),
            ),
          ),
        if (turn.awaitingConfirm && turn.extractedBalances.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ToonButton(
              label: text.approveBalances(turn.extractedBalances.length),
              glyph: ToonGlyph.wallet,
              compact: true,
              color: Toon.butter,
              onPressed: () => _confirm(turn.id, 'balances', text),
            ),
          ),
        if (menuById(turn.menuId) case final menu?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Flexible(
                  child: ToonButton(
                    label: turn.savedMenu != null ? text.savedBadge(text.menuName(menu.name)) : text.openMenu(text.menuName(menu.name)),
                    glyph: turn.savedMenu != null ? ToonGlyph.check : menu.glyph,
                    compact: true,
                    color: turn.savedMenu != null ? Toon.leaf : menu.color,
                    onPressed: () => _showMenu(menu),
                  ),
                ),
                if (turn.savedMenu != null) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '✓✓',
                    style: TextStyle(color: Toon.green, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _send(AppText text, String locale) async {
    final value = _input.text.trim();
    final file = _file;
    if (value.isEmpty && file == null) {
      _failLocal(text.emptyInput, text);
      return;
    }
    final isVoice = _listening || _spoken;
    if (_listening) {
      await _speech.stop();
    }
    _input.clear();
    setState(() {
      _file = null;
      _listening = false;
      _spoken = false;
    });
    await _run(
      userText: value.isEmpty ? file!.name : value,
      isVoice: isVoice,
      fileName: file?.name,
      text: text,
      action: (api) async {
        String? path;
        if (file != null) {
          final ext = (file.extension ?? '').toLowerCase();
          if (!allowedExtensions.contains(ext)) {
            throw AppFailure('bad-extension');
          }
          final bytes = await file.readAsBytes();
          if (bytes.length > maxUploadBytes) {
            throw AppFailure('file-too-large');
          }
          path = await api.upload(fileName: file.name, bytes: bytes, contentType: 'application/octet-stream');
        }
        return api.submitPrompt(text: value, locale: locale, isVoice: isVoice, filePath: path, fileName: file?.name);
      },
    );
  }

  Future<void> _presetBalance(AppText text, String locale) async {
    final items = ref.read(balancesProvider).asData?.value ?? const <BalanceItem>[];
    final start = SeoulClock.startOfWeek(DateTime.now());
    final week = items.where((item) => SeoulClock.inWeek(item.occurredAt, start)).toList();
    final totals = weekTotals([
      for (final item in week) BalancePoint(id: item.id, occurredAt: item.occurredAt, amount: item.amount, isIncome: item.isIncome),
    ]);
    final table = TableModel(
      headers: [text.weekExpense, text.weekIncome, text.weekNet],
      rows: [
        ['${totals.expense}', '${totals.income}', '${totals.net}'],
      ],
    );
    final chart = ChartModel(
      type: 'bar',
      labels: [text.weekExpense, text.weekIncome],
      values: [totals.expense.toDouble(), totals.income.toDouble()],
    );
    final summary = week.isEmpty ? text.emptyData : '${text.weekExpense} ${totals.expense} / ${text.weekIncome} ${totals.income}';
    await _appendLocal(userText: text.presetBalance, aiText: summary, table: table, chart: chart, targetMenu: 'balance', text: text);
  }

  Future<void> _presetNews(AppText text, String locale) async {
    await _run(
      userText: text.presetNews,
      text: text,
      action: (api) async {
        final usa = await api.getNews('USA');
        final japan = await api.getNews('JAPAN');
        final top = [...usa, ...japan];
        return api.appendTurn(
          ChatTurn(
            id: '',
            userText: text.presetNews,
            aiText: top.isEmpty ? text.emptyData : top.map((item) => item.title).join('\n'),
            savedMenu: 'news',
            table: TableModel(
              headers: const ['country', 'title'],
              rows: [
                for (final item in top) [item.country, item.title],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _presetWeather(AppText text, String locale) async {
    await _run(
      userText: text.presetWeather,
      text: text,
      action: (api) async {
        final seongnam = await api.getWeather(cityName: '경기도 성남시', cityQuery: 'Seongnam,KR');
        final yokohama = await api.getWeather(cityName: 'Yokohama', cityQuery: 'Yokohama,JP');
        return api.appendTurn(
          ChatTurn(
            id: '',
            userText: text.presetWeather,
            aiText:
                '${seongnam.cityName} ${seongnam.temperature.toStringAsFixed(1)}°C / ${yokohama.cityName} ${yokohama.temperature.toStringAsFixed(1)}°C',
            savedMenu: 'weather',
            table: TableModel(
              headers: const ['city', 'temp', 'condition'],
              rows: [
                [seongnam.cityName, seongnam.temperature.toStringAsFixed(1), seongnam.condition],
                [yokohama.cityName, yokohama.temperature.toStringAsFixed(1), yokohama.condition],
              ],
            ),
            chart: ChartModel(
              type: 'bar',
              labels: [seongnam.cityName, yokohama.cityName],
              values: [seongnam.temperature, yokohama.temperature],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirm(String turnId, String kind, AppText text) async {
    try {
      await ref.read(apiProvider).confirmExtracted(turnId: turnId, kind: kind);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(explainError(error, text))));
      }
    }
  }

  Future<void> _appendLocal({
    required String userText,
    required String aiText,
    required AppText text,
    TableModel? table,
    ChartModel? chart,
    String? targetMenu,
  }) async {
    await _run(
      userText: userText,
      text: text,
      menu: targetMenu,
      action: (api) =>
          api.appendTurn(ChatTurn(id: '', userText: userText, aiText: aiText, table: table, chart: chart, targetMenu: targetMenu)),
    );
  }

  Future<void> _run({
    required String userText,
    required AppText text,
    required Future<ChatTurn> Function(AssistantApi api) action,
    bool isVoice = false,
    String? fileName,
    String? menu,
  }) async {
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    ref
        .read(localTurnsProvider.notifier)
        .add(ChatTurn(id: localId, userText: userText, aiText: '', isVoice: isVoice, fileName: fileName, pending: true, localOnly: true));
    _scrollToNewest();
    try {
      final turn = await action(ref.read(apiProvider));
      ref.read(localTurnsProvider.notifier).replace(localId, turn.copyWith(localOnly: true, pending: false));
      if (menuById(turn.menuId ?? menu) case final target? when mounted) {
        _showMenu(target);
      }
    } catch (error) {
      ref
          .read(localTurnsProvider.notifier)
          .replace(
            localId,
            ChatTurn(id: localId, userText: userText, aiText: explainError(error, text), failed: true, localOnly: true, fileName: fileName),
          );
    }
    _scrollToNewest();
  }

  void _showMenu(AppMenu menu) {
    ref.read(accountOpenProvider.notifier).close();
    ref.read(menuProvider.notifier).select(menu);
  }

  void _failLocal(String message, AppText text) {
    ref
        .read(localTurnsProvider.notifier)
        .add(
          ChatTurn(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            userText: message,
            aiText: text.emptyInput,
            failed: true,
            localOnly: true,
          ),
        );
    _scrollToNewest();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: allowedExtensions.toList());
    if (result != null) {
      setState(() => _file = result);
    }
  }

  Future<void> _toggleVoice(String locale) async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted && _listening) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _listening = false);
        }
      },
    );
    if (!ready) {
      return;
    }
    final region = switch (locale) {
      'en' => 'en_US',
      'ja' => 'ja_JP',
      _ => 'ko_KR',
    };
    // Android Chrome repeats earlier words in every continuous result, so it gets one final utterance instead.
    final androidWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    setState(() => _listening = true);
    final session = _voiceSession;
    await _speech.listen(
      onResult: (result) {
        if (session != _voiceSession) {
          return;
        }
        _spoken = result.recognizedWords.isNotEmpty;
        _input.text = result.recognizedWords;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      },
      listenOptions: SpeechListenOptions(localeId: kIsWeb ? region.replaceAll('_', '-') : region, partialResults: !androidWeb),
    );
  }
}

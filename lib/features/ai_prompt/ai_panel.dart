import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/widgets/chart_block.dart';

class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({super.key});

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  PlatformFile? _file;
  bool _listening = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).languageCode;
    ref.listen(insertProvider, (_, next) {
      if (next != null) {
        _input.text = next.text;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      }
    });
    ref.listen(turnsProvider, (_, next) {
      next.whenData((remote) {
        ref.read(localTurnsProvider.notifier).dropIds(remote.map((turn) => turn.id).toSet());
        _scrollDown();
      });
    });
    final remote = ref.watch(turnsProvider).asData?.value ?? const <ChatTurn>[];
    final local = ref.watch(localTurnsProvider);
    final turns = [...remote, ...local.where((turn) => remote.every((item) => item.id != turn.id))];

    return ColoredBox(
      color: const Color(0xFFE4ECE6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(text.welcome, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: turns.length,
              itemBuilder: (context, index) => _turn(turns[index], text),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 6,
              children: [
                ActionChip(label: Text(text.presetBalance), onPressed: () => _presetBalance(text, locale)),
                ActionChip(label: Text(text.presetNews), onPressed: () => _presetNews(text, locale)),
                ActionChip(label: Text(text.presetWeather), onPressed: () => _presetWeather(text, locale)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  tooltip: text.voiceBadge,
                  onPressed: () => _toggleVoice(locale),
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
                IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _send(text, locale);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: _file?.name,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(onPressed: () => _send(text, locale), child: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _turn(ChatTurn turn, AppText text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _bubble(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (turn.isVoice) Text(text.voiceBadge, style: const TextStyle(fontSize: 11)),
                  if (turn.fileName != null) Text(turn.fileName!, style: const TextStyle(fontSize: 11)),
                  Text(turn.userText),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _bubble(
              color: const Color(0xFFEFFDDE),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (turn.pending) const LinearProgressIndicator(),
                  Text(turn.pending ? text.aiThinking : turn.aiText),
                  if (turn.table != null) TableBlock(table: turn.table!),
                  if (turn.chart != null) ChartBlock(chart: turn.chart!),
                  if (turn.savedMenu != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => ref.read(menuProvider.notifier).selectById(turn.savedMenu!),
                        child: Text('${text.savedBadge(text.menuName(turn.savedMenu!))}  ✓✓'),
                      ),
                    ),
                  if (turn.awaitingConfirm && turn.extractedSchedules.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirm(turn.id, 'schedules', text),
                      child: Text(text.approveSchedules(turn.extractedSchedules.length)),
                    ),
                  if (turn.awaitingConfirm && turn.extractedBalances.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirm(turn.id, 'balances', text),
                      child: Text(text.approveBalances(turn.extractedBalances.length)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble({required Color color, required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }

  Future<void> _send(AppText text, String locale) async {
    final value = _input.text.trim();
    final file = _file;
    if (value.isEmpty && file == null) {
      _failLocal(text.emptyInput, text);
      return;
    }
    _input.clear();
    setState(() => _file = null);
    await _run(
      userText: value.isEmpty ? file!.name : value,
      isVoice: _listening,
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
          path = await api.upload(
            fileName: file.name,
            bytes: bytes,
            contentType: 'application/octet-stream',
          );
        }
        return api.submitPrompt(text: value, locale: locale, isVoice: _listening, filePath: path, fileName: file?.name);
      },
    );
  }

  Future<void> _presetBalance(AppText text, String locale) async {
    final items = ref.read(balancesProvider).asData?.value ?? const <BalanceItem>[];
    final start = SeoulClock.startOfWeek(DateTime.now());
    final week = items.where((item) => SeoulClock.inWeek(item.occurredAt, start)).toList();
    final totals = weekTotals([
      for (final item in week)
        BalancePoint(id: item.id, occurredAt: item.occurredAt, amount: item.amount, isIncome: item.isIncome),
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
    await _appendLocal(
      userText: text.presetBalance,
      aiText: summary,
      table: table,
      chart: chart,
      text: text,
    );
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
              rows: [for (final item in top) [item.country, item.title]],
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
            aiText: '${seongnam.cityName} ${seongnam.temperature.toStringAsFixed(1)}°C / ${yokohama.cityName} ${yokohama.temperature.toStringAsFixed(1)}°C',
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
  }) async {
    await _run(
      userText: userText,
      text: text,
      action: (api) => api.appendTurn(
        ChatTurn(id: '', userText: userText, aiText: aiText, table: table, chart: chart),
      ),
    );
  }

  Future<void> _run({
    required String userText,
    required AppText text,
    required Future<ChatTurn> Function(AssistantApi api) action,
    bool isVoice = false,
    String? fileName,
  }) async {
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    ref.read(localTurnsProvider.notifier).add(
          ChatTurn(id: localId, userText: userText, aiText: '', isVoice: isVoice, fileName: fileName, pending: true, localOnly: true),
        );
    _scrollDown();
    try {
      final turn = await action(ref.read(apiProvider));
      ref.read(localTurnsProvider.notifier).replace(localId, turn.copyWith(localOnly: true, pending: false));
    } catch (error) {
      ref.read(localTurnsProvider.notifier).replace(
            localId,
            ChatTurn(id: localId, userText: userText, aiText: explainError(error, text), failed: true, localOnly: true, fileName: fileName),
          );
    }
    _scrollDown();
  }

  void _failLocal(String message, AppText text) {
    ref.read(localTurnsProvider.notifier).add(
          ChatTurn(id: 'local-${DateTime.now().microsecondsSinceEpoch}', userText: message, aiText: text.emptyInput, failed: true, localOnly: true),
        );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions.toList(),
    );
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
    final ready = await _speech.initialize();
    if (!ready) {
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) => _input.text = result.recognizedWords,
      listenOptions: SpeechListenOptions(
        localeId: switch (locale) {
          'en' => 'en_US',
          'ja' => 'ja_JP',
          _ => 'ko_KR',
        },
      ),
    );
  }
}

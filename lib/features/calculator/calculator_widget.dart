import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/api/assistant_api.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/ink_icons.dart';
import 'calc_engine.dart';

class CalculatorWidget extends ConsumerWidget {
  const CalculatorWidget({super.key, required this.popupMode, this.onDrag});

  final bool popupMode;
  final GestureDragUpdateCallback? onDrag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(Localizations.localeOf(context));
    final engine = ref.watch(calcProvider);
    final calc = ref.read(calcProvider.notifier);
    final rates = ref.watch(exchangeProvider).asData?.value ?? const <ExchangeItem>[];

    final panel = Material(
      elevation: 0,
      color: InkPalette.cream,
      child: Column(
        children: [
          GestureDetector(
            onPanUpdate: onDrag,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: InkPalette.mustard,
                border: popupMode ? Border.all(color: InkPalette.ink, width: 2) : const Border(bottom: BorderSide(color: InkPalette.ink, width: 2)),
              ),
              child: Row(
                children: [
                  if (!popupMode)
                    TextButton(
                      onPressed: () => ref.read(floatProvider.notifier).open(),
                      child: Text(text.popup, style: const TextStyle(color: InkPalette.ink, fontWeight: FontWeight.w800)),
                    ),
                  const Spacer(),
                  if (popupMode)
                    IconButton(
                      tooltip: text.delete,
                      onPressed: () => ref.read(floatProvider.notifier).close(),
                      icon: const Icon(Icons.close, color: InkPalette.ink, size: 18),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                engine.display,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _applyRate(context, ref, text, rates, engine),
                    child: Text(text.applyRate, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final value = engine.numericValue;
                      if (value == null) {
                        return;
                      }
                      ref.read(insertProvider.notifier).insert(text.expenseDraft(value.round().abs()));
                    },
                    child: Text(text.sendToBalance, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.5,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final label in ['C', '⌫', '±', '÷', '7', '8', '9', '×', '4', '5', '6', '-', '1', '2', '3', '+', '0', '.', '='])
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _op(label) ? InkPalette.coral : InkPalette.ink,
                      foregroundColor: _op(label) ? InkPalette.cream : InkPalette.mustard,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: InkPalette.ink, width: 1.6)),
                    ),
                    onPressed: () => _press(calc, label),
                    child: Text(label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!popupMode) {
      return panel;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: InkPalette.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InkPalette.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: InkPalette.ink, offset: Offset(5, 5))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: panel),
    );
  }

  bool _op(String label) => '÷×-+='.contains(label);

  void _press(CalcController calc, String label) {
    switch (label) {
      case 'C':
        calc.clear();
      case '⌫':
        calc.backspace();
      case '±':
        calc.sign();
      case '=':
        calc.equals();
      case '.':
        calc.dot();
      case '÷' || '×' || '-' || '+':
        calc.op(label);
      default:
        calc.digit(label);
    }
  }

  Future<void> _applyRate(
    BuildContext context,
    WidgetRef ref,
    AppText text,
    List<ExchangeItem> rates,
    CalcEngine engine,
  ) async {
    final value = engine.numericValue;
    if (value == null) {
      return;
    }
    final latest = <String, ExchangeItem>{};
    for (final rate in rates) {
      latest.putIfAbsent(rate.currencyCode, () => rate);
    }
    if (latest.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.searchRateFirst)));
      }
      return;
    }
    final code = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(text.applyRate),
        children: [
          for (final entry in latest.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.currencyCode),
              child: Text(entry.currencyLabel),
            ),
        ],
      ),
    );
    if (code == null || !context.mounted) {
      return;
    }
    final rate = latest[code]!;
    final krw = value * rate.rateToKrw;
    final formatted = NumberFormat.decimalPattern().format(krw.round());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.krwLine('1 $code × ${formatCalc(value)} =', formatted))),
    );
  }
}

class FloatingCalculator extends ConsumerWidget {
  const FloatingCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(floatProvider);
    if (!open.open) {
      return const SizedBox.shrink();
    }
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.20).clamp(210.0, 360.0);
    final height = (screen.height * 0.35).clamp(280.0, 460.0);
    final left = (open.left ?? (screen.width - width - 20)).clamp(0.0, (screen.width - width).clamp(0.0, double.infinity));
    final top = (open.top ?? 20).clamp(0.0, (screen.height - height).clamp(0.0, double.infinity));
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: CalculatorWidget(
        popupMode: true,
        onDrag: (details) {
          ref.read(floatProvider.notifier).moveBy(details.delta.dx, details.delta.dy, screen, Size(width, height));
        },
      ),
    );
  }
}

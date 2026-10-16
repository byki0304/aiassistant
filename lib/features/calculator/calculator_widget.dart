import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/api/assistant_api.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/selectable_list.dart';
import 'calc_engine.dart';

const _rows = [
  ['C', '⌫', '±', '÷'],
  ['7', '8', '9', '×'],
  ['4', '5', '6', '-'],
  ['1', '2', '3', '+'],
  ['0', '.', '='],
];

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

    final header = popupMode
        ? GestureDetector(
            onPanUpdate: onDrag,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Container(
                height: 38,
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: const BoxDecoration(
                  gradient: Toon.rainbow,
                  border: Border(bottom: Toon.border),
                ),
                child: Row(
                  children: [
                    const ToonIcon(ToonGlyph.calculator, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(text.dragMove, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: text.closeAccount,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(floatProvider.notifier).close(),
                      icon: const ToonIcon(ToonGlyph.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              gradient: Toon.rainbow,
              borderRadius: BorderRadius.circular(14),
              border: const Border.fromBorderSide(Toon.border),
            ),
            child: Row(
              children: [
                const ToonIcon(ToonGlyph.calculator, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text.calcTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                ToonButton(label: text.popup, compact: true, color: Toon.white, onPressed: () => ref.read(floatProvider.notifier).open()),
              ],
            ),
          );

    final display = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Toon.ink,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Toon.ink, width: 2),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            engine.display,
            style: TextStyle(
              fontSize: popupMode ? 26 : 34,
              fontWeight: FontWeight.w800,
              color: Toon.sun,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );

    final actions = Row(
      children: [
        Expanded(
          child: ToonButton(
            label: text.applyRate,
            glyph: ToonGlyph.exchange,
            compact: true,
            color: Toon.coral,
            onPressed: () => _applyRate(context, ref, text, rates, engine),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ToonButton(
            label: text.sendToBalance,
            glyph: ToonGlyph.wallet,
            compact: true,
            color: Toon.butter,
            onPressed: () {
              final value = engine.numericValue;
              if (value == null) {
                return;
              }
              ref.read(insertProvider.notifier).insert(text.expenseDraft(value.round().abs()));
            },
          ),
        ),
      ],
    );

    final keys = Column(
      children: [
        for (final row in _rows)
          Expanded(
            child: Row(
              children: [
                for (final label in row)
                  Expanded(
                    flex: label == '0' ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _Key(label: label, onTap: () => _press(calc, label)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    if (popupMode) {
      return Container(
        decoration: BoxDecoration(
          color: Toon.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Toon.ink, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 6), blurRadius: 0)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), child: display),
            Expanded(
              child: Padding(padding: const EdgeInsets.fromLTRB(5, 2, 5, 6), child: keys),
            ),
          ],
        ),
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final history = SelectableList(
      title: text.calcHistory,
      dot: Toon.orange,
      emptyPose: RobotPose.point,
      emptyText: text.calcHistoryEmpty,
      selectAllLabel: text.selectAll,
      deleteLabel: text.delete,
      onDelete: (ids) async => ref.read(calcHistoryProvider.notifier).remove(ids),
      rows: [
        for (final record in ref.watch(calcHistoryProvider))
          SelectableRow(
            id: record.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    record.expression,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(width: 6),
                ToonPill(DateFormat.MMMd(locale).add_Hm().format(record.at), color: Toon.cream),
              ],
            ),
          ),
      ],
    );
    final calculator = <Widget>[header, const SizedBox(height: 10), display, const SizedBox(height: 8), actions, const SizedBox(height: 8)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth >= 500 ? 18.0 : 10.0;
        if (constraints.maxWidth >= 760) {
          return Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...calculator,
                      Expanded(child: keys),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(child: history),
              ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.all(pad),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...calculator,
                    SizedBox(height: 280, child: keys),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            history,
          ],
        );
      },
    );
  }

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

  Future<void> _applyRate(BuildContext context, WidgetRef ref, AppText text, List<ExchangeItem> rates, CalcEngine engine) async {
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
              child: Text(entry.currencyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.krwLine('1 $code × ${formatCalc(value)} =', formatted))));
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink) = switch (label) {
      '÷' || '×' || '-' || '+' => (Toon.orange, Toon.ink),
      '=' => (Toon.green, Toon.white),
      'C' || '⌫' || '±' => (Toon.steel, Toon.ink),
      _ => (Toon.navy, Toon.sun),
    };
    return Pressable(
      onTap: onTap,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Toon.ink, width: 1.8),
          boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ),
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
    final width = (screen.width * 0.22).clamp(230.0, 330.0);
    final height = (screen.height * 0.5).clamp(300.0, 440.0);
    final left = (open.left ?? (screen.width - width - 20)).clamp(0.0, (screen.width - width).clamp(0.0, double.infinity));
    final top = (open.top ?? 70).clamp(0.0, (screen.height - height).clamp(0.0, double.infinity));
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/menu_body.dart';
import '../../shared/widgets/selectable_list.dart';

const _incomeColor = Color(0xFF2F7FB8);
const _expenseColor = Color(0xFFD2553A);

/// Balance after every entry up to [now], whatever week is on screen.
int balanceAt(List<BalanceItem> items, DateTime now) {
  var total = 0;
  for (final item in items) {
    if (!item.occurredAt.isAfter(now)) {
      total += item.isIncome ? item.amount : -item.amount;
    }
  }
  return total;
}

class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  late DateTime _weekStart = SeoulClock.startOfWeek(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).toString();
    final money = NumberFormat.decimalPattern(locale);
    return ref
        .watch(balancesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => LoadFailure(error),
          data: (items) {
            final now = DateTime.now();
            final seoulNow = SeoulClock.toSeoul(now);
            final todayStart = SeoulClock.seoulMidnightToUtc(seoulNow.year, seoulNow.month, seoulNow.day);
            final tomorrowStart = todayStart.add(const Duration(days: 1));
            final newestFirst = [...items]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
            final today = newestFirst
                .where((item) => !item.occurredAt.isBefore(todayStart) && item.occurredAt.isBefore(tomorrowStart))
                .toList();
            final todayTotals = weekTotals([
              for (final item in today)
                BalancePoint(id: item.id, occurredAt: item.occurredAt, amount: item.amount, isIncome: item.isIncome),
            ]);
            final week = newestFirst.where((item) => SeoulClock.inWeek(item.occurredAt, _weekStart)).toList();
            final lastDay = SeoulClock.addWeeks(_weekStart, 1).subtract(const Duration(days: 1));
            final range =
                '${DateFormat.MMMd(locale).format(SeoulClock.toSeoul(_weekStart))} – '
                '${DateFormat.MMMd(locale).format(SeoulClock.toSeoul(lastDay))}';
            Future<void> delete(List<String> ids) => ref.read(apiProvider).deleteByIds('balance_entries', ids);

            final summary = Row(
              children: [
                Expanded(
                  child: _Summary(
                    label: text.todayExpense,
                    value: todayTotals.expense == 0 ? '0' : '-${money.format(todayTotals.expense)}',
                    color: Toon.coral,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Summary(
                    label: text.todayIncome,
                    value: todayTotals.income == 0 ? '0' : '+${money.format(todayTotals.income)}',
                    color: Toon.sky,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Summary(label: text.currentBalance, value: money.format(balanceAt(items, now)), color: Toon.leaf),
                ),
              ],
            );
            final todayTable = _EntryTable(
              key: const ValueKey('today'),
              title: text.todayEntries,
              dot: Toon.coral,
              items: today,
              firstLabel: text.columnTime,
              first: (item) => DateFormat.Hm(locale).format(SeoulClock.toSeoul(item.occurredAt)),
              money: money,
              onDelete: delete,
            );
            final weekHeader = ToonCard(
              color: Toon.butter,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  ToonButton(
                    label: '',
                    glyph: ToonGlyph.chevronLeft,
                    compact: true,
                    tooltip: text.prevWeek,
                    onPressed: () => setState(() => _weekStart = SeoulClock.addWeeks(_weekStart, -1)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(text.weekBook, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        Text(
                          range,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  ToonButton(
                    label: '',
                    glyph: ToonGlyph.chevronRight,
                    compact: true,
                    tooltip: text.nextWeek,
                    onPressed: () => setState(() => _weekStart = SeoulClock.addWeeks(_weekStart, 1)),
                  ),
                ],
              ),
            );
            final weekTable = _EntryTable(
              key: ValueKey('week-$_weekStart'),
              title: text.weekEntries,
              dot: Toon.butter,
              items: week,
              firstLabel: text.columnDate,
              first: (item) => DateFormat.Md(locale).add_E().format(SeoulClock.toSeoul(item.occurredAt)),
              money: money,
              onDelete: delete,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1000) {
                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 44,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [summary, const SizedBox(height: 12), todayTable],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 56,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [weekHeader, const SizedBox(height: 10), weekTable],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  children: [
                    summary,
                    const SizedBox(height: 12),
                    todayTable,
                    const SizedBox(height: 14),
                    weekHeader,
                    const SizedBox(height: 10),
                    weekTable,
                  ],
                );
              },
            );
          },
        );
  }
}

/// Ledger rows laid out as columns, six per page, with the chat's select-all / delete toggle.
class _EntryTable extends StatefulWidget {
  const _EntryTable({
    super.key,
    required this.title,
    required this.dot,
    required this.items,
    required this.firstLabel,
    required this.first,
    required this.money,
    required this.onDelete,
  });

  final String title;
  final Color dot;
  final List<BalanceItem> items;
  final String firstLabel;
  final String Function(BalanceItem item) first;
  final NumberFormat money;
  final Future<void> Function(List<String> ids) onDelete;

  @override
  State<_EntryTable> createState() => _EntryTableState();
}

class _EntryTableState extends State<_EntryTable> {
  static const _pageSize = 6;
  final _checked = <String>{};
  final _expanded = <String>{};
  int _page = 0;
  bool _deleting = false;

  int get _pageCount => widget.items.isEmpty ? 1 : (widget.items.length / _pageSize).ceil();

  @override
  void didUpdateWidget(_EntryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.items.map((item) => item.id).toSet();
    _checked.retainAll(ids);
    _expanded.retainAll(ids);
    _page = _page.clamp(0, _pageCount - 1);
  }

  Future<void> _delete(AppText text) async {
    final ids = _checked.toList();
    setState(() => _deleting = true);
    try {
      await widget.onDelete(ids);
      if (mounted) {
        setState(_checked.clear);
      }
    } catch (error) {
      if (mounted) {
        showToonMessage(context, explainError(error, text));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final items = widget.items;
    final visible = items.skip(_page * _pageSize).take(_pageSize).toList();
    final toggle = items.isEmpty
        ? null
        : _checked.isEmpty
        ? ToonButton(
            label: text.selectAll,
            glyph: ToonGlyph.check,
            compact: true,
            onPressed: _deleting ? null : () => setState(() => _checked.addAll(items.map((item) => item.id))),
          )
        : ToonButton(
            label: text.delete,
            glyph: ToonGlyph.trash,
            compact: true,
            color: Toon.coral,
            onPressed: _deleting ? null : () => _delete(text),
          );
    const headStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Toon.inkSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 8),
          child: ToonTitle('${widget.title} (${items.length})', dot: widget.dot, size: 14.5, trailing: toggle),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              text.emptyData,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Toon.inkSoft, fontWeight: FontWeight.w700),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 4),
            child: Row(
              children: [
                const SizedBox(width: 30),
                SizedBox(width: 64, child: Text(widget.firstLabel, style: headStyle)),
                SizedBox(width: 58, child: Text(text.columnKind, style: headStyle)),
                Expanded(child: Text(text.columnDescription, style: headStyle)),
                SizedBox(
                  width: 92,
                  child: Text(text.columnAmount, textAlign: TextAlign.right, style: headStyle),
                ),
              ],
            ),
          ),
          for (final item in visible) _row(item, text),
          if (_pageCount > 1)
            PageNumbers(count: _pageCount, current: _page, onSelect: (page) => setState(() => _page = page), label: text.pageLabel),
        ],
      ],
    );
  }

  Widget _row(BalanceItem item, AppText text) {
    final checked = _checked.contains(item.id);
    final expanded = _expanded.contains(item.id);
    final color = item.isIncome ? _incomeColor : _expenseColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
        decoration: BoxDecoration(
          color: checked ? Toon.cream : Toon.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Toon.ink, width: checked ? 2.2 : 1.6),
        ),
        child: Row(
          crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              child: Align(
                alignment: Alignment.centerLeft,
                child: RowCheck(
                  checked: checked,
                  size: 18,
                  label: '${text.selectEntry}: ${item.description}',
                  onChanged: _deleting ? null : () => setState(() => checked ? _checked.remove(item.id) : _checked.add(item.id)),
                ),
              ),
            ),
            Expanded(
              child: RowToggle(
                expanded: expanded,
                onToggle: () => setState(() => expanded ? _expanded.remove(item.id) : _expanded.add(item.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        child: RowText(widget.first(item), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      SizedBox(
                        width: 58,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              item.isIncome ? text.weekIncome : text.weekExpense,
                              style: const TextStyle(color: Toon.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RowText(item.description, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      SizedBox(
                        width: 92,
                        child: RowText(
                          '${item.isIncome ? '+' : '-'}${widget.money.format(item.amount)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ToonCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          ),
        ],
      ),
    );
  }
}

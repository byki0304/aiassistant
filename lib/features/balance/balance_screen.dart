import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/app_text.dart';
import '../../shared/errors.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/widgets/selectable_list.dart';

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
    final asyncItems = ref.watch(balancesProvider);
    final locale = Localizations.localeOf(context).toString();
    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(explainError(error, text))),
      data: (items) {
        final weekItems = items.where((item) => SeoulClock.inWeek(item.occurredAt, _weekStart)).toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        final totals = weekTotals([
          for (final item in weekItems)
            BalancePoint(id: item.id, occurredAt: item.occurredAt, amount: item.amount, isIncome: item.isIncome),
        ]);
        final label = DateFormat.MMMd(locale).format(_weekStart.toLocal());
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(onPressed: () => setState(() => _weekStart = SeoulClock.addWeeks(_weekStart, -1)), icon: const Icon(Icons.chevron_left), tooltip: text.prevWeek),
                  Expanded(
                    child: Text(
                      '$label   ${text.weekExpense} ${totals.expense}   ${text.weekIncome} ${totals.income}   ${text.weekNet} ${totals.net}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(onPressed: () => setState(() => _weekStart = SeoulClock.addWeeks(_weekStart, 1)), icon: const Icon(Icons.chevron_right), tooltip: text.nextWeek),
                ],
              ),
            ),
            Expanded(
              child: SelectableList(
                title: text.menuName('balance'),
                rows: [
                  for (final item in weekItems)
                    SelectableRow(
                      id: item.id,
                      child: Row(
                        children: [
                          Expanded(child: Text(text.balanceLine(item.description, item.amount, item.isIncome))),
                          Text(text.runningBalance(item.runningBalance), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
                emptyText: text.emptyData,
                selectAllLabel: text.selectAll,
                deleteLabel: text.delete,
                selectedLabel: text.selectedCount,
                confirmLabel: text.deleteConfirm,
                cancelLabel: text.cancel,
                onDelete: (ids) => ref.read(apiProvider).deleteByIds('balance_entries', ids),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/widgets/selectable_list.dart';
import '../../shared/errors.dart';

enum ScheduleMode { year, month, week, day }

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  ScheduleMode _mode = ScheduleMode.month;
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final asyncItems = ref.watch(schedulesProvider);
    final locale = Localizations.localeOf(context).toString();
    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(explainError(error, text))),
      data: (items) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<ScheduleMode>(
                segments: [
                  ButtonSegment(value: ScheduleMode.year, label: Text(text.year)),
                  ButtonSegment(value: ScheduleMode.month, label: Text(text.month)),
                  ButtonSegment(value: ScheduleMode.week, label: Text(text.week)),
                  ButtonSegment(value: ScheduleMode.day, label: Text(text.day)),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() => _mode = value.first),
              ),
            ),
            Expanded(flex: 3, child: _calendar(items, locale)),
            Expanded(
              flex: 2,
              child: SelectableList(
                title: text.menuName('schedules'),
                rows: [
                  for (final item in items)
                    SelectableRow(
                      id: item.id,
                      child: Text('${item.title}  ${DateFormat.MMMd(locale).add_Hm().format(item.startAt.toLocal())}'),
                    ),
                ],
                emptyText: text.emptyData,
                selectAllLabel: text.selectAll,
                deleteLabel: text.delete,
                selectedLabel: text.selectedCount,
                confirmLabel: text.deleteConfirm,
                cancelLabel: text.cancel,
                onDelete: (ids) => ref.read(apiProvider).deleteByIds('schedules', ids),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _calendar(List<ScheduleItem> items, String locale) {
    if (_mode == ScheduleMode.year) {
      return GridView.count(
        crossAxisCount: 3,
        children: [
          for (var month = 1; month <= 12; month++)
            InkWell(
              onTap: () => setState(() {
                _focused = DateTime(_focused.year, month);
                _mode = ScheduleMode.month;
              }),
              child: Card(
                child: Center(
                  child: Text(
                    DateFormat.MMM(locale).format(DateTime(_focused.year, month)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (_mode == ScheduleMode.day) {
      final dayItems = items.where((item) => _sameSeoulDay(item.startAt, _focused)).toList();
      return ListView(
        children: [
          for (final item in dayItems)
            ListTile(
              title: Text(item.title),
              subtitle: Text(DateFormat.Hm(locale).format(item.startAt.toLocal())),
            ),
          if (dayItems.isEmpty) const SizedBox.shrink(),
        ],
      );
    }
    return TableCalendar<ScheduleItem>(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2036),
      focusedDay: _focused,
      calendarFormat: _mode == ScheduleMode.week ? CalendarFormat.week : CalendarFormat.month,
      availableCalendarFormats: const {
        CalendarFormat.month: 'month',
        CalendarFormat.week: 'week',
      },
      selectedDayPredicate: (day) => isSameDay(day, _focused),
      onDaySelected: (selected, focused) => setState(() => _focused = focused),
      onPageChanged: (focused) => _focused = focused,
      eventLoader: (day) => items.where((item) => _sameSeoulDay(item.startAt, day)).toList(),
      startingDayOfWeek: StartingDayOfWeek.monday,
    );
  }

  bool _sameSeoulDay(DateTime instant, DateTime day) {
    final seoul = SeoulClock.toSeoul(instant);
    return seoul.year == day.year && seoul.month == day.month && seoul.day == day.day;
  }
}

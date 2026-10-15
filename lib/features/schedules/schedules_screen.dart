import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/ink_icons.dart';
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final calendarHeight = switch (_mode) {
                    ScheduleMode.month => 300.0,
                    ScheduleMode.year => 260.0,
                    ScheduleMode.week => 150.0,
                    ScheduleMode.day => 180.0,
                  };
                  const listHeight = 168.0;
                  final list = SelectableList(
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
                  );
                  final calendar = _calendar(items, locale);
                  if (constraints.maxHeight >= calendarHeight + listHeight) {
                    return Column(
                      children: [
                        SizedBox(height: calendarHeight, child: calendar),
                        Expanded(child: list),
                      ],
                    );
                  }
                  return ListView(
                    children: [
                      SizedBox(height: calendarHeight, child: calendar),
                      SizedBox(height: listHeight, child: list),
                    ],
                  );
                },
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
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: InkPalette.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: InkPalette.ink, width: 2),
                    boxShadow: const [BoxShadow(color: InkPalette.ink, offset: Offset(3, 3))],
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.MMM(locale).format(DateTime(_focused.year, month)),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: InkPalette.ink),
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const header = 44.0;
        const daysOfWeek = 16.0;
        final rows = _mode == ScheduleMode.week ? 1 : 6;
        final available = constraints.maxHeight.isFinite ? constraints.maxHeight : 320.0;
        final rowHeight = ((available - header - daysOfWeek) / rows).clamp(28.0, 42.0);
        return TableCalendar<ScheduleItem>(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2036),
      focusedDay: _focused,
      rowHeight: rowHeight,
      daysOfWeekHeight: daysOfWeek,
      calendarFormat: _mode == ScheduleMode.week ? CalendarFormat.week : CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: EdgeInsets.symmetric(vertical: 4),
        titleTextStyle: TextStyle(fontWeight: FontWeight.w800, color: InkPalette.ink),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: InkPalette.ink, fontWeight: FontWeight.w800, fontSize: 12),
        weekendStyle: TextStyle(color: InkPalette.coral, fontWeight: FontWeight.w800, fontSize: 12),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: InkPalette.ink, fontWeight: FontWeight.w700),
        weekendTextStyle: const TextStyle(color: InkPalette.coral, fontWeight: FontWeight.w700),
        todayDecoration: const BoxDecoration(color: InkPalette.coral, shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: InkPalette.cream, fontWeight: FontWeight.w800),
        selectedDecoration: BoxDecoration(
          color: InkPalette.mustard,
          shape: BoxShape.circle,
          border: Border.all(color: InkPalette.ink, width: 2),
        ),
        selectedTextStyle: const TextStyle(color: InkPalette.ink, fontWeight: FontWeight.w800),
        markerDecoration: const BoxDecoration(color: InkPalette.teal, shape: BoxShape.circle),
      ),
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
      },
    );
  }

  bool _sameSeoulDay(DateTime instant, DateTime day) {
    final seoul = SeoulClock.toSeoul(instant);
    return seoul.year == day.year && seoul.month == day.month && seoul.day == day.day;
  }
}

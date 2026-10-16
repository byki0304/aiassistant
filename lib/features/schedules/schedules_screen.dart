import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../shared/api/assistant_api.dart';
import '../../shared/app_text.dart';
import '../../shared/logic/domain.dart';
import '../../shared/state/providers.dart';
import '../../shared/theme/toon.dart';
import '../../shared/theme/toon_icons.dart';
import '../../shared/theme/toon_widgets.dart';
import '../../shared/widgets/menu_body.dart';
import '../../shared/widgets/selectable_list.dart';

enum ScheduleMode { year, month, week, day }

/// Deep tones so white pill text stays readable.
const _pillColors = [Color(0xFFE0609A), Color(0xFF3B8FD0), Color(0xFF4FA36B), Color(0xFF8B63D6), Color(0xFFE07A3E), Toon.navy];
const _cancelledColor = Color(0xFF9AA0AB);
const _weekendColor = Color(0xFFD2553A);

/// Seoul calendar date of [instant], as a UTC midnight like the dates table_calendar hands out.
DateTime seoulDay(DateTime instant) {
  final seoul = SeoulClock.toSeoul(instant);
  return DateTime.utc(seoul.year, seoul.month, seoul.day);
}

DateTime _dateOnly(DateTime day) => DateTime.utc(day.year, day.month, day.day);

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  ScheduleMode _mode = ScheduleMode.month;
  DateTime _focused = DateTime.now();
  late Set<DateTime> _days = _todayAndTomorrow();
  bool _allDays = false;

  static Set<DateTime> _todayAndTomorrow() {
    final today = seoulDay(DateTime.now());
    return {today, today.add(const Duration(days: 1))};
  }

  void _toggleDay(DateTime day) {
    final key = _dateOnly(day);
    setState(() {
      if (_allDays) {
        _allDays = false;
        _days = {key};
      } else if (!_days.remove(key)) {
        _days.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context));
    final locale = Localizations.localeOf(context).toString();
    return ref
        .watch(schedulesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => LoadFailure(error),
          data: (items) {
            final controls = Row(
              children: [
                Expanded(
                  child: SegmentedButton<ScheduleMode>(
                    showSelectedIcon: false,
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
                const SizedBox(width: 8),
                ToonButton(
                  label: text.allDates,
                  glyph: _allDays ? ToonGlyph.check : null,
                  compact: true,
                  color: _allDays ? Toon.sun : Toon.white,
                  onPressed: () => setState(() => _allDays = !_allDays),
                ),
              ],
            );
            final list = _list(items, text, locale);

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxHeight >= 600) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        controls,
                        const SizedBox(height: 8),
                        Expanded(flex: 3, child: _calendarCard(items, text, locale)),
                        const SizedBox(height: 10),
                        Expanded(flex: 2, child: list),
                      ],
                    ),
                  );
                }
                final calendarHeight = switch (_mode) {
                  ScheduleMode.month => 400.0,
                  ScheduleMode.year => 260.0,
                  ScheduleMode.week => 170.0,
                  ScheduleMode.day => 200.0,
                };
                return ListView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  children: [
                    controls,
                    const SizedBox(height: 8),
                    SizedBox(height: calendarHeight, child: _calendarCard(items, text, locale)),
                    const SizedBox(height: 10),
                    SizedBox(height: 430, child: list),
                  ],
                );
              },
            );
          },
        );
  }

  /// Schedules of the chosen dates, latest first, six per page.
  Widget _list(List<ScheduleItem> items, AppText text, String locale) {
    final chosen = items.where((item) => _allDays || _days.contains(seoulDay(item.startAt))).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return SelectableList(
      title: text.scheduleList,
      dot: Toon.pink,
      pageSize: 6,
      pageLabel: text.pageLabel,
      rows: [
        for (final item in chosen)
          SelectableRow(
            id: item.id,
            group: DateFormat.yMMMEd(locale).format(seoulDay(item.startAt)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, color: item.cancelled ? Toon.inkSoft : Toon.ink),
                  ),
                ),
                const SizedBox(width: 6),
                ToonPill(
                  item.allDay
                      ? text.allDates
                      : '${DateFormat.Hm(locale).format(SeoulClock.toSeoul(item.startAt))}~'
                            '${DateFormat.Hm(locale).format(SeoulClock.toSeoul(item.endAt))}',
                  color: Toon.pink.withValues(alpha: 0.55),
                ),
                if (item.cancelled) ...[const SizedBox(width: 6), _WhitePill(text.cancelledBadge, color: Toon.red)],
              ],
            ),
          ),
      ],
      emptyText: _allDays || _days.isNotEmpty ? text.emptyData : text.pickDates,
      selectAllLabel: text.selectAll,
      deleteLabel: text.delete,
      onDelete: (ids) => ref.read(apiProvider).deleteByIds('schedules', ids),
    );
  }

  Widget _calendarCard(List<ScheduleItem> items, AppText text, String locale) {
    return ToonCard(
      padding: const EdgeInsets.all(6),
      shadow: false,
      child: switch (_mode) {
        ScheduleMode.year => _yearGrid(items, locale),
        ScheduleMode.day => _dayList(items, text, locale),
        _ => _calendar(items, locale),
      },
    );
  }

  Widget _yearGrid(List<ScheduleItem> items, String locale) {
    const colors = [Toon.pink, Toon.butter, Toon.sky, Toon.leaf, Toon.lilac, Toon.coral];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 4 : 3;
        final rows = (12 / columns).ceil();
        final ratio = (constraints.maxWidth / columns) / (constraints.maxHeight / rows);
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: ratio.clamp(0.8, 4.0),
          padding: EdgeInsets.zero,
          children: [
            for (var month = 1; month <= 12; month++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Pressable(
                  onTap: () => setState(() {
                    _focused = DateTime(_focused.year, month);
                    _mode = ScheduleMode.month;
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors[(month - 1) % colors.length].withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Toon.ink, width: 1.8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.MMM(locale).format(DateTime(_focused.year, month)),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${items.where((item) => _inMonth(item.startAt, _focused.year, month)).length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Toon.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dayList(List<ScheduleItem> items, AppText text, String locale) {
    final day = _dateOnly(_focused);
    final dayItems = items.where((item) => seoulDay(item.startAt) == day).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            DateFormat.yMMMMEEEEd(locale).format(_focused),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: dayItems.isEmpty
              ? const Center(child: RobotArt(RobotPose.head, height: 46))
              : ListView(
                  children: [
                    for (final item in dayItems)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: Row(
                          children: [
                            ToonPill(DateFormat.Hm(locale).format(SeoulClock.toSeoul(item.startAt)), color: Toon.butter),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            if (item.cancelled) _WhitePill(text.cancelledBadge, color: Toon.red),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _calendar(List<ScheduleItem> items, String locale) {
    final byDay = <DateTime, List<ScheduleItem>>{};
    for (final item in items) {
      byDay.putIfAbsent(seoulDay(item.startAt), () => []).add(item);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const header = 44.0;
        const daysOfWeek = 18.0;
        final rows = _mode == ScheduleMode.week ? 1 : 6;
        final available = constraints.maxHeight.isFinite ? constraints.maxHeight : 320.0;
        final rowHeight = ((available - header - daysOfWeek) / rows).clamp(28.0, 96.0);
        final numberSize = math.min(24.0, rowHeight - 6);
        final pillHeight = ((rowHeight - numberSize - 6) / 3 - 1.5).clamp(0.0, 15.0);
        final pills = pillHeight >= 7;

        Widget dayCell(DateTime day, {bool outside = false}) {
          final selected = _allDays ? byDay.containsKey(_dateOnly(day)) : _days.contains(_dateOnly(day));
          final today = isSameDay(day, seoulDay(DateTime.now()));
          final weekend = day.weekday >= DateTime.saturday;
          return Align(
            alignment: pills ? Alignment.topCenter : Alignment.center,
            child: Container(
              width: numberSize,
              height: numberSize,
              margin: EdgeInsets.only(top: pills ? 2 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Toon.sun
                    : today
                    ? Toon.sky
                    : null,
                shape: BoxShape.circle,
                border: selected ? Border.all(color: Toon.ink, width: 1.8) : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: math.min(13.0, numberSize * 0.55),
                  fontWeight: selected || today ? FontWeight.w900 : FontWeight.w700,
                  color: outside ? Toon.ink.withValues(alpha: 0.3) : (weekend ? _weekendColor : Toon.ink),
                ),
              ),
            ),
          );
        }

        return TableCalendar<ScheduleItem>(
          locale: locale,
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
            titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Toon.ink),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Toon.ink, fontWeight: FontWeight.w800, fontSize: 11.5),
            weekendStyle: TextStyle(color: _weekendColor, fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
          calendarBuilders: CalendarBuilders<ScheduleItem>(
            defaultBuilder: (context, day, _) => dayCell(day),
            todayBuilder: (context, day, _) => dayCell(day),
            selectedBuilder: (context, day, _) => dayCell(day),
            outsideBuilder: (context, day, _) => dayCell(day, outside: true),
            markerBuilder: (context, day, events) {
              if (events.isEmpty) {
                return null;
              }
              final shown = ([...events]..sort((a, b) => a.startAt.compareTo(b.startAt))).take(3).toList();
              if (!pills) {
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in shown)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: _pillColorOf(item), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              }
              return Positioned(
                left: 2,
                right: 2,
                top: numberSize + 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1.5),
                        child: _CalendarPill(item: item, height: pillHeight, color: _pillColorOf(item)),
                      ),
                  ],
                ),
              );
            },
          ),
          availableCalendarFormats: const {CalendarFormat.month: 'month', CalendarFormat.week: 'week'},
          selectedDayPredicate: (day) => _allDays ? byDay.containsKey(_dateOnly(day)) : _days.contains(_dateOnly(day)),
          onDaySelected: (selected, focused) {
            _focused = focused;
            _toggleDay(selected);
          },
          onPageChanged: (focused) => _focused = focused,
          eventLoader: (day) => byDay[_dateOnly(day)] ?? const [],
          startingDayOfWeek: StartingDayOfWeek.monday,
        );
      },
    );
  }

  Color _pillColorOf(ScheduleItem item) {
    if (item.cancelled) {
      return _cancelledColor;
    }
    return _pillColors[item.id.codeUnits.fold(0, (sum, unit) => sum + unit) % _pillColors.length];
  }

  bool _inMonth(DateTime instant, int year, int month) {
    final seoul = SeoulClock.toSeoul(instant);
    return seoul.year == year && seoul.month == month;
  }
}

/// A day-cell pill: the first six characters of the title in white, scaled to the cell.
class _CalendarPill extends StatelessWidget {
  const _CalendarPill({required this.item, required this.height, required this.color});

  final ScheduleItem item;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = item.title.characters.take(6).toString();
    return Tooltip(
      message: item.title,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height * 0.3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: TextStyle(
            color: Toon.white,
            fontSize: height * 0.68,
            height: 1,
            fontWeight: FontWeight.w800,
            decoration: item.cancelled ? TextDecoration.lineThrough : null,
            decorationColor: Toon.white,
          ),
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Toon.ink, width: 1.6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Toon.white, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.2),
      ),
    );
  }
}

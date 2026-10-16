import 'package:ai_assistant/features/schedules/schedules_screen.dart';
import 'package:ai_assistant/features/weather/weather_screen.dart';
import 'package:ai_assistant/shared/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => ProviderScope(
  overrides: [
    schedulesProvider.overrideWith((ref) => Stream.value(const [])),
    weatherProvider.overrideWith((ref) => Stream.value(const [])),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    home: Scaffold(
      body: Center(child: SizedBox(width: 384, height: 300, child: child)),
    ),
  ),
);

void main() {
  for (final mode in ['Year', 'Month', 'Week', 'Day']) {
    testWidgets('schedules $mode scrolls when dragged on the calendar', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host(const SchedulesScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(mode));
      await tester.pump(const Duration(seconds: 1));
      final controls = tester.getBottomLeft(find.text('Month'));
      await tester.dragFrom(Offset(controls.dx + 150, controls.dy + 120), const Offset(0, -250), touchSlopY: 20);
      await tester.pump(const Duration(seconds: 1));
      final outer = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(outer.pixels, greaterThan(20), reason: 'max ${outer.maxScrollExtent}');
    });
  }

  testWidgets('weather scrolls as one column on a short pane', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_host(const WeatherScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ListView), findsWidgets);
    final title = find.textContaining('(0)');
    final before = tester.getTopLeft(title).dy;
    await tester.dragFrom(tester.getCenter(find.byType(ListView).first) - const Offset(0, 120), const Offset(0, -200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(title).dy, lessThan(before));
  });
}

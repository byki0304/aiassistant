import 'package:ai_assistant/features/calculator/calculator_widget.dart';
import 'package:ai_assistant/features/schedules/schedules_screen.dart';
import 'package:ai_assistant/features/weather/weather_screen.dart';
import 'package:ai_assistant/shared/state/providers.dart';
import 'package:ai_assistant/shared/widgets/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {int font = 3, int line = 4, Size pane = const Size(384, 700)}) => ProviderScope(
  overrides: [
    schedulesProvider.overrideWith((ref) => Stream.value(const [])),
    weatherProvider.overrideWith((ref) => Stream.value(const [])),
    exchangeProvider.overrideWith((ref) => Stream.value(const [])),
    fontLevelProvider.overrideWith(() => LevelController('fontLevel', font)),
    lineLevelProvider.overrideWith(() => LevelController('lineLevel', line)),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    builder: (context, child) => ReadingScale(child: child!),
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(size: pane, child: child),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the default levels leave text exactly as designed', (tester) async {
    await tester.pumpWidget(_host(const ReadingSettings()));
    final context = tester.element(find.textContaining('Text size'));
    expect(MediaQuery.textScalerOf(context).scale(10), 10);
    expect(MediaQuery.maybeLineHeightScaleFactorOverrideOf(context), isNull);
  });

  testWidgets('the bars change text size and line spacing by 10% a level', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_host(const ReadingSettings()));

    await tester.tap(find.text('Text size · Level 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getCenter(slider) + Offset(tester.getSize(slider).width / 2 - 16, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Text size · Level 5'), findsWidgets);
    expect(MediaQuery.textScalerOf(tester.element(find.byType(Slider))).scale(10), closeTo(12, 0.001));

    await tester.tap(find.text('Line spacing · Level 4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(tester.getCenter(slider) - Offset(tester.getSize(slider).width / 2 - 16, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Line spacing · Level 1'), findsWidgets);
    expect(MediaQuery.maybeLineHeightScaleFactorOverrideOf(tester.element(slider)), closeTo(1.45 * 0.7, 0.001));

    await tester.tap(find.text('Default'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Line spacing · Level 4'), findsWidgets);
  });

  for (final (font, line) in [(5, 5), (1, 1)]) {
    for (final (name, screen) in [
      ('weather', const WeatherScreen() as Widget),
      ('schedules', const SchedulesScreen()),
      ('calculator', const CalculatorWidget(popupMode: false)),
    ]) {
      testWidgets('$name fits at text level $font and line level $line', (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_host(screen, font: font, line: line));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

import 'package:ai_assistant/shared/widgets/selectable_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = 'A very long record line that cannot possibly fit on one line of this narrow list pane at all';

Widget _host() {
  return MaterialApp(
    locale: const Locale('en'),
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 500,
        child: SelectableList(
          title: 'Records',
          emptyText: 'Empty',
          selectAllLabel: 'Select all',
          deleteLabel: 'Delete',
          onDelete: (_) async {},
          rows: const [
            SelectableRow(id: 'a', child: RowText(_long)),
            SelectableRow(id: 'b', child: RowText(_long)),
          ],
        ),
      ),
    ),
  );
}

int? _lines(WidgetTester tester, int index) => tester.widget<Text>(find.text(_long).at(index)).maxLines;

bool _checked(WidgetTester tester, int index) => tester.widget<RowCheck>(find.byType(RowCheck).at(index)).checked;

void main() {
  testWidgets('a tap expands only that row and never checks it on phones', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_host());

    await tester.tap(find.text(_long).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lines(tester, 0), isNull);
    expect(_lines(tester, 1), 1);
    expect(_checked(tester, 0), isFalse);

    await tester.tap(find.text(_long).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lines(tester, 0), 1);

    await tester.tap(find.byType(RowCheck).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_checked(tester, 0), isTrue);
    expect(_lines(tester, 0), 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop needs a double click to expand', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_host());

    await tester.tap(find.text(_long).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lines(tester, 0), 1);

    await tester.tap(find.text(_long).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(_long).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lines(tester, 0), isNull);
    expect(_checked(tester, 0), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}

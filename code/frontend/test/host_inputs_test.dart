import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/pages/host_activity_page.dart';
import 'package:campus_companion/theme/app_theme.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('NumberStepper accepts a typed value and clamps it', (
    tester,
  ) async {
    var value = 8;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 300,
            child: NumberStepper(
              value: value,
              min: 2,
              max: 200,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '120');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 120);

    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 200, reason: 'typed values above max are clamped');

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(value, 199);
  });

  testWidgets('two steppers side by side on a phone still show their numbers', (
    tester,
  ) async {
    // iPhone 17 Pro width; the Host form has 20pt padding and a 12pt gap.
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: NumberStepper(
                    value: 6,
                    min: 2,
                    max: 20,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberStepper(
                    value: 12,
                    min: 2,
                    max: 50,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      final size = tester.getSize(find.byWidget(field));
      expect(
        size.width,
        greaterThanOrEqualTo(40),
        reason: 'number field is squeezed to ${size.width}pt and clips digits',
      );
    }
    expect(find.text('6'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('WhenPickerSheet returns the chosen day and time', (
    tester,
  ) async {
    DateTime? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showModalBottomSheet<DateTime>(
                context: context,
                isScrollControlled: true,
                builder: (_) => WhenPickerSheet(
                  initial: DateTime.now().add(
                    const Duration(days: 1, hours: 1),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('When is it?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Tomorrow'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(result, isNotNull);
    expect(result!.day, tomorrow.day);
    expect(result!.minute % 5, 0, reason: 'time wheel moves in 5-minute steps');
  });
}

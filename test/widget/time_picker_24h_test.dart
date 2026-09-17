import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('24-Hour TimePicker Format Tests', () {
    testWidgets('verifies alwaysUse24HourFormat defaults to true when configured',
        (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold();
            },
          ),
        ),
      );

      final mediaQuery = MediaQuery.of(capturedContext);
      expect(mediaQuery.alwaysUse24HourFormat, isTrue);
    });

    testWidgets('shows 24-hour TimePicker dial without AM/PM toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 23, minute: 0),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                  },
                  child: const Text('Open TimePicker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open TimePicker'));
      await tester.pumpAndSettle();

      // Verify "23" is displayed in the digital time header
      expect(find.text('23'), findsWidgets);

      // Verify AM and PM toggles are NOT displayed in 24-hour mode
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });
  });
}

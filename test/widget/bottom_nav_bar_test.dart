import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/bottom_nav_bar.dart';

void main() {
  group('BottomNavBar Widget Tests', () {
    testWidgets('renders all tabs and responds to taps', (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) {
                selectedIndex = index;
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('ภารกิจ'), findsOneWidget);
      expect(find.text('ปฏิทิน'), findsOneWidget);
      expect(find.text('ตั้งค่า'), findsOneWidget);
      expect(selectedIndex, 0);

      // Tap on Calendar tab (index 1)
      await tester.tap(find.text('ปฏิทิน'));
      await tester.pumpAndSettle();
      expect(selectedIndex, 1);

      // Tap on Settings tab (index 2)
      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();
      expect(selectedIndex, 2);

      // Tap on Tasks tab (index 0)
      await tester.tap(find.text('ภารกิจ'));
      await tester.pumpAndSettle();
      expect(selectedIndex, 0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/adaptive_nav_bar.dart';

void main() {
  group('AdaptiveNavBar Rail Tests', () {
    testWidgets('renders compact NavigationRail (extended=false, minWidth=76, no trailing FAB)',
        (WidgetTester tester) async {
      int selectedIndex = 0;

      // Set surface size to landscape tablet (1280 x 800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AdaptiveNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) {
                    selectedIndex = index;
                  },
                ),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );

      // Verify NavigationRail is rendered
      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);

      final NavigationRail rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.extended, isFalse);
      expect(rail.minWidth, 76.0);
      expect(rail.trailing, isNull);

      // Verify destinations
      expect(rail.destinations.length, 3);
    });
  });
}

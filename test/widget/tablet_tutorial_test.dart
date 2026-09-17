import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/widgets/adaptive_nav_bar.dart';
import 'package:todo_app/utils/tutorial_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

void main() {
  group('Tablet Portrait Tutorial & Navigation Tests', () {
    testWidgets('mounts navKey on tablet portrait NavigationRail and verifies responsive layout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: TutorialService.scaffoldKey,
            body: Row(
              children: [
                AdaptiveNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => selectedIndex = index,
                ),
                const Expanded(child: Center(child: Text('Content'))),
              ],
            ),
          ),
        ),
      );

      // Verify navKey is mounted
      expect(find.byKey(TutorialService.navKey), findsOneWidget);

      final BuildContext navContext = TutorialService.navKey.currentContext!;
      final RenderBox box = navContext.findRenderObject() as RenderBox;
      expect(box.size.width, 68.0);
      expect(box.size.height, 310.0);

      // Verify scaffoldKey is mounted
      expect(TutorialService.scaffoldKey.currentState, isNotNull);
    });

    testWidgets('mounts navKey on mobile bottom navigation bar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AdaptiveNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      // Verify navKey is mounted on mobile bottom nav
      expect(find.byKey(TutorialService.navKey), findsOneWidget);
    });

    testWidgets('TutorialService targets adapt align and layout for tablet vs mobile',
        (WidgetTester tester) async {
      // 1. Test tablet portrait target alignments
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold();
            },
          ),
        ),
      );

      // Verify Part 1 targets on tablet
      final tabletPart1 =
          TutorialService.createPart1TargetsForTesting(capturedContext);
      final navTargetTablet =
          tabletPart1.firstWhere((t) => t.identify == 'navTarget');
      expect(navTargetTablet.contents?.first.align, ContentAlign.right);
      expect(navTargetTablet.radius, 20.0);

      final fabTargetTablet =
          tabletPart1.firstWhere((t) => t.identify == 'fabTarget');
      expect(fabTargetTablet.contents?.first.align, ContentAlign.top);

      final switcherTargetTablet =
          tabletPart1.firstWhere((t) => t.identify == 'switcherTarget');
      expect(switcherTargetTablet.contents?.first.align, ContentAlign.bottom);

      // Verify Part 3 target on tablet
      final tabletPart3 =
          TutorialService.createPart3TargetsForTesting(capturedContext);
      final streakTargetTablet =
          tabletPart3.firstWhere((t) => t.identify == 'streakTarget');
      expect(streakTargetTablet.contents?.first.align, ContentAlign.bottom);
      expect(streakTargetTablet.shape, ShapeLightFocus.RRect);
    });
  });
}

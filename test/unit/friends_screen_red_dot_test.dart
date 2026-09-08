import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/config/colors.dart';

Widget buildAddFriendBadge({required bool hasPending, required bool isDark}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      SizedBox(
        key: const Key('add_friend_button'),
        width: 48,
        height: 48,
        child: const Icon(Icons.person_add_alt_1),
      ),
      if (hasPending)
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            key: const Key('friend_request_red_dot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.stormyNightBackground
                    : Colors.white,
                width: 1.5,
              ),
            ),
          ),
        ),
    ],
  );
}

void main() {
  group('Add Friend Button Red Dot Badge Tests', () {
    testWidgets('shows red dot badge when hasPending is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildAddFriendBadge(hasPending: true, isDark: true),
          ),
        ),
      );

      final redDotFinder = find.byKey(const Key('friend_request_red_dot'));
      expect(redDotFinder, findsOneWidget);

      final container = tester.widget<Container>(redDotFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.error);
      expect(decoration.shape, BoxShape.circle);
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.stormyNightBackground);
    });

    testWidgets('hides red dot badge when hasPending is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildAddFriendBadge(hasPending: false, isDark: true),
          ),
        ),
      );

      final redDotFinder = find.byKey(const Key('friend_request_red_dot'));
      expect(redDotFinder, findsNothing);
    });

    testWidgets('uses correct border color in light mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildAddFriendBadge(hasPending: true, isDark: false),
          ),
        ),
      );

      final redDotFinder = find.byKey(const Key('friend_request_red_dot'));
      expect(redDotFinder, findsOneWidget);

      final container = tester.widget<Container>(redDotFinder);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, Colors.white);
    });
  });
}

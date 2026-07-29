import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/providers/auth_provider.dart';

void main() {
  group('calculateStreakUpdate', () {
    const today = '2026-05-25';
    const yesterday = '2026-05-24';

    test('returns null when already logged in today', () {
      final update = calculateStreakUpdate(
        data: {'currentStreak': 4, 'lastLoginDate': today, 'longestStreak': 7},
        todayString: today,
        yesterdayString: yesterday,
      );

      expect(update, isNull);
    });

    test('increments current streak after yesterday login', () {
      final update = calculateStreakUpdate(
        data: {
          'currentStreak': 4,
          'lastLoginDate': yesterday,
          'longestStreak': 7,
        },
        todayString: today,
        yesterdayString: yesterday,
      );

      expect(update, {
        'currentStreak': 5,
        'lastLoginDate': today,
        'longestStreak': 7,
      });
    });

    test('starts missing login date at one', () {
      final update = calculateStreakUpdate(
        data: {'currentStreak': 0, 'longestStreak': 0},
        todayString: today,
        yesterdayString: yesterday,
      );

      expect(update, {
        'currentStreak': 1,
        'lastLoginDate': today,
        'longestStreak': 1,
      });
    });

    test('resets older login date to one', () {
      final update = calculateStreakUpdate(
        data: {
          'currentStreak': 9,
          'lastLoginDate': '2026-05-20',
          'longestStreak': 12,
        },
        todayString: today,
        yesterdayString: yesterday,
      );

      expect(update, {
        'currentStreak': 1,
        'lastLoginDate': today,
        'longestStreak': 12,
      });
    });

    test('updates longest streak when the new streak beats it', () {
      final update = calculateStreakUpdate(
        data: {
          'currentStreak': 7,
          'lastLoginDate': yesterday,
          'longestStreak': 7,
        },
        todayString: today,
        yesterdayString: yesterday,
      );

      expect(update, {
        'currentStreak': 8,
        'lastLoginDate': today,
        'longestStreak': 8,
      });
    });
  });
}

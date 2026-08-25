import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/xp_system.dart';

void main() {
  group('fixed level progression', () {
    test('requires 500 XP for every level', () {
      expect(getXpRequiredForNextLevel(1), 500);
      expect(getXpRequiredForNextLevel(5), 500);
      expect(getXpRequiredForNextLevel(6), 500);
      expect(getXpRequiredForNextLevel(10), 500);
      expect(getXpRequiredForNextLevel(11), 500);
      expect(getXpRequiredForNextLevel(15), 500);
    });

    test('calculates current level progress from total XP', () {
      final progress = calculateLevelProgress(3200);

      expect(progress.currentLevel, 7);
      expect(progress.progressXp, 200);
      expect(progress.requiredXp, 500);
      expect(progress.progressValue, 0.4);
    });

    test('calculates partial progress inside the current level', () {
      final progress = calculateLevelProgress(3550);

      expect(progress.currentLevel, 8);
      expect(progress.progressXp, 50);
      expect(progress.requiredXp, 500);
      expect(progress.progressValue, 0.1);
    });
  });

  group('personal task diminishing returns', () {
    test('tasks 1 through 3 receive full XP', () {
      expect(
        calculateDiminishedPersonalTaskXp(baseXp: 100, completedTaskNumber: 1),
        100,
      );
      expect(
        calculateDiminishedPersonalTaskXp(baseXp: 100, completedTaskNumber: 3),
        100,
      );
    });

    test('tasks receive full XP without diminishing returns', () {
      expect(
        calculateDiminishedPersonalTaskXp(baseXp: 100, completedTaskNumber: 4),
        100,
      );
      expect(
        calculateDiminishedPersonalTaskXp(baseXp: 100, completedTaskNumber: 7),
        100,
      );
    });

    test('resets the daily counter on a new date', () {
      final counter = normalizePersonalTaskCounter(
        completedToday: 6,
        lastResetDate: '2026-05-24',
        todayString: '2026-05-25',
      );

      expect(counter.completedToday, 0);
      expect(counter.resetDate, '2026-05-25');
    });

    test('keeps the daily counter on the same date', () {
      final counter = normalizePersonalTaskCounter(
        completedToday: 4,
        lastResetDate: '2026-05-25',
        todayString: '2026-05-25',
      );

      expect(counter.completedToday, 4);
      expect(counter.resetDate, '2026-05-25');
    });

    test('restore removes the originally awarded XP', () {
      expect(
        calculateRestoredPersonalTaskXpRemoval(awardedXP: 15, baseXP: 30),
        15,
      );
    });

    test('restore falls back to base XP when awarded XP is missing', () {
      expect(
        calculateRestoredPersonalTaskXpRemoval(awardedXP: 0, baseXP: 30),
        30,
      );
    });

    test('restore never removes negative XP', () {
      expect(
        calculateRestoredPersonalTaskXpRemoval(awardedXP: 0, baseXP: -30),
        0,
      );
    });
  });

  group('fast completion reward blocking', () {
    final createdAt = DateTime(2026, 6, 10, 12);

    test('blocks completion before five minutes', () {
      expect(
        isCompletionRewardBlockedByAge(
          createdAt: createdAt,
          completedAt: createdAt.add(const Duration(minutes: 4, seconds: 59)),
        ),
        true,
      );
    });

    test('allows completion at five minutes', () {
      expect(
        isCompletionRewardBlockedByAge(
          createdAt: createdAt,
          completedAt: createdAt.add(const Duration(minutes: 5)),
        ),
        false,
      );
    });

    test('blocks completion before created time', () {
      expect(
        isCompletionRewardBlockedByAge(
          createdAt: createdAt,
          completedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        true,
      );
    });
  });

  group('burst completion allowance reward blocking', () {
    final now = DateTime(2026, 6, 10, 12, 0, 0);

    test('allows up to 4 tasks in rapid succession', () {
      final recent = <DateTime>[];

      // 1st task
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: now,
        ),
        false,
      );
      recent.add(now);

      // 2nd task (5 seconds later)
      final t2 = now.add(const Duration(seconds: 5));
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: t2,
        ),
        false,
      );
      recent.add(t2);

      // 3rd task (10 seconds later)
      final t3 = now.add(const Duration(seconds: 10));
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: t3,
        ),
        false,
      );
      recent.add(t3);

      // 4th task (15 seconds later)
      final t4 = now.add(const Duration(seconds: 15));
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: t4,
        ),
        false,
      );
      recent.add(t4);

      // 5th task (20 seconds later - exceeds 4 tasks quota)
      final t5 = now.add(const Duration(seconds: 20));
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: t5,
        ),
        true,
      );
    });

    test('allows more tasks after the 1-minute window expires', () {
      final recent = <DateTime>[
        now,
        now.add(const Duration(seconds: 2)),
        now.add(const Duration(seconds: 4)),
        now.add(const Duration(seconds: 6)),
      ];

      // 5th task after 61 seconds
      final tAfterWindow = now.add(const Duration(seconds: 61));
      expect(
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: recent,
          completedAt: tAfterWindow,
        ),
        false,
      );
    });
  });
}

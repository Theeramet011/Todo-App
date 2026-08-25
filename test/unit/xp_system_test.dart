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

  group('rapid completion cooldown reward blocking', () {
    final firstCompletedAt = DateTime(2026, 6, 10, 12, 0, 0);

    test('allows first task when lastCompletedAt is null', () {
      expect(
        isCompletionRewardBlockedByCooldown(
          lastCompletedAt: null,
          completedAt: firstCompletedAt,
        ),
        false,
      );
    });

    test('blocks second task completed within 44 seconds', () {
      expect(
        isCompletionRewardBlockedByCooldown(
          lastCompletedAt: firstCompletedAt,
          completedAt: firstCompletedAt.add(const Duration(seconds: 44)),
        ),
        true,
      );
    });

    test('allows second task completed at 45 seconds', () {
      expect(
        isCompletionRewardBlockedByCooldown(
          lastCompletedAt: firstCompletedAt,
          completedAt: firstCompletedAt.add(const Duration(seconds: 45)),
        ),
        false,
      );
    });

    test('allows second task completed after 45 seconds', () {
      expect(
        isCompletionRewardBlockedByCooldown(
          lastCompletedAt: firstCompletedAt,
          completedAt: firstCompletedAt.add(const Duration(minutes: 2)),
        ),
        false,
      );
    });
  });
}
